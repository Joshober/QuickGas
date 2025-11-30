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

# Create placeholder .env file for Flutter build (required by pubspec.yaml assets)
# The actual .env will be generated at runtime from Railway environment variables
RUN touch .env && echo "# Placeholder .env file - will be replaced at runtime" > .env

# Build Flutter web app with proper base href for root deployment
# The --base-href / will replace $FLUTTER_BASE_HREF in index.html
RUN flutter build web --release --base-href /

# Runtime stage - use nginx to serve the built web app
FROM nginx:alpine

# Install bash for scripts
RUN apk add --no-cache bash

# Copy built web app from build stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy runtime scripts (ensure scripts directory exists)
RUN mkdir -p /scripts
COPY scripts/generate-config.sh /scripts/generate-config.sh
COPY scripts/docker-entrypoint.sh /scripts/docker-entrypoint.sh
RUN chmod +x /scripts/*.sh

# Expose port 80
EXPOSE 80

# Use entrypoint script to generate config and start nginx
ENTRYPOINT ["/scripts/docker-entrypoint.sh"]

