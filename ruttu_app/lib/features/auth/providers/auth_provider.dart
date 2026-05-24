import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/token_storage.dart';
import 'auth_state.dart';

final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => MockAuthRepository(),
);

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(tokenStorageProvider),
  ),
);

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final TokenStorage _tokenStorage;

  AuthNotifier(this._repository, this._tokenStorage)
      : super(const AuthState());

  Future<void> checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final hasToken = await _tokenStorage.hasValidToken();
      if (!hasToken) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      final hasNickname = await _tokenStorage.getHasNickname();
      final user = await _repository.getCachedUser();
      state = AuthState(
        status: hasNickname ? AuthStatus.authenticated : AuthStatus.needsNickname,
        user: user,
      );
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Google Sign-In SDK → idToken → POST /auth/google
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // TODO: GoogleSignIn().signIn() → idToken 획득
      const mockIdToken = 'mock-google-id-token';

      final response = await _repository.signInWithGoogle(mockIdToken);
      await _tokenStorage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.userId,
      );

      final user = await _repository.getCachedUser();
      final hasNickname = user?.hasNickname ?? false;
      await _tokenStorage.setHasNickname(hasNickname);

      state = AuthState(
        status: hasNickname ? AuthStatus.authenticated : AuthStatus.needsNickname,
        user: user,
      );
    } catch (e) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: '로그인에 실패했습니다. 다시 시도해주세요.',
      );
    }
  }

  /// PUT /users/mypage/nickname
  Future<bool> setNickname(String nickname) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final isAvailable = await _repository.isNicknameAvailable(nickname);
      if (!isAvailable) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '이미 사용 중인 닉네임입니다.',
        );
        return false;
      }
      await _repository.updateNickname(nickname);
      await _tokenStorage.setHasNickname(true);

      final user = await _repository.getCachedUser();
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '닉네임 설정에 실패했습니다. 다시 시도해주세요.',
      );
      return false;
    }
  }

  /// POST /auth/logout
  Future<void> signOut() async {
    final refreshToken = await _tokenStorage.getRefreshToken() ?? '';
    await _repository.signOut(refreshToken);
    await _tokenStorage.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// DELETE /users/me
  Future<void> deleteAccount() async {
    await _repository.deleteAccount();
    await _tokenStorage.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
