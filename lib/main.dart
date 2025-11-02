import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/constants/backend_constants.dart';
import 'core/constants/api_keys.dart';
import 'services/notification_service.dart';
import 'services/payment_service.dart';
import 'services/backend_service.dart';
import 'services/traffic_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }

  await Firebase.initializeApp();

  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.createNotificationChannels();

  String? backendUrl = ApiKeys.backendUrl.isNotEmpty
      ? ApiKeys.backendUrl
      : BackendConstants.getBackendUrl();

  if (backendUrl.isNotEmpty && backendUrl != 'YOUR_BACKEND_URL_HERE') {
    final paymentService = PaymentService();
    paymentService.setBackendUrl(backendUrl);

    final backendService = BackendService();
    backendService.setBaseUrl(backendUrl);
  }

  final openRouteServiceApiKey = ApiKeys.openRouteServiceApiKey;
  if (openRouteServiceApiKey.isNotEmpty) {
    final trafficService = TrafficService();
    trafficService.setApiKey(openRouteServiceApiKey);
  }

  final stripePublishableKey = ApiKeys.stripePublishableKey;
  if (stripePublishableKey.isNotEmpty) {
    final paymentService = PaymentService();
    paymentService.setPublishableKey(stripePublishableKey);
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'QuickGas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
