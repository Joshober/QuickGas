#!/bin/sh
# Docker entrypoint script that generates .env and starts nginx

# Generate .env file from environment variables
echo "Generating .env file from Railway environment variables..."
if /scripts/generate-config.sh; then
    echo "✓ .env file generated successfully"
else
    echo "⚠ Warning: .env generation had issues, continuing anyway..."
fi

# Test nginx configuration
echo "Testing nginx configuration..."
if nginx -t; then
    echo "✓ Nginx configuration is valid"
else
    echo "✗ Nginx configuration test failed!"
    exit 1
fi

# Start nginx in foreground
echo "Starting nginx..."
exec nginx -g 'daemon off;'

