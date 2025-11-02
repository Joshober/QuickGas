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

3. **Set up environment variables**
   - Create `.env` file in the `quickgas` directory (copy from `.env.example`)
   - Add all your API keys and Firebase configuration:
     ```env
     OPENROUTESERVICE_API_KEY=your_key_here
     GOOGLE_MAPS_API_KEY=your_key_here
     STRIPE_PUBLISHABLE_KEY=your_key_here
     BACKEND_URL=your_backend_url_here
     
     FIREBASE_PROJECT_ID=your_project_id
     FIREBASE_PROJECT_NUMBER=your_project_number
     
     FIREBASE_ANDROID_API_KEY=your_android_api_key
     FIREBASE_ANDROID_PACKAGE_NAME=com.example.chatappfinal
     FIREBASE_ANDROID_APP_ID=your_android_app_id
     
     FIREBASE_IOS_API_KEY=your_ios_api_key
     FIREBASE_IOS_BUNDLE_ID=your_bundle_id
     FIREBASE_IOS_APP_ID=your_ios_app_id
     FIREBASE_STORAGE_BUCKET=your_storage_bucket
     FIREBASE_DATABASE_URL=your_database_url
     ```
   - Get these values from your Firebase Console project settings

4. **Generate Firebase configuration files from environment variables**
   - Windows: Run `make_config.bat`
   - Linux/Mac: Run `chmod +x make_config.sh && ./make_config.sh`
   - Or manually: `dart run scripts/generate_firebase_configs.dart`
   - This will generate `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` from your `.env` file
   - **IMPORTANT**: These generated files are gitignored - never commit them to version control

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
4. Add to `.env` as `GOOGLE_MAPS_API_KEY`
5. Update platform-specific configs (AndroidManifest.xml for Android, Info.plist for iOS)

### Firebase Configuration
1. Create a Firebase project at https://console.firebase.google.com
2. Add Android and iOS apps to your project
3. Download the config files or get the values from Firebase Console
4. Add all Firebase configuration values to your `.env` file (see `.env.example`)
5. Run the config generator script to create Firebase config files:
   - Windows: `make_config.bat`
   - Linux/Mac: `./make_config.sh`

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

### Security
- **Never commit API keys or Firebase configuration files to version control**
- `.env` file is gitignored - store all API keys here
- Firebase config files (`google-services.json` and `GoogleService-Info.plist`) are gitignored
- Use the `.example` template files as reference, but always add your actual config files locally
- If you accidentally commit API keys, rotate them immediately in Google Cloud Console

### Configuration
- Firebase configuration files must match your project package name
- For production, use secure storage for sensitive keys
- Payment confirmation requires backend integration

## License

This project is for educational purposes.

## Support

For issues or questions, please refer to the documentation or create an issue in the repository.
