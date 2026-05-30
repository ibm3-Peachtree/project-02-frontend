import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/config/env_config.dart';
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
    debugPrint("🔥 로그인 함수 시작");
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      debugPrint("1. login start");
      final googleSignIn = GoogleSignIn(
        scopes: ['openid', 'email', 'profile'],
        serverClientId: EnvConfig.googleServerClientId,
      );
      final googleUser = await googleSignIn.signIn();
      debugPrint("2. google done");

      if (googleUser == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '로그인이 취소됐습니다.',
        );
        return;
      }
      debugPrint("🔥 googleUser: $googleUser");
      final googleAuth = await googleUser.authentication;
      debugPrint("🔥 accessToken: ${googleAuth.accessToken}");
      debugPrint("🔥 idToken: ${googleAuth.idToken}");

      final idToken = googleAuth.idToken;
      if (idToken == null) {
        // serverClientId가 잘못됐거나 Google Cloud Console 설정 문제
        debugPrint("❌ idToken null — serverClientId 확인 필요: ${EnvConfig.googleServerClientId}");
        state = state.copyWith(
          isLoading: false,
          status: AuthStatus.unauthenticated,
          errorMessage: 'Google 인증 토큰을 받지 못했습니다. 잠시 후 다시 시도해주세요.',
        );
        return;
      }
      final response = await _repository.signInWithGoogle(idToken);
      debugPrint("4. API call done");
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

      // ✅ 최초 가입(로그인) 시에만 GPS 권한 1회 요청
      // 이미 요청한 적 있으면 스킵, 권한이 꺼져 있으면 앱 사용 중 별도 처리
      await _requestGpsPermissionIfNeeded();
    } catch (e) {
      debugPrint("❌ 로그인 전체 에러: $e");
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),  // 실제 에러 그대로 표시
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
      debugPrint(" 로그아웃 API 성공");
    } catch (e) {
      debugPrint("로그아웃 API 실패: $e");
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

  /// 최초 가입(로그인) 시 GPS 권한을 1회만 요청합니다.
  /// - 이미 요청한 적 있으면 스킵
  /// - 이미 권한이 있으면 스킵
  /// - denied 상태라면 OS 권한 다이얼로그 표시
  /// - deniedForever(영구 거부)라면 요청 없이 플래그만 기록 → 앱 사용 중 별도 안내
  Future<void> _requestGpsPermissionIfNeeded() async {
    try {
      final alreadyRequested = await _tokenStorage.hasRequestedGpsPermission();
      if (alreadyRequested) return; // 이미 요청한 적 있음 → 스킵

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        // 이미 허용 상태 → 플래그만 저장하고 종료
        await _tokenStorage.setGpsPermissionRequested();
        return;
      }

      if (permission != LocationPermission.deniedForever) {
        // denied(한 번도 안 물어봤거나 거부) → 요청
        await Geolocator.requestPermission();
      }
      // deniedForever는 요청 없이 플래그만 기록 → 이후 앱 사용 중 설정 유도
      await _tokenStorage.setGpsPermissionRequested();
    } catch (e) {
      debugPrint('[GPS] 권한 요청 오류: $e');
    }
  }}
