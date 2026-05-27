import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko', null);

  // ✅ 네이버 지도 초기화 — 반드시 runApp 전에 호출
  await NaverMapSdk.instance.initialize(
    clientId: 'bkwlse8ybe', // ← 네이버 클라우드에서 발급받은 Client ID로 교체
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