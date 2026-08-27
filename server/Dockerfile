FROM python:3.12-slim

WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.deno/bin:${PATH}"

# yt-dlp since 2025.11.12 REQUIRES an external JavaScript runtime (Deno)
# plus the yt-dlp-ejs challenge solver to handle YouTube's bot challenges
# (po_token / "n" / signature). Without it, YouTube returns
# "Sign in to confirm you're not a bot" or "The page needs to be reloaded."
# Build deps (git) + runtime deps (curl, unzip for Deno, ca-certificates for TLS).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl unzip git \
    && rm -rf /var/lib/apt/lists/*

# Install Deno (recommended JS runtime for yt-dlp).
RUN curl -fsSL https://deno.land/install.sh | sh

COPY requirements.txt .
# yt-dlp[default] includes the yt-dlp-ejs JS challenge-solver component.
RUN pip install --no-cache-dir -r requirements.txt

COPY server.py .

ENV PORT=8080
EXPOSE 8080

# --timeout must be generous: Render web services cold-start after idle, and
# yt-dlp extraction + first Deno challenge solve can take a while. The app
# waits up to 75s, so we allow workers 90s. Default (30s) causes Render 502s.
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "--timeout", "90", "--graceful-timeout", "90", "server:app"]
