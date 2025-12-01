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
  bool _isStopping = false;

  LocationTrackingService(this._firebaseService);

  // Start tracking driver location for an order
  Future<void> startTracking({
    required String orderId,
    required GeoPoint destination,
  }) async {
    // Stop any existing tracking first to prevent multiple subscriptions
    if (_positionSubscription != null) {
      await stopTracking();
    }
    
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

    // Reset stopping flag
    _isStopping = false;
    
    // Start location updates - stream provides position updates every 50 meters
    // This is more efficient than periodic getCurrentPosition() calls
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // Update every 50 meters
      ),
    ).listen(
      (Position position) async {
        // Only process if we're not stopping and still tracking this order
        if (!_isStopping && 
            _currentOrderId == orderId && 
            _currentDestination != null) {
          await _updateLocationAndETA(
            orderId,
            position.latitude,
            position.longitude,
            _currentDestination!.latitude,
            _currentDestination!.longitude,
          );
        }
      },
      onError: (error) {
        if (!_isStopping) {
          print('Location tracking error: $error');
        }
      },
      cancelOnError: false, // Keep stream alive even on errors
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
  Future<void> stopTracking() async {
    if (_isStopping) {
      return; // Already stopping
    }
    
    _isStopping = true;
    
    try {
      // Cancel ETA update timer first
      _etaUpdateTimer?.cancel();
      _etaUpdateTimer = null;
      
      // Cancel position stream subscription
      if (_positionSubscription != null) {
        await _positionSubscription!.cancel();
        _positionSubscription = null;
      }
      
      // Give the geolocator plugin a moment to clean up
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Clear tracking data
      _currentOrderId = null;
      _currentDestination = null;
    } catch (e) {
      print('Error stopping location tracking: $e');
    } finally {
      _isStopping = false;
    }
  }

  Future<void> dispose() async {
    await stopTracking();
  }
}

