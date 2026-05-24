import '../models/user_model.dart';

// POST /auth/google 응답 구조
class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final int userId;

  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        userId: json['userId'] as int,
      );
}

abstract class AuthRepository {
  /// Google idToken을 받아 서버 로그인 → LoginResponse 반환
  Future<LoginResponse> signInWithGoogle(String idToken);

  /// PUT /users/mypage/nickname
  Future<void> updateNickname(String nickname);

  /// PUT /users/mypage/nickname 전 중복 확인 (서버 409 에러로 처리)
  /// Mock에서만 별도 구현, 실제 서버는 updateNickname 시 409 반환
  Future<bool> isNicknameAvailable(String nickname);

  /// 로컬에 캐시된 유저 정보 반환 (토큰 기반 복원용)
  Future<UserModel?> getCachedUser();

  /// POST /auth/logout
  Future<void> signOut(String refreshToken);

  /// DELETE /users/me
  Future<void> deleteAccount();
}

class MockAuthRepository implements AuthRepository {
  UserModel? _cachedUser;

  static const _takenNicknames = ['admin', '관리자', 'ruttu', '루뚜'];

  @override
  Future<LoginResponse> signInWithGoogle(String idToken) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _cachedUser = const UserModel(
      userId: 1001,
      email: 'test@example.com',
      nickname: null, // 최초 로그인 시 닉네임 없음
    );
    return const LoginResponse(
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
      userId: 1001,
    );
  }

  @override
  Future<void> updateNickname(String nickname) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_cachedUser != null) {
      _cachedUser = _cachedUser!.copyWith(nickname: nickname);
    }
  }

  @override
  Future<bool> isNicknameAvailable(String nickname) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return !_takenNicknames.contains(nickname.toLowerCase());
  }

  @override
  Future<UserModel?> getCachedUser() async => _cachedUser;

  @override
  Future<void> signOut(String refreshToken) async {
    _cachedUser = null;
  }

  @override
  Future<void> deleteAccount() async {
    _cachedUser = null;
  }
}
