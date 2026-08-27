# TuneLoad Stream Resolver Server

A tiny, free HTTP backend that resolves a direct audio stream URL for a
YouTube video using **yt-dlp**, running on a server IP that isn't bot-flagged.

The Flutter app uses this as a **fallback** when direct client-side extraction
(`youtube_explode_dart`) is blocked by YouTube — e.g. when the user's device
IP is flagged ("Sign in to confirm you're not a bot" / HTTP 403).

## API

| Endpoint        | Description                                                    |
|-----------------|---------------------------------------------------------------|
| `GET /health`   | Returns `{"ok": true, "yt_dlp": "<version>"}`                  |
| `GET /stream?vid=<11-char-id>` | Returns `{"url":"...","title":"...","duration":n}` |
| `GET /update`   | Forces a `yt-dlp` self-update (keeps it working)              |

The `/stream` endpoint is rate-limited (`5 per minute` per IP) to prevent
abuse. Optional HTTP Basic auth can be enabled via `BASIC_AUTH_USER` /
`BASIC_AUTH_PASS` env vars.

## Run locally (test)

```bash
cd server
python -m venv .venv
.\.venv\Scripts\activate          # Windows
# source .venv/bin/activate        # Linux/macOS
pip install -r requirements.txt
set PORT=8080 && python server.py # Windows
# PORT=8080 python server.py      # Linux/macOS
```

Then test:

```
curl "http://127.0.0.1:8080/stream?vid=DPaqlPFznBI"
```

## Deploy for free (always-on)

You **cannot** run yt-dlp inside a standard Cloudflare Worker (it's Python).
Use one of these always-on free options instead:

### Option 1 — Oracle Cloud Free Tier (recommended, truly free forever)
1. Create a free Oracle Cloud account → **Compute → Instances → Create**.
2. Choose an **Always Free** shape (e.g. `VM.Standard.A1.Flex` ARM, 4 OCPU,
   24 GB RAM) or a small eligible shape.
3. Ubuntu image. After it boots, SSH in and:
   ```bash
   sudo apt update
   sudo apt install -y python3-venv python3-pip docker.io
   cd ~ && git clone <your-repo> res && cd res/server
   docker build -t tuneload-res . && docker run -d -p 8080:8080 --restart unless-stopped tuneload-res
   ```
4. Open port **8080** in the instance's security list / network security group.
5. Get the public IP → `curl "http://<ip>:8080/stream?vid=DPaqlPFznBI"`.

### Option 2 — Render free tier (Recommended: free, no card, always-on)
Render auto-builds the `Dockerfile` from your GitHub repo and gives you a
stable **https** URL. No credit card is needed for a free web service.

1. Push this repo (with `server/`) to GitHub.
2. [render.com](https://render.com) → **New → Web Service** → connect your
   repo.
3. Render will auto-detect the `Dockerfile`. If not:
   - **Environment:** `Docker`
   - **Root Directory:** `server`  ⚠️ (this is what makes the Dockerfile's
     `COPY server.py .` resolve correctly)
   - **Plan:** `Free`
4. Deploy. You'll get a URL like `https://tuneload-res.onrender.com`.
5. Verify: open `https://<your-url>/health` in a browser → `{"ok":true,...}`.

> Note: Render free web services **sleep on idle** (~15 min inactivity). The
> first request after sleeping takes ~30-50s to cold-start — the app already
> waits up to 75s for this, so once you trigger it (e.g. play a song on a
> blocked network), it wakes up and plays.

### Option 3 — Any cheap VPS (Hetzner/DigitalOcean, ~$4-5/mo)
Not free, but the most reliable. Same docker steps as Option 1.

## Point the app at it

Edit `lib/config.dart`:

```dart
static const String streamServerBaseUrl = 'https://your-server.example.com';
```

> **HTTPS required for Android.** Android blocks plain-HTTP by default. The
> free options above (Oracle, Render, Fly) all give you a TLS/https URL. If
> you self-host over plain HTTP, enable cleartext via
> `android:usesCleartextTraffic="true"` in the manifest instead.

## Why a server? How do we "keep it working"?

YouTube changes its extraction frequently. The client library
(`youtube_explode_dart`) lags behind those changes. The server instead runs
**yt-dlp**, the community-maintained tool that updates itself. On boot and
once a day, the server runs `yt-dlp -U` (self-update), so it keeps working
with **zero code changes** on your side. That's the maintenance answer.

## Notes
- The stream URL returned is a `googlevideo.com` URL that works on any device.
- Rate limit (5/min/IP) is intentionally low — the app only calls this as a
  fallback, so real traffic is minimal and stays within free tiers.
- Set `BASIC_AUTH_USER`/`BASIC_AUTH_PASS` and put the same credentials in
  `lib/config.dart` if the server is public.
