import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/bottom_navigation.dart';
import '../../order/customer_order/order_list_screen.dart'
    hide firebaseServiceProvider;
import '../../order/customer_order/create_order_screen.dart';
import '../../order/customer_order/order_detail_screen.dart';
import '../../profile/profile_screen.dart';
import '../../../core/animations/page_transitions.dart';
import '../../../shared/models/order_model.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const CustomerHomeScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen>
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
            const OrderListScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        userRole: AppConstants.roleCustomer,
      ),
    );
  }

  Widget _buildHomeTab(userProfile) {
    final authState = ref.watch(authStateProvider);
    final firebaseService = ref.watch(firebaseServiceProvider);

    if (authState.value == null) {
      return const Center(child: Text('Please login'));
    }

    final customerOrders = firebaseService.getCustomerOrders(
      authState.value!.uid,
    );

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
          stream: customerOrders,
          builder: (context, snapshot) {
            final orders = snapshot.data ?? [];
            final activeOrders = orders
                .where(
                  (order) =>
                      order.status == AppConstants.orderStatusPending ||
                      order.status == AppConstants.orderStatusAccepted ||
                      order.status == AppConstants.orderStatusInTransit,
                )
                .length;
            final completedOrders = orders
                .where(
                  (order) => order.status == AppConstants.orderStatusCompleted,
                )
                .length;

            // Get recent orders (last 5, sorted by creation date)
            final recentOrders = orders
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final displayOrders = recentOrders.take(5).toList();

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
                          'Active Orders',
                          '$activeOrders',
                          Icons.shopping_cart,
                          AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Completed',
                          '$completedOrders',
                          Icons.check_circle,
                          AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Recent Orders Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Orders',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (orders.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            _onTabChanged(1);
                          },
                          child: const Text('View All'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Recent orders list
                  if (displayOrders.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No orders yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first order to get started',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...displayOrders.map((order) {
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
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
                                OrderDetailScreen(orderId: order.id),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            PageTransitions.slideTransition(const CreateOrderScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.orderStatusPending:
        return AppTheme.warningColor;
      case AppConstants.orderStatusAccepted:
        return AppTheme.primaryColor;
      case AppConstants.orderStatusInTransit:
        return AppTheme.secondaryColor;
      case AppConstants.orderStatusCompleted:
        return AppTheme.successColor;
      case AppConstants.orderStatusCancelled:
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case AppConstants.orderStatusPending:
        return Icons.pending;
      case AppConstants.orderStatusAccepted:
        return Icons.check_circle;
      case AppConstants.orderStatusInTransit:
        return Icons.local_shipping;
      case AppConstants.orderStatusCompleted:
        return Icons.check;
      case AppConstants.orderStatusCancelled:
        return Icons.cancel;
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
