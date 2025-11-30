import 'dart:typed_data';
import 'package:dio/dio.dart';

class BackendService {
  final Dio _dio = Dio();
  String? _baseUrl;

  void setBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
    _dio.options.headers['Content-Type'] = 'application/json';
  }

  Future<void> sendNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (_baseUrl == null) {
      throw Exception('Backend URL not configured');
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
    } catch (e) {
      throw Exception('Failed to send notification: $e');
    }
  }

  Future<void> sendBatchNotifications({
    required List<String> fcmTokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (_baseUrl == null) {
      throw Exception('Backend URL not configured');
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
    } catch (e) {
      throw Exception('Failed to send batch notifications: $e');
    }
  }

  Future<Map<String, dynamic>> optimizeRoute({
    required List<List<double>> locations,
    String? apiKey,
  }) async {
    if (_baseUrl == null) {
      throw Exception('Backend URL not configured');
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
      throw Exception('Failed to optimize route: $e');
    }
  }

  Future<String> uploadImage({
    required String orderId,
    required String imageType,
    required String filePath,
  }) async {
    if (_baseUrl == null) {
      throw Exception('Backend URL not configured');
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
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<Uint8List> getImage(String imageId) async {
    if (_baseUrl == null) {
      throw Exception('Backend URL not configured');
    }

    try {
      final response = await _dio.get(
        '/api/images/$imageId',
        options: Options(responseType: ResponseType.bytes),
      );

      return response.data as Uint8List;
    } catch (e) {
      throw Exception('Failed to get image: $e');
    }
  }
}
