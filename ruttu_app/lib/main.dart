import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko', null);
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
