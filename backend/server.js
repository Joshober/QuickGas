const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const stripe = require('stripe');
const admin = require('firebase-admin');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin (for push notifications)
let firebaseInitialized = false;
try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    firebaseInitialized = true;
    console.log('Firebase Admin initialized');
  }
} catch (error) {
  console.log('Firebase Admin not initialized (optional):', error.message);
}

// Initialize Stripe
const stripeClient = stripe(process.env.STRIPE_SECRET_KEY);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Payment Routes
app.post('/api/payments/create-intent', async (req, res) => {
  try {
    const { amount, currency = 'usd', metadata = {} } = req.body;

    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'Invalid amount' });
    }

    const paymentIntent = await stripeClient.paymentIntents.create({
      amount: Math.round(amount * 100), // Convert to cents
      currency: currency.toLowerCase(),
      metadata: metadata,
      automatic_payment_methods: {
        enabled: true,
      },
    });

    res.json({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    });
  } catch (error) {
    console.error('Payment intent creation error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/payments/confirm', async (req, res) => {
  try {
    const { paymentIntentId } = req.body;

    if (!paymentIntentId) {
      return res.status(400).json({ error: 'Payment intent ID required' });
    }

    const paymentIntent = await stripeClient.paymentIntents.retrieve(
      paymentIntentId,
    );

    res.json({
      status: paymentIntent.status,
      paymentIntentId: paymentIntent.id,
    });
  } catch (error) {
    console.error('Payment confirmation error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/payments/cancel', async (req, res) => {
  try {
    const { paymentIntentId } = req.body;

    if (!paymentIntentId) {
      return res.status(400).json({ error: 'Payment intent ID required' });
    }

    const paymentIntent = await stripeClient.paymentIntents.cancel(
      paymentIntentId,
    );

    res.json({
      status: paymentIntent.status,
      paymentIntentId: paymentIntent.id,
    });
  } catch (error) {
    console.error('Payment cancellation error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Push Notification Routes
app.post('/api/notifications/send', async (req, res) => {
  try {
    if (!firebaseInitialized) {
      return res.status(503).json({
        error: 'Firebase Admin not initialized',
      });
    }

    const { fcmToken, title, body, data = {} } = req.body;

    if (!fcmToken || !title || !body) {
      return res.status(400).json({
        error: 'fcmToken, title, and body are required',
      });
    }

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...Object.keys(data).reduce((acc, key) => {
          acc[key] = String(data[key]);
          return acc;
        }, {}),
      },
      token: fcmToken,
    };

    const response = await admin.messaging().send(message);

    res.json({
      success: true,
      messageId: response,
    });
  } catch (error) {
    console.error('Notification sending error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/notifications/send-multiple', async (req, res) => {
  try {
    if (!firebaseInitialized) {
      return res.status(503).json({
        error: 'Firebase Admin not initialized',
      });
    }

    const { fcmTokens, title, body, data = {} } = req.body;

    if (!fcmTokens || !Array.isArray(fcmTokens) || fcmTokens.length === 0) {
      return res.status(400).json({ error: 'fcmTokens array required' });
    }

    if (!title || !body) {
      return res.status(400).json({ error: 'title and body are required' });
    }

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...Object.keys(data).reduce((acc, key) => {
          acc[key] = String(data[key]);
          return acc;
        }, {}),
      },
    };

    const response = await admin.messaging().sendEachForMulticast({
      ...message,
      tokens: fcmTokens,
    });

    res.json({
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  } catch (error) {
    console.error('Batch notification error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Route Optimization (caching layer for OpenRouteService)
app.post('/api/routes/optimize', async (req, res) => {
  try {
    const { locations, apiKey } = req.body;

    if (!locations || !Array.isArray(locations) || locations.length < 2) {
      return res.status(400).json({
        error: 'At least 2 locations required',
      });
    }

    if (!apiKey && !process.env.OPENROUTESERVICE_API_KEY) {
      return res.status(400).json({
        error: 'OpenRouteService API key required',
      });
    }

    const axios = require('axios');
    const key = apiKey || process.env.OPENROUTESERVICE_API_KEY;

    // Call OpenRouteService API
    const response = await axios.post(
      'https://api.openrouteservice.org/v2/matrix/driving-car',
      {
        locations: locations,
        metrics: ['distance', 'duration'],
      },
      {
        headers: {
          Authorization: `Bearer ${key}`,
          'Content-Type': 'application/json',
        },
      },
    );

    res.json({
      distances: response.data.distances,
      durations: response.data.durations,
    });
  } catch (error) {
    console.error('Route optimization error:', error);
    res.status(500).json({
      error: error.response?.data || error.message,
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`QuickGas Backend running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Stripe: ${process.env.STRIPE_SECRET_KEY ? 'Configured' : 'Not configured'}`);
  console.log(`Firebase: ${firebaseInitialized ? 'Initialized' : 'Not initialized'}`);
});

