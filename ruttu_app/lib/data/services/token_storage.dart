import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();

  static const _accessTokenKey            = 'access_token';
  static const _refreshTokenKey           = 'refresh_token';
  static const _accessTokenExpiresAtKey   = 'access_token_expires_at'; // 만료 시각(ms)
  static const _userIdKey                 = 'user_id';
  static const _hasNicknameKey            = 'has_nickname';
  static const _gpsPermissionRequestedKey = 'gps_permission_requested';

  /// 액세스 토큰 유효 기간 (서버 설정과 동일: 2시간)
  static const _accessTokenTtlMs = 7200000;

  // ── 저장 ──────────────────────────────────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int userId,
  }) async {
    final expiresAt =
        DateTime.now().millisecondsSinceEpoch + _accessTokenTtlMs;
    await Future.wait([
      _storage.write(key: _accessTokenKey,          value: accessToken),
      _storage.write(key: _refreshTokenKey,         value: refreshToken),
      _storage.write(key: _accessTokenExpiresAtKey, value: expiresAt.toString()),
      _storage.write(key: _userIdKey,               value: userId.toString()),
    ]);
  }

  /// 액세스 토큰 갱신 시 토큰 + 만료 시각을 함께 저장
  Future<void> saveAccessToken(String token) async {
    final expiresAt =
        DateTime.now().millisecondsSinceEpoch + _accessTokenTtlMs;
    await Future.wait([
      _storage.write(key: _accessTokenKey,          value: token),
      _storage.write(key: _accessTokenExpiresAtKey, value: expiresAt.toString()),
    ]);
  }

  // ── 조회 ──────────────────────────────────────────────────────────────────

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

  /// 액세스 토큰이 [thresholdMinutes]분 이내에 만료되는지 여부
  /// true → 미리 재발급 필요
  Future<bool> isAccessTokenExpiringSoon({int thresholdMinutes = 5}) async {
    final raw = await _storage.read(key: _accessTokenExpiresAtKey);
    if (raw == null) return true; // 저장된 만료 정보 없으면 갱신 필요로 간주
    final expiresAt = int.tryParse(raw);
    if (expiresAt == null) return true;
    final threshold = thresholdMinutes * 60 * 1000;
    final remaining = expiresAt - DateTime.now().millisecondsSinceEpoch;
    return remaining < threshold;
  }

  // ── 기타 설정 ─────────────────────────────────────────────────────────────

  Future<void> setHasNickname(bool value) =>
      _storage.write(key: _hasNicknameKey, value: value.toString());

  Future<bool> getHasNickname() async {
    final value = await _storage.read(key: _hasNicknameKey);
    return value == 'true';
  }

  Future<bool> hasRequestedGpsPermission() async {
    final value = await _storage.read(key: _gpsPermissionRequestedKey);
    return value == 'true';
  }

  Future<void> setGpsPermissionRequested() =>
      _storage.write(key: _gpsPermissionRequestedKey, value: 'true');

  Future<void> clearAll()    => _storage.deleteAll();
  Future<void> clearTokens() => clearAll();
}