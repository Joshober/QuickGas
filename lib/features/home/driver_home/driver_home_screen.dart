import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/bottom_navigation.dart';
import '../../order/driver_order/routes/routes_screen.dart';
import '../../order/driver_order/deliveries/deliveries_screen.dart';
import '../../profile/profile_screen.dart';
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
            const DeliveriesScreen(),
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

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

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
                              'View Orders',
                              Icons.list_alt,
                              AppTheme.primaryColor,
                              () {
                                _onTabChanged(1);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionCard(
                              'My Deliveries',
                              Icons.local_shipping,
                              AppTheme.secondaryColor,
                              () {
                                _onTabChanged(2);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
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
