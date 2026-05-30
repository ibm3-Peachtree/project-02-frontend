import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/config/env_config.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/router.dart';

// GPS 권한 요청은 최초 가입(로그인 성공) 시 auth_provider에서 1회만 수행합니다.
// main.dart에서는 요청하지 않습니다.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko', null);

  // 환경 변수 로드 (dev/prod 자동 선택)
  await EnvConfig.load();
  debugPrint("🔧 환경: ${EnvConfig.springBaseUrl}");

  // 네이버 지도 초기화
  await FlutterNaverMap().init(
    clientId: EnvConfig.naverMapClientId,
    onAuthFailed: (e) => debugPrint('네이버 지도 인증 실패: $e'),
  );

  runApp(const ProviderScope(child: RuttuApp()));
}

class RuttuApp extends ConsumerWidget {
  const RuttuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'RUTTU',
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
