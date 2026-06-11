import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../../features/mypage/screens/notification_settings_screen.dart'
    show NotificationSettings;

// ──────────────────────────────────────────────────────────────
// Abstract
// ──────────────────────────────────────────────────────────────
abstract class NotificationRepository {
  /// 서버에서 알림 설정을 조회합니다.
  Future<NotificationSettings> getSettings();

  /// 서버에 알림 설정을 저장합니다.
  Future<void> updateSettings(NotificationSettings settings);
}

// ──────────────────────────────────────────────────────────────
// API 구현체
// ──────────────────────────────────────────────────────────────
class ApiNotificationRepository implements NotificationRepository {
  final Dio _dio;
  ApiNotificationRepository(this._dio);

  /// GET /notifications
  @override
  Future<NotificationSettings> getSettings() async {
    final res = await _dio.get(ApiConstants.notification);
    final data = res.data as Map<String, dynamic>;

    return NotificationSettings(
      departureAlert:   data['departureAlert']  as bool?   ?? false,
      departureMinutes: data['departureMinutes'] as String? ?? '10분 전',
      alightingAlert:   data['alightingAlert']  as bool?   ?? false,
      alightingMode:    data['alightingMode']   as String? ?? '진동',
      alightingStops:   data['alightingStops']  as String? ?? '2정류장 전',
      // ttsEnabled:       data['ttsEnabled']      as bool?   ?? false,
      // ttsMode:          data['ttsMode']         as String? ?? '매 단계마다',
      briefingAlert:    data['briefingAlert']   as bool?   ?? false,
      morningTime:      data['morningTime']     as String? ?? '07:30',
    );
  }

  /// PUT /notifications
  @override
  Future<void> updateSettings(NotificationSettings s) async {
    await _dio.put(
      ApiConstants.updateNotification,
      data: {
        'departureAlert':   s.departureAlert,
        'departureMinutes': s.departureMinutes,
        'alightingAlert':   s.alightingAlert,
        'alightingMode':    s.alightingMode,
        'alightingStops':   s.alightingStops,
        // 'ttsEnabled':       s.ttsEnabled,
        // 'ttsMode':          s.ttsMode,
        'briefingAlert':    s.briefingAlert,
        'morningTime':      s.morningTime, // "HH:mm" — 백엔드 @JsonFormat(pattern="HH:mm")
      },
    );
  }
}
