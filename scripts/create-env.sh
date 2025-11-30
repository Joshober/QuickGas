#!/bin/sh
# Create .env file from Railway environment variables
# This script runs during Docker build

touch .env

# Railway provides these as environment variables during build
if [ -n "$GOOGLE_MAPS_API_KEY" ]; then
  echo "GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY" >> .env
fi

if [ -n "$STRIPE_PUBLISHABLE_KEY" ]; then
  echo "STRIPE_PUBLISHABLE_KEY=$STRIPE_PUBLISHABLE_KEY" >> .env
fi

if [ -n "$BACKEND_URL" ]; then
  echo "BACKEND_URL=$BACKEND_URL" >> .env
fi

if [ -n "$OPENROUTESERVICE_API_KEY" ]; then
  echo "OPENROUTESERVICE_API_KEY=$OPENROUTESERVICE_API_KEY" >> .env
fi

echo "Created .env file with available environment variables"

