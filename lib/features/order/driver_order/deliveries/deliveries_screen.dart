import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/route_model.dart';
import '../routes/create_route_screen.dart';
import '../routes/route_planning_screen.dart';
import 'delivery_detail_screen.dart';
import 'delivery_route_screen.dart';

class DeliveriesScreen extends ConsumerStatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  ConsumerState<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends ConsumerState<DeliveriesScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final firebaseService = ref.watch(firebaseServiceProvider);

    if (authState.value == null) {
      return const Scaffold(
        body: Center(child: Text('Please login')),
      );
    }

    final driverId = authState.value!.uid;
    final driverOrders = firebaseService.getDriverOrders(driverId);
    final driverRoutes = firebaseService.getDriverRoutes(driverId);

    final activeOrders = driverOrders.map(
      (orders) {
        // Filter and deduplicate by order ID
        final Map<String, OrderModel> uniqueOrders = {};
        for (final order in orders) {
          if ((order.status == AppConstants.orderStatusAccepted ||
                  order.status == AppConstants.orderStatusInTransit) &&
              (!uniqueOrders.containsKey(order.id) ||
                  order.updatedAt.isAfter(uniqueOrders[order.id]!.updatedAt))) {
            uniqueOrders[order.id] = order;
          }
        }
        return uniqueOrders.values.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Deliveries'),
        actions: [
          StreamBuilder<List<OrderModel>>(
            stream: activeOrders,
            builder: (context, snapshot) {
              final orders = snapshot.data ?? [];
              if (orders.length < 2) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.route),
                tooltip: 'Create Optimized Route',
                onPressed: () {
                  Navigator.of(context).push(
                    PageTransitions.slideTransition(
                      DeliveryRouteScreen(orders: orders),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      drawer: _buildRoutesDrawer(driverRoutes),
      body: Column(
        children: [
          // Large Create Route Button
          StreamBuilder<List<OrderModel>>(
            stream: activeOrders,
            builder: (context, snapshot) {
              final orders = snapshot.data ?? [];
              if (orders.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<List<OrderModel>>(
                      PageTransitions.slideTransition<List<OrderModel>>(
                        const CreateRouteScreen(),
                      ),
                    );

                    if (result != null && result.isNotEmpty && mounted) {
                      final additionalOrders = result.length > 1 ? result.sublist(1) : null;
                      Navigator.of(context).push(
                        PageTransitions.slideTransition(
                          RoutePlanningScreen(
                            initialOrder: result.first,
                            additionalOrders: additionalOrders,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_road, size: 28),
                  label: const Text(
                    'Create Route',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            },
          ),
          // Accepted Orders List
          Expanded(
            child: StreamBuilder<List<OrderModel>>(
              stream: activeOrders,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final orders = snapshot.data ?? [];

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No active deliveries',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Accepted orders will appear here',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            final router = GoRouter.of(context);
                            router.go('/driver/routes');
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Accept New Orders'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(order.status),
                          child: Icon(
                            _getStatusIcon(order.status),
                            color: Colors.white,
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
                                color: _getStatusColor(order.status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            PageTransitions.slideTransition(
                              DeliveryDetailScreen(order: order),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case AppConstants.orderStatusAccepted:
        return Icons.check_circle;
      case AppConstants.orderStatusInTransit:
        return Icons.local_shipping;
      default:
        return Icons.help;
    }
  }

  Widget _buildRoutesDrawer(Stream<List<RouteModel>> routesStream) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.route,
                  color: Colors.white,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'My Routes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<RouteModel>>(
              stream: routesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final routes = snapshot.data ?? [];

                if (routes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.route_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No active routes',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a route to see it here',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: routes.length,
                  itemBuilder: (context, index) {
                    final route = routes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRouteStatusColor(route.status),
                          child: Icon(
                            _getRouteStatusIcon(route.status),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          'Route ${route.id.substring(0, 8)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${route.orderIds.length} orders'),
                            if (route.totalDistance != null)
                              Text(
                                '${route.totalDistance!.toStringAsFixed(1)} km',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            Text(
                              'Status: ${route.status.toUpperCase()}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _getRouteStatusColor(route.status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            PageTransitions.slideTransition(
                              RoutePlanningScreen(
                                initialOrder: null,
                                routeId: route.id,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getRouteStatusColor(String status) {
    switch (status) {
      case AppConstants.routeStatusPlanning:
        return Colors.orange;
      case AppConstants.routeStatusActive:
        return AppTheme.successColor;
      case AppConstants.routeStatusCompleted:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getRouteStatusIcon(String status) {
    switch (status) {
      case AppConstants.routeStatusPlanning:
        return Icons.edit_location;
      case AppConstants.routeStatusActive:
        return Icons.navigation;
      case AppConstants.routeStatusCompleted:
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }
}
