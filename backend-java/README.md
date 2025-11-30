# QuickGas Backend (Java Spring Boot)

Java Spring Boot backend for QuickGas mobile app with PostgreSQL database.

## Features

- **Payment Processing**: Stripe payment intent creation and confirmation
- **Push Notifications**: Firebase Cloud Messaging integration
- **Route Optimization**: Integration with OpenRouteService API
- **PostgreSQL Database**: Persistent data storage

## Prerequisites

- Java 17 or higher
- Maven 3.6+
- PostgreSQL 12+ (or use Docker)
- Stripe account (for payments)
- Firebase project (for push notifications, optional)

## Setup

### 1. Database Setup

#### Using Docker (Recommended)
```bash
docker run --name quickgas-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=quickgas \
  -p 5432:5432 \
  -d postgres:15
```

#### Manual Setup
1. Install PostgreSQL
2. Create database:
```sql
CREATE DATABASE quickgas;
```

3. Run migration script:
```bash
psql -U postgres -d quickgas -f src/main/resources/db/migration/V1__init_schema.sql
```

### 2. Environment Variables

Create a `.env` file or set environment variables:

```env
# Database
DATABASE_URL=jdbc:postgresql://localhost:5432/quickgas
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres

# Server
PORT=8080
SERVER_ADDRESS=localhost
SERVER_BASE_URL=http://localhost:8080  # Full base URL for image URLs

# Stripe
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key

# Firebase (optional)
FIREBASE_SERVICE_ACCOUNT={"type":"service_account",...}
FIREBASE_ENABLED=true

# OpenRouteService (optional)
OPENROUTESERVICE_API_KEY=your_api_key

# CORS
CORS_ALLOWED_ORIGINS=*
```

### 3. Build and Run

```bash
# Build
mvn clean package

# Run
mvn spring-boot:run

# Or run the JAR
java -jar target/quickgas-backend-1.0.0.jar
```

## API Endpoints

### Health Check
- `GET /health` - Health check endpoint

### Payment
- `POST /api/payments/create-intent` - Create Stripe payment intent
  ```json
  {
    "amount": 100.50,
    "currency": "usd",
    "metadata": {"orderId": "123"}
  }
  ```

- `POST /api/payments/confirm` - Confirm payment
  ```json
  {
    "paymentIntentId": "pi_xxx"
  }
  ```

- `POST /api/payments/cancel` - Cancel payment
  ```json
  {
    "paymentIntentId": "pi_xxx"
  }
  ```

### Notifications
- `POST /api/notifications/send` - Send push notification to single user
  ```json
  {
    "fcmToken": "token",
    "title": "Title",
    "body": "Body",
    "data": {"key": "value"}
  }
  ```

- `POST /api/notifications/send-multiple` - Send push notification to multiple users
  ```json
  {
    "fcmTokens": ["token1", "token2"],
    "title": "Title",
    "body": "Body",
    "data": {"key": "value"}
  }
  ```

### Routes
- `POST /api/routes/optimize` - Optimize route using OpenRouteService
  ```json
  {
    "locations": [[-122.4, 37.8], [-122.5, 37.9]],
    "apiKey": "optional_api_key"
  }
  ```

### Images
- `POST /api/images/upload` - Upload image (multipart/form-data)
  - `orderId`: Order ID
  - `imageType`: Type of image (e.g., 'delivery_photo')
  - `file`: Image file
  - Returns: `{ "id": "...", "url": "http://...", ... }`

- `GET /api/images/{imageId}` - Get image by ID
  - Returns: Image binary data

- `GET /api/images/order/{orderId}` - Get all images for an order
  - Returns: Array of image objects

- `DELETE /api/images/{imageId}` - Delete image
  - Returns: `{ "success": true }`

## Database Schema

The database includes:
- `users` - User information (mirrors Firestore)
- `orders` - Order information (mirrors Firestore)
- `payment_transactions` - Payment transaction records

## Deployment

### Using Docker

1. Build Docker image:
```bash
docker build -t quickgas-backend .
```

2. Run container:
```bash
docker run -p 8080:8080 \
  -e DATABASE_URL=jdbc:postgresql://host.docker.internal:5432/quickgas \
  -e STRIPE_SECRET_KEY=sk_test_xxx \
  quickgas-backend
```

### Using Docker Compose

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: quickgas
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  backend:
    build: .
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: jdbc:postgresql://postgres:5432/quickgas
      DATABASE_USERNAME: postgres
      DATABASE_PASSWORD: postgres
      STRIPE_SECRET_KEY: ${STRIPE_SECRET_KEY}
    depends_on:
      - postgres

volumes:
  postgres_data:
```

## Development

### Running Tests
```bash
mvn test
```

### Code Formatting
The project uses standard Java formatting. Consider using:
- IntelliJ IDEA code formatter
- Google Java Style Guide

## Troubleshooting

### Database Connection Issues
- Ensure PostgreSQL is running
- Check database credentials
- Verify network connectivity

### Firebase Not Working
- Check `FIREBASE_SERVICE_ACCOUNT` JSON format
- Ensure `FIREBASE_ENABLED=true`
- Verify Firebase Admin SDK credentials

### Stripe Errors
- Verify `STRIPE_SECRET_KEY` is set correctly
- Check Stripe API key permissions
- Ensure using correct environment (test/live)

## License

MIT

