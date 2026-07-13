import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_user.dart';
import '../../../core/providers.dart';
import '../../../core/utils/enums.dart';
import 'auth_state.dart';

class AuthViewModel extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<bool> signIn({required String email, required String password}) async {
    if (state.loading) return false;
    state = state.copyWith(loading: true, error: () => null);

    final result = await ref.read(authRepositoryProvider).signIn(
      email: email,
      password: password,
    );

    return result.map(
      onSuccess: (user) {
        state = state.copyWith(loading: false, appUser: user);
        _registerFcmTokenIfEnabled(user);
        return true;
      },
      onError: (error) {
        state = state.copyWith(loading: false, error: () => error.message);
        return false;
      },
    );
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    VehicleType? vehicleType,
  }) async {
    if (state.loading) return false;
    state = state.copyWith(loading: true, error: () => null);

    final result = await ref.read(authRepositoryProvider).signUp(
      name: name,
      email: email,
      password: password,
      role: role,
      vehicleType: vehicleType,
    );

    return result.map(
      onSuccess: (user) {
        state = state.copyWith(loading: false, appUser: user);
        _registerFcmTokenIfEnabled(user);
        return true;
      },
      onError: (error) {
        state = state.copyWith(loading: false, error: () => error.message);
        return false;
      },
    );
  }

  Future<void> _registerFcmTokenIfEnabled(AppUser user) async {
    if (!user.notificationsEnabled) return;
    try {
      final fcm = ref.read(fcmServiceProvider);
      final granted = await fcm.requestPermission();
      if (!granted) return;
      final token = await fcm.getToken();
      if (token == null) return;
      await ref.read(authRepositoryProvider).registerFcmToken(
        uid: user.uid,
        role: user.role,
        token: token,
      );
    } catch (_) {
      // Best-effort — a failed token registration shouldn't block sign-in.
    }
  }
}

final authViewModelProvider = NotifierProvider<AuthViewModel, AuthState>(
  AuthViewModel.new,
);