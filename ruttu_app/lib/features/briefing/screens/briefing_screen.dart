import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/weather_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/repositories/briefing_repository.dart';
import '../providers/briefing_provider.dart';

class BriefingScreen extends ConsumerStatefulWidget {
  const BriefingScreen({super.key});

  @override
  ConsumerState<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends ConsumerState<BriefingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(briefingProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(briefingProvider);
    final now = DateTime.now();
    final dateLabel = DateFormat('M월 d일 EEEE', 'ko').format(now);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '오늘의 브리핑',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(
              dateLabel,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        toolbarHeight: 64,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                32 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                // ① AI 요약 카드
                _AiSummaryCard(summary: state.todayBriefing),
                const SizedBox(height: 12),

                // ③ 출발지/도착지 날씨 카드
                if (state.weatherError != null && state.originWeather == null && state.destinationWeather == null)
                  _WeatherErrorCard(
                    error: state.weatherError!,
                    onRetry: () => ref.read(briefingProvider.notifier).load(),
                  )
                else if (state.originWeather == null && state.destinationWeather == null)
                  _WeatherLoadingCard()
                else ...[
                  if (state.originWeather != null)
                    _BriefingWeatherCard(
                      weather: state.originWeather!,
                      isOrigin: true,
                    ),
                  if (state.originWeather != null && state.destinationWeather != null)
                    const SizedBox(height: 12),
                  if (state.destinationWeather != null)
                    _BriefingWeatherCard(
                      weather: state.destinationWeather!,
                      isOrigin: false,
                    ),
                ],
                const SizedBox(height: 12),
                // ④ 준비물 브리핑 카드 — supplies API 결과 우선, fallback: originWeather
                if (state.suppliesResult != null)
                  _BriefingPrepCard(
                    clothes: state.suppliesResult!.clothes,
                    supplies: state.suppliesResult!.supplies,
                  )
                else if (state.originWeather != null)
                  _BriefingPrepCard(
                    clothes: state.originWeather!.clothes,
                    supplies: state.originWeather!.supplies,
                  ),
                if (state.suppliesResult != null || state.originWeather != null)
                  const SizedBox(height: 12),

                // ⑤ 오늘의 일정 카드 (Google Calendar)
                _ScheduleCard(
                  calendarGroups: state.calendarGroups,
                  calendarError: state.calendarError,
                ),
                const SizedBox(height: 12),

              ],
            ),
    );
  }
}

// ── ⑦ 새 날씨 카드 (ResponseWeatherDto 기반) ───────────────────────────────
class _BriefingWeatherCard extends StatelessWidget {
  final BriefingWeatherModel weather;
  final bool isOrigin;
  const _BriefingWeatherCard({
    required this.weather,
    required this.isOrigin,
  });

  /// locationName이 있으면 그대로, 없으면 출발지/도착지 fallback
  String get _title {
    final name = weather.locationName.trim();
    if (name.isNotEmpty) return '$name 날씨';
    return isOrigin ? '출발지 날씨' : '도착지 날씨';
  }

  IconData get _icon =>
      isOrigin ? Icons.home_outlined : Icons.place_outlined;

  String get _skyEmoji {
    switch (weather.sky) {
      case '맑음':    return '☀️';
      case '구름많음': return '⛅';
      case '흐림':    return '☁️';
      default:        return '🌤';
    }
  }

  String get _skyLabel => weather.sky; // 백엔드가 이미 한글로 내려줌

  /// 강수량 문자열이 의미있는 값인지 (없음/빈값 제외)
  bool get _hasPcp {
    final v = weather.pcp.trim();
    return v.isNotEmpty && v != '강수없음' && v != '없음' && v != '-' && v != '0';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 ──
            Row(
              children: [
                Icon(_icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(_title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),

            // ── 현재 기온 + 최고/최저 ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_skyEmoji, style: const TextStyle(fontSize: 44)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${weather.tmp.toStringAsFixed(1)}°',
                        style: const TextStyle(
                            fontSize: 36, fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    Text(_skyLabel,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_upward, size: 13, color: Colors.red),
                        const SizedBox(width: 2),
                        Text('${weather.maxTemp.toStringAsFixed(0)}°',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.arrow_downward, size: 13, color: Colors.blue),
                        const SizedBox(width: 2),
                        Text('${weather.minTemp.toStringAsFixed(0)}°',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: Colors.blue)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── 강수량 + 미세먼지 그리드 ──
            Row(
              children: [
                // 강수량
                Expanded(
                  child: _WeatherInfoTile(
                    icon: Icons.water_drop_outlined,
                    iconColor: const Color(0xFF1565C0),
                    label: '강수량',
                    value: _hasPcp ? weather.pcp : '없음',
                    valueColor: _hasPcp
                        ? const Color(0xFF1565C0)
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                // 미세먼지
                Expanded(
                  child: _WeatherInfoTile(
                    icon: Icons.air,
                    iconColor: _AirBadge.colorFor(weather.pm10),
                    label: '미세먼지',
                    value: weather.pm10.isEmpty ? '—' : weather.pm10,
                    valueColor: _AirBadge.colorFor(weather.pm10),
                  ),
                ),
                const SizedBox(width: 8),
                // 초미세먼지
                Expanded(
                  child: _WeatherInfoTile(
                    icon: Icons.blur_on,
                    iconColor: _AirBadge.colorFor(weather.pm25),
                    label: '초미세먼지',
                    value: weather.pm25.isEmpty ? '—' : weather.pm25,
                    valueColor: _AirBadge.colorFor(weather.pm25),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 날씨 정보 타일 (아이콘 + 라벨 + 값)
class _WeatherInfoTile extends StatelessWidget {
  const _WeatherInfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AirBadge extends StatelessWidget {
  final String label;
  final String value;
  const _AirBadge({required this.label, required this.value});

  static Color colorFor(String value) {
    switch (value) {
      case '좋음': return Colors.blue;
      case '보통': return Colors.green;
      case '나쁨': return Colors.orange;
      case '매우나쁨': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color get _color => colorFor(value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
            fontSize: 12, color: _color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── ⑧ 새 준비물 카드 (clothes / supplies 텍스트 직접 표시) ────────────────
class _BriefingPrepCard extends StatelessWidget {
  final String clothes;
  final String supplies;
  const _BriefingPrepCard({required this.clothes, required this.supplies});

  /// 쉼표로 구분된 아이템 목록으로 파싱
  List<String> _parseItems(String raw) {
    return raw
        .split(RegExp(r'[,，、\n]'))          // 쉼표·줄바꿈 모두 구분자
        .map((s) => s
            .replaceAll(RegExp(r'^[\d\.\-\*\•]+\s*'), '') // 앞 번호·기호 제거
            .trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 ──
            Row(
              children: [
                const Icon(Icons.backpack_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('오늘의 준비물',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),

            // ── 옷차림 ──
            _PrepSection(
              icon: Icons.dry_cleaning_outlined,
              label: '옷차림 추천',
            ),
            const SizedBox(height: 8),
            Text(
              clothes.isEmpty ? '정보 없음' : clothes,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),

            // ── 준비물 ──
            if (supplies.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _PrepSection(
                icon: Icons.checklist_outlined,
                label: '챙겨야 할 것',
              ),
              const SizedBox(height: 8),
              Text(
                supplies,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrepSection extends StatelessWidget {
  const _PrepSection({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondary),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      ],
    );
  }
}

class _PrepChip extends StatelessWidget {
  const _PrepChip({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500, color: c),
      ),
    );
  }
}

// ── ③ 교통 이슈 카드 ──────────────────────────────
class _TrafficIssueCard extends StatelessWidget {
  final List<IssueModel> issues;
  const _TrafficIssueCard({required this.issues});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_outlined,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                const Text(
                  '주요 교통 이슈',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: issues.isEmpty
                        ? Colors.green.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    issues.isEmpty ? '이상 없음' : '${issues.length}건',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: issues.isEmpty ? Colors.green : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            if (issues.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '현재 주요 교통 이슈가 없어요.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ] else ...[
              const SizedBox(height: 12),
              ...issues.map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: issue.isFullClosure
                              ? AppColors.error
                              : AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              issue.location,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              issue.description,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── ③ 오늘의 일정 카드 ───────────────────────────
class _ScheduleCard extends StatelessWidget {
  final List<BriefingCalendarGroup> calendarGroups;
  final String? calendarError;
  const _ScheduleCard({required this.calendarGroups, this.calendarError});

  /// 그룹마다 고유한 색상 반환 (primary/secondary 계열 순환)
  static const List<Color> _calendarColors = [
    AppColors.primary,
    AppColors.secondary,
    Color(0xFF7C3AED), // 보라
    Color(0xFF0369A1), // 파랑
    Color(0xFFB45309), // 황갈
  ];

  Color _colorFor(int index) => _calendarColors[index % _calendarColors.length];

  @override
  Widget build(BuildContext context) {
    // 일정이 있는 그룹만 필터 (일정 없는 캘린더도 칩은 표시)
    final hasAnyEvent = calendarGroups.any((g) => g.items.isNotEmpty);
    final hasError = calendarError != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 ──
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  '오늘의 일정',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                // 에러 여부에 따라 배지 색상/아이콘/문구 변경
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasError
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasError
                          ? Colors.orange.withValues(alpha: 0.4)
                          : Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasError
                            ? Icons.sync_problem_outlined
                            : Icons.check_circle_outline,
                        size: 12,
                        color: hasError ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasError ? '일정 불러오기 실패' : 'Google Calendar 연동됨',
                        style: TextStyle(
                          fontSize: 11,
                          color: hasError ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── 에러 ──
            if (hasError) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.info_outline_rounded,
                          color: Colors.orange, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        calendarError!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7C4A00),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]

            // ── 일정 없음 ──
            else if (!hasAnyEvent && calendarGroups.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '오늘 일정이 없어요.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ]

            // ── 캘린더 그룹별 렌더링 ──
            else ...[
              const SizedBox(height: 14),
              ...calendarGroups.asMap().entries.map((entry) {
                final groupIndex = entry.key;
                final group = entry.value;
                final color = _colorFor(groupIndex);
                // 이 그룹의 이벤트를 시간순 정렬
                final sortedEvents = [...group.items]
                  ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: groupIndex < calendarGroups.length - 1 ? 16 : 0,
                  ),
                  child: _CalendarGroupSection(
                    group: group,
                    sortedEvents: sortedEvents,
                    color: color,
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// 캘린더 하나(그룹)를 칩 + 설명 + 이벤트 목록으로 표시
class _CalendarGroupSection extends StatelessWidget {
  final BriefingCalendarGroup group;
  final List<BriefingCalendarEvent> sortedEvents;
  final Color color;

  const _CalendarGroupSection({
    required this.group,
    required this.sortedEvents,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 캘린더명 칩 ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  group.summary,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // ── 캘린더 설명 (있을 때만) ──
        if (group.description != null && group.description!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              group.description!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],

        // ── 일정 없음 ──
        if (sortedEvents.isEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '이 캘린더에 오늘 일정이 없어요.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
        ]

        // ── 이벤트 목록 (왼쪽 컬러 바 연결) ──
        else ...[
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 컬러 세로 바 (그룹 소속 시각화)
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                // 이벤트들
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sortedEvents.asMap().entries.map((e) {
                      final idx = e.key;
                      final event = e.value;
                      return Column(
                        children: [
                          if (idx > 0)
                            Divider(
                              height: 14,
                              color: AppColors.border,
                            ),
                          _CalendarEventTile(event: event, accentColor: color),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 개별 이벤트 타일
class _CalendarEventTile extends StatelessWidget {
  final BriefingCalendarEvent event;
  final Color accentColor;

  const _CalendarEventTile({required this.event, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 시간
        SizedBox(
          width: 42,
          child: Text(
            event.startTimeLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // 내용
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 일정명
              Text(
                event.summary,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              // 위치
              if (event.location != null && event.location!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.place_outlined,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // 설명
              if (event.description != null && event.description!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.notes_outlined,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        event.description!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── ④ 미팅 경로 카드 ──────────────────────────────
class _MeetingRouteCard extends StatelessWidget {
  final RouteModel route;
  const _MeetingRouteCard({required this.route});

  Color _lineColor(String? subwayCode) {
    return switch (subwayCode) {
      '1' => Colors.blue,
      '2' => Colors.green,
      '3' => Colors.orange,
      '4' => Colors.lightBlue,
      '5' => Colors.purple,
      '6' => Colors.brown,
      '7' => Colors.green.shade800,
      '8' => Colors.pink,
      '9' => Colors.yellow.shade800,
      _ => AppColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final transitPaths = route.path.where((p) => !p.isWalking).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.directions_transit_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  '오늘 미팅 경로',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '총 ${route.totalTime}분',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 경로 요약 칩
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: route.path.map((p) {
                    if (p.isWalking) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.directions_walk,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${p.sectionTime}분',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final color = p.isSubway
                        ? _lineColor(p.no.isNotEmpty ? p.no.first : null)
                        : Colors.green;
                    if (p.isSubway) {
                      // 지하철: subwayLineName 사용 (호선 중복 방어)
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p.subwayLineName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // 버스: no 전체를 강챔 치프로 표시
                      return Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: p.no
                            .where((n) => n.isNotEmpty)
                            .map(
                              (n) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${n}번',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      );
                    }
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // 출발-도착 정보
                if (transitPaths.isNotEmpty)
                  Row(
                    children: [
                      Text(
                        route.startName ?? route.path.first.start ?? '출발',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        route.endName ?? route.path.last.end ?? '도착',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(route.payment).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      '경로 보기',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 날씨 로딩 카드 (briefingWeather가 아직 없을 때) ──────────────────────────
class _WeatherLoadingCard extends StatelessWidget {
  const _WeatherLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.wb_sunny_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('오늘의 날씨',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(
              '날씨 정보를 불러오는 중...',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 날씨 에러 카드 (API 실패 시) ─────────────────────────────────────────────
class _WeatherErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _WeatherErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.wb_sunny_outlined, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            const Text('오늘의 날씨',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('다시 시도', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiSummaryCard extends StatelessWidget {
  final String? summary;
  const _AiSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.secondary, Color(0xFF00D4C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'AI 요약',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: summary == null
                ? const Text(
                    '루틴을 등록하면 AI가 맞춤 브리핑을 제공해드려요.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  )
                : Text(
                    summary!,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
          ),
        ],
      ),
    );
  }
}