import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/constants/backend_constants.dart';
import 'core/constants/api_keys.dart';
import 'services/notification_service.dart';
import 'services/payment_service.dart';
import 'services/backend_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load and cache Google Maps API key - this MUST happen before anything else
  String? googleMapsKey;
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('dotenv loaded successfully');

    // Get the key directly from dotenv and cache it immediately
    googleMapsKey = dotenv.env['GOOGLE_MAPS_API_KEY']?.trim();
    if (googleMapsKey != null && googleMapsKey.isNotEmpty) {
      ApiKeys.setGoogleMapsApiKey(googleMapsKey);
      debugPrint(
        'Google Maps API key loaded and cached: ${googleMapsKey.substring(0, 10)}...',
      );
    } else {
      debugPrint('Warning: GOOGLE_MAPS_API_KEY not found in .env file');
    }
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }

  // If key still not loaded, try reading file directly
  if (googleMapsKey == null || googleMapsKey.isEmpty) {
    try {
      final key = await ApiKeys.readGoogleMapsKeyFromFile();
      if (key.isNotEmpty) {
        ApiKeys.setGoogleMapsApiKey(key);
        debugPrint(
          'Google Maps API key loaded from file directly: ${key.substring(0, 10)}...',
        );
        googleMapsKey = key;
      }
    } catch (e) {
      debugPrint('Could not read .env file directly: $e');
    }
  }

  // Final verification
  final finalKey = ApiKeys.googleMapsApiKey;
  if (finalKey.isNotEmpty) {
    debugPrint(
      '✓ Google Maps API key verified and ready: ${finalKey.substring(0, 10)}...',
    );
  } else {
    debugPrint(
      '✗ ERROR: Google Maps API key is still empty - route optimization will not work',
    );
  }

  await Firebase.initializeApp();

  // Initialize notification service (channels are created inside initialize)
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Try to connect to backend, but don't fail if unavailable
  String? backendUrl = ApiKeys.backendUrl.isNotEmpty
      ? ApiKeys.backendUrl
      : BackendConstants.getBackendUrl();

  bool backendAvailable = false;
  if (backendUrl.isNotEmpty && backendUrl != 'YOUR_BACKEND_URL_HERE') {
    try {
      final backendService = BackendService();
      backendService.setBaseUrl(backendUrl);

      // Check if backend is available with longer timeout for first connection
      debugPrint('Checking backend availability: $backendUrl');
      backendAvailable = await backendService.checkAvailability();

      if (backendAvailable) {
        debugPrint('✓ Backend connected: $backendUrl');

        // Configure payment service with backend
        final paymentService = PaymentService();
        paymentService.setBackendUrl(backendUrl);
      } else {
        debugPrint('⚠ Backend unavailable, using Firebase-only mode');
        debugPrint('  Backend URL: $backendUrl');
        debugPrint('  Health endpoint: $backendUrl/health');
        debugPrint(
          '  Check Railway dashboard to ensure backend service is running',
        );
        debugPrint('  Common issues:');
        debugPrint('    - Backend service not deployed or crashed');
        debugPrint('    - Database connection issues');
        debugPrint(
          '    - Missing environment variables (STRIPE_SECRET_KEY, DATABASE_URL)',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('⚠ Backend connection failed: $e');
      debugPrint('  Stack trace: $stackTrace');
      debugPrint('  Using Firebase-only mode');
      backendAvailable = false;
    }
  } else {
    debugPrint('ℹ No backend URL configured - Using Firebase-only mode');
    debugPrint('  Set BACKEND_URL in .env or environment variables');
  }

  // TrafficService now uses only Google Maps API - no OpenRouteService needed

  // Initialize Stripe SDK early (required before using CardFormField)
  final stripePublishableKey = ApiKeys.stripePublishableKey;
  debugPrint(
    'DEBUG: Stripe publishable key from ApiKeys: ${stripePublishableKey.isEmpty ? "EMPTY" : "${stripePublishableKey.substring(0, stripePublishableKey.length > 20 ? 20 : stripePublishableKey.length)}..."}',
  );
  debugPrint('DEBUG: dotenv.isInitialized: ${dotenv.isInitialized}');
  if (dotenv.isInitialized) {
    debugPrint(
      'DEBUG: dotenv.env[STRIPE_PUBLISHABLE_KEY]: ${dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? "NOT SET"}',
    );
  }
  if (stripePublishableKey.isNotEmpty &&
      stripePublishableKey != 'STRIPE_PUBLISHABLE_KEY') {
    Stripe.publishableKey = stripePublishableKey;
    debugPrint('✓ Stripe publishable key configured');
  } else {
    debugPrint(
      '⚠ Stripe publishable key not configured - Payment features will be unavailable',
    );
    if (stripePublishableKey == 'STRIPE_PUBLISHABLE_KEY') {
      debugPrint(
        'ERROR: Stripe key appears to be the placeholder string, not an actual key',
      );
      debugPrint(
        '  Please check your .env file and ensure STRIPE_PUBLISHABLE_KEY is set to your actual Stripe key',
      );
    }
  }

  if (!backendAvailable) {
    debugPrint(
      'ℹ App running in Firebase-only mode. Backend features disabled.',
    );
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'QuickGas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
