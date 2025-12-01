import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_keys.dart';
import '../../services/payment_service.dart';
import '../../services/payment_error.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final double amount;
  final String orderId;
  final String currency;

  const PaymentScreen({
    super.key,
    required this.amount,
    required this.orderId,
    this.currency = 'usd',
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _cardFormKey = GlobalKey<FormState>();
  final _cardHolderNameController = TextEditingController();

  bool _isProcessing = false;
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _cardHolderNameController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    // Validate amount
    if (widget.amount <= 0) {
      setState(() {
        _errorMessage = 'Invalid payment amount';
      });
      return;
    }

    // No form validation needed - PaymentSheet handles card input

    setState(() {
      _isProcessing = true;
      _isAuthenticating = false;
      _errorMessage = null;
    });

    try {
      final paymentService = PaymentService();

      // Get backend URL from ApiKeys
      final backendUrl = ApiKeys.backendUrl;
      if (backendUrl.isEmpty || backendUrl == 'YOUR_BACKEND_URL_HERE') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Backend URL not configured. Payment processing unavailable.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Set backend URL for payment service
      paymentService.setBackendUrl(backendUrl);

      // Don't block on backend availability check - just try to create payment intent
      // If backend is down, the payment intent creation will fail with a clear error

      // Generate idempotency key from order ID
      final idempotencyKey =
          'order_${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}';

      // Create payment intent
      final clientSecret = await paymentService.createPaymentIntent(
        amount: widget.amount,
        currency: widget.currency,
        metadata: {'orderId': widget.orderId},
        idempotencyKey: idempotencyKey,
      );

      // Verify Stripe is initialized
      if (Stripe.publishableKey.isEmpty) {
        throw PaymentError.configuration(
          'Stripe is not initialized. Please check your configuration.',
        );
      }

      // Use PaymentSheet for secure payment processing
      // PaymentSheet handles card collection, validation, and 3D Secure automatically
      // This is the recommended Stripe approach for Flutter
      try {
        print(
          'Initializing PaymentSheet with clientSecret: ${clientSecret.substring(0, 20)}...',
        );

        // Initialize PaymentSheet with the payment intent
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'QuickGas',
          ),
        );

        print('PaymentSheet initialized successfully, presenting...');

        // Present PaymentSheet to user
        // This shows a native payment form where user can enter card details securely
        await Stripe.instance.presentPaymentSheet();

        print('PaymentSheet presented successfully');

        // Payment was successful
        final paymentIntentId = paymentService.extractPaymentIntentId(
          clientSecret,
        );
        if (mounted) {
          Navigator.of(
            context,
          ).pop({'success': true, 'paymentIntentId': paymentIntentId});
        }
      } on StripeException catch (e) {
        // Handle Stripe-specific errors
        // Check if user canceled (error code 'payment_intent_payment_attempt_failed' or similar)
        final errorCode = e.error.code.toString();
        print('StripeException: code=$errorCode, message=${e.error.message}');
        if (errorCode.contains('canceled') || errorCode.contains('Canceled')) {
          // User canceled - don't show error, just stop processing
          setState(() {
            _isProcessing = false;
          });
          return;
        }

        setState(() {
          _errorMessage =
              e.error.message ?? 'Payment failed. Please try again.';
          _isProcessing = false;
        });
      } catch (e, stackTrace) {
        print('PaymentSheet error: $e');
        print('Stack trace: $stackTrace');
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _isProcessing = false;
        });
      }
    } on PaymentError catch (e) {
      print('PaymentError: ${e.userFriendlyMessage}');
      setState(() {
        _errorMessage = e.userFriendlyMessage;
      });
    } catch (e, stackTrace) {
      print('Unexpected error in _processPayment: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isAuthenticating = false;
        });
      }
    }
  }

  // Note: 3D Secure is handled automatically by PaymentSheet

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _cardFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Order Summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Summary',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '\$${widget.amount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Payment Form
              Text(
                'Card Information',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Payment Information
              // Note: Card details are collected via PaymentSheet when user taps "Pay"
              // PaymentSheet provides a secure, native payment form
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Payment Information',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Card details will be collected securely when you tap "Pay". '
                      'You\'ll be prompted to enter your card information in a secure payment form.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Card Holder Name (optional but recommended)
              TextFormField(
                controller: _cardHolderNameController,
                decoration: const InputDecoration(
                  labelText: 'Card Holder Name (Optional)',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.errorColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppTheme.errorColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: 16),

              // Pay Button
              ElevatedButton(
                onPressed: (_isProcessing || _isAuthenticating)
                    ? null
                    : _processPayment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: (_isProcessing || _isAuthenticating)
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          if (_isAuthenticating) ...[
                            const SizedBox(width: 12),
                            const Text(
                              'Authenticating...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ],
                      )
                    : Text(
                        'Pay \$${widget.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Test Card Info
              Card(
                color: Colors.blue.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Test Card',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Card: 4242 4242 4242 4242\nExpiry: Any future date\nCVC: Any 3 digits',
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                      ),
                    ],
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
