import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 환경 변수 로더
/// main()에서 EnvConfig.load() 한 번만 호출하면 이후 어디서든 사용 가능
class EnvConfig {
  EnvConfig._();

  /// debug → .env.dev / release·profile → .env.prod
  static Future<void> load() async {
    final fileName = kDebugMode ? '.env.dev' : '.env.prod';
    await dotenv.load(fileName: fileName);
    if (kDebugMode) {
      debugPrint('[EnvConfig] 환경: DEV  SPRING=${springBaseUrl}');
    }
  }

  // ── API ─────────────────────────────────────────────────
  static String get springBaseUrl =>
      dotenv.env['SPRING_BASE_URL'] ?? 'http://10.0.2.2:8080';

  static String get fastapiBaseUrl =>
      dotenv.env['FASTAPI_BASE_URL'] ?? springBaseUrl;

  // ── Third-party Keys ────────────────────────────────────
  static String get naverMapClientId =>
      dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '';

  static String get googleServerClientId =>
      dotenv.env['GOOGLE_SERVER_CLIENT_ID'] ?? '';
}
