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
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 5);
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
