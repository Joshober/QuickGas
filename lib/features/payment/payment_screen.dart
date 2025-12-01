import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_keys.dart';
import '../../services/payment_service.dart';
import '../../services/payment_error.dart';
import '../../core/providers/auth_provider.dart';

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
  final _cardNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvcController = TextEditingController();
  final _cardHolderNameController = TextEditingController();

  bool _isProcessing = false;
  bool _isAuthenticating = false;
  String? _errorMessage;
  CardFormEditController? _cardFormController;

  @override
  void initState() {
    super.initState();
    _cardFormController = CardFormEditController();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvcController.dispose();
    _cardHolderNameController.dispose();
    _cardFormController?.dispose();
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

    if (!_cardFormKey.currentState!.validate()) {
      return;
    }

    // Check if card form is valid
    if (_cardFormController == null) {
      setState(() {
        _errorMessage = 'Card form not initialized';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _isAuthenticating = false;
      _errorMessage = null;
    });

    try {
      final paymentService = PaymentService();
      final backendService = ref.read(backendServiceProvider);
      
      // Check if backend is available
      if (backendService == null || !backendService.isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment processing requires backend connection. Please try again later or use cash payment.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Get backend URL from ApiKeys
      final backendUrl = ApiKeys.backendUrl;
      if (backendUrl.isEmpty || backendUrl == 'YOUR_BACKEND_URL_HERE') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backend URL not configured. Payment processing unavailable.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      paymentService.setBackendUrl(backendUrl);

      // Generate idempotency key from order ID
      final idempotencyKey = 'order_${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}';

      // Create payment intent
      final clientSecret = await paymentService.createPaymentIntent(
        amount: widget.amount,
        currency: widget.currency,
        metadata: {
          'orderId': widget.orderId,
        },
        idempotencyKey: idempotencyKey,
      );

      // Payment intent ID can be extracted from clientSecret if needed for cancellation

      // Create payment method using card form
      // CardFormField automatically handles card input
      final paymentMethodParams = PaymentMethodParams.card(
        paymentMethodData: PaymentMethodData(
          billingDetails: BillingDetails(
            name: _cardHolderNameController.text.isEmpty
                ? null
                : _cardHolderNameController.text,
          ),
        ),
      );

      // Confirm payment
      PaymentIntent paymentIntent;
      try {
        paymentIntent = await paymentService.confirmPayment(
          paymentIntentClientSecret: clientSecret,
          params: paymentMethodParams,
        );
      } catch (e) {
        // Check if payment requires action (3D Secure)
        if (e is PaymentError && e.type == PaymentErrorType.payment) {
          // Try to retrieve payment intent to check if it requires action
          try {
            final retrievedIntent = await Stripe.instance.retrievePaymentIntent(clientSecret);
            if (retrievedIntent.status == PaymentIntentsStatus.RequiresAction) {
              // Handle 3D Secure authentication
              return await _handle3DSecure(clientSecret, paymentService);
            }
          } catch (_) {
            // Fall through to error handling
          }
        }
        rethrow;
      }

      // Check payment status
      if (paymentIntent.status == PaymentIntentsStatus.Succeeded) {
        if (mounted) {
          Navigator.of(context).pop({
            'success': true,
            'paymentIntentId': paymentIntent.id,
          });
        }
      } else if (paymentIntent.status == PaymentIntentsStatus.RequiresAction) {
        // Handle 3D Secure
        await _handle3DSecure(clientSecret, paymentService);
      } else {
        throw PaymentError.payment('Payment not completed: ${paymentIntent.status}');
      }
    } on PaymentError catch (e) {
      setState(() {
        _errorMessage = e.userFriendlyMessage;
      });
    } catch (e) {
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

  Future<void> _handle3DSecure(String clientSecret, PaymentService paymentService) async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      // Retrieve payment intent to get the action
      final paymentIntent = await Stripe.instance.retrievePaymentIntent(clientSecret);
      
      if (paymentIntent.status != PaymentIntentsStatus.RequiresAction) {
        throw PaymentError.payment('Payment does not require authentication');
      }

      final nextAction = paymentIntent.nextAction;
      if (nextAction == null) {
        throw PaymentError.payment('No authentication action available');
      }

      // Handle the authentication
      final authenticatedIntent = await paymentService.handlePaymentAction(
        paymentIntentClientSecret: clientSecret,
      );

      // Check final status
      if (authenticatedIntent.status == PaymentIntentsStatus.Succeeded) {
        if (mounted) {
          Navigator.of(context).pop({
            'success': true,
            'paymentIntentId': authenticatedIntent.id,
          });
        }
      } else {
        throw PaymentError.payment('Authentication failed: ${authenticatedIntent.status}');
      }
    } on PaymentError catch (e) {
      setState(() {
        _errorMessage = e.userFriendlyMessage;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Authentication failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
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
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Stripe Card Form (includes card number, expiry, CVC)
              CardFormField(
                controller: _cardFormController,
                style: CardFormStyle(
                  borderColor: Colors.grey,
                  borderWidth: 1,
                  borderRadius: 8,
                  textColor: Colors.black,
                  placeholderColor: Colors.grey,
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
                onPressed: (_isProcessing || _isAuthenticating) ? null : _processPayment,
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
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

