import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';
import '../../services/traffic_service.dart';
import '../../shared/models/user_model.dart';
import '../constants/api_keys.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

final trafficServiceProvider = Provider<TrafficService>((ref) {
  final service = TrafficService();

  final apiKey = ApiKeys.openRouteServiceApiKey;
  if (apiKey.isNotEmpty) {
    service.setApiKey(apiKey);
  }
  return service;
});

final authStateProvider = StreamProvider<User?>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.authStateChanges;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final firebaseService = ref.watch(firebaseServiceProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) async {
      if (user != null) {
        return await firebaseService.getUserProfile(user.uid);
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user != null) {
        final firebaseService = ref.watch(firebaseServiceProvider);
        return firebaseService.getUserProfileStream(user.uid);
      }
      return Stream.value(null);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

final userRoleProvider = StateProvider<String?>((ref) {
  final userProfile = ref.watch(userProfileProvider);
  return userProfile.when(
    data: (profile) => profile?.defaultRole,
    loading: () => null,
    error: (_, __) => null,
  );
});

final currentRoleProvider = StateNotifierProvider<CurrentRoleNotifier, String?>(
  (ref) {
    return CurrentRoleNotifier(ref);
  },
);

class CurrentRoleNotifier extends StateNotifier<String?> {
  final Ref _ref;

  CurrentRoleNotifier(this._ref) : super(null) {

    final defaultRole = _ref.watch(userRoleProvider);
    _ref.listen(userRoleProvider, (previous, next) {
      if (next != null && state == null) {
        state = next;
      }
    });
    if (defaultRole != null) {
      state = defaultRole;
    }
  }

  void setRole(String role) {
    state = role;
  }

  void switchRole() {
    final userProfile = _ref.read(userProfileProvider).value;
    if (userProfile != null && userProfile.role == 'both') {
      state = state == 'customer' ? 'driver' : 'customer';
    }
  }
}
