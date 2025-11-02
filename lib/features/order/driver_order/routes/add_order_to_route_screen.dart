import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/models/order_model.dart';

class AddOrderToRouteScreen extends ConsumerWidget {
  final List<String> excludedOrderIds;

  const AddOrderToRouteScreen({super.key, required this.excludedOrderIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseService = ref.watch(firebaseServiceProvider);
    final pendingOrders = firebaseService.getPendingOrders();

    final availableOrders = pendingOrders.map(
      (orders) => orders
          .where((order) => !excludedOrderIds.contains(order.id))
          .toList(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Add Orders to Route')),
      body: StreamBuilder<List<OrderModel>>(
        stream: availableOrders,
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
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No additional orders available',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
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
                child: CheckboxListTile(
                  title: Text('Order #${order.id.substring(0, 8)}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.address),
                      Text('${order.gasQuantity} gallons'),
                    ],
                  ),
                  value: false,
                  onChanged: (value) {

                    Navigator.of(context).pop(order);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
