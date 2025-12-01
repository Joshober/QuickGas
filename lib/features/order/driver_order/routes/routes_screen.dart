import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../../../services/maps_service.dart';
import '../../../../shared/models/order_model.dart';
import 'route_planning_screen.dart';
import 'create_route_screen.dart';
import '../deliveries/delivery_route_screen.dart';
import '../deliveries/delivery_detail_screen.dart';

class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});

  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends ConsumerState<RoutesScreen>
    with SingleTickerProviderStateMixin {
  Position? _currentLocation;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final mapsService = MapsService();
      final position = await mapsService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentLocation = position;
        });
      }
    } catch (e) {
      // Silently fail - location is optional
      if (mounted) {
        debugPrint('Could not get current location: $e');
      }
    }
  }

  Future<void> _openCreateRouteScreen() async {
    final result = await Navigator.of(context).push<List<OrderModel>>(
      PageTransitions.slideTransition<List<OrderModel>>(
        const CreateRouteScreen(),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      // Navigate to RoutePlanningScreen with all selected orders
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
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final firebaseService = ref.watch(firebaseServiceProvider);

    if (authState.value == null) {
      return const Scaffold(
        body: Center(child: Text('Please login')),
      );
    }

    final pendingOrders = firebaseService.getPendingOrders();
    final driverOrders = firebaseService.getDriverOrders(authState.value!.uid);

    // Get active orders (accepted or in transit) for optimized routes
    // Deduplicate by order ID to prevent duplicates
    final activeOrders = driverOrders.map(
      (orders) {
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
        title: const Text('Orders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Available'),
            Tab(text: 'Active'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Optimized Route',
            onPressed: _openCreateRouteScreen,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _getCurrentLocation();
          await Future.delayed(const Duration(seconds: 1));
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Available Orders
            _buildAvailableOrdersTab(pendingOrders),
            // Tab 2: Active Orders
            _buildActiveOrdersTab(activeOrders),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableOrdersTab(Stream<List<OrderModel>> pendingOrders) {
    return StreamBuilder<List<OrderModel>>(
      stream: pendingOrders,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Additional safety filter: remove any orders that have a driverId assigned
        // This is a UI-level safety check in case the query doesn't filter properly
        final orders = (snapshot.data ?? [])
            .where((order) => order.driverId == null || order.driverId!.isEmpty)
            .toList();

        if (orders.isEmpty) {
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
                  'No pending orders',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Orders will appear here when customers place requests',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Sort orders by proximity if location is available
        List<OrderModel> sortedOrders = List.from(orders);
        if (_currentLocation != null) {
          sortedOrders.sort((a, b) {
            final distanceA = Geolocator.distanceBetween(
              _currentLocation!.latitude,
              _currentLocation!.longitude,
              a.location.latitude,
              a.location.longitude,
            );
            final distanceB = Geolocator.distanceBetween(
              _currentLocation!.latitude,
              _currentLocation!.longitude,
              b.location.latitude,
              b.location.longitude,
            );
            return distanceA.compareTo(distanceB);
          });
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedOrders.length,
          itemBuilder: (context, index) {
            final order = sortedOrders[index];
            final distance = _currentLocation != null
                ? Geolocator.distanceBetween(
                    _currentLocation!.latitude,
                    _currentLocation!.longitude,
                    order.location.latitude,
                    order.location.longitude,
                  ) / 1000 // Convert to km
                : null;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: const Icon(
                    Icons.local_shipping,
                    color: Colors.white,
                  ),
                ),
                title: Text('Order #${order.id.substring(0, 8)}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.address,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
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
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (distance != null) ...[
                          const SizedBox(width: 16),
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${distance.toStringAsFixed(1)} km',
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      PageTransitions.slideTransition(
                        RoutePlanningScreen(initialOrder: order),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveOrdersTab(Stream<List<OrderModel>> activeOrders) {
    return StreamBuilder<List<OrderModel>>(
      stream: activeOrders,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final activeOrdersList = snapshot.data ?? [];

        if (activeOrdersList.isEmpty) {
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
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Accepted orders will appear here',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        // Show route optimization card if 2+ orders
        final hasRoute = activeOrdersList.length >= 2;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (hasRoute)
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      PageTransitions.slideTransition(
                        DeliveryRouteScreen(orders: activeOrdersList),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.route,
                              color: AppTheme.primaryColor,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Optimized Route',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    '${activeOrdersList.length} stops',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Chip(
                              label: const Text('Active'),
                              backgroundColor:
                                  AppTheme.successColor.withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildRouteStat(
                              Icons.location_on,
                              '${activeOrdersList.length}',
                              'Stops',
                            ),
                            _buildRouteStat(
                              Icons.access_time,
                              'Active',
                              'Status',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // List of active orders
            ...activeOrdersList.map((order) {
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
                      Text(
                        order.address,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${order.status.toUpperCase()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getStatusColor(order.status),
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
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
            }).toList(),
          ],
        );
      },
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

  Widget _buildRouteStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }
}
