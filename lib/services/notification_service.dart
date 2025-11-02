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
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
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
      payload: message.data.toString(),
    );
  }

  void _onNotificationTap(NotificationResponse response) {

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
