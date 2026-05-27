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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('오늘의 브리핑',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(dateLabel,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary,
                    fontWeight: FontWeight.normal)),
          ],
        ),
        toolbarHeight: 64,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.of(context).padding.bottom),
              children: [
                // ① AI 요약 카드
                _AiSummaryCard(summary: state.aiSummary),
                const SizedBox(height: 12),

                // ② 교통 이슈 카드
                _TrafficIssueCard(issues: state.issues),
                const SizedBox(height: 12),

                // ③ 날씨 카드
                if (state.weather != null)
                  _WeatherCard(weather: state.weather!),
                const SizedBox(height: 12),

                // ④ 준비물 브리핑 카드
                if (state.weather != null)
                  _PrepCard(weather: state.weather!),
                const SizedBox(height: 12),

                // ⑤ 오늘의 일정 카드 (Google Calendar)
                if (state.scheduleItems.isNotEmpty)
                  _ScheduleCard(items: state.scheduleItems),
                if (state.scheduleItems.isNotEmpty)
                  const SizedBox(height: 12),

                // ⑥ 미팅 경로 카드
                if (state.meetingRoute != null)
                  _MeetingRouteCard(route: state.meetingRoute!),
                if (state.meetingRoute != null)
                  const SizedBox(height: 12),
              ],
            ),
    );
  }
}

// ── ① 날씨 카드 ───────────────────────────────────
class _WeatherCard extends StatelessWidget {
  final WeatherAirQualityModel weather;
  const _WeatherCard({required this.weather});

  String get _skyLabel {
    final w = weather.current;
    if (w == null) return '—';
    if (w.pty == '1') return '비';
    if (w.pty == '3') return '눈';
    return switch (w.sky) {
      '1' => '맑음',
      '3' => '구름 많음',
      '4' => '흐림',
      _   => '맑음',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cur = weather.current;
    final temps = weather.weather.map((w) => w.tmp).toList();
    final minTmp = temps.isNotEmpty ? temps.reduce((a, b) => a < b ? a : b) : 0;
    final maxTmp = temps.isNotEmpty ? temps.reduce((a, b) => a > b ? a : b) : 0;
    final maxPop  = weather.weather.isNotEmpty
        ? weather.weather.map((w) => w.pop).reduce((a, b) => a > b ? a : b)
        : 0;
    final pm25Label = weather.airQuality.pm25.seoul;

    Color airColor(String label) => switch (label) {
      '좋음' => Colors.green,
      '보통' => Colors.orange,
      _     => AppColors.error,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(weather.skyEmoji,
                    style: const TextStyle(fontSize: 52)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${cur?.tmp ?? '—'}°C',
                        style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    Text(_skyLabel,
                        style: const TextStyle(
                            fontSize: 16, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _WeatherStat('최저', '$minTmp°'),
                _WeatherStat('최고', '$maxTmp°'),
                _WeatherStat('강수확률', '$maxPop%'),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _AirChip(
                  label: '미세먼지',
                  value: weather.pm10Label,
                  color: airColor(weather.pm10Label),
                ),
                const SizedBox(width: 8),
                _AirChip(
                  label: '초미세먼지',
                  value: pm25Label,
                  color: airColor(pm25Label),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherStat extends StatelessWidget {
  final String label;
  final String value;
  const _WeatherStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      );
}

class _AirChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AirChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: color)),
            const SizedBox(width: 6),
            Text('$label $value',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      );
}

// ── ② 준비물 브리핑 카드 ──────────────────────────
class _PrepCard extends StatelessWidget {
  final WeatherAirQualityModel weather;
  const _PrepCard({required this.weather});

  String _clothingTip() {
    final tmp = weather.current?.tmp ?? 20;
    if (tmp >= 28) return '반팔과 얇은 아우터를 챙기세요. 최고 $tmp°C';
    if (tmp >= 20) return '오늘은 가벼운 긴팔이 적당해요. 일교차 큼';
    if (tmp >= 10) return '가을 재킷이 적당해요. 아침·저녁 쌀쌀해요';
    return '패딩 착용을 권장해요. 최저 $tmp°C';
  }

  List<({IconData icon, String text, Color bg, Color fg})> _prepItems() {
    final items = <({IconData icon, String text, Color bg, Color fg})>[];
    final pop = weather.weather.isNotEmpty
        ? weather.weather.map((w) => w.pop).reduce((a, b) => a > b ? a : b)
        : 0;
    final pm10 = weather.airQuality.pm10.seoul;

    if (pop >= 40) {
      items.add((
        icon: Icons.umbrella_outlined,
        text: '오늘 오후 비 예보 · 우산 챙기세요',
        bg: Colors.blue.withValues(alpha: 0.1),
        fg: Colors.blue,
      ));
    }
    if (pm10 == '나쁨' || pm10 == '매우나쁨') {
      items.add((
        icon: Icons.masks_outlined,
        text: '미세먼지 나쁨 · 마스크 필수',
        bg: Colors.orange.withValues(alpha: 0.1),
        fg: Colors.orange,
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _prepItems();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.backpack_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('오늘의 준비물',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            // 옷차림 추천
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.dry_cleaning_outlined,
                    size: 20, color: AppColors.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('옷차림 추천',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(_clothingTip(),
                          style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            // 준비물 항목
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                          color: item.bg,
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Icon(item.icon, size: 18, color: item.fg),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(item.text,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: item.fg,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  )),
            ] else ...[
              const SizedBox(height: 12),
              const Text('오늘은 특별히 챙길 준비물이 없어요 ✅',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ],
        ),
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
                const Icon(Icons.warning_amber_outlined,
                    color: AppColors.warning),
                const SizedBox(width: 8),
                const Text('주요 교통 이슈',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
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
                        color: issues.isEmpty
                            ? Colors.green
                            : AppColors.warning),
                  ),
                ),
              ],
            ),
            if (issues.isEmpty) ...[
              const SizedBox(height: 12),
              const Text('현재 주요 교통 이슈가 없어요.',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
            ] else ...[
              const SizedBox(height: 12),
              ...issues.map((issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 8, height: 8,
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
                              Text(issue.location,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(issue.description,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ── ③ 오늘의 일정 카드 ───────────────────────────
class _ScheduleCard extends StatelessWidget {
  final List<ScheduleItemModel> items;
  const _ScheduleCard({required this.items});

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
                const Icon(Icons.calendar_today_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text('오늘의 일정',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text('Google Calendar 연동됨',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  if (i > 0) const Divider(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(item.time,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            if (item.location != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.place_outlined,
                                      size: 12,
                                      color: AppColors.textSecondary),
                                  const SizedBox(width: 2),
                                  Text(item.location!,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
      ),
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
    final transitPaths =
        route.path.where((p) => !p.isWalking).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_transit_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text('오늘 미팅 경로',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const Spacer(),
                Text('총 ${route.totalTime}분',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
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
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_walk,
                                size: 13,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text('${p.sectionTime}분',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      );
                    }
                    final color = p.isSubway
                        ? _lineColor(p.no.isNotEmpty ? p.no.first : null)
                        : Colors.blue;
                    final label = p.isSubway
                        ? '${p.no.isNotEmpty ? p.no.first : ''}호선'
                        : '버스 ${p.no.isNotEmpty ? p.no.first : ''}';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle, color: color),
                          ),
                          const SizedBox(width: 4),
                          Text(label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color)),
                        ],
                      ),
                    );
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
                            color: AppColors.textSecondary),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward,
                            size: 14,
                            color: AppColors.textSecondary),
                      ),
                      Text(
                        route.endName ?? route.path.last.end ?? '도착',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        '${(route.payment).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary),
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
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('경로 보기',
                        style: TextStyle(
                            fontWeight: FontWeight.w600)),
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

// ── ⑥ AI 요약 카드 ────────────────────────────────
class _AiSummaryCard extends StatelessWidget {
  final AiSummaryModel? summary;
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
                Text('AI 요약',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: summary == null
                ? const Text(
                    '루틴을 등록하면 AI가 맞춤 브리핑을 제공해드려요.',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  )
                : Text(
                    summary!.summary,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
          ),
        ],
      ),
    );
  }
}