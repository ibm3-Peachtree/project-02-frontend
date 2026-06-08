import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();

  static const _accessTokenKey            = 'access_token';
  static const _refreshTokenKey           = 'refresh_token';
  static const _userIdKey                 = 'user_id';
  static const _hasNicknameKey            = 'has_nickname';
  static const _gpsPermissionRequestedKey = 'gps_permission_requested';
  static const _fcmTokenKey               = 'fcm_token';

  // ── JWT exp 파싱 ──────────────────────────────────────────────────────────

  /// JWT payload에서 exp 클레임을 꺼내 밀리초 단위 Unix 시각으로 반환.
  /// 파싱 실패 시 null 반환.
  static int? _extractExpMs(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Base64URL → Base64 변환 후 디코딩
      String payload = parts[1];
      // 패딩 보정
      switch (payload.length % 4) {
        case 2: payload += '=='; break;
        case 3: payload += '=';  break;
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = json.decode(decoded) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp == null) return null;
      // exp는 초 단위 Unix timestamp
      return (exp as num).toInt() * 1000;
    } catch (_) {
      return null;
    }
  }

  // ── 저장 ──────────────────────────────────────────────────────────────────

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

  /// 액세스 토큰 갱신 시 토큰 저장 (만료 시각은 JWT exp에서 직접 파싱)
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
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

  /// 액세스 토큰이 [thresholdMinutes]분 이내에 만료되는지 여부.
  /// JWT payload의 exp 클레임을 직접 파싱하므로 로컬 시계 오차에 영향 없음.
  /// true → 미리 재발급 필요
  Future<bool> isAccessTokenExpiringSoon({int thresholdMinutes = 5}) async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null || token.isEmpty) return true;

    final expMs = _extractExpMs(token);
    if (expMs == null) return true; // 파싱 실패 → 안전하게 갱신 필요로 간주

    final threshold = thresholdMinutes * 60 * 1000;
    final remaining = expMs - DateTime.now().millisecondsSinceEpoch;
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

  // ── FCM 디바이스 토큰 ─────────────────────────────────────────────────────

  Future<void> saveFcmToken(String token) =>
      _storage.write(key: _fcmTokenKey, value: token);

  Future<String?> getFcmToken() => _storage.read(key: _fcmTokenKey);

  Future<void> clearFcmToken() => _storage.delete(key: _fcmTokenKey);

  Future<void> clearAll()    => _storage.deleteAll();
  Future<void> clearTokens() => clearAll();
}