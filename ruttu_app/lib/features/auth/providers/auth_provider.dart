import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
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
      // 토큰이 유효하면 서버에서 최신 사용자 정보 조회
      try {
        final user = await _repository.getMyInfo();
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
      } catch (_) {
        // getMyInfo 실패 시 캐시 사용
        final user = await _repository.getCachedUser();
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
      }
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  bool _isRestoringAccount = false; // 복구 후 재로그인 중일 때 탈퇴 분기 무시

  /// Google Sign-In SDK → idToken → POST /auth/google
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['openid', 'email', 'profile', 'https://www.googleapis.com/auth/calendar.readonly'],
        serverClientId: EnvConfig.googleServerClientId,
      );
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '로그인이 취소됐습니다.',
        );
        return;
      }
      final googleAuth = await googleUser.authentication;

      final idToken = googleAuth.idToken;
      if (idToken == null) {
        // serverClientId가 잘못됐거나 Google Cloud Console 설정 문제
        state = state.copyWith(
          isLoading: false,
          status: AuthStatus.unauthenticated,
          errorMessage: 'Google 인증 토큰을 받지 못했습니다. 잠시 후 다시 시도해주세요.',
        );
        return;
      }
      final response = await _repository.signInWithGoogle(idToken);

      // 휴먼 계정 처리: status == "DORMANT" → 복구 화면으로 이동
      if (response.status == 'DORMANT') {
        state = AuthState(
          status: AuthStatus.dormant,
          dormantUserId: response.userId,
          isLoading: false,
        );
        return;
      }

      await _tokenStorage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.userId,
      );

      final user = await _repository.getCachedUser();
      state = AuthState(
        status: response.isNew
            ? AuthStatus.needsOnboarding
            : AuthStatus.authenticated,
        user: user,
      );

      // ✅ 최초 가입(로그인) 시에만 GPS 권한 1회 요청
      // 이미 요청한 적 있으면 스킵, 권한이 꺼져 있으면 앱 사용 중 별도 처리
      await _requestGpsPermissionIfNeeded();
    } catch (e) {

      // 탈퇴된 계정: 서버가 401 + message에 '탈퇴' 포함 시
      // 단, 복구 후 재로그인 중(_isRestoringAccount)이면 이 분기 무시
      if (!_isRestoringAccount &&
          e is DioException && e.response?.statusCode == 401) {
        final msg = e.response?.data?['message'] as String? ?? '';
        if (msg.contains('탈퇴')) {
          final userId = (e.response?.data?['userId'] as num?)?.toInt();
          state = AuthState(
            status: AuthStatus.withdrawnAccount,
            dormantUserId: userId,
            isLoading: false,
          );
          return;
        }
      }

      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      );
    }
  }

  /// PATCH /users/nickname
  /// PATCH /users/nickname
  Future<bool> setNickname(String nickname) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.updateNickname(nickname);
      // 닉네임 변경 후 서버에서 최신 정보 재조회 (실제 서버 값 반영)
      try {
        final user = await _repository.getMyInfo();
        state = AuthState(status: AuthStatus.authenticated, user: user);
      } catch (_) {
        // getMyInfo 실패 시 로컬 캐시로 UI 즉시 갱신
        final cached = await _repository.getCachedUser();
        state = AuthState(
          status: AuthStatus.authenticated,
          user: cached?.copyWith(nickname: nickname),
        );
      }
      return true;
    } catch (e) {
      final isDuplicate = e is DioException && e.response?.statusCode == 409;
      state = state.copyWith(
        isLoading: false,
        errorMessage: isDuplicate ? '이미 존재하는 닉네임입니다.' : '닉네임 변경에 실패했어요.',
      );
      return false;
    }
  }

  /// GET /users/me — 앱 시작 또는 필요 시 최신 사용자 정보 조회
  Future<void> loadMyInfo() async {
    try {
      final user = await _repository.getMyInfo();
      state = state.copyWith(user: user, isLoading: false);
    } catch (_) {
      // 실패 시 기존 캐시 유지
      state = state.copyWith(isLoading: false);
    }
  }

  /// 온보딩 완료 → authenticated로 전환
  void completeOnboarding() {
    state = state.copyWith(status: AuthStatus.authenticated);
  }

  /// POST /auth/logout
  Future<void> signOut() async {
    // 로컬 정리는 API 성공 여부와 무관하게 반드시 실행
    try {
      final refreshToken = await _tokenStorage.getRefreshToken() ?? '';
      await _repository.signOut(refreshToken);
    } catch (e) {
      // 403/401 등 API 실패는 무시 — 어차피 토큰 만료 상태
      debugPrint('로그아웃 API 실패 (무시됨): $e');
    } finally {
      await _tokenStorage.clearTokens();
      await GoogleSignIn().signOut();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// JWT refresh 토큰까지 만료됐을 때 강제 로그아웃 (앱 재시작 없이 즉시 반영)
  Future<void> forceSignOut() async {
    await _tokenStorage.clearTokens();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// DELETE /users/me
  Future<void> deleteAccount() async {
    try {
      await _repository.deleteAccount();
    } catch (e) {
      debugPrint('회원탈퇴 API 오류: $e');
      // API 오류가 나더라도 로컬 토큰은 반드시 삭제하고 로그아웃 처리
    } finally {
      await _tokenStorage.clearAll();
      await GoogleSignIn().signOut();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// POST /auth/restore — 탈퇴 계정 복구 후 자동 재로그인
  /// withdrawnAccount 상태에서 사용자가 활성화를 선택했을 때 호출
  Future<void> restoreAndLogin() async {
    final userId = state.dormantUserId ?? 0;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // userId가 0이어도 idToken을 함께 보내서 서버가 식별하도록
      await _repository.restoreUser(userId);

      // 복구 성공 → 플래그 세팅 후 재로그인 (탈퇴 분기 재진입 방지)
      _isRestoringAccount = true;
      try {
        await signInWithGoogle();
      } finally {
        _isRestoringAccount = false;
      }
    } catch (e) {
      debugPrint('탈퇴 계정 복구 오류: ' + e.toString());
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.unauthenticated,
        errorMessage: '계정 복구에 실패했습니다. 잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// 탈퇴 계정 복구 취소 → 로그인 화면으로
  void cancelWithdrawnRestore() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// POST /auth/restore — 휴먼 계정 복구
  /// dormant 상태에서 사용자가 복구를 선택했을 때 호출
  Future<void> restoreUser() async {
    final userId = state.dormantUserId;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.restoreUser(userId);
      // 복구 완료 → 로그인 화면으로 돌아가 다시 로그인하도록 안내
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: '계정이 복구되었습니다. 다시 로그인해주세요.',
      );
    } catch (e) {
      debugPrint('계정 복구 오류: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '계정 복구에 실패했습니다. 잠시 후 다시 시도해주세요.',
      );
    }
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