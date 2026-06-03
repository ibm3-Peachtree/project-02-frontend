import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/routine_repository.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../features/auth/providers/network_provider.dart';

// ──────────────────────────────────────────────────────────────
// 알림 설정 Provider (앱 전체에서 참조 가능)
// ──────────────────────────────────────────────────────────────
class NotificationSettings {
  final bool departureAlert;       // 출발 권장 알림
  final String departureMinutes;   // '5분 전' | '10분 전' | '15분 전' | '30분 전'
  final bool alightingAlert;       // 하차 알림 (구: 승하차 알림)
  final String alightingMode;      // '진동' | '소리' | '진동+소리'
  final String alightingStops;     // '1정류장 전' | '2정류장 전' | '3정류장 전'
  final bool ttsEnabled;           // TTS 안내
  final String ttsMode;            // '매 단계마다' | '환승 시에만' | '출발·도착만'
  final bool briefingAlert;        // 브리핑 알림
  final String morningTime;        // 'HH:mm'

  const NotificationSettings({
    this.departureAlert = false,
    this.departureMinutes = '10분 전',
    this.alightingAlert = false,
    this.alightingMode = '진동',
    this.alightingStops = '2정류장 전',
    this.ttsEnabled = false,
    this.ttsMode = '매 단계마다',
    this.briefingAlert = false,
    this.morningTime = '07:30',
  });

  NotificationSettings copyWith({
    bool? departureAlert,
    String? departureMinutes,
    bool? alightingAlert,
    String? alightingMode,
    String? alightingStops,
    bool? ttsEnabled,
    String? ttsMode,
    bool? briefingAlert,
    String? morningTime,
  }) => NotificationSettings(
    departureAlert: departureAlert ?? this.departureAlert,
    departureMinutes: departureMinutes ?? this.departureMinutes,
    alightingAlert: alightingAlert ?? this.alightingAlert,
    alightingMode: alightingMode ?? this.alightingMode,
    alightingStops: alightingStops ?? this.alightingStops,
    ttsEnabled: ttsEnabled ?? this.ttsEnabled,
    ttsMode: ttsMode ?? this.ttsMode,
    briefingAlert: briefingAlert ?? this.briefingAlert,
    morningTime: morningTime ?? this.morningTime,
  );

  /// '10분 전' → 10
  int get departureMinutesValue {
    final match = RegExp(r'(\d+)').firstMatch(departureMinutes);
    return match != null ? int.parse(match.group(1)!) : 10;
  }

  /// '2정류장 전' → 2
  int get alightingStopsValue {
    final match = RegExp(r'(\d+)').firstMatch(alightingStops);
    return match != null ? int.parse(match.group(1)!) : 2;
  }
}

// ──────────────────────────────────────────────────────────────
// Notifier — API 조회/저장을 담당
// ──────────────────────────────────────────────────────────────
class NotificationSettingsNotifier
    extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() async {
    final client = ref.read(apiClientProvider);
    final repo = ApiNotificationRepository(client.dio);
    return repo.getSettings();
  }

  Future<void> updateAndSave(NotificationSettings updated) async {
    // 낙관적 업데이트: UI를 즉시 반영
    state = AsyncData(updated);

    try {
      final client = ref.read(apiClientProvider);
      final repo = ApiNotificationRepository(client.dio);
      await repo.updateSettings(updated);
    } catch (e) {
      // 저장 실패 시 로그 출력 — 필요 시 스낵바 추가 가능
      debugPrint('[NotifSettings] 저장 실패: $e');
    }
  }
}

final notificationSettingsProvider =
    AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  NotificationSettingsNotifier.new,
);

// ──────────────────────────────────────────────────────────────
// 알림 서비스 (출발 권장 / 브리핑 스케줄링)
// ──────────────────────────────────────────────────────────────
class AppNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;

  static const int _departureNotifId = 1001;
  static const int _briefingMorningId = 2001;
  static const int _briefingEveningId = 2002;

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    // Android 13+ 알림 권한 요청
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5);
    _initialized = true;
  }

  // ── 출발 권장 알림 스케줄링 ──────────────────────────────────
  /// [routines] 목록에서 오늘 요일에 해당하는 루틴의
  /// recommendedDepartureTime에서 [minutesBefore]분 전에 알림을 예약합니다.
  static Future<void> scheduleDepartureAlerts({
    required List<dynamic> routines,
    required int minutesBefore,
  }) async {
    await _plugin.cancel(_departureNotifId);

    final now = DateTime.now();
    final weekday = _weekdayKey(now.weekday); // 'MON', 'TUE', ...

    debugPrint("===== 출발 알림 스케줄 시작 =====");
    debugPrint("현재시간: $now");
    print("TZ: ${tz.local.name}");
    debugPrint("오늘 요일: $weekday");

    for (final routine in routines) {
      debugPrint("루틴명: ${routine.routineName}");
      final days = routine.days as List<String>;
      debugPrint("루틴 요일: $days");
      if (!days.contains(weekday)) continue;

      final deptTime = routine.recommendedDepartureTime as String; // 'HH:mm'
      debugPrint("출발시간: $deptTime");
      if (deptTime == '--:--') continue;

      final parts = deptTime.split(':');
      if (parts.length < 2) continue;
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;

      var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute)
          .subtract(Duration(minutes: minutesBefore));
      debugPrint("알림 예정 시간: $scheduledTime");

      if (scheduledTime.isBefore(now)) continue; // 이미 지난 시간

      final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);
      debugPrint("알림 등록 완료");

      await _plugin.zonedSchedule(
        _departureNotifId,
        '출발 권장 알림',
        '${routine.routineName} 루틴 출발 시간이 $minutesBefore분 후예요! 지금 준비하세요 🚀',
        tzScheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'departure_alert',
            '출발 권장 알림',
            channelDescription: '루틴 출발 권장 시간 알림',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> cancelDepartureAlerts() async {
    await _plugin.cancel(_departureNotifId);
  }

  // ── 브리핑 알림 스케줄링 ──────────────────────────────────────
  static Future<void> scheduleBriefingAlerts({
    required String morningTime,
  }) async {
    await _plugin.cancel(_briefingMorningId);
    await _plugin.cancel(_briefingEveningId);

    final t = _parseTime(morningTime);
    await _scheduleDaily(
      id: _briefingMorningId,
      title: '아침 브리핑',
      body: '오늘의 날씨·교통·출발 시간을 확인해보세요 ☀️',
      channelId: 'briefing_morning',
      channelName: '아침 브리핑 알림',
      hour: t.$1,
      minute: t.$2,
      allowedWeekdays: null,
    );
  }

  static Future<void> cancelBriefingAlerts() async {
    await _plugin.cancel(_briefingMorningId);
    await _plugin.cancel(_briefingEveningId);
  }

  // ── TTS 안내 ─────────────────────────────────────────────────
  /// [mode]: '매 단계마다' | '환승 시에만' | '출발·도착만'
  /// [event]: 'step' | 'transfer' | 'departure' | 'arrival'
  static Future<void> speak({
    required String message,
    required String mode,
    required String event,
  }) async {
    if (!_shouldSpeak(mode: mode, event: event)) return;
    await _tts.speak(message);
  }

  static Future<void> stopTts() => _tts.stop();

  static bool _shouldSpeak({required String mode, required String event}) {
    switch (mode) {
      case '매 단계마다':
        return true;
      case '환승 시에만':
        return event == 'transfer';
      case '출발·도착만':
        return event == 'departure' || event == 'arrival';
      default:
        return false;
    }
  }

  // ── 하차 알림 (호출부: home_screen / route tracking) ─────────
  /// 설정된 정류장 수 전에 진동/소리 알림을 발생시킵니다.
  /// [stopsRemaining]: 현재 남은 정류장 수
  /// [alightingStops]: 설정된 몇 정류장 전 (예: 2)
  /// [mode]: '진동' | '소리' | '진동+소리'
  static Future<void> triggerAlightingAlert({
    required int stopsRemaining,
    required int alightingStops,
    required String mode,
    required String routeName,
  }) async {
    if (stopsRemaining != alightingStops) return;

    final details = _alightingNotifDetails(mode);
    await _plugin.show(
      3001,
      '🔔 하차 알림',
      '$routeName — $alightingStops정류장 후 내리세요!',
      details,
    );
  }

  static NotificationDetails _alightingNotifDetails(String mode) {
    AndroidNotificationDetails android;
    switch (mode) {
      case '소리':
        android = const AndroidNotificationDetails(
          'alighting_alert', '하차 알림',
          channelDescription: '하차 전 알림',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: false,
          playSound: true,
        );
        break;
      case '진동+소리':
        android = const AndroidNotificationDetails(
          'alighting_alert', '하차 알림',
          channelDescription: '하차 전 알림',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        );
        break;
      case '진동':
      default:
        android = const AndroidNotificationDetails(
          'alighting_alert', '하차 알림',
          channelDescription: '하차 전 알림',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          playSound: false,
        );
    }
    return NotificationDetails(android: android, iOS: const DarwinNotificationDetails());
  }

  // ── 내부 유틸 ────────────────────────────────────────────────
  static Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required int hour,
    required int minute,
    List<int>? allowedWeekdays,
  }) async {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // 지정 요일까지 날짜를 앞으로 당김
    if (allowedWeekdays != null) {
      while (!allowedWeekdays.contains(scheduled.weekday)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    }

    final tzScheduled = tz.TZDateTime.from(scheduled, tz.local);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: allowedWeekdays == null
          ? DateTimeComponents.time          // 매일 같은 시간
          : DateTimeComponents.dayOfWeekAndTime, // 평일 같은 요일+시간
    );
  }

  static (int, int) _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return (int.tryParse(parts[0]) ?? 7, int.tryParse(parts[1]) ?? 0);
  }

  static String _weekdayKey(int weekday) {
    const keys = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return keys[(weekday - 1).clamp(0, 6)];
  }
}

// ──────────────────────────────────────────────────────────────
// 알림 설정 화면
// ──────────────────────────────────────────────────────────────
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {

  @override
  void initState() {
    super.initState();
    AppNotificationService.init();
  }

  Future<void> _update(
      NotificationSettings Function(NotificationSettings) fn) async {
    final current = ref.read(notificationSettingsProvider).valueOrNull;
    if (current == null) return;
    await ref
        .read(notificationSettingsProvider.notifier)
        .updateAndSave(fn(current));
  }

  Future<void> _onDepartureAlertChanged(bool value, NotificationSettings s) async {
    await _update((old) => old.copyWith(departureAlert: value));
    if (value) {
      await _rescheduleDepartureAlerts(s.copyWith(departureAlert: value));
    } else {
      await AppNotificationService.cancelDepartureAlerts();
    }
  }

  Future<void> _onDepartureMinutesChanged(String v, NotificationSettings s) async {
    await _update((old) => old.copyWith(departureMinutes: v));
    if (s.departureAlert) {
      await _rescheduleDepartureAlerts(s.copyWith(departureMinutes: v));
    }
  }

  Future<void> _rescheduleDepartureAlerts(NotificationSettings s) async {
    final client = ref.read(apiClientProvider);
    final repo = ApiRoutineRepository(client);
    try {
      final routines = await repo.getRoutines();
      await AppNotificationService.scheduleDepartureAlerts(
        routines: routines,
        minutesBefore: s.departureMinutesValue,
      );
    } catch (e) {
      debugPrint('[NotifSettings] 출발 권장 알림 스케줄 오류: $e');
    }
  }

  Future<void> _onBriefingAlertChanged(bool value, NotificationSettings s) async {
    await _update((old) => old.copyWith(briefingAlert: value));
    if (value) {
      await _rescheduleBriefingAlerts(s.copyWith(briefingAlert: value));
    } else {
      await AppNotificationService.cancelBriefingAlerts();
    }
  }

  Future<void> _rescheduleBriefingAlerts(NotificationSettings s) async {
    await AppNotificationService.scheduleBriefingAlerts(
      morningTime: s.morningTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(notificationSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('알림 설정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        leading: const BackButton(),
      ),
      body: asyncSettings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('설정을 불러오지 못했어요.',
                  style: TextStyle(fontSize: 15)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    ref.invalidate(notificationSettingsProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (s) => _buildBody(context, s),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationSettings s) {
    return ListView(
        padding: EdgeInsets.only(bottom: 32 + MediaQuery.of(context).padding.bottom),
        children: [
          const SizedBox(height: 12),
          _SectionLabel(label: '경로 안내 알림'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 0),
            shape: const RoundedRectangleBorder(),
            child: Column(
              children: [
                // 출발 권장 알림
                _ToggleItem(
                  icon: Icons.notifications_outlined,
                  emoji: '🔔',
                  title: '출발 권장 알림',
                  description: '루틴 출발 권장 시간에 알림을 받아요',
                  value: s.departureAlert,
                  onChanged: (v) => _onDepartureAlertChanged(v, s),
                ),
                if (s.departureAlert)
                  _SubSetting(
                    label: '출발 몇 분 전에 알림받을까요?',
                    chips: ['5분 전', '10분 전', '15분 전', '30분 전'],
                    selected: s.departureMinutes,
                    onSelected: (v) => _onDepartureMinutesChanged(v, s),
                  ),
                const Divider(height: 1, indent: 56),

                // 하차 알림
                _ToggleItem(
                  icon: Icons.vibration,
                  emoji: '📳',
                  title: '하차 알림',
                  description: '지하철·버스 하차 전 알림을 받아요',
                  value: s.alightingAlert,
                  onChanged: (v) => _update((old) => old.copyWith(alightingAlert: v)),
                ),
                if (s.alightingAlert) ...[
                  _SubSetting(
                    label: '알림 방식',
                    chips: ['진동', '소리', '진동+소리'],
                    selected: s.alightingMode,
                    onSelected: (v) => _update((old) => old.copyWith(alightingMode: v)),
                  ),
                  _SubSetting(
                    label: '하차 몇 정류장 전에 알림받을까요?',
                    chips: ['1정류장 전', '2정류장 전', '3정류장 전'],
                    selected: s.alightingStops,
                    onSelected: (v) => _update((old) => old.copyWith(alightingStops: v)),
                  ),
                ],
                const Divider(height: 1, indent: 56),

                // TTS 안내
                _ToggleItem(
                  icon: Icons.volume_up_outlined,
                  emoji: '🔊',
                  title: 'TTS 안내',
                  description: '음성으로 경로 단계를 안내받아요',
                  value: s.ttsEnabled,
                  onChanged: (v) {
                    _update((old) => old.copyWith(ttsEnabled: v));
                    if (!v) AppNotificationService.stopTts();
                  },
                ),
                if (s.ttsEnabled)
                  _SubSetting(
                    label: '안내 시점',
                    chips: ['매 단계마다', '환승 시에만', '출발·도착만'],
                    selected: s.ttsMode,
                    onSelected: (v) => _update((old) => old.copyWith(ttsMode: v)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionLabel(label: '브리핑 알림'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 0),
            shape: const RoundedRectangleBorder(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ToggleItem(
                  icon: Icons.article_outlined,
                  emoji: '📋',
                  title: '브리핑 알림',
                  description: '매일 아침 날씨, 교통 브리핑을 원하는 시간에 받아요',
                  value: s.briefingAlert,
                  onChanged: (v) => _onBriefingAlertChanged(v, s),
                ),
                if (s.briefingAlert) ...[
                  const Divider(height: 1),
                  _BriefingTimeRow(
                    label: '아침 브리핑',
                    description: '실시간 날씨 · 교통 이슈 · 출발 시간 안내',
                    time: s.morningTime,
                    initialHour: 7,
                    initialMinute: 30,
                    onChanged: (t) {
                      _update((old) => old.copyWith(morningTime: t));
                      _rescheduleBriefingAlerts(s.copyWith(morningTime: t));
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 공통 위젯
// ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );
}

class _ToggleItem extends StatelessWidget {
  final IconData icon;
  final String emoji;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleItem({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text('$emoji $title',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        subtitle: Text(description,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.primary,
        ),
      );
}

class _SubSetting extends StatelessWidget {
  final String label;
  final List<String> chips;
  final String selected;
  final ValueChanged<String> onSelected;

  const _SubSetting({
    required this.label,
    required this.chips,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: chips.map((c) {
                final isSelected = c == selected;
                return GestureDetector(
                  onTap: () => onSelected(c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border),
                    ),
                    child: Text(c,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
}

class _CardSubRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _CardSubRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _ChipRow extends StatelessWidget {
  final List<String> chips;
  final String selected;
  final ValueChanged<String> onSelected;
  const _ChipRow(
      {required this.chips,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 4,
        children: chips.map((c) {
          final isSelected = c == selected;
          return GestureDetector(
            onTap: () => onSelected(c),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color:
                        isSelected ? AppColors.primary : AppColors.border),
              ),
              child: Text(c,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary)),
            ),
          );
        }).toList(),
      );
}

class _BriefingTimeRow extends StatelessWidget {
  final String label;
  final String description;
  final String time;
  final int initialHour;
  final int initialMinute;
  final ValueChanged<String> onChanged;

  const _BriefingTimeRow({
    required this.label,
    required this.description,
    required this.time,
    required this.initialHour,
    required this.initialMinute,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime:
                      TimeOfDay(hour: initialHour, minute: initialMinute),
                  builder: (ctx, child) => MediaQuery(
                    data: MediaQuery.of(ctx)
                        .copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  onChanged(
                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                  );
                }
              },
              child: Row(
                children: [
                  Text(time,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined,
                      size: 15, color: AppColors.primary),
                ],
              ),
            ),
          ],
        ),
      );
}