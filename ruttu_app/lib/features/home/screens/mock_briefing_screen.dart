import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// ── Mock 데이터 정의 ──────────────────────────────
class _MockIssue {
  final String location;
  final String description;
  final bool isFullClosure;
  const _MockIssue({required this.location, required this.description, this.isFullClosure = false});
}

class _MockCalendarEvent {
  final String startTimeLabel;
  final String summary;
  final String? location;
  final String? description;
  final String sortKey;
  const _MockCalendarEvent({
    required this.startTimeLabel,
    required this.summary,
    required this.sortKey,
    this.location,
    this.description,
  });
}

// ── Mock AI 브리핑 화면 ───────────────────────────
class MockBriefingScreen extends StatelessWidget {
  const MockBriefingScreen({super.key});

  static final _mockIssues = [
    _MockIssue(location: '2호선 (강남~신도림)', description: '출근 시간대 혼잡 예상 (08:00~09:00)', isFullClosure: false),
    _MockIssue(location: '강남대로 일부 구간', description: '도로 공사로 인한 차량 지연', isFullClosure: false),
    _MockIssue(location: '신분당선', description: '정상 운행 중', isFullClosure: false),
  ];

  static final _mockEvents = [
    _MockCalendarEvent(startTimeLabel: '10:00', summary: '팀 주간 회의', location: '3층 회의실', sortKey: '1000'),
    _MockCalendarEvent(startTimeLabel: '14:30', summary: '디자인 리뷰', description: '앱 UI 개선안 검토', sortKey: '1430'),
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final dateLabel = '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('오늘의 브리핑',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
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
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16, 8, 16, 32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          // ① AI 요약 카드
          _AiSummaryCard(
            summary: '오늘 출근 시간대(08:00~09:00) 2호선 강남~신도림 구간이 혼잡할 예정이에요. '
                '평소보다 10분 일찍 출발하시면 여유롭게 도착할 수 있어요. '
                '오후에 소나기 예보가 있으니 우산을 꼭 챙겨가세요! ☂️',
          ),
          const SizedBox(height: 12),

          // ② 교통 이슈 카드
          _TrafficIssueCard(issues: _mockIssues),
          const SizedBox(height: 12),

          // ③ 날씨 카드
          const _WeatherCard(),
          const SizedBox(height: 12),

          // ④ 준비물 카드
          const _PrepCard(),
          const SizedBox(height: 12),

          // ⑤ 오늘의 일정 카드
          _ScheduleCard(events: _mockEvents),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── ① AI 요약 카드 (실제 _AiSummaryCard 레이아웃 그대로) ─────────────────────
class _AiSummaryCard extends StatelessWidget {
  final String summary;
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
            child: Text(
              summary,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ② 교통 이슈 카드 (실제 _TrafficIssueCard 레이아웃 그대로) ─────────────────
class _TrafficIssueCard extends StatelessWidget {
  final List<_MockIssue> issues;
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
                const Icon(Icons.warning_amber_outlined, color: AppColors.warning),
                const SizedBox(width: 8),
                const Text('주요 교통 이슈',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${issues.length}건',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
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
                        color: issue.isFullClosure ? AppColors.error : AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(issue.location,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(issue.description,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ③ 날씨 카드 (실제 _BriefingWeatherCard 레이아웃 그대로) ─────────────────
class _WeatherCard extends StatelessWidget {
  const _WeatherCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.wb_sunny_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text('오늘의 날씨',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('⛅', style: TextStyle(fontSize: 40)),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('24°',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
                    Text('구름 많음  오후 소나기',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text('최고 27°', style: TextStyle(fontSize: 13, color: Colors.red)),
                    Text('최저 18°', style: TextStyle(fontSize: 13, color: Colors.blue)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                _AirBadge(label: '미세먼지', value: '보통'),
                const SizedBox(width: 8),
                _AirBadge(label: '초미세먼지', value: '좋음'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AirBadge extends StatelessWidget {
  final String label;
  final String value;
  const _AirBadge({required this.label, required this.value});

  Color get _color {
    switch (value) {
      case '좋음': return Colors.blue;
      case '보통': return Colors.green;
      case '나쁨': return Colors.orange;
      case '매우나쁨': return Colors.red;
      default: return Colors.grey;
    }
  }

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
        style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── ④ 준비물 카드 (실제 _BriefingPrepCard 레이아웃 그대로) ───────────────────
class _PrepCard extends StatelessWidget {
  const _PrepCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.backpack_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text('오늘의 준비물',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.dry_cleaning_outlined, size: 20, color: AppColors.secondary),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('옷차림 추천',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      Text('블라우스, 얇은 가디건, 면바지',
                          style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.checklist_outlined, size: 20, color: AppColors.secondary),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('챙겨야 할 것',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      Text('우산 (오후 소나기 예보)',
                          style: TextStyle(fontSize: 14)),
                    ],
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

// ── ⑤ 오늘의 일정 카드 (실제 _ScheduleCard 레이아웃 그대로) ─────────────────
class _ScheduleCard extends StatelessWidget {
  final List<_MockCalendarEvent> events;
  const _ScheduleCard({required this.events});

  static const _calendarColor = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final sortedEvents = [...events]..sort((a, b) => a.sortKey.compareTo(b.sortKey));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text('오늘의 일정',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text('Google Calendar 연동됨',
                          style: TextStyle(
                              fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // 캘린더명 칩
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _calendarColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _calendarColor.withValues(alpha: 0.30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: _calendarColor),
                  ),
                  const SizedBox(width: 6),
                  const Text('내 캘린더',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _calendarColor)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 이벤트 목록
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: _calendarColor.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sortedEvents.asMap().entries.map((e) {
                        return Column(
                          children: [
                            if (e.key > 0)
                              Divider(height: 14, color: AppColors.border),
                            _EventTile(event: e.value),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final _MockCalendarEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: Text(
            event.startTimeLabel,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.summary,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              if (event.location != null && event.location!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.place_outlined,
                          size: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(event.location!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ],
              if (event.description != null && event.description!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.notes_outlined,
                          size: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(event.description!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
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