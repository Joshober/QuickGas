import 'package:geolocator/geolocator.dart';
import 'google_maps_service.dart';

class RoutePoint {
  final double latitude;
  final double longitude;

  RoutePoint(this.latitude, this.longitude);
}

class RouteSegment {
  final RoutePoint start;
  final RoutePoint end;
  final double distance; // in meters
  final double duration; // in seconds
  final double eta; // in minutes

  RouteSegment({
    required this.start,
    required this.end,
    required this.distance,
    required this.duration,
    required this.eta,
  });
}

class OptimizedRoute {
  final List<RoutePoint> waypoints;
  final List<RouteSegment> segments;
  final double totalDistance; // in km
  final double totalDuration; // in minutes
  final List<double> etas; // ETAs for each segment in minutes
  final String? polyline; // Google Maps encoded polyline

  OptimizedRoute({
    required this.waypoints,
    required this.segments,
    required this.totalDistance,
    required this.totalDuration,
    required this.etas,
    this.polyline,
  });
}

class TrafficService {
  final GoogleMapsDirectionsService _googleMapsService = GoogleMapsDirectionsService();

  Future<OptimizedRoute> optimizeRoute(
    RoutePoint start,
    List<RoutePoint> stops,
    RoutePoint? end,
  ) async {
    if (stops.isEmpty) {
      throw Exception('No stops provided');
    }

    // Determine origin and destination
    final origin = start;
    final destination = end ?? stops.last; // Use last stop as destination if no end point
    
    // Prepare waypoints (exclude destination if it's in stops)
    List<Map<String, double>>? waypoints;
    if (stops.length > 1) {
      // If destination is the last stop, exclude it from waypoints
      final waypointStops = destination == stops.last 
          ? stops.sublist(0, stops.length - 1)
          : stops;
      waypoints = waypointStops.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();
    } else if (stops.length == 1 && destination != stops.first) {
      // Single stop that's different from destination
      waypoints = [{'lat': stops.first.latitude, 'lng': stops.first.longitude}];
    }
    // If stops.length == 1 and destination == stops.first, no waypoints needed

    // Get optimized route from Google Maps
    // Note: optimize:true may require Premium plan - try with optimization first
    Map<String, dynamic> route;
    try {
      print('Requesting route from Google Maps:');
      print('Origin: ${origin.latitude}, ${origin.longitude}');
      print('Destination: ${destination.latitude}, ${destination.longitude}');
      print('Waypoints: ${waypoints?.length ?? 0}');
      print('Optimize waypoints: ${waypoints != null && waypoints.length > 1}');
      
      route = await _googleMapsService.getRoute(
        originLat: origin.latitude,
        originLng: origin.longitude,
        destLat: destination.latitude,
        destLng: destination.longitude,
        waypoints: waypoints,
        optimizeWaypoints: waypoints != null && waypoints.length > 1, // Only optimize if 2+ waypoints
      );
      
      print('Route received successfully. Legs: ${(route['legs'] as List?)?.length ?? 0}');
    } catch (e) {
      // If optimization fails (might need Premium), try without optimization
      print('Google Maps optimization failed, trying without optimization: $e');
      try {
        route = await _googleMapsService.getRoute(
          originLat: origin.latitude,
          originLng: origin.longitude,
          destLat: destination.latitude,
          destLng: destination.longitude,
          waypoints: waypoints,
          optimizeWaypoints: false, // Skip Google's optimization
        );
        print('Route received successfully (without optimization). Legs: ${(route['legs'] as List?)?.length ?? 0}');
      } catch (e2) {
        // If that also fails, rethrow with better error message
        print('Both optimization attempts failed. Original: $e. Retry: $e2');
        throw Exception('Failed to get route from Google Maps. Original error: $e. Retry error: $e2');
      }
    }

    // Extract waypoint order from Google Maps response
    final waypointList = _extractWaypointOrder(route, start, stops, destination);
    
    // Calculate segments and ETAs from route legs (Google Maps provides this)
    final segments = <RouteSegment>[];
    final etas = <double>[];
    double totalDistance = 0;
    double totalDuration = 0;

    // Extract data from route legs (Google Maps provides detailed leg data)
    // Google Maps returns legs as a list where each leg is a segment between waypoints
    // Number of legs = number of waypoints + 1 (origin to first waypoint, waypoint to waypoint, last waypoint to destination)
    final legs = route['legs'] as List? ?? [];

    // Process each leg (one leg per segment)
    if (legs.isNotEmpty && waypointList.length >= 2) {
      for (int i = 0; i < legs.length && i < waypointList.length; i++) {
        final leg = legs[i];
        
        // Extract distance and duration from leg
        final legDistance = (leg['distance']['value'] as num).toDouble() / 1000.0; // km
        final legDuration = (leg['duration']['value'] as num).toDouble() / 60.0; // minutes
        final legDurationInTraffic = leg['duration_in_traffic'] != null
            ? (leg['duration_in_traffic']['value'] as num).toDouble() / 60.0
            : legDuration;

        // Each leg connects waypointList[i] to waypointList[i+1]
        // If this is the last leg, it goes to the last waypoint
        final segmentStart = waypointList[i];
        final segmentEnd = i + 1 < waypointList.length 
            ? waypointList[i + 1] 
            : waypointList.last;

        segments.add(
          RouteSegment(
            start: segmentStart,
            end: segmentEnd,
            distance: legDistance * 1000, // Convert km to meters
            duration: legDurationInTraffic * 60, // Convert minutes to seconds
            eta: legDurationInTraffic,
          ),
        );

        etas.add(legDurationInTraffic);
        totalDistance += legDistance;
        totalDuration += legDurationInTraffic;
      }
    }

    // Fallback if no legs data
    if (legs.isEmpty && waypointList.length >= 2) {
      totalDistance = route['distance'] as double? ?? 0.0;
      totalDuration = route['durationInTraffic'] as double? ?? route['duration'] as double? ?? 0.0;
      
      segments.add(
        RouteSegment(
          start: waypointList[0],
          end: waypointList[waypointList.length - 1],
          distance: totalDistance * 1000,
          duration: totalDuration * 60,
          eta: totalDuration,
        ),
      );
      etas.add(totalDuration);
    }

    return OptimizedRoute(
      waypoints: waypointList,
      segments: segments,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      etas: etas,
      polyline: route['polyline'] as String?,
    );
  }

  // Extract waypoint order from Google Maps optimized route
  List<RoutePoint> _extractWaypointOrder(
    Map<String, dynamic> route,
    RoutePoint start,
    List<RoutePoint> stops,
    RoutePoint destination,
  ) {
    // Google Maps returns waypoint_order in the response when optimize:true
    // waypoint_order is an array of indices showing the optimized order
    final waypointOrder = route['waypoint_order'] as List?;
    
    if (waypointOrder != null && waypointOrder.length == stops.length) {
      // Reorder stops based on Google's optimization
      final orderedStops = waypointOrder
          .map((index) => stops[index as int])
          .toList();
      // If destination is same as last stop, don't duplicate
      if (destination.latitude == stops.last.latitude && 
          destination.longitude == stops.last.longitude) {
        return [start, ...orderedStops];
      }
      return [start, ...orderedStops, destination];
    }

    // Fallback: use stops in original order
    if (destination.latitude == stops.last.latitude && 
        destination.longitude == stops.last.longitude) {
      return [start, ...stops];
    }
    return [start, ...stops, destination];
  }

  List<RoutePoint> suggestNearbyStops(
    RoutePoint center,
    List<RoutePoint> allStops,
    double radiusKm,
  ) {
    final nearby = <RoutePoint>[];

    for (final stop in allStops) {
      final distance = _calculateDistance(
        center.latitude,
        center.longitude,
        stop.latitude,
        stop.longitude,
      );

      if (distance <= radiusKm) {
        nearby.add(stop);
      }
    }

    return nearby;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // km
  }
}
