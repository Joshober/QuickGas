import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/animations/page_transitions.dart';
import '../../../services/firebase_service.dart';
import '../../../shared/models/order_model.dart';
import 'create_order_screen.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends ConsumerWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final orders = ref
        .watch(firebaseServiceProvider)
        .getCustomerOrders(authState.value?.uid ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
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

          final orderList = snapshot.data ?? [];

          if (orderList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first order',
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
            itemCount: orderList.length,
            itemBuilder: (context, index) {
              final order = orderList[index];
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
                  subtitle: Text(order.address),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () {
                    Navigator.of(context).push(
                      PageTransitions.slideTransition(
                        OrderDetailScreen(orderId: order.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
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
}

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});
