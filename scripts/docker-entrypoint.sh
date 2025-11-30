#!/bin/sh
# Docker entrypoint script that generates .env and starts nginx

set -e

# Generate .env file from environment variables
echo "Generating .env file from Railway environment variables..."
/scripts/generate-config.sh

# Test nginx configuration
echo "Testing nginx configuration..."
nginx -t

# Start nginx in foreground
echo "Starting nginx..."
exec nginx -g 'daemon off;'

