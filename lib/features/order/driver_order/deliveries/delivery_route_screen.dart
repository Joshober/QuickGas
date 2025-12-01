import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../services/maps_service.dart';
import '../../../../services/traffic_service.dart';
import '../../../../shared/models/order_model.dart';
import '../../../map/map_widget.dart';
import 'delivery_detail_screen.dart';

class DeliveryRouteScreen extends ConsumerStatefulWidget {
  final List<OrderModel> orders;

  const DeliveryRouteScreen({super.key, required this.orders});

  @override
  ConsumerState<DeliveryRouteScreen> createState() =>
      _DeliveryRouteScreenState();
}

class _DeliveryRouteScreenState extends ConsumerState<DeliveryRouteScreen> {
  List<RoutePoint> _waypoints = [];
  OptimizedRoute? _optimizedRoute;
  bool _isOptimizing = false;
  RoutePoint? _currentLocation;
  List<OrderModel> _activeOrders = [];

  @override
  void initState() {
    super.initState();
    _activeOrders = widget.orders;
    _getCurrentLocation();
    _initializeWaypoints();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh orders when screen becomes visible again
    _refreshOrders();
  }

  Future<void> _refreshOrders() async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final refreshedOrders = <OrderModel>[];
      
      for (final order in widget.orders) {
        final updatedOrder = await firebaseService.getOrderById(order.id);
        if (updatedOrder != null && 
            updatedOrder.status != AppConstants.orderStatusCompleted) {
          refreshedOrders.add(updatedOrder);
        }
      }

      if (mounted && refreshedOrders.length != _activeOrders.length) {
        setState(() {
          _activeOrders = refreshedOrders;
          _updateWaypoints();
        });
      }
    } catch (e) {
      print('Failed to refresh orders: $e');
    }
  }

  void _updateWaypoints() {
    setState(() {
      _waypoints = _activeOrders
          .map(
            (order) =>
                RoutePoint(order.location.latitude, order.location.longitude),
          )
          .toList();
    });
  }

  void _initializeWaypoints() {
    _updateWaypoints();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final mapsService = MapsService();
      final position = await mapsService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentLocation = RoutePoint(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get current location: $e')),
        );
      }
    }
  }

  Future<void> _optimizeRoute() async {
    if (_activeOrders.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 deliveries to optimize')),
      );
      return;
    }

    setState(() => _isOptimizing = true);

    try {
      final trafficService = ref.read(trafficServiceProvider);

      // Use current location as start if available, otherwise use first order
      final startPoint =
          _currentLocation ??
          RoutePoint(
            _activeOrders[0].location.latitude,
            _activeOrders[0].location.longitude,
          );

      final stops = _activeOrders
          .map(
            (order) =>
                RoutePoint(order.location.latitude, order.location.longitude),
          )
          .toList();

      final optimized = await trafficService.optimizeRoute(
        startPoint,
        stops,
        null,
      );

      setState(() {
        _optimizedRoute = optimized;
        _waypoints = optimized.waypoints;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route optimized successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to optimize route: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOptimizing = false);
      }
    }
  }

  Future<void> _openInNativeMaps() async {
    // Use optimized route if available, otherwise use current waypoints
    final waypointsToUse = _optimizedRoute?.waypoints ?? _waypoints;

    if (waypointsToUse.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No route to display')));
      return;
    }

    if (waypointsToUse.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 stops to open in maps')),
      );
      return;
    }

    try {
      final origin = waypointsToUse.first;
      final destination = waypointsToUse.last;

      // Build waypoints string (exclude origin and destination)
      String waypointsParam = '';
      if (waypointsToUse.length > 2) {
        final intermediateWaypoints = waypointsToUse
            .sublist(1, waypointsToUse.length - 1)
            .map((p) => '${p.latitude},${p.longitude}')
            .join('|');
        waypointsParam = '&waypoints=$intermediateWaypoints';
      }

      // Google Maps URL format with waypoints
      final url =
          'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}$waypointsParam&travelmode=driving';

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open maps app')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open maps: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Route'),
        actions: [
          if (_activeOrders.length >= 2)
            IconButton(
              icon: _isOptimizing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_graph),
              onPressed: _isOptimizing ? null : _optimizeRoute,
              tooltip: 'Optimize Route',
            ),
        ],
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            flex: 2,
            child: MapWidget(
              waypoints: _waypoints,
              showRoute: _optimizedRoute != null,
              routePolyline: _optimizedRoute?.polyline,
              optimizedRoute: _optimizedRoute,
            ),
          ),

          // Route info
          if (_optimizedRoute != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Optimized Route',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRouteInfo(
                        'Distance',
                        '${_optimizedRoute!.totalDistance.toStringAsFixed(1)} km',
                        Icons.straighten,
                      ),
                      _buildRouteInfo(
                        'Duration',
                        '${_optimizedRoute!.totalDuration.toStringAsFixed(0)} min',
                        Icons.access_time,
                      ),
                      _buildRouteInfo(
                        'Stops',
                        '${_optimizedRoute!.waypoints.length}',
                        Icons.location_on,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openInNativeMaps,
                      icon: const Icon(Icons.navigation),
                      label: const Text('Open in Maps App'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppTheme.secondaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
          // Show open in maps button even if route not optimized (use current waypoints)
          else if (_waypoints.length >= 2)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openInNativeMaps,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Open in Maps App'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),

          // Delivery addresses list
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Delivery Addresses (${_activeOrders.length})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (_optimizedRoute != null)
                        Chip(
                          label: const Text('Optimized'),
                          backgroundColor: AppTheme.successColor.withValues(
                            alpha: 0.2,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _activeOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'All deliveries completed!',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _activeOrders.length,
                            itemBuilder: (context, index) {
                              final order = _activeOrders[index];
                        // Find the optimized position if route is optimized
                        int optimizedIndex = index;
                        if (_optimizedRoute != null) {
                          // Find which waypoint corresponds to this order
                          for (
                            int i = 0;
                            i < _optimizedRoute!.waypoints.length;
                            i++
                          ) {
                            final waypoint = _optimizedRoute!.waypoints[i];
                            if ((waypoint.latitude - order.location.latitude)
                                        .abs() <
                                    0.0001 &&
                                (waypoint.longitude - order.location.longitude)
                                        .abs() <
                                    0.0001) {
                              optimizedIndex = i;
                              break;
                            }
                          }
                        }
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _optimizedRoute != null
                                  ? AppTheme.primaryColor
                                  : Colors.grey,
                              child: Text(
                                '${optimizedIndex + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              'Order #${order.id.substring(0, 8)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(order.address),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.water_drop,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${order.gasQuantity} gallons',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          order.status,
                                        ).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        order.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(order.status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.of(context).push<OrderModel>(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DeliveryDetailScreen(order: order),
                                ),
                              );
                              
                              // Refresh orders when returning from delivery detail
                              if (mounted) {
                                await _refreshOrders();
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.orderStatusAccepted:
        return AppTheme.primaryColor;
      case AppConstants.orderStatusInTransit:
        return AppTheme.secondaryColor;
      default:
        return Colors.grey;
    }
  }
}
