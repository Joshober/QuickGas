import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:dio/dio.dart';

class PaymentService {
  void setPublishableKey(String key) {
    Stripe.publishableKey = key;
  }

  String? _backendUrl;

  void setBackendUrl(String url) {
    _backendUrl = url;
  }

  Future<String> createPaymentIntent({
    required double amount,
    required String currency,
    Map<String, dynamic>? metadata,
  }) async {
    if (_backendUrl == null) {
      throw Exception(
        'Backend URL not configured. Call setBackendUrl() first.',
      );
    }

    try {
      final dio = Dio();
      final response = await dio.post(
        '$_backendUrl/api/payments/create-intent',
        data: {
          'amount': amount,
          'currency': currency,
          'metadata': metadata ?? {},
        },
      );

      return response.data['clientSecret'] as String;
    } catch (e) {
      throw Exception('Failed to create payment intent: $e');
    }
  }

  Future<PaymentIntent> confirmPayment({
    required String paymentIntentClientSecret,
    required PaymentMethodParams params,
  }) async {
    try {
      // Confirm payment using Stripe SDK
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: paymentIntentClientSecret,
        data: params,
      );

      // Retrieve payment intent to get status
      final paymentIntent = await Stripe.instance.retrievePaymentIntent(
        paymentIntentClientSecret,
      );

      return paymentIntent;
    } on StripeException catch (e) {
      throw Exception('Payment failed: ${e.error.message}');
    } catch (e) {
      throw Exception('Payment failed: $e');
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
      throw Exception('Failed to create payment method: ${e.error.message}');
    } catch (e) {
      throw Exception('Failed to create payment method: $e');
    }
  }

  Future<bool> handlePaymentSuccess(PaymentIntent paymentIntent) async {
    if (paymentIntent.status == PaymentIntentsStatus.Succeeded) {
      return true;
    }
    return false;
  }

  Future<void> cancelPaymentIntent(String paymentIntentId) async {
    if (_backendUrl == null) {
      throw Exception(
        'Backend URL not configured. Call setBackendUrl() first.',
      );
    }

    try {
      final dio = Dio();
      await dio.post(
        '$_backendUrl/api/payments/cancel',
        data: {'paymentIntentId': paymentIntentId},
      );
    } catch (e) {
      throw Exception('Failed to cancel payment: $e');
    }
  }
}
