import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../../core/constants/api_constants.dart';


class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final int userId;
  final String email;
  final String nickname;

  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
    required this.nickname,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        userId: json['userId'] as int,
        email: json['email'] as String,
        nickname: json['nickname'] as String,
      );
}

abstract class AuthRepository {
  Future<LoginResponse> signInWithGoogle(String idToken);
  Future<void> updateNickname(String nickname);
  Future<bool> isNicknameAvailable(String nickname);
  Future<UserModel?> getCachedUser();
  Future<void> signOut(String refreshToken);
  Future<void> deleteAccount();
  Future<LoginResponse> refreshToken(String refreshToken); // 추가
}

class ApiAuthRepository implements AuthRepository {
  final Dio _dio;
  UserModel? _cachedUser;

  ApiAuthRepository(this._dio);

  @override
  Future<LoginResponse> signInWithGoogle(String idToken) async {
    print("🔥 Login API 호출 시작");
    final res = await _dio.post(
      ApiConstants.googleLogin, // '/auth/google'
      data: {'idToken': idToken},
    );
    print("🔥 Login API 응답 옴");
    final loginRes = LoginResponse.fromJson(res.data);
    // 로그인 성공 시 유저 캐싱
    _cachedUser = UserModel(
      userId: loginRes.userId,
      email: loginRes.email,   // 서버 응답에 있으면 res.data['email']로 교체
      nickname: null,
    );
    return loginRes;
  }

  @override
  Future<void> updateNickname(String nickname) async {
    await _dio.put(
      ApiConstants.updateNickname, // '/users/mypage/nickname'
      data: {'nickname': nickname},
    );
    if (_cachedUser != null) {
      _cachedUser = _cachedUser!.copyWith(nickname: nickname);
    }
  }

  @override
  Future<bool> isNicknameAvailable(String nickname) async {
    // 서버는 PUT 시 409로 중복 처리 → 여기선 항상 true 반환
    // 실제 중복은 updateNickname()의 DioException catch에서 처리
    return true;
  }

  @override
  Future<UserModel?> getCachedUser() async => _cachedUser;

  @override
  Future<void> signOut(String refreshToken) async {
    await _dio.post(
      ApiConstants.logout, // '/auth/logout'
      data: {'refreshToken': refreshToken},
    );
    _cachedUser = null;
  }

  @override
  Future<void> deleteAccount() async {
    await _dio.delete(ApiConstants.deleteAccount); // '/users/me'
    _cachedUser = null;
  }

  @override
  Future<LoginResponse> refreshToken(String refreshToken) async {
    final res = await _dio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return LoginResponse.fromJson(res.data);
  }
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
      email: 'test@example.com',
      nickname: 'tester'
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
    @override
  Future<LoginResponse> refreshToken(String refreshToken) {
    throw UnimplementedError();
  }
}