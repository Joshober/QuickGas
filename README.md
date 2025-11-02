# QuickGas - Boat Fuel Delivery App

A Flutter mobile application for on-demand boat fuel delivery service. Customers can request fuel delivery to their boats, and drivers can manage deliveries with optimized route planning.

## Features

### Customer Features
- Firebase Authentication (Email/Password)
- Place fuel delivery orders with location selection
- View order history and status
- Real-time order tracking
- Payment options: Stripe and Cash on Delivery
- Delivery photo verification
- Modern UI with animated transitions

### Driver Features
- Driver dashboard with available orders
- Route optimization using OpenRouteService
- Multi-stop delivery planning
- Order acceptance and status updates
- Delivery verification with photo upload
- Navigation integration

### Technical Features
- Firebase (Authentication, Firestore, Storage, Messaging)
- Google Maps integration
- OpenRouteService for route optimization
- Stripe payment integration
- Push notifications
- Role-based navigation (Customer/Driver/Both)
- Environment variable configuration (.env)

## Setup Instructions

### Prerequisites
- Flutter SDK (3.9.0 or higher)
- Firebase project configured
- Google Maps API key
- OpenRouteService API key (free tier available)
- Stripe account (optional, for payments)

### Installation

1. **Clone the repository**
   ```bash
   cd quickgas
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Android: Place `google-services.json` in `android/app/`
   - iOS: Place `GoogleService-Info.plist` in `ios/Runner/`
   - Ensure Firebase is properly initialized

4. **Set up environment variables**
   - Create `.env` file in the `quickgas` directory
   - Add your API keys:
     ```env
     OPENROUTESERVICE_API_KEY=your_key_here
     GOOGLE_MAPS_API_KEY=your_key_here
     STRIPE_PUBLISHABLE_KEY=your_key_here
     BACKEND_URL=your_backend_url_here
     ```

5. **Configure Google Maps**
   - Android: Add API key to `android/app/src/main/AndroidManifest.xml`
   - iOS: Add API key to `ios/Runner/Info.plist`

6. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

```
quickgas/
├── lib/
│   ├── core/
│   │   ├── animations/      # Page transitions
│   │   ├── constants/       # App constants & API keys
│   │   ├── providers/       # Riverpod providers
│   │   ├── router/          # Navigation
│   │   └── theme/           # App theme
│   ├── features/
│   │   ├── authentication/  # Login, Signup
│   │   ├── home/            # Customer & Driver dashboards
│   │   ├── map/             # Map widgets
│   │   ├── order/           # Order management
│   │   ├── profile/         # User profile
│   │   └── tracking/        # Order tracking
│   ├── services/            # Firebase, Payment, Maps services
│   └── shared/              # Shared models & widgets
└── backend/                 # Node.js backend (optional)
```

## API Keys Setup

### OpenRouteService API Key
1. Sign up at https://openrouteservice.org/dev/#/signup
2. Get your free API key
3. Add to `.env` file as `OPENROUTESERVICE_API_KEY`

### Google Maps API Key
1. Create project in Google Cloud Console
2. Enable Maps SDK for Android/iOS
3. Create API key
4. Add to `.env` and platform-specific configs

### Stripe Keys
1. Create Stripe account
2. Get publishable key from dashboard
3. Add to `.env` as `STRIPE_PUBLISHABLE_KEY`
4. Add secret key to backend `.env` if using backend

## Backend Setup (Optional)

If using backend for payments/notifications:

1. Navigate to backend directory
   ```bash
   cd backend
   ```

2. Install dependencies
   ```bash
   npm install
   ```

3. Create `.env` file
   ```env
   STRIPE_SECRET_KEY=your_stripe_secret_key
   PORT=3000
   ```

4. Deploy to Render/Railway/Fly.io (see `backend/DEPLOYMENT.md`)

## Building for Production

### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## Important Notes

- `.env` file is gitignored - never commit API keys
- Firebase configuration files must match your project package name
- For production, use secure storage for sensitive keys
- Payment confirmation requires backend integration

## License

This project is for educational purposes.

## Support

For issues or questions, please refer to the documentation or create an issue in the repository.
