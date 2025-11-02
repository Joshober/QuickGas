import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/animations/page_transitions.dart';
import '../../../features/map/location_picker_screen.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gasQuantityController = TextEditingController();
  final _instructionsController = TextEditingController();

  GeoPoint? _selectedLocation;
  String _selectedAddress = '';
  String _selectedPaymentMethod = AppConstants.paymentMethodCash;
  bool _isLoading = false;

  @override
  void dispose() {
    _gasQuantityController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _selectLocation() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      PageTransitions.slideTransition<Map<String, dynamic>>(
        const LocationPickerScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result['location'] as GeoPoint;
        _selectedAddress = result['address'] as String;
      });
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery location')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authStateProvider);
      final firebaseService = ref.read(firebaseServiceProvider);

      if (authState.value == null) {
        throw Exception('User not authenticated');
      }

      await firebaseService.createOrder(
        customerId: authState.value!.uid,
        location: _selectedLocation!,
        address: _selectedAddress,
        gasQuantity: double.parse(_gasQuantityController.text),
        specialInstructions: _instructionsController.text.isEmpty
            ? null
            : _instructionsController.text,
        paymentMethod: _selectedPaymentMethod,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order created successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create order: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Order')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.location_on,
                    color: AppTheme.primaryColor,
                  ),
                  title: const Text('Delivery Location'),
                  subtitle: Text(
                    _selectedAddress.isEmpty
                        ? 'Tap to select location'
                        : _selectedAddress,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _selectLocation,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _gasQuantityController,
                decoration: const InputDecoration(
                  labelText: 'Gas Quantity (gallons)',
                  prefixIcon: Icon(Icons.water_drop),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter gas quantity';
                  }
                  final quantity = double.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _instructionsController,
                decoration: const InputDecoration(
                  labelText: 'Special Instructions (Optional)',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              Text(
                'Payment Method',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: AppConstants.paymentMethodCash,
                    label: Text('Cash on Delivery'),
                  ),
                  ButtonSegment(
                    value: AppConstants.paymentMethodStripe,
                    label: Text('Stripe'),
                  ),
                ],
                selected: {_selectedPaymentMethod},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedPaymentMethod = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _createOrder,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Create Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
