#!/usr/bin/env python3
"""
TuneLoad stream resolver.
Exposes a tiny HTTP API that resolves a direct audio stream URL for a YouTube
video using yt-dlp on the server's (non-flagged) network.

This runs on the SERVER, not in the Flutter app. The app calls it as a
fallback when direct client-side extraction (youtube_explode_dart) is blocked
by YouTube (e.g. the user's IP is bot-flagged).

Endpoints:
    GET /health          -> {"ok": true, "version": "..."}
    GET /stream?vid=ID   -> {"url": "...", "title": "...", "duration": 123}
    GET /update          -> run `yt-dlp -U` to self-update it

Optional auth: set BASIC_AUTH_USER / BASIC_AUTH_PASS env vars to require
HTTP Basic auth on every request.
"""

import os
import re
import subprocess
import sys
import threading
import time
import urllib.request
from typing import Optional

from flask import Flask, Response, jsonify, request
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import yt_dlp

import base64
import tempfile

app = Flask(__name__)

UA = (
    "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"
)
limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["5 per minute"],
    storage_uri="memory://",
)

BASIC_AUTH_USER = os.environ.get("BASIC_AUTH_USER", "")
BASIC_AUTH_PASS = os.environ.get("BASIC_AUTH_PASS", "")

_UPDATE_LOCK = threading.Lock()
_LAST_UPDATE = 0.0
UPDATE_INTERVAL = 60 * 60 * 24  # refresh yt-dlp binary once a day


def _materialize_cookies() -> str:
    """Writes YouTube cookies to a temp file if provided via env var.

    Cookies solve YouTube's "Sign in to confirm you're not a bot" on flagged
    IPs. Provide them as base64 (Netscape/cookies.txt format) in
    `YTDLP_COOKIES_B64` so no file upload is needed on Render.
    """
    b64 = os.environ.get("YTDLP_COOKIES_B64", "")
    if not b64:
        return ""
    try:
        data = base64.b64decode(b64)
        fd, path = tempfile.mkstemp(suffix=".txt")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(data.decode("utf-8"))
        return path
    except Exception as e:  # noqa: BLE001
        print(f"[warn] could not decode YTDLP_COOKIES_B64: {e}", flush=True)
        return ""


COOKIES_FILE = _materialize_cookies()


def _youtube_id(video_id: str) -> bool:
    """Basic sanity check on a YouTube video id to avoid SSRF/garbage."""
    return bool(re.fullmatch(r"[A-Za-z0-9_-]{11}", video_id))


def _check_auth() -> Optional[Response]:
    if not BASIC_AUTH_USER:
        return None
    auth = request.authorization
    if (
        auth
        and auth.username == BASIC_AUTH_USER
        and auth.password == BASIC_AUTH_PASS
    ):
        return None
    return Response(
        "Unauthorized", 401, {"WWW-Authenticate": 'Basic realm="TuneLoad"'}
    )


def _ensure_updated():
    """Refreshes yt-dlp so it keeps working as YouTube changes.

    Runs in a background thread and is best-effort. Never delays or crashes
    a request, and a failed update (e.g. GitHub rate limit) is retried soon
    instead of waiting a whole day.
    """
    global _LAST_UPDATE
    now = time.time()
    if now - _LAST_UPDATE < UPDATE_INTERVAL:
        return

    def _run():
        global _LAST_UPDATE
        with _UPDATE_LOCK:
            if time.time() - _LAST_UPDATE < UPDATE_INTERVAL:
                return
            try:
                result = subprocess.run(
                    [sys.executable, "-m", "yt_dlp", "-U"],
                    capture_output=True,
                    timeout=120,
                )
                if result.returncode == 0:
                    _LAST_UPDATE = time.time()
                else:
                    _LAST_UPDATE = time.time() - (UPDATE_INTERVAL - 900)
            except Exception:
                _LAST_UPDATE = time.time() - (UPDATE_INTERVAL - 900)

    threading.Thread(target=_run, daemon=True).start()


# Player clients to try in order. YouTube bot-checks some clients on flagged
# IPs; rotating through them (esp. `tv` / `android`) usually gets past it
# without cookies on most networks.
PLAYER_CLIENTS = [
    "default",
    "tv",
    "android",
    "ios",
    "web_embedded",
    "tv_embedded",
]


def _info_with_clients(video_id):
    last_err = None
    for client in PLAYER_CLIENTS:
        opts = {
            "format": "bestaudio/best",
            "noplaylist": True,
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "extractor_args": {"youtube": {"player_client": [client]}},
        }
        if os.path.exists(COOKIES_FILE):
            opts["cookiefile"] = COOKIES_FILE
        try:
            with yt_dlp.YoutubeDL(opts) as ydl:
                return ydl.extract_info(video_id, download=False)
        except Exception as e:  # noqa: BLE001
            last_err = e
            continue
    raise last_err


def _pick_audio(info):
    """Returns the best audio (url, mime) from extracted format info."""
    candidates = []
    for f in info.get("formats", []):
        if f.get("url") and f.get("acodec") not in ("none", None):
            candidates.append(f)
    if not candidates:
        return None
    # Prefer m4a/webm audio-only over progressive (video+audio) fallbacks.
    def _rank(f):
        audio_only = f.get("vcodec") in ("none", None)
        return (audio_only, f.get("tbr") or 0)

    candidates.sort(key=_rank, reverse=True)
    f = candidates[0]
    mime = (f.get("ext") or "").lower()
    if mime in ("m4a", "mp4"):
        mime = "audio/mp4"
    elif mime == "webm":
        mime = "audio/webm"
    else:
        mime = "application/octet-stream"
    return f["url"], mime


def _resolve_audio(info):
    if not info or info.get("_type") == "playlist":
        raise ValueError("no video found")
    picked = _pick_audio(info)
    if not picked:
        raise ValueError("no playable stream")
    return picked


@app.get("/health")
def health():
    return jsonify(
        {
            "ok": True,
            "yt_dlp": yt_dlp.version.__version__,
            "cookies": bool(COOKIES_FILE and os.path.exists(COOKIES_FILE)),
        }
    )


@app.get("/stream")
@limiter.limit("5 per minute")
def stream():
    auth = _check_auth()
    if auth:
        return auth

    vid = request.args.get("vid", "")
    if not _youtube_id(vid):
        return jsonify({"error": "invalid video id"}), 400

    try:
        _ensure_updated()
        info = _info_with_clients(vid)
        url, _ = _resolve_audio(info)
        return jsonify(
            {
                "url": url,
                "title": info.get("title"),
                "duration": info.get("duration"),
            }
        )
    except yt_dlp.utils.DownloadError as e:
        return jsonify({"error": "download_error", "detail": str(e)}), 502
    except ValueError as e:
        return jsonify({"error": str(e)}), 404
    except Exception as e:  # noqa: BLE001
        return jsonify({"error": "internal", "detail": str(e)}), 500


@app.get("/proxy")
@limiter.limit("6 per minute")
def proxy():
    """Streams (relays) the audio bytes to the client.

    google stream URLs are IP-locked to the requester, so a URL-returning
    proxy doesn't work cross-IP. Instead we download the audio on the server
    (from the server's own IP, with cookies) and stream the bytes back to the
    app. The app plays this endpoint directly.
    """
    auth = _check_auth()
    if auth:
        return auth

    vid = request.args.get("vid", "")
    if not _youtube_id(vid):
        return jsonify({"error": "invalid video id"}), 400

    try:
        _ensure_updated()
        info = _info_with_clients(vid)
        url, mime = _resolve_audio(info)
    except yt_dlp.utils.DownloadError as e:
        return jsonify({"error": "download_error", "detail": str(e)}), 502
    except ValueError as e:
        return jsonify({"error": str(e)}), 404
    except Exception as e:  # noqa: BLE001
        return jsonify({"error": "internal", "detail": str(e)}), 500

    req = urllib.request.Request(url, headers={"User-Agent": UA})
    upstream = urllib.request.urlopen(req, timeout=60)

    def generate():
        try:
            while True:
                chunk = upstream.read(64 * 1024)
                if not chunk:
                    break
                yield chunk
        finally:
            upstream.close()

    resp = Response(generate(), mimetype=mime)
    resp.headers["Cache-Control"] = "no-store"
    resp.headers["Accept-Ranges"] = "bytes"
    return resp


@app.get("/update")
def update():
    auth = _check_auth()
    if auth:
        return auth
    _ensure_updated()
    return jsonify({"ok": True})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    # Flask dev server is fine for low-traffic / self-hosting.
    # For production run gunicorn:  gunicorn -w 2 -b 0.0.0.0:8080 server:app
    app.run(host="0.0.0.0", port=port)
