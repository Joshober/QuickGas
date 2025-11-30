#!/bin/sh
# Generate .env file from Railway environment variables at runtime
# This file will be served by nginx and loaded by flutter_dotenv

ENV_FILE="/usr/share/nginx/html/.env"

# Create .env file from environment variables
echo "Creating .env file at $ENV_FILE"
touch "$ENV_FILE" || {
    echo "Error: Failed to create .env file"
    exit 1
}

# Write environment variables
COUNT=0
if [ -n "$GOOGLE_MAPS_API_KEY" ]; then
  echo "GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY" >> "$ENV_FILE"
  COUNT=$((COUNT + 1))
fi

if [ -n "$STRIPE_PUBLISHABLE_KEY" ]; then
  echo "STRIPE_PUBLISHABLE_KEY=$STRIPE_PUBLISHABLE_KEY" >> "$ENV_FILE"
  COUNT=$((COUNT + 1))
fi

if [ -n "$BACKEND_URL" ]; then
  echo "BACKEND_URL=$BACKEND_URL" >> "$ENV_FILE"
  COUNT=$((COUNT + 1))
fi

if [ -n "$OPENROUTESERVICE_API_KEY" ]; then
  echo "OPENROUTESERVICE_API_KEY=$OPENROUTESERVICE_API_KEY" >> "$ENV_FILE"
  COUNT=$((COUNT + 1))
fi

echo "Generated .env file with $COUNT environment variables"

