import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 앱이 완전히 종료된 상태에서 수신된 백그라운드 메시지 처리.
/// top-level 함수여야 합니다 (Firebase 요구사항).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] 백그라운드 메시지: ${message.notification?.title}');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;

  // 로컬 알림 (포그라운드 수신 시 직접 표시)
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'ruttu_default_channel',
    'RUTTU 알림',
    description: '루투 앱 기본 알림 채널',
    importance: Importance.high,
  );

  // ── 초기화 ────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // 1) 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2) 권한 요청 (iOS / Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] 알림 권한: ${settings.authorizationStatus}');

    // 3) Android 알림 채널 생성
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // 4) 로컬 알림 초기화
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(initSettings);

    // 5) 포그라운드 메시지 → 로컬 알림으로 표시
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    debugPrint('[FCM] 초기화 완료');
  }

  // ── FCM 토큰 ─────────────────────────────────────────────────────────────

  /// FCM 디바이스 토큰 반환. 네트워크 오류 시 null.
  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('[FCM] 토큰: $token');
      return token;
    } catch (e) {
      debugPrint('[FCM] 토큰 조회 실패: $e');
      return null;
    }
  }

  /// 토큰 갱신 스트림 — 서버 재등록이 필요한 시점에 호출됩니다.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  // ── 포그라운드 메시지 처리 ────────────────────────────────────────────────

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] 포그라운드 메시지: ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
