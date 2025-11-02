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
}
