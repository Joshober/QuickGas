import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/animations/page_transitions.dart';
import '../../../services/firebase_service.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/widgets/base64_image_widget.dart';
import '../../../features/map/map_widget.dart';
import '../../../services/traffic_service.dart';
import 'create_order_screen.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all'; // 'all', 'active', 'completed'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedFilter = 'all';
            break;
          case 1:
            _selectedFilter = 'active';
            break;
          case 2:
            _selectedFilter = 'completed';
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    switch (_selectedFilter) {
      case 'active':
        return orders
            .where(
              (order) =>
                  order.status == AppConstants.orderStatusPending ||
                  order.status == AppConstants.orderStatusAccepted ||
                  order.status == AppConstants.orderStatusInTransit,
            )
            .toList();
      case 'completed':
        return orders
            .where(
              (order) => order.status == AppConstants.orderStatusCompleted,
            )
            .toList();
      default:
        return orders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final orders = ref
        .watch(firebaseServiceProvider)
        .getCustomerOrders(authState.value?.uid ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                PageTransitions.slideTransition(const CreateOrderScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: orders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allOrders = snapshot.data ?? [];
          final filteredOrders = _filterOrders(allOrders);

          if (filteredOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedFilter == 'active'
                        ? Icons.location_on_outlined
                        : _selectedFilter == 'completed'
                            ? Icons.check_circle_outline
                            : Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFilter == 'active'
                        ? 'No active orders'
                        : _selectedFilter == 'completed'
                            ? 'No completed orders'
                            : 'No orders yet',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedFilter == 'all'
                        ? 'Create your first order'
                        : 'Orders will appear here',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredOrders.length,
            itemBuilder: (context, index) {
              final order = filteredOrders[index];
              final isActive = order.status == AppConstants.orderStatusAccepted ||
                  order.status == AppConstants.orderStatusInTransit;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(order.status),
                    child: Icon(
                      _getStatusIcon(order.status),
                      color: Colors.white,
                    ),
                  ),
                  title: Text('Order #${order.id.substring(0, 8)}'),
                  subtitle: Text(
                    order.address,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onExpansionChanged: (expanded) {
                    // Optional: Load map data when expanded
                  },
                  children: isActive
                      ? [
                          // Show map and tracking info for active orders
                          SizedBox(
                            height: 200,
                            child: MapWidget(
                              waypoints: [
                                RoutePoint(
                                  order.location.latitude,
                                  order.location.longitude,
                                ),
                              ],
                              showRoute: false,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status: ${order.status.toUpperCase()}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(order.status),
                                      ),
                                ),
                                const SizedBox(height: 8),
                                if (order.driverId != null)
                                  Text('Driver assigned'),
                                if (order.estimatedTimeMinutes != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          order.estimatedArrivalTime != null
                                              ? 'ETA: ${_formatTime(order.estimatedArrivalTime!)} (${order.estimatedTimeMinutes!.toStringAsFixed(0)} min)'
                                              : 'ETA: ${order.estimatedTimeMinutes!.toStringAsFixed(0)} minutes',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (order.driverLocation != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.my_location,
                                          size: 16, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Driver location: Live tracking',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (order.deliveryPhotoUrl != null) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Delivery Photo',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Base64ImageWidget(
                                      imageString: order.deliveryPhotoUrl,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        PageTransitions.slideTransition(
                                          OrderDetailScreen(orderId: order.id),
                                        ),
                                      );
                                    },
                                    child: const Text('View Details'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]
                      : [
                          // Simple view for non-active orders
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status: ${order.status.toUpperCase()}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(order.status),
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text('Gas Quantity: ${order.gasQuantity} gallons'),
                                if (order.specialInstructions != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Instructions: ${order.specialInstructions}',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 3,
                                  ),
                                ],
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        PageTransitions.slideTransition(
                                          OrderDetailScreen(orderId: order.id),
                                        ),
                                      );
                                    },
                                    child: const Text('View Details'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                ),
              );
            },
          );
        },
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

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
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
}

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});
