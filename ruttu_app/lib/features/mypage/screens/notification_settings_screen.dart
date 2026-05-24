import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _departureAlert = false;
  bool _boardingAlert = false;
  bool _ttsAlert = false;
  bool _briefingAlert = false;

  String _departureMinutes = '10분 전';
  String _boardingMode = '진동';
  String _boardingStops = '2정류장 전';
  String _ttsMode = '매 단계마다';

  // 브리핑
  String _briefingTiming = '당일 아침';  // '당일 아침' | '전날 저녁' | '둘 다'
  String _morningTime = '07:30';
  String _eveningTime = '22:00';
  String _briefingDays = '평일만';        // '평일만' | '매일'
  String _briefingFormat = '텍스트';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('알림 설정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        leading: const BackButton(),
      ),
      body: ListView(
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
                  value: _departureAlert,
                  onChanged: (v) => setState(() => _departureAlert = v),
                ),
                if (_departureAlert)
                  _SubSetting(
                    label: '출발 몇 분 전에 알림받을까요?',
                    chips: ['5분 전', '10분 전', '15분 전', '30분 전'],
                    selected: _departureMinutes,
                    onSelected: (v) =>
                        setState(() => _departureMinutes = v),
                  ),
                const Divider(height: 1, indent: 56),

                // 승하차 알림
                _ToggleItem(
                  icon: Icons.vibration,
                  emoji: '📳',
                  title: '승하차 알림',
                  description: '지하철·버스 탑승 및 하차 시 진동 알림',
                  value: _boardingAlert,
                  onChanged: (v) => setState(() => _boardingAlert = v),
                ),
                if (_boardingAlert) ...[
                  _SubSetting(
                    label: '알림 방식',
                    chips: ['진동', '소리', '진동+소리'],
                    selected: _boardingMode,
                    onSelected: (v) => setState(() => _boardingMode = v),
                  ),
                  _SubSetting(
                    label: '하차 몇 정류장 전에 알림받을까요?',
                    chips: ['1정류장 전', '2정류장 전', '3정류장 전'],
                    selected: _boardingStops,
                    onSelected: (v) =>
                        setState(() => _boardingStops = v),
                  ),
                ],
                const Divider(height: 1, indent: 56),

                // TTS 안내
                _ToggleItem(
                  icon: Icons.volume_up_outlined,
                  emoji: '🔊',
                  title: 'TTS 안내',
                  description: '음성으로 경로 단계를 안내받아요',
                  value: _ttsAlert,
                  onChanged: (v) => setState(() => _ttsAlert = v),
                ),
                if (_ttsAlert)
                  _SubSetting(
                    label: '안내 시점',
                    chips: ['매 단계마다', '환승 시에만', '출발·도착만'],
                    selected: _ttsMode,
                    onSelected: (v) => setState(() => _ttsMode = v),
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
                  description: '날씨·교통 브리핑을 원하는 시점에 받아요',
                  value: _briefingAlert,
                  onChanged: (v) => setState(() => _briefingAlert = v),
                ),
                if (_briefingAlert) ...[
                  const Divider(height: 1),
                  // ① 브리핑 시점
                  _CardSubRow(
                    label: '브리핑 시점',
                    child: _ChipRow(
                      chips: ['당일 아침', '전날 저녁', '둘 다'],
                      selected: _briefingTiming,
                      onSelected: (v) =>
                          setState(() => _briefingTiming = v),
                    ),
                  ),
                  // ② 시간 설정 — 시점에 따라 노출
                  if (_briefingTiming == '당일 아침' ||
                      _briefingTiming == '둘 다') ...[
                    const Divider(height: 1, indent: 16),
                    _BriefingTimeRow(
                      label: '아침 브리핑',
                      description: '실시간 날씨 · 교통 이슈 · 출발 시간 안내',
                      time: _morningTime,
                      initialHour: 7,
                      initialMinute: 30,
                      onChanged: (t) =>
                          setState(() => _morningTime = t),
                    ),
                  ],
                  if (_briefingTiming == '전날 저녁' ||
                      _briefingTiming == '둘 다') ...[
                    const Divider(height: 1, indent: 16),
                    _BriefingTimeRow(
                      label: '저녁 브리핑',
                      description: '내일 날씨 예보 · 내일 일정 · 루틴 확인',
                      time: _eveningTime,
                      initialHour: 22,
                      initialMinute: 0,
                      onChanged: (t) =>
                          setState(() => _eveningTime = t),
                    ),
                  ],
                  // ③+④ 알림 요일 + 브리핑 형식 (한 줄)
                  const Divider(height: 1, indent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('알림 요일',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              _ChipRow(
                                chips: ['평일만', '매일'],
                                selected: _briefingDays,
                                onSelected: (v) =>
                                    setState(() => _briefingDays = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('브리핑 형식',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              _ChipRow(
                                chips: ['텍스트', '음성'],
                                selected: _briefingFormat,
                                onSelected: (v) =>
                                    setState(() => _briefingFormat = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
                        color: isSelected
                            ? AppColors.primary
                            : Colors.white,
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

// 카드 내부 공통 행 — 라벨 + 자식 위젯
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

// 칩 선택 행
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

// 브리핑 시간 행 — 라벨 + 시간 피커 + 설명
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
