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
# Railway makes environment variables available during build
# Note: Use ARG to make them available in the build context
ARG GOOGLE_MAPS_API_KEY
ARG STRIPE_PUBLISHABLE_KEY
ARG BACKEND_URL
ARG OPENROUTESERVICE_API_KEY

RUN touch .env && \
    echo "Creating .env file from Railway environment variables..." && \
    ([ -n "$GOOGLE_MAPS_API_KEY" ] && echo "GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY" >> .env || true) && \
    ([ -n "$STRIPE_PUBLISHABLE_KEY" ] && echo "STRIPE_PUBLISHABLE_KEY=$STRIPE_PUBLISHABLE_KEY" >> .env || true) && \
    ([ -n "$BACKEND_URL" ] && echo "BACKEND_URL=$BACKEND_URL" >> .env || true) && \
    ([ -n "$OPENROUTESERVICE_API_KEY" ] && echo "OPENROUTESERVICE_API_KEY=$OPENROUTESERVICE_API_KEY" >> .env || true) && \
    echo "Environment variables configured for build" && \
    (cat .env || echo "No environment variables found")

# Build Flutter web app with proper base href for root deployment
# The --base-href / will replace $FLUTTER_BASE_HREF in index.html
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

