import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'google_maps_service.dart';
import 'firebase_service.dart';

class LocationTrackingService {
  StreamSubscription<Position>? _positionSubscription;
  final FirebaseService _firebaseService;
  final GoogleMapsDirectionsService _googleMapsService =
      GoogleMapsDirectionsService();
  Timer? _etaUpdateTimer;
  String? _currentOrderId;
  GeoPoint? _currentDestination;

  LocationTrackingService(this._firebaseService);

  // Start tracking driver location for an order
  Future<void> startTracking({
    required String orderId,
    required GeoPoint destination,
  }) async {
    _currentOrderId = orderId;
    _currentDestination = destination;

    // Request location permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    // Start location updates
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // Update every 50 meters
      ),
    ).listen(
      (Position position) async {
        await _updateLocationAndETA(
          orderId,
          position.latitude,
          position.longitude,
          destination.latitude,
          destination.longitude,
        );
      },
      onError: (error) {
        print('Location tracking error: $error');
      },
    );

    // Update ETA every 30 seconds
    _etaUpdateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        if (_currentOrderId != null && _currentDestination != null) {
          try {
            final position = await Geolocator.getCurrentPosition();
            await _updateLocationAndETA(
              _currentOrderId!,
              position.latitude,
              position.longitude,
              _currentDestination!.latitude,
              _currentDestination!.longitude,
            );
          } catch (e) {
            print('ETA update error: $e');
          }
        }
      },
    );
  }

  Future<void> _updateLocationAndETA(
    String orderId,
    double driverLat,
    double driverLng,
    double destLat,
    double destLng,
  ) async {
    try {
      // Update driver location
      await _firebaseService.updateDriverLocation(
        orderId,
        GeoPoint(driverLat, driverLng),
      );

      // Calculate ETA using Google Maps
      try {
        final route = await _googleMapsService.getRoute(
          originLat: driverLat,
          originLng: driverLng,
          destLat: destLat,
          destLng: destLng,
        );

        final etaMinutes = route['durationInTraffic'] as double? ??
            route['duration'] as double? ??
            0.0;

        await _firebaseService.updateOrderETA(orderId, etaMinutes);
      } catch (e) {
        // If Google Maps fails, calculate simple distance-based ETA
        final distance = Geolocator.distanceBetween(
          driverLat,
          driverLng,
          destLat,
          destLng,
        );
        // Assume average speed of 50 km/h
        final etaMinutes = (distance / 1000) / 50 * 60;
        await _firebaseService.updateOrderETA(orderId, etaMinutes);
      }
    } catch (e) {
      print('Failed to update location and ETA: $e');
    }
  }

  // Stop tracking
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _etaUpdateTimer?.cancel();
    _etaUpdateTimer = null;
    _currentOrderId = null;
    _currentDestination = null;
  }

  void dispose() {
    stopTracking();
  }
}

