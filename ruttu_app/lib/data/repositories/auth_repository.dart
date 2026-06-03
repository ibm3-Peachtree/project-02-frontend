import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../../core/constants/api_constants.dart';


class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final int userId;
  final String email;
  final String nickname;
  final bool isNew;
  final String status; // "ACTIVE" | "DORMANT"

  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
    required this.nickname,
    this.isNew = false,
    this.status = 'ACTIVE',
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        accessToken:  json['accessToken']  as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
        userId:       json['userId']       as int?    ?? 0,
        email:        json['email']        as String? ?? '',
        nickname:     json['nickname']     as String? ?? '',
        isNew:        json['isNew']        as bool?   ?? false,
        status:       json['status']       as String? ?? 'ACTIVE',
      );
}

abstract class AuthRepository {
  Future<LoginResponse> signInWithGoogle(String idToken, {String? accessToken});
  Future<void> updateNickname(String nickname);
  Future<bool> isNicknameAvailable(String nickname);
  Future<UserModel?> getCachedUser();
  Future<UserModel> getMyInfo();           // GET /users/me
  Future<void> signOut(String refreshToken);
  Future<void> deleteAccount();
  Future<LoginResponse> refreshToken(String refreshToken);
  Future<void> restoreUser(int userId, {String? idToken});    // POST /auth/restore
}

class ApiAuthRepository implements AuthRepository {
  final Dio _dio;
  UserModel? _cachedUser;

  ApiAuthRepository(this._dio);

  String? _lastIdToken; // DORMANT/WITHDRAWN 복구 시 재사용

  @override
  Future<LoginResponse> signInWithGoogle(String idToken, {String? accessToken}) async {
    _lastIdToken = idToken; // 복구용으로 저장
    final body = <String, dynamic>{'idToken': idToken};
    if (accessToken != null) body['accessToken'] = accessToken;
    final res = await _dio.post(
      ApiConstants.googleLogin, // '/auth/google'
      data: body,
    );
    final loginRes = LoginResponse.fromJson(res.data);
    // 로그인 성공 시 유저 캐싱
    _cachedUser = UserModel(
      userId: loginRes.userId,
      email: loginRes.email,
      nickname: null,
    );
    return loginRes;
  }

  @override
  Future<void> updateNickname(String nickname) async {
    // PATCH /users/nickname  →  body: { "nickname": "..." }
    await _dio.patch(
      ApiConstants.updateNickname,
      data: {'nickname': nickname},
    );
    // 로컬 캐시도 즉시 갱신
    if (_cachedUser != null) {
      _cachedUser = _cachedUser!.copyWith(nickname: nickname);
    }
  }

  @override
  Future<bool> isNicknameAvailable(String nickname) async {
    // 서버는 PATCH 시 409로 중복 처리 → 여기선 항상 true 반환
    return true;
  }

  @override
  Future<UserModel?> getCachedUser() async => _cachedUser;

  @override
  Future<UserModel> getMyInfo() async {
    // GET /users/me → { email, nickname } 또는 { data: { email, nickname } }
    final res = await _dio.get(ApiConstants.getMyInfo);
    final raw = res.data;

    // 서버 응답이 { data: {...} } 래퍼일 수도 있고 flat 일 수도 있으므로 양쪽 처리
    final Map<String, dynamic> data;
    if (raw is Map<String, dynamic>) {
      data = (raw['data'] is Map<String, dynamic>)
          ? raw['data'] as Map<String, dynamic>
          : raw;
    } else {
      data = {};
    }

    final user = UserModel(
      userId: _cachedUser?.userId ?? 0,
      email: (data['email'] as String?)?.isNotEmpty == true
          ? data['email'] as String
          : _cachedUser?.email ?? '',
      nickname: data['nickname'] as String?,
    );
    _cachedUser = user;
    return user;
  }

  @override
  Future<void> signOut(String refreshToken) async {
    await _dio.post(
      ApiConstants.logout,
      data: {'refreshToken': refreshToken},
    );
    _cachedUser = null;
  }

  @override
  Future<void> deleteAccount() async {
    await _dio.delete(ApiConstants.deleteAccount); // DELETE /users/me
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

  @override
  Future<void> restoreUser(int userId, {String? idToken}) async {
    // POST /auth/restore — 탈퇴/휴먼 계정은 액세스 토큰이 없으므로
    // 인터셉터가 없는 별도 Dio로 호출해 Authorization 헤더를 붙이지 않음
    final plainDio = Dio(BaseOptions(
      baseUrl: _dio.options.baseUrl,
      headers: const {'Content-Type': 'application/json'},
    ));
    final token = idToken ?? _lastIdToken;
    final body = <String, dynamic>{};
    if (userId != 0) body['userId'] = userId;
    if (token != null) body['idToken'] = token;
    await plainDio.post('/auth/restore', data: body);
  }
}

class MockAuthRepository implements AuthRepository {
  UserModel? _cachedUser;

  static const _takenNicknames = ['admin', '관리자', 'ruttu', '루뚜'];

  @override
  Future<LoginResponse> signInWithGoogle(String idToken, {String? accessToken}) async {
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
  Future<UserModel> getMyInfo() async =>
      _cachedUser ?? const UserModel(userId: 0, email: '', nickname: null);

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

  @override
  @override
  Future<void> restoreUser(int userId, {String? idToken}) async {
    // mock: no-op
  }
}