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
from typing import Optional

from flask import Flask, Response, jsonify, request
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import yt_dlp

app = Flask(__name__)
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


@app.get("/health")
def health():
    return jsonify({"ok": True, "yt_dlp": yt_dlp.version.__version__})


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
        ydl_opts = {
            "format": "bestaudio/best",
            "noplaylist": True,
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(vid, download=False)

        if not info or info.get("_type") == "playlist":
            return jsonify({"error": "no video found"}), 404

        # Prefer a direct progressive/audio-only webm/m4a URL that just_audio
        # can stream.
        url = None
        for f in info.get("formats", []):
            if f.get("url") and f.get("acodec") not in ("none", None):
                url = f["url"]
                break
        if not url:
            url = info.get("url") or info.get("webpage_url")

        if not url:
            return jsonify({"error": "no playable stream"}), 404

        return jsonify(
            {
                "url": url,
                "title": info.get("title"),
                "duration": info.get("duration"),
            }
        )
    except yt_dlp.utils.DownloadError as e:
        return jsonify({"error": "download_error", "detail": str(e)}), 502
    except Exception as e:  # noqa: BLE001
        return jsonify({"error": "internal", "detail": str(e)}), 500


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
