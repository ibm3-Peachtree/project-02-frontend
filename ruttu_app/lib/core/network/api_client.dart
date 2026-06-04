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
    dio.interceptors.add(LogInterceptor(
      requestBody: kDebugMode,
      responseBody: kDebugMode,
      error: kDebugMode,
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        // ── onRequest: API 호출 전 토큰 만료 임박 체크 → 선제 갱신 ──────────
        onRequest: (options, handler) async {
          dio.options.baseUrl = ApiConstants.springBaseUrl;

          // /auth/ 경로(로그인·복구·refresh)는 토큰 갱신 로직 전부 스킵
          // 로그인 전엔 토큰이 없으므로 갱신 시도 자체를 해선 안 됨
          final isAuthPath = options.path.contains('/auth/');

          if (!isAuthPath) {
            final expiringSoon =
                await _tokenStorage.isAccessTokenExpiringSoon(
                    thresholdMinutes: 5);

            if (expiringSoon) {
              final refreshed = await _proactiveRefresh();
              // 갱신 실패(refresh 만료)면 세션 만료 처리 후 요청 취소
              if (!refreshed) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.cancel,
                    message: 'session_expired',
                  ),
                  true,
                );
                return;
              }
            }
          }

          final token = await _tokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },

        // ── onError: 401 대응 (네트워크 지연 등으로 선제 갱신을 놓친 경우) ──
        onError: (error, handler) async {
          assert(true);
          final statusCode = error.response?.statusCode;

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
                await _tokenStorage.clearTokens();
                onSessionExpired?.call();
              }
            } else {
              await _tokenStorage.clearTokens();
              onSessionExpired?.call();
            }
          }

          // 403 → /auth/ 경로일 때만 세션 만료 처리
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

  // ── 선제 갱신 헬퍼 ────────────────────────────────────────────────────────
  // true: 갱신 성공, false: refresh 만료 → 세션 만료 처리 필요
  Future<bool> _proactiveRefresh() async {
    final refresh = await _tokenStorage.getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      await _tokenStorage.clearTokens();
      onSessionExpired?.call();
      return false;
    }
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
      debugPrint('[ApiClient] 액세스 토큰 선제 갱신 완료');
      return true;
    } catch (e) {
      debugPrint('[ApiClient] 선제 갱신 실패: $e → 세션 만료 처리');
      await _tokenStorage.clearTokens();
      onSessionExpired?.call();
      return false;
    }
  }
}