import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants/app_constants.dart';

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

  OptimizedRoute({
    required this.waypoints,
    required this.segments,
    required this.totalDistance,
    required this.totalDuration,
    required this.etas,
  });
}

class TrafficService {
  final Dio _dio = Dio();
  String? _apiKey;

  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  Future<Map<String, double>> calculateDistanceMatrix(
    List<RoutePoint> points,
  ) async {
    if (_apiKey == null) {
      throw Exception('OpenRouteService API key not set');
    }

    final coordinates = points.map((p) => [p.longitude, p.latitude]).toList();

    try {
      final response = await _dio.post(
        '${AppConstants.openRouteServiceBaseUrl}/matrix/driving-car',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'locations': coordinates,
          'metrics': ['distance', 'duration'],
        },
      );

      final distances = response.data['distances'] as List;

      final distanceMap = <String, double>{};
      for (int i = 0; i < points.length; i++) {
        for (int j = 0; j < points.length; j++) {
          if (i != j) {
            final key = '$i-$j';
            distanceMap[key] = (distances[i][j] as num).toDouble();
          }
        }
      }

      return distanceMap;
    } catch (e) {
      throw Exception('Failed to calculate distance matrix: $e');
    }
  }

  Future<OptimizedRoute> optimizeRoute(
    RoutePoint start,
    List<RoutePoint> stops,
    RoutePoint? end,
  ) async {
    if (stops.isEmpty) {
      throw Exception('No stops provided');
    }

    final allPoints = [start, ...stops];
    if (end != null) {
      allPoints.add(end);
    }

    final distanceMatrix = await calculateDistanceMatrix(allPoints);

    final visited = <int>{0}; // Start at index 0
    final route = [0];
    var currentIndex = 0;

    while (visited.length < stops.length + 1) {
      int? nearestIndex;
      double? nearestDistance;

      for (int i = 1; i < allPoints.length; i++) {
        if (!visited.contains(i)) {
          final key = '$currentIndex-$i';
          final distance = distanceMatrix[key];
          if (distance != null &&
              (nearestDistance == null || distance < nearestDistance)) {
            nearestDistance = distance;
            nearestIndex = i;
          }
        }
      }

      if (nearestIndex != null) {
        route.add(nearestIndex);
        visited.add(nearestIndex);
        currentIndex = nearestIndex;
      } else {
        break;
      }
    }

    if (end != null && !visited.contains(allPoints.length - 1)) {
      route.add(allPoints.length - 1);
    }

    final optimizedWaypoints = route.map((index) => allPoints[index]).toList();

    final segments = <RouteSegment>[];
    final etas = <double>[];
    double totalDistance = 0;
    double totalDuration = 0;

    for (int i = 0; i < route.length - 1; i++) {
      final fromIndex = route[i];
      final toIndex = route[i + 1];
      final key = '$fromIndex-$toIndex';

      final distance = distanceMatrix[key] ?? 0.0;
      final duration = (distance / 50.0) * 60; // Assume 50 km/h average speed
      final eta = duration / 60.0; // Convert to minutes

      segments.add(
        RouteSegment(
          start: allPoints[fromIndex],
          end: allPoints[toIndex],
          distance: distance,
          duration: duration,
          eta: eta,
        ),
      );

      etas.add(eta);
      totalDistance += distance / 1000; // Convert to km
      totalDuration += eta;
    }

    return OptimizedRoute(
      waypoints: optimizedWaypoints,
      segments: segments,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      etas: etas,
    );
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
