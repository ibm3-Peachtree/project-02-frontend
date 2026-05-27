import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../data/services/token_storage.dart';

// ✅ 순환 참조 방지: auth_provider.dart를 import하지 않음
// JWT 만료 시 authProvider에 직접 접근하는 대신,
// tokenStorageProvider를 공유하고 authProvider가 토큰 없음을 스스로 감지하도록 설계
//
// 흐름: refresh 실패 → clearTokens() → authProvider.checkAuthStatus() 자동 호출
// (splash_screen.dart 또는 routerProvider의 redirect에서 토큰 유무로 상태 판단)
//
// 즉시 로그아웃이 필요하면 sessionExpiredNotifier를 watch해서 처리합니다.

/// JWT refresh 실패 이벤트를 authProvider 없이 전달하는 단순 StateProvider
/// true가 되면 routerProvider 또는 splash_screen이 감지해 로그아웃 처리합니다.
final sessionExpiredProvider = StateProvider<bool>((ref) => false);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    TokenStorage(),
    onSessionExpired: () {
      // authProvider 직접 호출 대신 이벤트 플래그를 올림 → 순환 참조 없음
      try {
        ref.read(sessionExpiredProvider.notifier).state = true;
      } catch (_) {}
    },
  );
});