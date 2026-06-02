import '../../../data/models/user_model.dart';

enum AuthStatus { unknown, unauthenticated, needsNickname, needsOnboarding, authenticated, dormant, withdrawnAccount }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;
  final int? dormantUserId; // dormant 상태일 때 복구용 userId

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.dormantUserId,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    int? dormantUserId,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage ?? this.errorMessage,
        dormantUserId: dormantUserId ?? this.dormantUserId,
      );

  AuthState clearError() => AuthState(
        status: status,
        user: user,
        isLoading: isLoading,
        dormantUserId: dormantUserId,
      );
}