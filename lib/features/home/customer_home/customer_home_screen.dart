import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/bottom_navigation.dart';
import '../../order/customer_order/order_list_screen.dart'
    hide firebaseServiceProvider;
import '../../order/customer_order/create_order_screen.dart';
import '../../tracking/customer_tracking/tracking_screen.dart';
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
            const TrackingScreen(),
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

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

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
                  const SizedBox(height: 16),

                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          'New Order',
                          Icons.add_circle_outline,
                          AppTheme.primaryColor,
                          () {
                            Navigator.of(context).push(
                              PageTransitions.slideTransition(
                                const CreateOrderScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionCard(
                          'My Orders',
                          Icons.list_alt,
                          AppTheme.secondaryColor,
                          () {
                            _onTabChanged(1);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
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

  Widget _buildActionCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 48),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
