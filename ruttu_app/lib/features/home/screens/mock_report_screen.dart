import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// ── Mock 데이터 ───────────────────────────────────
class _MockDailyEntry {
  final String day;
  final int commuteTimeMin;
  final bool isComfort;
  const _MockDailyEntry(this.day, this.commuteTimeMin, {this.isComfort = false});
}

// ── Mock 리포트 화면 (실제 ReportScreen 레이아웃 그대로) ─────────────────────
class MockReportScreen extends StatefulWidget {
  const MockReportScreen({super.key});

  @override
  State<MockReportScreen> createState() => _MockReportScreenState();
}

class _MockReportScreenState extends State<MockReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('리포트',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        leading: const BackButton(),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          tabs: const [Tab(text: '주간'), Tab(text: '월간')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MockWeeklyTab(),
          _MockMonthlyTab(),
        ],
      ),
    );
  }
}

// ── 주간 탭 (실제 _WeeklyTab 레이아웃 그대로) ────────────────────────────────
class _MockWeeklyTab extends StatelessWidget {
  const _MockWeeklyTab();

  static const _entries = [
    _MockDailyEntry('월', 41),
    _MockDailyEntry('화', 38, isComfort: true),
    _MockDailyEntry('수', 52),
    _MockDailyEntry('목', 35, isComfort: true),
    _MockDailyEntry('금', 44),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
      children: [
        // 주차 네비게이터
        const _PeriodNavigator(
          label: '5월 5주 (5.26~5.31)',
          subLabel: '일요일 자동 생성',
          canPrev: true,
          canNext: false,
        ),
        const SizedBox(height: 16),

        // ① 요일별 소요 시간 바 차트
        _MockWeeklyBarCard(entries: _entries, avg: 42),
        const SizedBox(height: 12),

        // ② 통계 그리드
        const _MockWeeklyStatGrid(),
      ],
    );
  }
}

// ── 요일별 바 차트 카드 (실제 _WeeklyBarCard 레이아웃 그대로) ────────────────
class _MockWeeklyBarCard extends StatelessWidget {
  final List<_MockDailyEntry> entries;
  final int avg;
  const _MockWeeklyBarCard({required this.entries, required this.avg});

  @override
  Widget build(BuildContext context) {
    final maxVal = entries.isEmpty
        ? 60
        : entries.map((e) => e.commuteTimeMin).reduce((a, b) => a > b ? a : b);
    final maxBar = (maxVal * 1.2).ceil().clamp(10, 999);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('요일별 출근 소요 시간',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...entries.map((e) => _BarRow(
                  day: e.day,
                  minutes: e.commuteTimeMin,
                  isComfort: e.isComfort,
                  max: maxBar,
                  avg: avg,
                )),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '이번 주 평균 ${avg}분',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 주간 통계 그리드 (실제 _WeeklyStatGrid 레이아웃 그대로) ──────────────────
class _MockWeeklyStatGrid extends StatelessWidget {
  const _MockWeeklyStatGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.4,
      children: const [
        _StatCard(icon: '💰', title: '주간 교통비', value: '32,500원', sub: '일 평균 6,500원'),
        _StatCard(icon: '🔥', title: '소모 칼로리', value: '1,240 kcal', sub: '도보 구간 합산'),
        _StatCard(icon: '⚠️', title: '지각 위기', value: '1회', sub: '비자의적 지각 기준',
            valueColor: AppColors.warning),
        _StatCard(icon: '⏳', title: '평균 대기 시간', value: '4분', sub: '정류장·승강장 합산'),
      ],
    );
  }
}

// ── 월간 탭 (실제 _MonthlyTab 레이아웃 그대로) ───────────────────────────────
class _MockMonthlyTab extends StatelessWidget {
  const _MockMonthlyTab();

  static const _avgVals = <int?>[42, 38, 45, 35, 44, null, null];
  static const _maxVals = <int?>[52, 48, 58, 42, 55, null, null];
  static const _minVals = <int?>[35, 31, 38, 28, 38, null, null];
  static const _days = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
      children: [
        // 월 네비게이터
        const _PeriodNavigator(
          label: '2025년 5월',
          subLabel: '매월 1일 자동 생성',
          canPrev: true,
          canNext: false,
        ),
        const SizedBox(height: 16),

        // 쾌적 출발 시간 인사이트 (실제 _ComfortTimeCard 레이아웃)
        Card(
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
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('AI 인사이트',
                        style: TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '이번 달 가장 쾌적했던 출발 시간은 목요일 07:50 출발이에요.',
                  style: TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 소요 시간 꺾은선 차트 (실제 _MonthlyCommuteCard 레이아웃)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('요일별 출근 소요 시간',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('평균 41분',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    _LegendDot(color: AppColors.warning, label: '최대'),
                    SizedBox(width: 12),
                    _LegendDot(color: AppColors.primary, label: '평균'),
                    SizedBox(width: 12),
                    _LegendDot(color: Colors.green, label: '최소'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: CustomPaint(
                    painter: _LineChartPainter(
                      avgValues: _avgVals,
                      maxValues: _maxVals,
                      minValues: _minVals,
                      labels: _days,
                      yMin: 20.0,
                      yMax: 68.0,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 월간 통계 그리드
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: const [
            _StatCard(icon: '💰', title: '월간 교통비', value: '130,000원', sub: ''),
            _StatCard(icon: '🔥', title: '총 소모 칼로리', value: '4,960 kcal', sub: ''),
            _StatCard(icon: '⚠️', title: '지각 위기 횟수', value: '2회', sub: '',
                valueColor: AppColors.warning),
            _StatCard(icon: '⏱️', title: '평균 소요 시간', value: '41분', sub: ''),
          ],
        ),
      ],
    );
  }
}

// ── 공용 위젯 (실제 화면과 동일) ─────────────────────────────────────────────
class _PeriodNavigator extends StatelessWidget {
  final String label;
  final String subLabel;
  final bool canPrev;
  final bool canNext;

  const _PeriodNavigator({
    required this.label,
    required this.subLabel,
    required this.canPrev,
    required this.canNext,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left,
                color: canPrev ? null : AppColors.textSecondary.withValues(alpha: 0.3)),
            onPressed: canPrev ? () {} : null,
          ),
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          IconButton(
            icon: Icon(Icons.chevron_right,
                color: canNext ? null : AppColors.textSecondary.withValues(alpha: 0.3)),
            onPressed: canNext ? () {} : null,
          ),
        ],
      ),
      Text(subLabel,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ],
  );
}

class _BarRow extends StatelessWidget {
  final String day;
  final int minutes;
  final bool isComfort;
  final int max;
  final int avg;

  const _BarRow({
    required this.day,
    required this.minutes,
    required this.isComfort,
    required this.max,
    required this.avg,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : (minutes / max).clamp(0.0, 1.0);
    final barColor = isComfort
        ? AppColors.secondary.withValues(alpha: 0.85)
        : AppColors.primary.withValues(alpha: 0.8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(day,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              '$minutes분${isComfort ? ' 😊' : ''}',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final String sub;
  final Color? valueColor;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.sub,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$icon $title',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.primary)),
          if (sub.isNotEmpty)
            Text(sub,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ],
  );
}

// ── 꺾은선 차트 (실제 _LineChartPainter 그대로) ──────────────────────────────
class _LineChartPainter extends CustomPainter {
  final List<int?> avgValues;
  final List<int?> maxValues;
  final List<int?> minValues;
  final List<String> labels;
  final double yMin;
  final double yMax;

  const _LineChartPainter({
    required this.avgValues,
    required this.maxValues,
    required this.minValues,
    required this.labels,
    required this.yMin,
    required this.yMax,
  });

  static const _leftPad  = 36.0;
  static const _rightPad = 12.0;
  static const _topPad   = 12.0;
  static const _botPad   = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width  - _leftPad - _rightPad;
    final chartH = size.height - _topPad  - _botPad;
    final range  = yMax - yMin == 0 ? 1.0 : yMax - yMin;

    double xOf(int i) => _leftPad + i * chartW / (labels.length - 1);
    double yOf(double v) => _topPad + chartH * (1 - (v - yMin) / range);

    // 격자
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    const ySteps = 4;
    for (int i = 0; i <= ySteps; i++) {
      final v = yMin + (yMax - yMin) * i / ySteps;
      final y = yOf(v);
      canvas.drawLine(
          Offset(_leftPad, y), Offset(size.width - _rightPad, y), gridPaint);
      _drawText(canvas, '${v.round()}',
          Offset(_leftPad - 4, y), 10, const Color(0xFF9CA3AF), right: true);
    }

    // x축 레이블
    for (int i = 0; i < labels.length; i++) {
      _drawText(canvas, labels[i],
          Offset(xOf(i), size.height - _botPad + 8), 11, const Color(0xFF6B7280));
    }

    // min/max 사이 영역 채우기
    _drawFillBetween(canvas, minValues, maxValues, xOf, yOf,
        AppColors.primary.withValues(alpha: 0.06));

    // 선 그리기
    _drawLine(canvas, minValues, xOf, yOf, Colors.green, size);
    _drawLine(canvas, avgValues, xOf, yOf, AppColors.primary, size);
    _drawLine(canvas, maxValues, xOf, yOf, AppColors.warning, size);

    // 점
    _drawDots(canvas, minValues, xOf, yOf, Colors.green);
    _drawDots(canvas, avgValues, xOf, yOf, AppColors.primary);
    _drawDots(canvas, maxValues, xOf, yOf, AppColors.warning);
  }

  void _drawLine(Canvas canvas, List<int?> vals,
      double Function(int) xOf, double Function(double) yOf,
      Color color, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    bool started = false;
    for (int i = 0; i < vals.length; i++) {
      final v = vals[i];
      if (v == null) { started = false; continue; }
      final x = xOf(i); final y = yOf(v.toDouble());
      if (!started) { path.moveTo(x, y); started = true; }
      else          { path.lineTo(x, y); }
    }
    canvas.drawPath(path, paint);
  }

  void _drawDots(Canvas canvas, List<int?> vals,
      double Function(int) xOf, double Function(double) yOf, Color color) {
    final fill   = Paint()..color = color;
    final border = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5;
    for (int i = 0; i < vals.length; i++) {
      final v = vals[i];
      if (v == null) continue;
      final c = Offset(xOf(i), yOf(v.toDouble()));
      canvas.drawCircle(c, 4, fill);
      canvas.drawCircle(c, 4, border);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, double size,
      Color color, {bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = right ? offset.dx - tp.width - 2 : offset.dx - tp.width / 2;
    tp.paint(canvas, Offset(dx, offset.dy - tp.height / 2));
  }

  void _drawFillBetween(Canvas canvas, List<int?> minVals, List<int?> maxVals,
      double Function(int) xOf, double Function(double) yOf, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    bool started = false;
    for (int i = 0; i < maxVals.length; i++) {
      final v = maxVals[i];
      if (v == null) { started = false; continue; }
      if (!started) { path.moveTo(xOf(i), yOf(v.toDouble())); started = true; }
      else          { path.lineTo(xOf(i), yOf(v.toDouble())); }
    }
    for (int i = minVals.length - 1; i >= 0; i--) {
      final v = minVals[i];
      if (v == null) continue;
      path.lineTo(xOf(i), yOf(v.toDouble()));
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.avgValues != avgValues ||
      old.maxValues != maxValues ||
      old.minValues != minValues;
}