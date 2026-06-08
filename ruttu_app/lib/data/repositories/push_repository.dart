import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';

abstract class PushRepository {
  /// FCM 토큰을 서버에 등록합니다.
  Future<void> registerFcmToken(String token);
}

class ApiPushRepository implements PushRepository {
  final Dio _dio;
  ApiPushRepository(this._dio);

  /// POST /users/fcm-token
  /// body: raw String (Content-Type: text/plain)
  /// 백엔드: @RequestBody String token
  @override
  Future<void> registerFcmToken(String token) async {
    try {
      await _dio.post(
        ApiConstants.fcmToken,
        data: token,
        options: Options(
          contentType: 'text/plain',
        ),
      );
      debugPrint('[PushRepo] FCM 토큰 서버 등록 완료');
    } catch (e) {
      debugPrint('[PushRepo] FCM 토큰 등록 실패: $e');
      rethrow;
    }
  }
}
