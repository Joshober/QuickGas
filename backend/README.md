# QuickGas Backend

Lightweight backend server for QuickGas mobile app.

## Features

- **Payment Processing**: Stripe payment intent creation and confirmation
- **Push Notifications**: Firebase Cloud Messaging integration
- **Route Optimization**: Caching layer for OpenRouteService API

## Deployment Options

### Option 1: Render (Free Tier Available)
- Free tier: 512MB RAM, sufficient for small apps
- **Recommended for under 50 users**

1. Create account at [render.com](https://render.com)
2. Create new Web Service
3. Connect your repository
4. Set environment variables
5. Deploy!

### Option 2: Railway (Paid - $5/month credit)
- No free tier, but $5/month credit
- More reliable for production

1. Create account at [railway.app](https://railway.app)
2. Create new project
3. Add environment variables
4. Deploy!

### Option 3: Fly.io (Free Tier)
- 3 shared-cpu-1x VMs for free
- Good alternative to Railway

## Setup

1. Install dependencies:
```bash
npm install
```

2. Copy `.env.example` to `.env` and fill in:
   - `STRIPE_SECRET_KEY`: Your Stripe secret key
   - `FIREBASE_SERVICE_ACCOUNT`: Firebase Admin SDK JSON (optional)
   - `OPENROUTESERVICE_API_KEY`: OpenRouteService API key (optional)

3. Run locally:
```bash
npm run dev
```

## Environment Variables

- `PORT`: Server port (default: 3000)
- `STRIPE_SECRET_KEY`: Stripe secret key (required for payments)
- `FIREBASE_SERVICE_ACCOUNT`: Firebase Admin SDK JSON (optional, for push notifications)
- `OPENROUTESERVICE_API_KEY`: OpenRouteService API key (optional)

## API Endpoints

### Payment
- `POST /api/payments/create-intent` - Create Stripe payment intent
- `POST /api/payments/confirm` - Confirm payment
- `POST /api/payments/cancel` - Cancel payment

### Notifications
- `POST /api/notifications/send` - Send push notification to single user
- `POST /api/notifications/send-multiple` - Send push notification to multiple users

### Routes
- `POST /api/routes/optimize` - Optimize route using OpenRouteService

### Health
- `GET /health` - Health check endpoint

## Cost Comparison

For **under 50 users**:
- **Firebase only**: $0/month (free tier sufficient)
- **Backend on Render**: $0/month (free tier)
- **Backend on Railway**: $5/month (after $5 credit)
- **Backend on Fly.io**: $0/month (free tier)

**Recommendation**: Use **Render's free tier** for the backend if you want server-side payment processing and push notifications.

