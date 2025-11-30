import 'package:dio/dio.dart';
import '../core/constants/api_keys.dart';

class GoogleMapsDirectionsService {
  final Dio _dio = Dio();
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  Future<Map<String, dynamic>> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    List<Map<String, double>>? waypoints,
    bool optimizeWaypoints = false,
  }) async {
    final apiKey = ApiKeys.googleMapsApiKey;
    if (apiKey.isEmpty) {
      // Debug: Check what's happening
      print('DEBUG: Google Maps API key is empty when trying to get route');
      throw Exception('Google Maps API key not configured. Please check your .env file has GOOGLE_MAPS_API_KEY set and the app was started properly.');
    }
    print('DEBUG: Using Google Maps API key: ${apiKey.substring(0, 10)}...');
    
    return _getRouteWithKey(
      apiKey: apiKey,
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      waypoints: waypoints,
    );
  }

  Future<Map<String, dynamic>> _getRouteWithKey({
    required String apiKey,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    List<Map<String, double>>? waypoints,
    bool optimizeWaypoints = false,
  }) async {
    try {
      String waypointsParam = '';
      if (waypoints != null && waypoints.isNotEmpty) {
        final waypointsStr = waypoints.map((w) => '${w['lat']},${w['lng']}').join('|');
        // Google Maps waypoint optimization: prefix with "optimize:true|"
        waypointsParam = optimizeWaypoints
            ? '&waypoints=optimize:true|$waypointsStr'
            : '&waypoints=$waypointsStr';
      }

      // Build URL - note: optimize:true requires Directions API
      // departure_time and traffic_model require Distance Matrix API or Premium plan
      String url = '$_baseUrl?origin=$originLat,$originLng&destination=$destLat,$destLng$waypointsParam&key=$apiKey';
      
      // Only add traffic parameters if we have waypoints (optimization)
      // For simple routes, we can skip traffic_model to avoid API requirements
      if (waypoints != null && waypoints.isNotEmpty) {
        url += '&departure_time=now&traffic_model=best_guess';
      }

      final response = await _dio.get(url);

      if (response.data['status'] != 'OK') {
        final status = response.data['status'] as String;
        final errorMessage = response.data['error_message'] as String?;
        
        // Debug logging
        print('=== Google Maps API Error ===');
        print('Status: $status');
        print('Error Message: $errorMessage');
        final hiddenUrl = url.replaceAll(apiKey, 'API_KEY_HIDDEN');
        print('URL used: $hiddenUrl');
        print('===========================');
        
        String error = 'Directions API error: $status';
        if (errorMessage != null) {
          error += '\n$errorMessage';
        }
        
        // Provide helpful guidance for common errors
        if (status == 'REQUEST_DENIED') {
          error += '\n\nThis usually means:\n'
              '1. Directions API is not enabled in Google Cloud Console\n'
              '2. Your API key restrictions are blocking the request\n'
              '3. The API key is invalid or expired\n\n'
              'To fix:\n'
              '- Go to Google Cloud Console → APIs & Services → Credentials\n'
              '- Click your API key\n'
              '- Under "API restrictions", ensure "Directions API" is in the allowed list\n'
              '- OR temporarily set to "Do not restrict key" for testing\n'
              '- Verify the API key matches GOOGLE_MAPS_API_KEY in your .env file';
        } else if (status == 'OVER_QUERY_LIMIT') {
          error += '\n\nYou have exceeded your API quota.\n'
              'Check your Google Cloud Console billing/quota page.';
        } else if (status == 'INVALID_REQUEST') {
          error += '\n\nInvalid request parameters.\n'
              'This might be due to waypoint optimization requiring Premium plan.\n'
              'The app will try without optimization.';
        }
        
        throw Exception(error);
      }

      final route = response.data['routes'][0];
      final legs = route['legs'] as List;
      
      // Calculate total distance and duration across all legs
      double totalDistance = 0;
      double totalDuration = 0;
      double totalDurationInTraffic = 0;
      
      for (final leg in legs) {
        totalDistance += (leg['distance']['value'] as num).toDouble();
        totalDuration += (leg['duration']['value'] as num).toDouble();
        if (leg['duration_in_traffic'] != null) {
          totalDurationInTraffic += (leg['duration_in_traffic']['value'] as num).toDouble();
        }
      }

      return {
        'distance': totalDistance / 1000.0, // Convert to km
        'duration': totalDuration / 60.0, // Convert to minutes
        'durationInTraffic': totalDurationInTraffic > 0
            ? totalDurationInTraffic / 60.0
            : totalDuration / 60.0,
        'polyline': route['overview_polyline']['points'],
        'waypoint_order': route['waypoint_order'], // Google's optimized order
        'legs': legs, // All route legs for detailed segment info
      };
    } catch (e) {
      throw Exception('Failed to get route from Google Maps: $e');
    }
  }

  Future<Map<String, dynamic>> getDistanceMatrix({
    required List<Map<String, double>> origins,
    required List<Map<String, double>> destinations,
  }) async {
    final apiKey = ApiKeys.googleMapsApiKey;
    if (apiKey.isEmpty) {
      // Don't try to reload - if it's empty, it means the .env wasn't loaded properly at startup
      throw Exception('Google Maps API key not configured. Please check your .env file has GOOGLE_MAPS_API_KEY set and the app was started properly.');
    }

    try {
      final originsParam = origins.map((o) => '${o['lat']},${o['lng']}').join('|');
      final destinationsParam =
          destinations.map((d) => '${d['lat']},${d['lng']}').join('|');

      final url =
          'https://maps.googleapis.com/maps/api/distancematrix/json?origins=$originsParam&destinations=$destinationsParam&key=$apiKey&departure_time=now&traffic_model=best_guess';

      final response = await _dio.get(url);

      if (response.data['status'] != 'OK') {
        final status = response.data['status'] as String;
        final errorMessage = response.data['error_message'] as String?;
        
        String error = 'Distance Matrix API error: $status';
        if (errorMessage != null) {
          error += '\n$errorMessage';
        }
        
        // Provide helpful guidance for common errors
        if (status == 'REQUEST_DENIED' || status == 'OVER_QUERY_LIMIT') {
          error += '\n\nPlease check:\n'
              '1. Distance Matrix API is enabled in Google Cloud Console\n'
              '2. Directions API is enabled in Google Cloud Console\n'
              '3. Your API key has proper restrictions/quotas\n'
              '4. Billing is enabled for your Google Cloud project';
        }
        
        throw Exception(error);
      }

      final rows = response.data['rows'] as List;
      final matrix = <String, Map<String, dynamic>>{};

      for (int i = 0; i < rows.length; i++) {
        final elements = rows[i]['elements'] as List;
        for (int j = 0; j < elements.length; j++) {
          final element = elements[j];
          if (element['status'] == 'OK') {
            matrix['$i-$j'] = {
              'distance': element['distance']['value'] / 1000.0, // km
              'duration': element['duration']['value'] / 60.0, // minutes
              'durationInTraffic': element['duration_in_traffic'] != null
                  ? element['duration_in_traffic']['value'] / 60.0
                  : element['duration']['value'] / 60.0,
            };
          }
        }
      }

      return matrix;
    } on DioException catch (e) {
      // Handle Dio errors (network, HTTP errors)
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map && data['error_message'] != null) {
          throw Exception('Google Maps API error: ${data['error_message']}');
        }
      }
      throw Exception('Failed to get distance matrix: ${e.message}');
    } catch (e) {
      throw Exception('Failed to get distance matrix: $e');
    }
  }

  Future<Map<String, dynamic>> optimizeRouteWithGoogleMaps({
    required double startLat,
    required double startLng,
    required List<Map<String, double>> stops,
  }) async {
    if (stops.isEmpty) {
      throw Exception('No stops provided');
    }

    // Use Google Maps Directions API with waypoints optimization
    final waypoints = stops.map((s) => {'lat': s['lat']!, 'lng': s['lng']!}).toList();
    
    // For optimization, we'll use the first stop as destination and optimize waypoints
    final firstStop = waypoints[0];
    final remainingWaypoints = waypoints.skip(1).toList();

    final route = await getRoute(
      originLat: startLat,
      originLng: startLng,
      destLat: firstStop['lat']!,
      destLng: firstStop['lng']!,
      waypoints: remainingWaypoints,
    );

    return route;
  }
}

