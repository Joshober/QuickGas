#!/bin/sh
# Docker entrypoint script that generates config.js and starts nginx

# Generate config.js from environment variables
/scripts/generate-config.sh

# Start nginx
exec nginx -g 'daemon off;'

