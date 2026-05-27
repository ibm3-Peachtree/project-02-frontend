import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/token_storage.dart';
import 'auth_state.dart';
import 'network_provider.dart';

final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(
    ref.read(apiClientProvider).dio,
  ),
);

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) {
    final notifier = AuthNotifier(
      ref.read(authRepositoryProvider),
      ref.read(tokenStorageProvider),
    );

    // ✅ JWT refresh 만료 이벤트 감지 → 즉시 강제 로그아웃 (순환 참조 없음)
    ref.listen<bool>(sessionExpiredProvider, (previous, expired) {
      if (expired) {
        notifier.forceSignOut();
        // 플래그 초기화 (재트리거 방지)
        try {
          ref.read(sessionExpiredProvider.notifier).state = false;
        } catch (_) {}
      }
    });

    return notifier;
  },
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
        //status: hasNickname ? AuthStatus.authenticated : AuthStatus.needsNickname,
        status: AuthStatus.authenticated,
        user: user,
      );
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Google Sign-In SDK → idToken → POST /auth/google
  Future<void> signInWithGoogle() async {
    print("🔥 로그인 함수 시작");
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      print("1. login start");
      final googleSignIn = GoogleSignIn(
        scopes: ['openid', 'email', 'profile'],
        serverClientId: '555767445860-rcbt294kkpvs94nuvp0jdpt03j7n8c2s.apps.googleusercontent.com',
      );
      final googleUser = await googleSignIn.signIn();
      print("2. google done");

      if (googleUser == null) {
        throw Exception('로그인 취소됨');
      }
      print("🔥 googleUser: $googleUser");
      final googleAuth = await googleUser.authentication;
      print("🔥 accessToken: ${googleAuth.accessToken}");
      print("🔥 idToken: ${googleAuth.idToken}");

      final idToken = googleAuth.idToken;
      if (idToken == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Google 로그인 실패',
        );
        return;
      }
      final response = await _repository.signInWithGoogle(idToken);
      print("4. API call done");
      await _tokenStorage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.userId,
      );

      final user = await _repository.getCachedUser();
      state = AuthState(
        //status: hasNickname ? AuthStatus.authenticated : AuthStatus.needsNickname,
        status: AuthStatus.authenticated,
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
    final user = await _repository.getCachedUser();
    state = AuthState(status: AuthStatus.authenticated, user: user);
    return true;
  }

  /// POST /auth/logout
  Future<void> signOut() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken() ?? '';
      await _repository.signOut(refreshToken);
      print(" 로그아웃 API 성공");
    } catch (e) {
      print("로그아웃 API 실패: $e");
    }
    await _tokenStorage.clearTokens();
    await GoogleSignIn().signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// JWT refresh 토큰까지 만료됐을 때 강제 로그아웃 (앱 재시작 없이 즉시 반영)
  Future<void> forceSignOut() async {
    await _tokenStorage.clearTokens();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// DELETE /users/me
  Future<void> deleteAccount() async {
    await _repository.deleteAccount();
    await _tokenStorage.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}