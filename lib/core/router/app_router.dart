import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/signup_screen.dart';
import '../../features/authentication/presentation/forgot_password_screen.dart';
import '../../features/home/customer_home/customer_home_screen.dart';
import '../../features/home/driver_home/driver_home_screen.dart';
import '../../core/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoginRoute =
          state.uri.path == '/login' ||
          state.uri.path == '/signup' ||
          state.uri.path == '/forgot-password';

      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }

      if (isLoggedIn && isLoginRoute) {
        return '/home';
      }

      return null;
    },
    routes: [

      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      GoRoute(
        path: '/home',
        builder: (context, state) {
          final currentUser = ref.read(userProfileProvider).value;
          final role = currentUser?.defaultRole ?? 'customer';

          if (role == 'driver') {
            return const DriverHomeScreen();
          }
          return const CustomerHomeScreen();
        },
      ),

      GoRoute(
        path: '/customer/orders',
        builder: (context, state) => const CustomerHomeScreen(initialIndex: 1),
      ),
      GoRoute(
        path: '/customer/tracking',
        builder: (context, state) => const CustomerHomeScreen(initialIndex: 2),
      ),
      GoRoute(
        path: '/customer/profile',
        builder: (context, state) => const CustomerHomeScreen(initialIndex: 3),
      ),

      GoRoute(
        path: '/driver/routes',
        builder: (context, state) => const DriverHomeScreen(initialIndex: 1),
      ),
      GoRoute(
        path: '/driver/deliveries',
        builder: (context, state) => const DriverHomeScreen(initialIndex: 2),
      ),
      GoRoute(
        path: '/driver/profile',
        builder: (context, state) => const DriverHomeScreen(initialIndex: 3),
      ),
    ],
  );
});
