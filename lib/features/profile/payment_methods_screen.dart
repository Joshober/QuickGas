import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Payment Methods',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.credit_card,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('Add Payment Method'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment method integration coming soon'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Default Payment Method',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.payment,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('Cash on Delivery'),
                subtitle: const Text('Default payment method'),
                trailing: const Icon(Icons.check, color: AppTheme.successColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
