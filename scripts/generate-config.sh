#!/bin/sh
# Generate .env file from Railway environment variables at runtime
# This file will be served by nginx and loaded by flutter_dotenv

ENV_FILE="/usr/share/nginx/html/.env"

# Create .env file from environment variables
touch "$ENV_FILE"

if [ -n "$GOOGLE_MAPS_API_KEY" ]; then
  echo "GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY" >> "$ENV_FILE"
fi

if [ -n "$STRIPE_PUBLISHABLE_KEY" ]; then
  echo "STRIPE_PUBLISHABLE_KEY=$STRIPE_PUBLISHABLE_KEY" >> "$ENV_FILE"
fi

if [ -n "$BACKEND_URL" ]; then
  echo "BACKEND_URL=$BACKEND_URL" >> "$ENV_FILE"
fi

if [ -n "$OPENROUTESERVICE_API_KEY" ]; then
  echo "OPENROUTESERVICE_API_KEY=$OPENROUTESERVICE_API_KEY" >> "$ENV_FILE"
fi

echo "Generated .env file with environment variables"

