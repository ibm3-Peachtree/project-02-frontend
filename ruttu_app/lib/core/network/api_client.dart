import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../../data/services/token_storage.dart';

class ApiClient {
  ApiClient(this._tokenStorage, {this.onSessionExpired})
      : dio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.springBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {'Content-Type': 'application/json'},
          ),
        ) {
    // 모든 빌드에서 네트워크 로그 출력
    dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      error: false,
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          dio.options.baseUrl = ApiConstants.springBaseUrl;
          final token = await _tokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // 내부 에러 상세는 debug 빌드에서만 출력 (보안)
          assert(() {
            return true;
          }());
          final statusCode = error.response?.statusCode;

          // 401 → refreshToken으로 자동 갱신 후 재시도
          if (statusCode == 401) {
            final refresh = await _tokenStorage.getRefreshToken();
            if (refresh != null && refresh.isNotEmpty) {
              try {
                final refreshDio = Dio(BaseOptions(
                  baseUrl: ApiConstants.springBaseUrl,
                  headers: const {'Content-Type': 'application/json'},
                ));
                final res = await refreshDio.post(
                  ApiConstants.refreshToken,
                  data: {'refreshToken': refresh},
                );
                final newAccessToken = res.data['accessToken'] as String;
                await _tokenStorage.saveAccessToken(newAccessToken);

                error.requestOptions.headers['Authorization'] =
                    'Bearer $newAccessToken';
                final retryRes = await dio.fetch(error.requestOptions);
                return handler.resolve(retryRes);
              } catch (_) {
                // refresh도 만료 → 토큰 삭제 후 로그인 화면으로 이동
                await _tokenStorage.clearTokens();
                onSessionExpired?.call();
              }
            } else {
              // refresh 토큰 자체가 없는 경우
              await _tokenStorage.clearTokens();
              onSessionExpired?.call();
            }
          }

          // 403 → /auth/ 경로일 때만 세션 만료 처리
          // 그 외 403(active 루틴 없음, 권한 없음 등)은 비즈니스 오류이므로 그냥 흘려보냄
          // ⚠️ 여기서 retry하면 무한 루프 발생하므로 절대 retry 하지 않음
          if (statusCode == 403 &&
              error.requestOptions.path.contains('/auth/') &&
              !error.requestOptions.path.contains('/auth/logout') &&
              !error.requestOptions.path.contains('/auth/restore')) {
            await _tokenStorage.clearTokens();
            onSessionExpired?.call();
          }

          handler.next(error);
        },
      ),
    );
  }

  final TokenStorage _tokenStorage;
  final VoidCallback? onSessionExpired;
  final Dio dio;
}