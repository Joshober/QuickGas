import 'dart:typed_data';
import 'package:dio/dio.dart';

class BackendService {
  final Dio _dio = Dio();
  String? _baseUrl;
  bool _isAvailable = false;

  void setBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
    _dio.options.headers['Content-Type'] = 'application/json';
    // Increased timeouts for better reliability, especially on first connection
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  /// Check if backend is available by hitting health endpoint
  Future<bool> checkAvailability() async {
    if (_baseUrl == null) {
      _isAvailable = false;
      return false;
    }

    try {
      final response = await _dio.get(
        '/health',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          followRedirects: true,
        ),
      );
      _isAvailable = response.statusCode == 200;
      if (!_isAvailable) {
        // Log for debugging
        print('Backend health check failed: status=${response.statusCode}');
      }
      return _isAvailable;
    } on DioException catch (e) {
      _isAvailable = false;
      // Log connection errors for debugging, but don't spam for expected 502 errors
      final statusCode = e.response?.statusCode;
      if (statusCode == 502) {
        // 502 is expected if backend isn't running - just set availability, don't log repeatedly
        // The app will work in Firebase-only mode
      } else {
        // Log other errors for debugging
        print('Backend connection error: ${e.type} - ${e.message}');
        if (e.response != null) {
          print('Response status: ${e.response?.statusCode}');
          print('Response data: ${e.response?.data}');
        }
      }
      return false;
    } catch (e) {
      _isAvailable = false;
      print('Backend availability check error: $e');
      return false;
    }
  }

  bool get isAvailable => _isAvailable;

  Future<bool> createDriverPayment({
    required String driverId,
    required String orderId,
    required double orderTotal,
    String currency = 'usd',
    String? routeId,
  }) async {
    if (_baseUrl == null) {
      print('ERROR: Backend base URL is null, cannot create driver payment');
      return false;
    }

    // Don't check isAvailable here - let the request try and handle errors gracefully
    try {
      final response = await _dio.post(
        '/api/driver-payments',
        data: {
          'driverId': driverId,
          'orderId': orderId,
          'orderTotal': orderTotal,
          'currency': currency,
          if (routeId != null) 'routeId': routeId,
        },
        options: Options(
          validateStatus: (status) => status! < 500, // Don't throw on 4xx errors
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('SUCCESS: Driver payment created - driverId=$driverId, orderId=$orderId, amount=${orderTotal * 0.8}');
        return true;
      } else {
        print('ERROR: Driver payment creation failed - HTTP ${response.statusCode}, response: ${response.data}');
        return false;
      }
    } on DioException catch (e) {
      // Only mark as unavailable on network errors or 5xx errors
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          (e.response?.statusCode != null && e.response!.statusCode! >= 500)) {
        _isAvailable = false;
        print('ERROR: Backend unavailable after driver payment creation error: $e');
      } else {
        // For other errors (4xx, etc.), log but don't mark as unavailable
        print('ERROR: Failed to create driver payment: ${e.response?.data ?? e.message}');
      }
      return false;
    } catch (e) {
      print('ERROR: Unexpected error creating driver payment: $e');
      return false;
    }
  }

  Future<bool> processPendingPayment(
    int paymentId, {
    required String stripeAccountId,
    Map<String, dynamic>? userData,
  }) async {
    if (_baseUrl == null) {
      print('ERROR: Backend base URL is null, cannot process payment');
      return false;
    }

    try {
      final response = await _dio.post(
        '/api/driver-payments/$paymentId/process',
        data: {
          'stripeAccountId': stripeAccountId,
          if (userData != null) 'userData': userData,
        },
        options: Options(
          validateStatus: (status) => status! < 500, // Don't throw on 4xx errors
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('SUCCESS: Payment processed - paymentId=$paymentId');
        return true;
      } else {
        // Extract error message from response
        String errorMessage = 'Payment processing failed';
        if (response.data is Map) {
          errorMessage = response.data['error']?.toString() ?? errorMessage;
        }
        print('ERROR: Payment processing failed - HTTP ${response.statusCode}, response: ${response.data}');
        throw Exception(errorMessage);
      }
    } on DioException catch (e) {
      // Extract error message from response if available
      String errorMessage = 'Payment processing failed';
      if (e.response?.data is Map) {
        errorMessage = e.response!.data['error']?.toString() ?? 
                      (e.response!.data['message']?.toString() ?? errorMessage);
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      
      // Only mark as unavailable on network errors or 5xx errors (but not Stripe errors)
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        _isAvailable = false;
        print('ERROR: Backend unavailable after payment processing error: $e');
      } else if (e.response?.statusCode != null && e.response!.statusCode! >= 500) {
        // For 500 errors, check if it's a Stripe error (don't mark backend as unavailable)
        if (errorMessage.contains('Stripe') || errorMessage.contains('insufficient funds') || 
            errorMessage.contains('balance')) {
          print('ERROR: Stripe payment error: $errorMessage');
        } else {
          _isAvailable = false;
          print('ERROR: Backend unavailable after payment processing error: $e');
        }
      } else {
        // For other errors (4xx, etc.), log but don't mark as unavailable
        print('ERROR: Failed to process payment: $errorMessage');
      }
      throw Exception(errorMessage);
    } catch (e) {
      print('ERROR: Unexpected error processing payment: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>?> getDriverPayments(String driverId) async {
    if (_baseUrl == null) {
      return null;
    }

    // Don't check isAvailable here - let the request try and handle errors gracefully
    try {
      final response = await _dio.get(
        '/api/driver-payments/driver/$driverId',
        options: Options(
          validateStatus: (status) => status! < 500, // Don't throw on 4xx errors
        ),
      );

      // Handle different response structures
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map) {
          if (response.data['success'] == true && response.data['payments'] != null) {
            final payments = response.data['payments'];
            if (payments is List) {
              return List<Map<String, dynamic>>.from(payments);
            }
          } else if (response.data['payments'] != null) {
            // Handle case where success field is missing but payments exist
            final payments = response.data['payments'];
            if (payments is List) {
              return List<Map<String, dynamic>>.from(payments);
            }
          }
        } else if (response.data is List) {
          // Handle direct array response
          return List<Map<String, dynamic>>.from(response.data);
        }
        // If we get here, response structure is unexpected but not an error
        return [];
      } else {
        // 4xx errors - don't mark backend as unavailable, just return empty
        print('Failed to get driver payments: HTTP ${response.statusCode}');
        return [];
      }
    } on DioException catch (e) {
      // Only mark as unavailable on network errors or 5xx errors
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          (e.response?.statusCode != null && e.response!.statusCode! >= 500)) {
        _isAvailable = false;
        print('Backend unavailable after payment fetch error: $e');
      } else {
        // For other errors (4xx, etc.), don't mark as unavailable
        print('Failed to get driver payments: $e');
      }
      return null;
    } catch (e) {
      print('Unexpected error getting driver payments: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createStripeConnectAccount({
    required String driverId,
    required String email,
    String country = 'US',
  }) async {
    if (_baseUrl == null || !_isAvailable) {
      return null;
    }

    try {
      final response = await _dio.post(
        '/api/driver-payments/connect/create-account',
        data: {
          'driverId': driverId,
          'email': email,
          'country': country,
        },
      );

      if (response.data['success'] == true) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('Failed to create Stripe Connect account: $e');
      return null;
    }
  }

  Future<String?> createAccountLink({
    required String accountId,
    required String returnUrl,
    required String refreshUrl,
  }) async {
    if (_baseUrl == null || !_isAvailable) {
      return null;
    }

    try {
      final response = await _dio.post(
        '/api/driver-payments/connect/create-link',
        data: {
          'accountId': accountId,
          'returnUrl': returnUrl,
          'refreshUrl': refreshUrl,
        },
      );

      if (response.data['success'] == true) {
        return response.data['url'] as String?;
      }
      return null;
    } catch (e) {
      print('Failed to create account link: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStripeAccount(String accountId) async {
    if (_baseUrl == null || !_isAvailable) {
      return null;
    }

    try {
      final response = await _dio.get(
        '/api/driver-payments/connect/account/$accountId',
      );

      if (response.data['success'] == true) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('Failed to get Stripe account: $e');
      return null;
    }
  }

  Future<bool> sendNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (_baseUrl == null || !_isAvailable) {
      return false;
    }

    try {
      await _dio.post(
        '/api/notifications/send',
        data: {
          'fcmToken': fcmToken,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );
      return true;
    } catch (e) {
      _isAvailable = false; // Mark as unavailable on error
      return false;
    }
  }

  Future<bool> sendBatchNotifications({
    required List<String> fcmTokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (_baseUrl == null || !_isAvailable) {
      return false;
    }

    try {
      await _dio.post(
        '/api/notifications/send-multiple',
        data: {
          'fcmTokens': fcmTokens,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );
      return true;
    } catch (e) {
      _isAvailable = false;
      return false;
    }
  }

  Future<Map<String, dynamic>?> optimizeRoute({
    required List<List<double>> locations,
    String? apiKey,
  }) async {
    if (_baseUrl == null || !_isAvailable) {
      return null;
    }

    try {
      final response = await _dio.post(
        '/api/routes/optimize',
        data: {'locations': locations, if (apiKey != null) 'apiKey': apiKey},
      );

      return {
        'distances': response.data['distances'],
        'durations': response.data['durations'],
      };
    } catch (e) {
      _isAvailable = false;
      return null;
    }
  }

  Future<String?> uploadImage({
    required String orderId,
    required String imageType,
    required String filePath,
  }) async {
    if (_baseUrl == null || !_isAvailable) {
      return null;
    }

    try {
      final formData = FormData.fromMap({
        'orderId': orderId,
        'imageType': imageType,
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post(
        '/api/images/upload',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      return response.data['url'] as String;
    } catch (e) {
      _isAvailable = false;
      return null;
    }
  }

  Future<Uint8List?> getImage(String imageId) async {
    if (_baseUrl == null || !_isAvailable) {
      return null;
    }

    try {
      final response = await _dio.get(
        '/api/images/$imageId',
        options: Options(responseType: ResponseType.bytes),
      );

      return response.data as Uint8List;
    } catch (e) {
      _isAvailable = false;
      return null;
    }
  }
}
