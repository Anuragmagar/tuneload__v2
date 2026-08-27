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

# Keep it working across YouTube changes: refresh the yt-dlp binary on boot.
CMD ["sh", "-c", "python -m yt_dlp -U && gunicorn -w 2 -b 0.0.0.0:8080 server:app"]
