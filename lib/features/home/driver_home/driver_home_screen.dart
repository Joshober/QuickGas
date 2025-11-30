import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/bottom_navigation.dart';
import '../../order/driver_order/routes/routes_screen.dart';
import '../../order/driver_order/deliveries/delivery_detail_screen.dart';
import '../../order/driver_order/deliveries/delivery_route_screen.dart';
import '../../profile/profile_screen.dart';
import '../../../core/animations/page_transitions.dart';
import '../../../shared/models/order_model.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const DriverHomeScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider).value;

    return Scaffold(
      body: FadeTransition(
        opacity: _animationController,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(userProfile),
            const RoutesScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        userRole: AppConstants.roleDriver,
      ),
    );
  }

  Widget _buildHomeTab(userProfile) {
    final authState = ref.watch(authStateProvider);
    final firebaseService = ref.watch(firebaseServiceProvider);

    if (authState.value == null) {
      return const Center(child: Text('Please login'));
    }

    final pendingOrders = firebaseService.getPendingOrders();
    final driverOrders = firebaseService.getDriverOrders(authState.value!.uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Welcome${userProfile?.name != null ? ', ${userProfile!.name}' : ''}',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: StreamBuilder<List<OrderModel>>(
          stream: pendingOrders,
          builder: (context, pendingSnapshot) {
            final pendingCount = pendingSnapshot.data?.length ?? 0;

            return StreamBuilder<List<OrderModel>>(
              stream: driverOrders,
              builder: (context, driverSnapshot) {
                final activeCount =
                    driverSnapshot.data
                        ?.where(
                          (order) =>
                              order.status ==
                                  AppConstants.orderStatusAccepted ||
                              order.status == AppConstants.orderStatusInTransit,
                        )
                        .length ??
                    0;

                // Get active orders for display
                final activeOrdersList =
                    driverSnapshot.data
                        ?.where(
                          (order) =>
                              order.status ==
                                  AppConstants.orderStatusAccepted ||
                              order.status == AppConstants.orderStatusInTransit,
                        )
                        .toList() ??
                    [];

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats row
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Available',
                              '$pendingCount',
                              Icons.local_shipping,
                              AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'Active',
                              '$activeCount',
                              Icons.route,
                              AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Active Deliveries Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Active Deliveries',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (activeOrdersList.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                _onTabChanged(1);
                              },
                              child: const Text('View All'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Active deliveries list (max 5)
                      if (activeOrdersList.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.local_shipping_outlined,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No active deliveries',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Accept orders to start delivering',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[500]),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _onTabChanged(1);
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Find Orders'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        // Show route optimization button if 2+ orders
                        if (activeOrdersList.length >= 2)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  PageTransitions.slideTransition(
                                    DeliveryRouteScreen(
                                      orders: activeOrdersList,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.route,
                                      color: AppTheme.primaryColor,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Optimize Route',
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
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        // Show recent active orders
                        ...activeOrdersList.take(5).map((order) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(order.status),
                                child: Icon(
                                  _getStatusIcon(order.status),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text('Order #${order.id.substring(0, 8)}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    order.status.toUpperCase(),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
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
                        }).toList(),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _onTabChanged(1);
        },
        icon: const Icon(Icons.search),
        label: const Text('Find Orders'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
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

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
