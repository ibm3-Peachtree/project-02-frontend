import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey  = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey        = 'user_id';
  static const _hasNicknameKey   = 'has_nickname';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int userId,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey,  value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
      _storage.write(key: _userIdKey,       value: userId.toString()),
    ]);
  }

  Future<String?> getAccessToken()  => _storage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<int?> getUserId() async {
    final v = await _storage.read(key: _userIdKey);
    return v != null ? int.tryParse(v) : null;
  }

  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> setHasNickname(bool value) =>
      _storage.write(key: _hasNicknameKey, value: value.toString());

  Future<bool> getHasNickname() async {
    final value = await _storage.read(key: _hasNicknameKey);
    return value == 'true';
  }

  Future<void> clearAll() => _storage.deleteAll();
}
