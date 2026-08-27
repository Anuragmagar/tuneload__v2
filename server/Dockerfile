FROM python:3.12-slim

WORKDIR /app

# Requirement: certificate bundle for YouTube TLS.
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY server.py .

# Pre-fetch yt-dlp's default binary cache is unnecessary; pip installs it.
ENV PORT=8080

EXPOSE 8080

# Keep it working across YouTube changes: the app refreshes the yt-dlp binary
# in the background (best-effort, never crashes the container), so just start.
#
# --timeout must be generous: Render web services cold-start after idle, and
# yt-dlp extraction can occasionally take a while. The app waits up to 75s, so
# we allow workers 90s. The default (30s) makes Render return 502 on slow
# first/cold requests.
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "--timeout", "90", "--graceful-timeout", "90", "server:app"]
