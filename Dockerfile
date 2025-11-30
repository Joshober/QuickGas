# Build stage
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy pubspec files (pubspec.lock is optional)
COPY pubspec.yaml ./
COPY pubspec.lock* ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the application
COPY . .

# Create .env file from Railway environment variables
# Railway provides environment variables during build
# Note: If .env already exists, this will append to it
RUN chmod +x scripts/create-env.sh 2>/dev/null || true && \
    touch .env && \
    (if [ -n "$GOOGLE_MAPS_API_KEY" ]; then echo "GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY" >> .env; fi) && \
    (if [ -n "$STRIPE_PUBLISHABLE_KEY" ]; then echo "STRIPE_PUBLISHABLE_KEY=$STRIPE_PUBLISHABLE_KEY" >> .env; fi) && \
    (if [ -n "$BACKEND_URL" ]; then echo "BACKEND_URL=$BACKEND_URL" >> .env; fi) && \
    (if [ -n "$OPENROUTESERVICE_API_KEY" ]; then echo "OPENROUTESERVICE_API_KEY=$OPENROUTESERVICE_API_KEY" >> .env; fi) && \
    echo "Environment variables configured for build"

# Build Flutter web app with proper base href for root deployment
RUN flutter build web --release --base-href /

# Runtime stage - use nginx to serve the built web app
FROM nginx:alpine

# Copy built web app from build stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]

