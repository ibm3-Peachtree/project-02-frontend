import '../../../data/models/user_model.dart';

enum AuthStatus { unknown, unauthenticated, needsNickname, authenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  AuthState clearError() => AuthState(
        status: status,
        user: user,
        isLoading: isLoading,
      );
}
