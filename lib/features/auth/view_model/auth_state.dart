import '../../../core/models/app_user.dart';

class AuthState {
  final bool loading;
  final AppUser? appUser;
  final String? error;

  const AuthState({
    this.loading = false,
    this.appUser,
    this.error,
  });

  AuthState copyWith({
    bool? loading,
    AppUser? appUser,
    String? Function()? error,
  }) {
    return AuthState(
      loading: loading ?? this.loading,
      appUser: appUser ?? this.appUser,
      error: error != null ? error() : this.error,
    );
  }
}
