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
      requestBody: true,
      responseBody: true,
      error: true,
      logPrint: (o) => debugPrint('[DIO] $o'),
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          dio.options.baseUrl = ApiConstants.springBaseUrl;
          debugPrint('🌐 API 요청: ${dio.options.baseUrl}${options.path}');
          final token = await _tokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          debugPrint('❌ API 에러: [${error.response?.statusCode}] ${error.requestOptions.uri} — ${error.message}');
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

          // 403 → 실제 인증 만료인지 확인 후에만 로그아웃
          // (루틴 저장 권한 오류 등 일반 403은 로그아웃 하지 않음)
          if (statusCode == 403) {
            final data = error.response?.data;
            final msg = (data is Map ? (data['message'] ?? data['error'] ?? '') : data ?? '').toString();
            final isAuthError = msg.contains('expired') ||
                msg.contains('invalid') ||
                msg.contains('Unauthorized') ||
                msg.contains('토큰') ||
                error.requestOptions.path.contains('/auth/');
            if (isAuthError) {
              await _tokenStorage.clearTokens();
              onSessionExpired?.call();
            }
            // 일반 403은 그냥 에러로 흘려보내 화면에서 처리
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