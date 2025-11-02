import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../../../services/traffic_service.dart';
import '../../../../shared/models/order_model.dart';
import '../../../map/map_widget.dart';
import 'add_order_to_route_screen.dart';

class RoutePlanningScreen extends ConsumerStatefulWidget {
  final OrderModel initialOrder;

  const RoutePlanningScreen({super.key, required this.initialOrder});

  @override
  ConsumerState<RoutePlanningScreen> createState() =>
      _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends ConsumerState<RoutePlanningScreen> {
  final List<OrderModel> _selectedOrders = [];
  List<RoutePoint> _waypoints = [];
  OptimizedRoute? _optimizedRoute;
  bool _isOptimizing = false;

  @override
  void initState() {
    super.initState();
    _selectedOrders.add(widget.initialOrder);
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

        _optimizedRoute = null;
        _waypoints = [];
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

      final startPoint = RoutePoint(
        widget.initialOrder.location.latitude,
        widget.initialOrder.location.longitude,
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

  Future<void> _acceptOrders() async {
    if (_selectedOrders.isEmpty) return;

    setState(() => _isOptimizing = true);

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final authState = ref.read(authStateProvider);

      if (authState.value == null) {
        throw Exception('Driver not authenticated');
      }

      for (final order in _selectedOrders) {
        await firebaseService.acceptOrder(order.id, authState.value!.uid);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Route'),
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
                            subtitle: Text(order.address),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle),
                              onPressed: () {
                                setState(() {
                                  _selectedOrders.removeAt(index);
                                  if (_optimizedRoute != null) {
                                    _optimizedRoute = null;
                                  }
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
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
