import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  static String _getEnv(String key) {
    try {
      if (dotenv.isInitialized) {
        return dotenv.env[key] ?? '';
      }
    } catch (e) {}
    return '';
  }

  static String get openRouteServiceApiKey =>
      _getEnv('OPENROUTESERVICE_API_KEY');

  static String get googleMapsApiKey => _getEnv('GOOGLE_MAPS_API_KEY');

  static String get stripePublishableKey => _getEnv('STRIPE_PUBLISHABLE_KEY');

  static String get backendUrl => _getEnv('BACKEND_URL');
}
