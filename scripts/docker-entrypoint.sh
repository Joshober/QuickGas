#!/bin/sh
# Docker entrypoint script that generates .env and starts nginx

# Generate .env file from environment variables
echo "[ENTRYPOINT] Generating .env file from Railway environment variables..."
/scripts/generate-config.sh || echo "[ENTRYPOINT] Warning: .env generation had issues"

# Test nginx configuration
echo "[ENTRYPOINT] Testing nginx configuration..."
nginx -t || {
    echo "[ENTRYPOINT] ERROR: Nginx configuration test failed!"
    exit 1
}

# Start nginx in foreground
echo "[ENTRYPOINT] Starting nginx..."
exec nginx -g 'daemon off;'

