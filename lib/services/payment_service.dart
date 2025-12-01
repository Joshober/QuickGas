import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'payment_error.dart';

class PaymentService {
  void setPublishableKey(String key) {
    Stripe.publishableKey = key;
  }

  String? _backendUrl;

  void setBackendUrl(String url) {
    _backendUrl = url;
  }

  bool get isBackendAvailable => _backendUrl != null;

  /// Extracts payment intent ID from client secret
  /// Format: pi_xxx_secret_xxx -> pi_xxx
  String? extractPaymentIntentId(String clientSecret) {
    try {
      final parts = clientSecret.split('_secret_');
      if (parts.isNotEmpty) {
        return parts[0];
      }
    } catch (e) {
      // Invalid format
    }
    return null;
  }

  /// Creates a payment intent with retry logic
  Future<String> createPaymentIntent({
    required double amount,
    required String currency,
    Map<String, dynamic>? metadata,
    String? idempotencyKey,
    int maxRetries = 3,
  }) async {
    if (_backendUrl == null) {
      throw PaymentError.configuration('Backend URL not configured');
    }

    // Validate amount
    if (amount <= 0) {
      throw PaymentError.validation('Amount must be greater than 0');
    }

    // Validate currency
    if (currency.isEmpty || currency.length != 3) {
      throw PaymentError.validation('Invalid currency code');
    }

    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        final dio = Dio();
        dio.options.connectTimeout = const Duration(seconds: 10);
        dio.options.receiveTimeout = const Duration(seconds: 10);
        
        final requestData = {
          'amount': amount,
          'currency': currency.toLowerCase(),
          'metadata': metadata ?? {},
        };
        
        if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
          requestData['idempotencyKey'] = idempotencyKey;
        }
        
        final response = await dio.post(
          '$_backendUrl/api/payments/create-intent',
          data: requestData,
        );

        if (response.statusCode == 200 && response.data != null) {
          final clientSecret = response.data['clientSecret'] as String?;
          if (clientSecret != null && clientSecret.isNotEmpty) {
            return clientSecret;
          }
          throw PaymentError.unknown('Invalid response from server: missing clientSecret');
        } else {
          throw PaymentError.network('Invalid response from server: ${response.statusCode}');
        }
      } on DioException catch (e) {
        attempt++;
        
        // Check if it's a validation error (400)
        if (e.response?.statusCode == 400) {
          final errorData = e.response?.data;
          final errorMessage = errorData is Map 
              ? (errorData['error'] as String? ?? 'Validation error')
              : 'Validation error';
          throw PaymentError.validation(errorMessage);
        }
        
        // Check if it's a payment error (402)
        if (e.response?.statusCode == 402) {
          final errorData = e.response?.data;
          final errorMessage = errorData is Map 
              ? (errorData['error'] as String? ?? 'Payment failed')
              : 'Payment failed';
          final errorCode = errorData is Map ? errorData['code'] as String? : null;
          throw PaymentError.payment(errorMessage, errorCode, e);
        }
        
        // Network errors - retry with exponential backoff
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          if (attempt >= maxRetries) {
            throw PaymentError.network(
              'Unable to connect to payment service. Please check your connection.',
              e,
            );
          }
          // Exponential backoff: 1s, 2s, 4s
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
          continue;
        }
        
        // Other errors
        if (attempt >= maxRetries) {
          throw PaymentError.network(
            'Payment service error: ${e.message ?? 'Unknown error'}',
            e,
          );
        }
        
        await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
      } catch (e) {
        if (e is PaymentError) {
          rethrow;
        }
        throw PaymentError.unknown('Unexpected error: ${e.toString()}', e);
      }
    }
    
    throw PaymentError.network('Failed to create payment intent after $maxRetries attempts');
  }

  /// Confirms payment and handles 3D Secure authentication
  Future<PaymentIntent> confirmPayment({
    required String paymentIntentClientSecret,
    required PaymentMethodParams params,
  }) async {
    try {
      // Confirm payment using Stripe SDK
      final paymentIntent = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: paymentIntentClientSecret,
        data: params,
      );

      return paymentIntent;
    } on StripeException catch (e) {
      final errorCode = e.error.code.toString();
      final errorMessage = e.error.message ?? 'Payment failed';
      
      throw PaymentError.payment(errorMessage, errorCode, e);
    } catch (e) {
      if (e is PaymentError) {
        rethrow;
      }
      throw PaymentError.unknown('Payment confirmation failed: ${e.toString()}', e);
    }
  }

  /// Handles payment that requires action (3D Secure)
  Future<PaymentIntent> handlePaymentAction({
    required String paymentIntentClientSecret,
  }) async {
    try {
      final paymentIntent = await Stripe.instance.handleNextAction(
        paymentIntentClientSecret,
      );

      return paymentIntent;
    } on StripeException catch (e) {
      final errorMessage = e.error.message ?? 'Authentication failed';
      
      throw PaymentError.authentication(errorMessage);
    } catch (e) {
      throw PaymentError.unknown('Payment action handling failed: ${e.toString()}', e);
    }
  }

  Future<PaymentMethod> createPaymentMethod({
    required PaymentMethodParams params,
  }) async {
    try {
      final paymentMethod = await Stripe.instance.createPaymentMethod(
        params: params,
      );

      return paymentMethod;
    } on StripeException catch (e) {
      final errorCode = e.error.code.toString();
      final errorMessage = e.error.message ?? 'Failed to create payment method';
      
      throw PaymentError.payment(errorMessage, errorCode, e);
    } catch (e) {
      throw PaymentError.unknown('Failed to create payment method: ${e.toString()}', e);
    }
  }

  Future<bool> handlePaymentSuccess(PaymentIntent paymentIntent) async {
    return paymentIntent.status == PaymentIntentsStatus.Succeeded;
  }

  Future<bool> cancelPaymentIntent(String paymentIntentId) async {
    if (_backendUrl == null) {
      return false; // Backend not available
    }

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 5);
      
      await dio.post(
        '$_backendUrl/api/payments/cancel',
        data: {'paymentIntentId': paymentIntentId},
      );
      return true;
    } on DioException {
      // Log error but don't throw - cancellation is best effort
      return false;
    } catch (_) {
      return false;
    }
  }
}
