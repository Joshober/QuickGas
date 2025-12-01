import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_service.dart';

// Export background handler for registration in main.dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _firebaseMessagingBackgroundHandler(message);
}

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseService _firebaseService = FirebaseService();

  Future<void> initialize() async {
    print('=== Initializing Notification Service ===');
    
    // Always initialize notification channels first (needed for Android)
    print('Creating notification channels...');
    await createNotificationChannels();
    print('Notification channels creation completed');
    
    // Initialize local notifications (needed to show notifications)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    print('Initializing local notifications...');
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    print('Local notifications initialized');

    // Set up FCM message handlers (these work regardless of permission)
    print('Setting up FCM message handlers...');
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    print('FCM foreground handler registered');

    // Note: Background message handler is registered in main.dart before Firebase.initializeApp()

    // Handle notifications when app is opened from terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Handle notification taps when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Always save FCM token (needed to send notifications, even if permission not granted yet)
    _saveFCMToken();
    
    // Listen for auth state changes to save token when user logs in
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _saveFCMToken();
      }
    });

    // Check current permission status
    NotificationSettings currentSettings = await _messaging.getNotificationSettings();
    
    print('Current notification permission status: ${currentSettings.authorizationStatus}');
    
    // Request permission if not already authorized
    if (currentSettings.authorizationStatus != AuthorizationStatus.authorized) {
      print('Requesting notification permission...');
      
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );
      
      print('Permission request result: ${settings.authorizationStatus}');
      print('Alert: ${settings.alert}, Badge: ${settings.badge}, Sound: ${settings.sound}');
      
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        print('Notification permission denied. Status: ${settings.authorizationStatus}');
        print('User may need to enable notifications in device settings');
      }
    } else {
      print('Notification permission already granted');
    }
  }


  Future<void> _saveFCMToken() async {
    try {
      final token = await _messaging.getToken();
      print('FCM Token obtained: ${token != null ? "${token.substring(0, 20)}..." : "null"}');
      
      if (token != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _firebaseService.updateUserFcmToken(user.uid, token);
          print('FCM Token saved for user: ${user.uid}');
        } else {
          print('FCM Token obtained but user not logged in yet - will save after login');
        }
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      print('FCM Token refreshed: ${newToken.substring(0, 20)}...');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firebaseService.updateUserFcmToken(user.uid, newToken);
        print('FCM Token updated for user: ${user.uid}');
      }
    });
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground notification: ${message.notification?.title}');
    print('Notification data: ${message.data}');
    
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

    // Show local notification when app is in foreground
    try {
      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? message.data['title'] ?? 'New Notification',
        message.notification?.body ?? message.data['body'] ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: 'Notifications for QuickGas app',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            showWhen: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
      print('Local notification shown successfully');
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle local notification tap
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        // Parse notification data from payload
        // This will be handled by the app's notification handler
        print('Local notification tapped: ${response.payload}');
      } catch (e) {
        print('Error handling notification tap: $e');
      }
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Handle FCM notification tap (when app opened from notification)
    try {
      final notificationType = message.data['type'] as String?;
      final orderId = message.data['orderId'] as String?;
      
      print('Notification tapped - Type: $notificationType, OrderId: $orderId');
      
      // Navigation will be handled by the app router
      // Store notification data for navigation when app is ready
      // This can be accessed via a provider or global state
    } catch (e) {
      print('Error handling notification tap: $e');
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

  /// Manually request notification permission (can be called from UI)
  Future<bool> requestPermissionManually() async {
    try {
      print('Manually requesting notification permission...');
      
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );
      
      print('Manual permission request result: ${settings.authorizationStatus}');
      
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      print('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Check if notification permission is granted
  Future<bool> isPermissionGranted() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Get current FCM token (for debugging)
  Future<String?> getFCMToken() async {
    try {
      final token = await _messaging.getToken();
      print('Current FCM Token: ${token != null ? "${token.substring(0, 30)}..." : "null"}');
      return token;
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  /// Test notification (for debugging)
  Future<void> showTestNotification() async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Test Notification',
      'This is a test notification from QuickGas',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'quickgas_channel',
          'QuickGas Notifications',
          channelDescription: 'Notifications for QuickGas app',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
    print('Test notification shown');
  }

  Future<void> createNotificationChannels() async {
    // Create default channel first (required for Android)
    const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
      'quickgas_channel',
      'QuickGas Notifications',
      description: 'Notifications for QuickGas app',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    const AndroidNotificationChannel orderChannel = AndroidNotificationChannel(
      'order_updates',
      'Order Updates',
      description: 'Notifications for order status updates',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    const AndroidNotificationChannel routeChannel = AndroidNotificationChannel(
      'route_updates',
      'Route Updates',
      description: 'Notifications for route updates',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel paymentChannel =
        AndroidNotificationChannel(
      'payment_updates',
      'Payment Updates',
      description: 'Notifications for payment updates',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(defaultChannel);
      await androidImplementation.createNotificationChannel(orderChannel);
      await androidImplementation.createNotificationChannel(routeChannel);
      await androidImplementation.createNotificationChannel(paymentChannel);
      print('Notification channels created successfully');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp();
  
  // Initialize local notifications
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings();
  
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();
  
  await localNotifications.initialize(initSettings);
  
  // Create notification channels for Android
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
  
  const AndroidNotificationChannel paymentChannel = AndroidNotificationChannel(
    'payment_updates',
    'Payment Updates',
    description: 'Notifications for payment updates',
    importance: Importance.defaultImportance,
  );
  
  await localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(orderChannel);
  
  await localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(routeChannel);
  
  await localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(paymentChannel);
  
  // Create default channel if needed
  const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
    'quickgas_channel',
    'QuickGas Notifications',
    description: 'Notifications for QuickGas app',
    importance: Importance.high,
  );
  
  await localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(defaultChannel);
  
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
  
  // Extract title and body from notification or data payload
  final title = message.notification?.title ?? 
                message.data['title'] as String? ?? 
                'QuickGas Notification';
  final body = message.notification?.body ?? 
               message.data['body'] as String? ?? 
               'You have a new update';

  print('Background notification received - Title: $title, Body: $body, Type: $notificationType');

  // Show the notification
  await localNotifications.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Notifications for QuickGas app',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: message.data.toString(),
  );
  
  print('Background notification displayed successfully');
}
