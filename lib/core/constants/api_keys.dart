import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiKeys {
  static String? _cachedGoogleMapsKey;

  static String _getEnv(String key) {
    try {
      if (dotenv.isInitialized) {
        final value = dotenv.env[key];
        if (value != null && value.isNotEmpty) {
          return value.trim();
        }
        if (kDebugMode) {
          print('Warning: Environment variable $key is empty or not found');
        }
      } else {
        if (kDebugMode) {
          print('Warning: dotenv is not initialized');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting env variable $key: $e');
      }
    }
    return '';
  }

  static String get openRouteServiceApiKey =>
      _getEnv('OPENROUTESERVICE_API_KEY');

  static String get googleMapsApiKey {
    // ALWAYS return cached key if available - don't try to reload from dotenv
    // The key should be cached at app startup in main.dart
    if (_cachedGoogleMapsKey != null && _cachedGoogleMapsKey!.isNotEmpty) {
      return _cachedGoogleMapsKey!;
    }

    // If cache is empty, try to load from dotenv (might happen on hot reload)
    if (kDebugMode) {
      print(
        'WARNING: No cached Google Maps API key, attempting to read from dotenv',
      );
      print('DEBUG: dotenv.isInitialized: ${dotenv.isInitialized}');
    }

    // Try to initialize dotenv if not initialized (hot reload scenario)
    // Note: We can't await in a getter, so we try to load synchronously from file instead
    if (!dotenv.isInitialized) {
      if (kDebugMode) {
        print(
          'DEBUG: dotenv not initialized, trying to read from file directly',
        );
      }
    }

    final key = _getEnv('GOOGLE_MAPS_API_KEY');
    if (key.isNotEmpty) {
      _cachedGoogleMapsKey = key;
      if (kDebugMode) {
        print('DEBUG: Google Maps API key loaded from dotenv and cached');
      }
      return key;
    }

    // Last resort: try reading from file directly
    if (kDebugMode) {
      print('DEBUG: Attempting to read API key from file directly...');
    }
    // Note: This is synchronous, so we can't use the async method here
    // But we can try to read it synchronously as a last resort
    try {
      // Try multiple possible paths for .env file
      final possiblePaths = [
        '.env', // Current directory
        '../.env', // Parent directory
        'quickgas/.env', // In quickgas folder
        '../quickgas/.env', // Parent/quickgas folder
      ];

      File? envFile;
      for (final path in possiblePaths) {
        final file = File(path);
        if (file.existsSync()) {
          envFile = file;
          if (kDebugMode) {
            print('DEBUG: Found .env file at: $path');
          }
          break;
        }
      }

      if (envFile != null && envFile.existsSync()) {
        final content = envFile.readAsStringSync();
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.trim().startsWith('GOOGLE_MAPS_API_KEY=')) {
            final fileKey = line.split('=').skip(1).join('=').trim();
            final cleanKey = fileKey
                .replaceAll('"', '')
                .replaceAll("'", '')
                .trim();
            if (cleanKey.isNotEmpty) {
              _cachedGoogleMapsKey = cleanKey;
              if (kDebugMode) {
                print('DEBUG: Google Maps API key loaded from file and cached');
              }
              return cleanKey;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Failed to read from file: $e');
      }
    }

    // Last resort: Use the hardcoded key from AndroidManifest (same as what map widget uses)
    // This ensures the optimization button works even if .env isn't loaded
    const fallbackKey = 'AIzaSyC1gU7wIo5hp2_lKuwhMy6dMJtKIZ1WKZ4';
    if (kDebugMode) {
      print('WARNING: Using fallback API key from AndroidManifest');
      print(
        'ERROR: Google Maps API key should have been cached at app startup.',
      );
    }
    _cachedGoogleMapsKey = fallbackKey;
    return fallbackKey;
  }

  // Method to manually set the key (for testing or if .env fails)
  static void setGoogleMapsApiKey(String key) {
    _cachedGoogleMapsKey = key;
  }

  static String get stripePublishableKey => _getEnv('STRIPE_PUBLISHABLE_KEY');

  static String get backendUrl => _getEnv('BACKEND_URL');

  // Try to read Google Maps key directly from .env file as fallback
  static Future<String> readGoogleMapsKeyFromFile() async {
    try {
      final envFile = File('.env');
      if (await envFile.exists()) {
        // Try reading with different encodings
        try {
          final content = await envFile.readAsString();
          final lines = content.split('\n');
          for (final line in lines) {
            if (line.trim().startsWith('GOOGLE_MAPS_API_KEY=')) {
              final key = line.split('=').skip(1).join('=').trim();
              // Remove quotes if present
              return key.replaceAll('"', '').replaceAll("'", '').trim();
            }
          }
        } catch (e) {
          // If UTF-8 fails, try reading as bytes and converting
          final bytes = await envFile.readAsBytes();
          final content = String.fromCharCodes(
            bytes.where((b) => b < 128),
          ); // Only ASCII
          final lines = content.split('\n');
          for (final line in lines) {
            if (line.trim().startsWith('GOOGLE_MAPS_API_KEY=')) {
              final key = line.split('=').skip(1).join('=').trim();
              return key.replaceAll('"', '').replaceAll("'", '').trim();
            }
          }
        }
      }
    } catch (e) {
      print('Error reading .env file directly: $e');
    }
    return '';
  }
}
