import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/traffic_service.dart';
import '../../services/google_maps_service.dart';

class MapWidget extends StatefulWidget {
  final List<RoutePoint> waypoints;
  final bool showRoute;
  final LatLng? currentLocation;
  final String? routePolyline; // Google Maps encoded polyline
  final OptimizedRoute? optimizedRoute; // For route segments info

  const MapWidget({
    super.key,
    required this.waypoints,
    this.showRoute = false,
    this.currentLocation,
    this.routePolyline,
    this.optimizedRoute,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _updateMarkersAndRoute();
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.waypoints != oldWidget.waypoints ||
        widget.showRoute != oldWidget.showRoute ||
        widget.routePolyline != oldWidget.routePolyline) {
      _updateMarkersAndRoute();
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  Future<void> _updateMarkersAndRoute() async {
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    List<LatLng> routePoints = [];

    // Add current location marker
    if (widget.currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: widget.currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Current Location'),
        ),
      );
    }

    // Add waypoint markers with numbers
    for (int i = 0; i < widget.waypoints.length; i++) {
      final point = widget.waypoints[i];
      markers.add(
        Marker(
          markerId: MarkerId('waypoint_$i'),
          position: LatLng(point.latitude, point.longitude),
          infoWindow: InfoWindow(
            title: 'Stop ${i + 1}',
            snippet: widget.optimizedRoute != null && i < widget.optimizedRoute!.etas.length
                ? 'ETA: ${widget.optimizedRoute!.etas[i].toStringAsFixed(0)} min'
                : null,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            i == 0 ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
        ),
      );
    }

    // Get route polyline
    if (widget.showRoute && widget.waypoints.length > 1) {
      if (widget.routePolyline != null && widget.routePolyline!.isNotEmpty) {
        // Use provided Google Maps polyline
        routePoints = _decodePolyline(widget.routePolyline!);
      } else {
        // Fallback: try to get route from Google Maps API
        try {
          final googleMapsService = GoogleMapsDirectionsService();
          final start = widget.waypoints[0];
          final end = widget.waypoints[widget.waypoints.length - 1];
          
          final waypoints = widget.waypoints.length > 2
              ? widget.waypoints
                  .sublist(1, widget.waypoints.length - 1)
                  .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                  .toList()
              : null;

          final route = await googleMapsService.getRoute(
            originLat: start.latitude,
            originLng: start.longitude,
            destLat: end.latitude,
            destLng: end.longitude,
            waypoints: waypoints,
          );

          if (route['polyline'] != null) {
            routePoints = _decodePolyline(route['polyline'] as String);
          } else {
            // Fallback to straight lines
            routePoints = widget.waypoints
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();
          }
        } catch (e) {
          // Fallback to straight lines if API fails
          routePoints = widget.waypoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
        }
      }

      if (routePoints.isNotEmpty) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: routePoints,
            color: Colors.blue,
            width: 5,
            patterns: [],
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
      _routePoints = routePoints;
    });

    // Fit bounds to show all markers and route
    if (mounted && _mapController != null && (markers.isNotEmpty || routePoints.isNotEmpty)) {
      await _fitBounds(markers, routePoints);
    }
  }

  Future<void> _fitBounds(Set<Marker> markers, List<LatLng> routePoints) async {
    if (markers.isEmpty && routePoints.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    // Include all markers
    for (final marker in markers) {
      minLat = minLat < marker.position.latitude ? minLat : marker.position.latitude;
      maxLat = maxLat > marker.position.latitude ? maxLat : marker.position.latitude;
      minLng = minLng < marker.position.longitude ? minLng : marker.position.longitude;
      maxLng = maxLng > marker.position.longitude ? maxLng : marker.position.longitude;
    }

    // Include all route points
    for (final point in routePoints) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    // Add padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
    
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.waypoints.isEmpty) {
      return const Center(child: Text('No locations to display'));
    }

    double minLat = widget.waypoints.first.latitude;
    double maxLat = widget.waypoints.first.latitude;
    double minLng = widget.waypoints.first.longitude;
    double maxLng = widget.waypoints.first.longitude;

    for (final point in widget.waypoints) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(centerLat, centerLng),
        zoom: 12,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      onMapCreated: (controller) async {
        _mapController = controller;
        // Fit bounds after map is created
        if (widget.waypoints.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 500));
          await _fitBounds(_markers, _routePoints);
        }
      },
    );
  }
}
