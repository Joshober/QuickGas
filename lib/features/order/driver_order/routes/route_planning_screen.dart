import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../../../services/traffic_service.dart';
import '../../../../shared/models/order_model.dart';
import '../../../map/map_widget.dart';
import '../deliveries/delivery_detail_screen.dart';
import 'add_order_to_route_screen.dart';

class RoutePlanningScreen extends ConsumerStatefulWidget {
  final OrderModel? initialOrder;
  final List<OrderModel>? additionalOrders;
  final String? routeId; // Optional route ID to load existing route

  const RoutePlanningScreen({
    super.key,
    this.initialOrder,
    this.additionalOrders,
    this.routeId,
  });

  @override
  ConsumerState<RoutePlanningScreen> createState() =>
      _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends ConsumerState<RoutePlanningScreen> with WidgetsBindingObserver {
  final List<OrderModel> _selectedOrders = [];
  List<RoutePoint> _waypoints = [];
  OptimizedRoute? _optimizedRoute;
  bool _isOptimizing = false;
  bool _isLoading = false;
  String? _currentRouteId;
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.routeId != null) {
      _loadRoute(widget.routeId!);
    } else if (widget.initialOrder != null) {
      _selectedOrders.add(widget.initialOrder!);
      if (widget.additionalOrders != null) {
        _selectedOrders.addAll(widget.additionalOrders!);
      }
      _updateWaypoints();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh route when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshRoute();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when screen becomes visible again (e.g., returning from another screen)
    // But only if it's been more than 1 second since last refresh to avoid excessive calls
    final now = DateTime.now();
    if (_lastRefreshTime == null || 
        now.difference(_lastRefreshTime!).inSeconds > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_currentRouteId != null || _selectedOrders.isNotEmpty)) {
          _refreshRoute();
        }
      });
    }
  }

  Future<void> _refreshRoute() async {
    _lastRefreshTime = DateTime.now();
    if (_currentRouteId != null) {
      await _loadRoute(_currentRouteId!);
    } else if (_selectedOrders.isNotEmpty) {
      // Refresh orders if we have selected orders
      await _refreshOrders();
    }
  }

  Future<void> _refreshOrders() async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final refreshedOrders = <OrderModel>[];
      
      for (final order in _selectedOrders) {
        final updatedOrder = await firebaseService.getOrderById(order.id);
        if (updatedOrder != null) {
          refreshedOrders.add(updatedOrder);
        } else {
          // Order might have been deleted, keep the old one
          refreshedOrders.add(order);
        }
      }

      if (mounted) {
        setState(() {
          _selectedOrders.clear();
          _selectedOrders.addAll(refreshedOrders);
          _updateWaypoints();
        });
      }
    } catch (e) {
      print('Failed to refresh orders: $e');
    }
  }

  Future<void> _loadRoute(String routeId) async {
    setState(() => _isLoading = true);
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final route = await firebaseService.getRouteById(routeId);
      
      if (route != null && mounted) {
        setState(() {
          _currentRouteId = routeId;
        });

        // Load orders from route
        final orders = <OrderModel>[];
        for (final orderId in route.orderIds) {
          final orderDoc = await firebaseService.getOrderById(orderId);
          if (orderDoc != null) {
            orders.add(orderDoc);
          }
        }

        setState(() {
          _selectedOrders.clear();
          _selectedOrders.addAll(orders);
          _waypoints = route.waypoints
              .map((wp) => RoutePoint(wp.latitude, wp.longitude))
              .toList();
          
          // If route has polyline, create OptimizedRoute from it
          if (route.polyline != null && route.totalDistance != null && route.totalDuration != null) {
            // Create a simplified OptimizedRoute from saved route data
            _optimizedRoute = OptimizedRoute(
              waypoints: _waypoints,
              segments: [], // Empty segments as we don't have that data
              totalDistance: route.totalDistance!,
              totalDuration: route.totalDuration!,
              etas: [], // Empty ETAs
              polyline: route.polyline,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load route: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateWaypoints() {
    _waypoints = _selectedOrders
        .map(
          (order) =>
              RoutePoint(order.location.latitude, order.location.longitude),
        )
        .toList();
  }

  Future<void> _addOrderToRoute() async {
    final excludedIds = _selectedOrders.map((o) => o.id).toList();
    final selectedOrder = await Navigator.of(context).push<OrderModel>(
      PageTransitions.slideTransition<OrderModel>(
        AddOrderToRouteScreen(excludedOrderIds: excludedIds),
      ),
    );

    if (selectedOrder != null) {
      setState(() {
        _selectedOrders.add(selectedOrder);
        _updateWaypoints();
        _optimizedRoute = null;
      });
    }
  }

  Future<void> _optimizeRoute() async {
    if (_selectedOrders.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 orders to optimize')),
      );
      return;
    }

    setState(() => _isOptimizing = true);

    try {
      final trafficService = ref.read(trafficServiceProvider);

      if (_selectedOrders.isEmpty) {
        throw Exception('No orders selected');
      }

      final startPoint = RoutePoint(
        _selectedOrders.first.location.latitude,
        _selectedOrders.first.location.longitude,
      );

      final stops = _selectedOrders
          .skip(1)
          .map(
            (order) =>
                RoutePoint(order.location.latitude, order.location.longitude),
          )
          .toList();

      final optimized = await trafficService.optimizeRoute(
        startPoint,
        stops,
        null, // No end point for now
      );

      setState(() {
        _optimizedRoute = optimized;
        _waypoints = optimized.waypoints;
      });

      // Save route to Firestore
      await _saveRoute(optimized);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route optimized and saved successfully!'),
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

  Future<void> _openInGoogleMaps() async {
    if (_optimizedRoute == null || _optimizedRoute!.waypoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please optimize the route first')),
      );
      return;
    }

    try {
      final waypoints = _optimizedRoute!.waypoints;
      final origin = waypoints.first;
      final destination = waypoints.last;

      // Build waypoints string (exclude origin and destination)
      String waypointsParam = '';
      if (waypoints.length > 2) {
        final intermediateWaypoints = waypoints
            .sublist(1, waypoints.length - 1)
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
            const SnackBar(content: Text('Could not open Google Maps')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open Google Maps: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveRoute(OptimizedRoute optimized) async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final authState = ref.read(authStateProvider);

      if (authState.value == null) {
        throw Exception('Driver not authenticated');
      }

      final orderIds = _selectedOrders.map((o) => o.id).toList();
      final waypoints = optimized.waypoints
          .map((wp) => GeoPoint(wp.latitude, wp.longitude))
          .toList();

      if (_currentRouteId != null) {
        // Update existing route
        await firebaseService.updateRouteStatus(
          _currentRouteId!,
          AppConstants.routeStatusPlanning,
        );
        // Note: We could add an updateRoute method to update polyline, etc.
      } else {
        // Create new route
        final routeId = await firebaseService.createRoute(
          driverId: authState.value!.uid,
          orderIds: orderIds,
          waypoints: waypoints,
          polyline: optimized.polyline,
          totalDistance: optimized.totalDistance,
          totalDuration: optimized.totalDuration,
        );
        setState(() {
          _currentRouteId = routeId;
        });
      }
    } catch (e) {
      print('Failed to save route: $e');
    }
  }

  Future<void> _startRoute() async {
    if (_currentRouteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please optimize and save the route first'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No orders in route'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isOptimizing = true);

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final backendService = ref.read(backendServiceProvider);

      // Start route - this updates route status and all orders to in_transit
      await firebaseService.startRoute(_currentRouteId!, backendService);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route started! All orders marked as in transit.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start route: $e'),
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

  Future<void> _acceptOrders() async {
    if (_selectedOrders.isEmpty) return;

    setState(() => _isOptimizing = true);

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final authState = ref.read(authStateProvider);
      final backendService = ref.read(backendServiceProvider);

      if (authState.value == null) {
        throw Exception('Driver not authenticated');
      }

      // Accept orders one by one, stopping if any fail
      final List<String> acceptedOrderIds = [];
      final List<String> failedOrderIds = [];
      
      for (final order in _selectedOrders) {
        try {
          // Double-check order is still available before accepting
          if (order.driverId != null && order.driverId!.isNotEmpty) {
            failedOrderIds.add(order.id);
            continue;
          }
          
          await firebaseService.acceptOrder(
            order.id,
            authState.value!.uid,
            backendService: backendService,
          );
          acceptedOrderIds.add(order.id);
        } catch (e) {
          failedOrderIds.add(order.id);
          print('Failed to accept order ${order.id}: $e');
        }
      }
      
      if (failedOrderIds.isNotEmpty) {
        final message = acceptedOrderIds.isEmpty
            ? 'Failed to accept orders. Some may have been taken by other drivers.'
            : 'Accepted ${acceptedOrderIds.length} order(s). ${failedOrderIds.length} order(s) were unavailable.';
        throw Exception(message);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Orders accepted successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept orders: $e'),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentRouteId != null ? 'Route Details' : 'Plan Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addOrderToRoute,
            tooltip: 'Add Order',
          ),
          if (_selectedOrders.length >= 2)
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
          Expanded(
            flex: 2,
            child: MapWidget(
              waypoints: _waypoints,
              showRoute: _optimizedRoute != null,
              routePolyline: _optimizedRoute?.polyline,
              optimizedRoute: _optimizedRoute,
            ),
          ),

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
                      onPressed: _openInGoogleMaps,
                      icon: const Icon(Icons.navigation),
                      label: const Text('Open in Google Maps'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppTheme.secondaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Orders (${_selectedOrders.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _selectedOrders.length,
                      itemBuilder: (context, index) {
                        final order = _selectedOrders[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text('Order #${order.id.substring(0, 8)}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(order.address),
                                const SizedBox(height: 4),
                                Text(
                                  'Status: ${order.status.toUpperCase()}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: order.status == AppConstants.orderStatusCompleted
                                        ? AppTheme.successColor
                                        : order.status == AppConstants.orderStatusInTransit
                                            ? AppTheme.secondaryColor
                                            : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () async {
                              // Navigate to order detail screen
                              await Navigator.of(context).push<OrderModel>(
                                PageTransitions.slideTransition<OrderModel>(
                                  DeliveryDetailScreen(order: order),
                                ),
                              );
                              
                              // Always refresh route when returning from detail screen
                              // This ensures completed deliveries are reflected immediately
                              if (mounted) {
                                await _refreshRoute();
                              }
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (order.status == AppConstants.orderStatusCompleted)
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppTheme.successColor,
                                    size: 20,
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle),
                                  onPressed: () {
                                    setState(() {
                                      _selectedOrders.removeAt(index);
                                      // Update waypoints after removing order
                                      _waypoints = _selectedOrders
                                          .map(
                                            (order) => RoutePoint(
                                              order.location.latitude,
                                              order.location.longitude,
                                            ),
                                          )
                                          .toList();
                                      if (_optimizedRoute != null) {
                                        _optimizedRoute = null;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Show Start Route button if route is optimized and saved
                  if (_currentRouteId != null && _optimizedRoute != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isOptimizing ? null : _startRoute,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppTheme.successColor,
                          foregroundColor: Colors.white,
                        ),
                        child: _isOptimizing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Start Route',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isOptimizing ? null : _acceptOrders,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: _isOptimizing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Accept Orders',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
}
