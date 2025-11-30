import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/widgets/base64_image_widget.dart';
import '../../map/map_widget.dart';
import '../../../services/traffic_service.dart';

class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final firebaseService = ref.watch(firebaseServiceProvider);

    if (authState.value == null) {
      return const Center(child: Text('Please login'));
    }

    final customerOrders = firebaseService.getCustomerOrders(
      authState.value!.uid,
    );

    final activeOrders = customerOrders.map(
      (orders) => orders
          .where(
            (order) =>
                order.status == AppConstants.orderStatusAccepted ||
                order.status == AppConstants.orderStatusInTransit ||
                order.status == AppConstants.orderStatusCompleted,
          )
          .toList(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Order Tracking')),
      body: StreamBuilder<List<OrderModel>>(
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
                    Icons.location_on_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active orders',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your orders here',
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
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
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
                  subtitle: Text(order.address),
                  children: [

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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(order.status),
                                ),
                          ),
                          const SizedBox(height: 8),
                          if (order.driverId != null) Text('Driver assigned'),
                          if (order.estimatedTimeMinutes != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  order.estimatedArrivalTime != null
                                      ? 'ETA: ${_formatTime(order.estimatedArrivalTime!)} (${order.estimatedTimeMinutes!.toStringAsFixed(0)} min)'
                                      : 'ETA: ${order.estimatedTimeMinutes!.toStringAsFixed(0)} minutes',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                          if (order.driverLocation != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.my_location, size: 16, color: Colors.green),
                                const SizedBox(width: 8),
                                Text(
                                  'Driver location: Live tracking',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (order.deliveryPhotoUrl != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Delivery Photo',
                              style: Theme.of(context).textTheme.titleSmall,
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.orderStatusAccepted:
        return AppTheme.primaryColor;
      case AppConstants.orderStatusInTransit:
        return AppTheme.secondaryColor;
      case AppConstants.orderStatusCompleted:
        return AppTheme.successColor;
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
      case AppConstants.orderStatusCompleted:
        return Icons.check;
      default:
        return Icons.help;
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }
}
