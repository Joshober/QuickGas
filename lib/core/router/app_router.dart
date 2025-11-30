import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/signup_screen.dart';
import '../../features/authentication/presentation/forgot_password_screen.dart';
import '../../features/home/customer_home/customer_home_screen.dart';
import '../../features/home/driver_home/driver_home_screen.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/models/user_model.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userProfile = ref.watch(userProfileProvider);

  // Create a notifier that will trigger router refresh
  final roleNotifier = ValueNotifier<String?>(userProfile.value?.defaultRole);

  // Listen to user profile changes and update notifier to trigger router refresh
  ref.listen<AsyncValue<UserModel?>>(userProfileProvider, (previous, next) {
    final newRole = next.value?.defaultRole;
    if (roleNotifier.value != newRole) {
      roleNotifier.value = newRole;
    }
  });

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: roleNotifier,
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

      // Redirect if user tries to access driver routes as customer or vice versa
      if (isLoggedIn) {
        final profile = userProfile.value;
        final currentRole = profile?.defaultRole ?? 'customer';
        final isDriverRoute = state.uri.path.startsWith('/driver/');
        final isCustomerRoute = state.uri.path.startsWith('/customer/');

        if (isDriverRoute && currentRole != 'driver') {
          return '/home';
        }
        if (isCustomerRoute && currentRole == 'driver') {
          return '/home';
        }
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
          final userProfile = ref.watch(userProfileProvider);
          return userProfile.when(
            data: (profile) {
              final role = profile?.defaultRole ?? 'customer';
              if (role == 'driver') {
                return const DriverHomeScreen();
              }
              return const CustomerHomeScreen();
            },
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) =>
                Scaffold(body: Center(child: Text('Error: $error'))),
          );
        },
      ),

      GoRoute(
        path: '/customer/orders',
        builder: (context, state) => const CustomerHomeScreen(initialIndex: 1),
      ),
      GoRoute(
        path: '/customer/profile',
        builder: (context, state) => const CustomerHomeScreen(initialIndex: 2),
      ),

      GoRoute(
        path: '/driver/routes',
        builder: (context, state) => const DriverHomeScreen(initialIndex: 1),
      ),
      GoRoute(
        path: '/driver/profile',
        builder: (context, state) => const DriverHomeScreen(initialIndex: 2),
      ),
    ],
  );
});
