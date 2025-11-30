import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseService _firebaseService = FirebaseService();

  Future<void> initialize() async {

    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      _saveFCMToken();
    }
  }

  Future<void> _saveFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await _messaging.getToken();
      if (token != null) {
        await _firebaseService.updateUserFcmToken(user.uid, token);
      }
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firebaseService.updateUserFcmToken(user.uid, newToken);
      }
    });
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Determine notification channel based on type
    String channelId = 'quickgas_channel';
    String channelName = 'QuickGas Notifications';
    
    final notificationType = message.data['type'] as String?;
    if (notificationType != null) {
      switch (notificationType) {
        case 'new_order':
        case 'order_accepted':
        case 'order_in_transit':
        case 'order_completed':
          channelId = 'order_updates';
          channelName = 'Order Updates';
          break;
        case 'route_update':
          channelId = 'route_updates';
          channelName = 'Route Updates';
          break;
        case 'payment_update':
          channelId = 'payment_updates';
          channelName = 'Payment Updates';
          break;
      }
    }

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Notifications for QuickGas app',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap navigation
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        // Parse notification data from payload
        // Format: {type: 'order_accepted', orderId: '...', status: '...'}
        // For now, we'll use a global navigator key or context
        // This will be handled by the app's notification handler
      } catch (e) {
        print('Error handling notification tap: $e');
      }
    }
  }

  Future<void> sendNotificationToUser(
    String fcmToken,
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {


    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'quickgas_channel',
          'QuickGas Notifications',
          channelDescription: 'Notifications for QuickGas app',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: data?.toString(),
    );
  }

  Future<void> createNotificationChannels() async {
    const AndroidNotificationChannel orderChannel = AndroidNotificationChannel(
      'order_updates',
      'Order Updates',
      description: 'Notifications for order status updates',
      importance: Importance.high,
    );

    const AndroidNotificationChannel routeChannel = AndroidNotificationChannel(
      'route_updates',
      'Route Updates',
      description: 'Notifications for route updates',
      importance: Importance.defaultImportance,
    );

    const AndroidNotificationChannel paymentChannel =
        AndroidNotificationChannel(
          'payment_updates',
          'Payment Updates',
          description: 'Notifications for payment updates',
          importance: Importance.defaultImportance,
        );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(orderChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(routeChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(paymentChannel);
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {

}
