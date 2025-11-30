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

# Create .env file from build arguments (Railway environment variables)
# Railway automatically passes environment variables as build args
ARG GOOGLE_MAPS_API_KEY=""
ARG STRIPE_PUBLISHABLE_KEY=""
ARG BACKEND_URL=""
ARG OPENROUTESERVICE_API_KEY=""

RUN touch .env && \
    [ -n "$GOOGLE_MAPS_API_KEY" ] && echo "GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY" >> .env || true && \
    [ -n "$STRIPE_PUBLISHABLE_KEY" ] && echo "STRIPE_PUBLISHABLE_KEY=$STRIPE_PUBLISHABLE_KEY" >> .env || true && \
    [ -n "$BACKEND_URL" ] && echo "BACKEND_URL=$BACKEND_URL" >> .env || true && \
    [ -n "$OPENROUTESERVICE_API_KEY" ] && echo "OPENROUTESERVICE_API_KEY=$OPENROUTESERVICE_API_KEY" >> .env || true

# Build Flutter web app with proper base href for root deployment
RUN flutter build web --release --web-renderer html --base-href /

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

