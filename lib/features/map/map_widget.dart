import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/traffic_service.dart';

class MapWidget extends StatefulWidget {
  final List<RoutePoint> waypoints;
  final bool showRoute;
  final LatLng? currentLocation;

  const MapWidget({
    super.key,
    required this.waypoints,
    this.showRoute = false,
    this.currentLocation,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {


  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _updateMarkersAndRoute();
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.waypoints != oldWidget.waypoints ||
        widget.showRoute != oldWidget.showRoute) {
      _updateMarkersAndRoute();
    }
  }

  void _updateMarkersAndRoute() {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

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

    for (int i = 0; i < widget.waypoints.length; i++) {
      final point = widget.waypoints[i];
      markers.add(
        Marker(
          markerId: MarkerId('waypoint_$i'),
          position: LatLng(point.latitude, point.longitude),
          infoWindow: InfoWindow(title: 'Stop ${i + 1}'),
        ),
      );
    }

    if (widget.showRoute && widget.waypoints.length > 1) {
      final points = widget.waypoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.blue,
          width: 4,
        ),
      );
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
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
      onMapCreated: (controller) {
        _mapController = controller;
      },
    );
  }
}
