import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/widgets/base64_image_widget.dart';
import 'package:intl/intl.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseService = ref.read(firebaseServiceProvider);
    final orderStream = firebaseService.getOrderStream(orderId);

    return Scaffold(
      appBar: AppBar(title: Text('Order #${orderId.substring(0, 8)}')),
      body: StreamBuilder<OrderModel?>(
        stream: orderStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final order = snapshot.data;
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Card(
                  color: _getStatusColor(order.status),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(order.status),
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status: ${order.status.toUpperCase()}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                'Payment: ${order.paymentStatus.toUpperCase()}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Order Details',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.location_on,
                  'Delivery Address',
                  order.address,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.water_drop,
                  'Gas Quantity',
                  '${order.gasQuantity} gallons',
                ),
                if (order.specialInstructions != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.note,
                    'Special Instructions',
                    order.specialInstructions!,
                  ),
                ],
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.payment,
                  'Payment Method',
                  order.paymentMethod == AppConstants.paymentMethodStripe
                      ? 'Stripe'
                      : 'Cash on Delivery',
                ),
                const SizedBox(height: 16),

                if (order.deliveryPhotoUrl != null) ...[
                  Text(
                    'Delivery Photo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Base64ImageWidget(
                      imageString: order.deliveryPhotoUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                Text(
                  'Timestamps',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Created: ${DateFormat('MMM dd, yyyy hh:mm a').format(order.createdAt)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (order.deliveryVerifiedAt != null)
                  Text(
                    'Delivered: ${DateFormat('MMM dd, yyyy hh:mm a').format(order.deliveryVerifiedAt!)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
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
