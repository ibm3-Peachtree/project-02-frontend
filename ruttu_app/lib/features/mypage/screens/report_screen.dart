import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/report_model.dart';
import '../providers/report_provider.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 탭 전환 시 해당 탭 데이터 로드
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      if (_tabController.index == 0) {
        _loadWeeklyIfNeeded();
      } else {
        _loadMonthlyIfNeeded();
      }
    });
    // 첫 진입 시 주간 로드
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeeklyIfNeeded());
  }

  void _loadWeeklyIfNeeded() {
    final s = ref.read(reportProvider);
    if (s.weeklyList.isEmpty && !s.isLoadingWeekly) {
      ref.read(reportProvider.notifier).loadWeekly();
    }
  }

  void _loadMonthlyIfNeeded() {
    final s = ref.read(reportProvider);
    if (s.monthlyList.isEmpty && !s.isLoadingMonthly) {
      ref.read(reportProvider.notifier).loadMonthly();
    }
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
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          tabs: const [Tab(text: '주간'), Tab(text: '월간')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _WeeklyTab(),
          _MonthlyTab(),
        ],
      ),
    );
  }
}

// ── 주간 탭 ───────────────────────────────────────────────────────────────────
class _WeeklyTab extends ConsumerWidget {
  const _WeeklyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportProvider);

    if (state.isLoadingWeekly) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.weeklyError != null) {
      return _ErrorView(
        message: state.weeklyError!,
        onRetry: () => ref.read(reportProvider.notifier).loadWeekly(),
      );
    }

    if (state.weeklyList.isEmpty) {
      return const _EmptyView(message: '주간 리포트가 아직 없어요.\n루틴을 완료하면 일요일에 자동 생성됩니다.');
    }

    final report = state.currentWeekly!;
    final notifier = ref.read(reportProvider.notifier);
    final canPrev = state.weeklyIndex < state.weeklyList.length - 1;
    final canNext = state.weeklyIndex > 0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
      children: [
        // 주차 네비게이터
        _PeriodNavigator(
          label: report.weekLabel,
          subLabel: '일요일 자동 생성',
          canPrev: canPrev,
          canNext: canNext,
          onPrev: notifier.prevWeek,
          onNext: notifier.nextWeek,
        ),
        const SizedBox(height: 16),

        // ① 요일별 소요 시간 바 차트
        _WeeklyBarCard(report: report),
        const SizedBox(height: 12),

        // ② 통계 그리드
        _WeeklyStatGrid(report: report),
      ],
    );
  }
}

// ── 요일별 바 차트 카드 ───────────────────────────────────────────────────────
class _WeeklyBarCard extends StatelessWidget {
  final WeeklyReportModel report;
  const _WeeklyBarCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final entries = report.daily?.toEntries() ?? [];
    final maxVal = entries.isEmpty
        ? 60
        : entries.map((e) => e.value.commuteTimeMin).reduce((a, b) => a > b ? a : b);
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
            if (entries.isEmpty)
              const Text('일별 데이터가 없어요.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              ...entries.map((e) => _BarRow(
                    day: e.key,
                    minutes: e.value.commuteTimeMin,
                    isComfort: e.value.isComfort,
                    max: maxBar,
                    avg: report.avgCommuteTimeMin,
                  )),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              // daily 실측 값이 있으면 그걸로, 없으면 API avgCommuteTimeMin
              final times = entries
                  .map((e) => e.value.commuteTimeMin)
                  .where((v) => v > 0)
                  .toList();
              final displayAvg = times.isEmpty
                  ? report.avgCommuteTimeMin
                  : (times.reduce((a, b) => a + b) / times.length).round();
              return Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '이번 주 평균 ${displayAvg}분',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── 주간 통계 그리드 ──────────────────────────────────────────────────────────
class _WeeklyStatGrid extends StatelessWidget {
  final WeeklyReportModel report;
  const _WeeklyStatGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.4,
      children: [
        _StatCard(
          icon: '💰',
          title: '주간 교통비',
          value: '${_fmt(report.weeklyTransportCost)}원',
          sub: '일 평균 ${_fmt((report.weeklyTransportCost / 5).round())}원',
        ),
        _StatCard(
          icon: '🔥',
          title: '소모 칼로리',
          value: '${_fmt(report.weeklyBurnedCalories)} kcal',
          sub: '도보 구간 합산',
        ),
        _StatCard(
          icon: '⚠️',
          title: '지각 위기',
          value: '${report.lateRiskCount}회',
          sub: '비자의적 지각 기준',
          valueColor: report.lateRiskCount > 0 ? AppColors.warning : null,
        ),
        _StatCard(
          icon: '⏳',
          title: '평균 대기 시간',
          value: '${report.avgWaitTimeMin}분',
          sub: '정류장·승강장 합산',
        ),
      ],
    );
  }

  String _fmt(int n) {
    // 천 단위 콤마
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

// ── 월간 탭 ───────────────────────────────────────────────────────────────────
class _MonthlyTab extends ConsumerWidget {
  const _MonthlyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportProvider);

    if (state.isLoadingMonthly) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.monthlyError != null) {
      return _ErrorView(
        message: state.monthlyError!,
        onRetry: () => ref.read(reportProvider.notifier).loadMonthly(),
      );
    }

    if (state.monthlyList.isEmpty) {
      return const _EmptyView(message: '월간 리포트가 아직 없어요.\n루틴을 완료하면 매월 1일에 자동 생성됩니다.');
    }

    final report = state.currentMonthly!;
    final notifier = ref.read(reportProvider.notifier);
    final canPrev = state.monthlyIndex < state.monthlyList.length - 1;
    final canNext = state.monthlyIndex > 0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
      children: [
        // 월 네비게이터
        _PeriodNavigator(
          label: report.monthLabel,
          subLabel: '매월 1일 자동 생성',
          canPrev: canPrev,
          canNext: canNext,
          onPrev: notifier.prevMonth,
          onNext: notifier.nextMonth,
        ),
        const SizedBox(height: 16),

        // 쾌적 출발 시간 인사이트
        if (report.recommendedComfortTime != null)
          _ComfortTimeCard(model: report.recommendedComfortTime!),
        if (report.recommendedComfortTime != null) const SizedBox(height: 12),

        // 소요 시간 비교 (평균·최대·최소)
        if (report.avgCommuteTimeMin != null)
          _MonthlyCommuteCard(report: report),
        if (report.avgCommuteTimeMin != null) const SizedBox(height: 12),

        // 월간 통계 그리드
        _MonthlyStatGrid(report: report),
      ],
    );
  }
}

// ── 쾌적 출발 시간 카드 (AI 인사이트 역할) ────────────────────────────────────
class _ComfortTimeCard extends StatelessWidget {
  final ComfortTimeModel model;
  const _ComfortTimeCard({required this.model});

  @override
  Widget build(BuildContext context) {
    // 가장 이른 쾌적 출발 시간 요일 (HH:mm 문자열 비교)
    final best = model.earliest;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: best == null
                ? const Text('이번 달 쾌적 출발 시간 데이터가 없어요.',
                    style: TextStyle(fontSize: 14, height: 1.6))
                : Text(
                    '이번 달 가장 쾌적했던 출발 시간은 ${best.key}요일 ${best.value} 출발이에요.',
                    style: const TextStyle(fontSize: 14, height: 1.6)),
          ),
        ],
      ),
    );
  }
}

// ── 월간 소요 시간 꺾은선 차트 카드 ─────────────────────────────────────────
class _MonthlyCommuteCard extends StatelessWidget {
  final MonthlyReportModel report;
  const _MonthlyCommuteCard({required this.report});

  static const _days = ['월', '화', '수', '목', '금', '토', '일'];

  List<int?> _extractValues(CommuteTimeMinModel? model) {
    if (model == null) return List.filled(7, null);
    final m = model.toWeekdayMap();
    return _days.map((d) {
      final v = m[d] ?? 0;
      return v > 0 ? v : null;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final avgVals = _extractValues(report.avgCommuteTimeMin);
    final maxVals = _extractValues(report.maxCommuteTimeMin);
    final minVals = _extractValues(report.minCommuteTimeMin);

    // 전체 유효값으로 y축 범위 계산
    final allVals = [...avgVals, ...maxVals, ...minVals]
        .whereType<int>()
        .toList();
    if (allVals.isEmpty) {
      return const SizedBox.shrink();
    }
    final rawMin = allVals.reduce(math.min).toDouble();
    final rawMax = allVals.reduce(math.max).toDouble();
    // 데이터 범위가 너무 좁으면 최소 ±10분 여백 보장
    final spread = rawMax - rawMin;
    final pad = spread < 10 ? 10.0 : spread * 0.2;
    final yMin = (rawMin - pad).clamp(0.0, double.infinity);
    final yMax = rawMax + pad;

    // 평균값 중 유효한 것의 평균
    final avgNonNull = avgVals.whereType<int>().toList();
    final overallAvg = avgNonNull.isEmpty
        ? report.avgCommuteTimeMin?.average ?? 0
        : (avgNonNull.reduce((a, b) => a + b) / avgNonNull.length).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('요일별 출근 소요 시간',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('평균 ${overallAvg}분',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 범례
            Row(
              children: [
                _LegendDot(color: AppColors.warning, label: '최대'),
                const SizedBox(width: 12),
                _LegendDot(color: AppColors.primary, label: '평균'),
                const SizedBox(width: 12),
                _LegendDot(color: Colors.green, label: '최소'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: CustomPaint(
                painter: _LineChartPainter(
                  avgValues: avgVals,
                  maxValues: maxVals,
                  minValues: minVals,
                  labels: _days,
                  yMin: yMin,
                  yMax: yMax,
                ),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      );
}

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

    // ── 격자 ──────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    const ySteps = 4;
    for (int i = 0; i <= ySteps; i++) {
      final v   = yMin + (yMax - yMin) * i / ySteps;
      final y   = yOf(v);
      canvas.drawLine(
          Offset(_leftPad, y), Offset(size.width - _rightPad, y), gridPaint);
      // y축 레이블
      _drawText(canvas, '${v.round()}',
          Offset(_leftPad - 4, y), 10, const Color(0xFF9CA3AF), right: true);
    }

    // ── x축 레이블 ─────────────────────────────────────────
    for (int i = 0; i < labels.length; i++) {
      _drawText(canvas, labels[i],
          Offset(xOf(i), size.height - _botPad + 8), 11,
          const Color(0xFF6B7280));
    }

    // ── min/max 사이 영역 채우기 (반투명) ─────────────────
    _drawFillBetween(canvas, minValues, maxValues, xOf, yOf,
        AppColors.primary.withValues(alpha: 0.06));

    // ── 선 그리기 (min → avg → max 순: max가 맨 위) ────────
    _drawLine(canvas, minValues, xOf, yOf, Colors.green,      size);
    _drawLine(canvas, avgValues, xOf, yOf, AppColors.primary, size);
    _drawLine(canvas, maxValues, xOf, yOf, AppColors.warning, size);

    // ── 점 + 값 레이블 그리기 ─────────────────────────────
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
      final x = xOf(i);
      final y = yOf(v.toDouble());
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
      text: TextSpan(
          text: text,
          style: TextStyle(fontSize: size, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = right ? offset.dx - tp.width - 2 : offset.dx - tp.width / 2;
    tp.paint(canvas, Offset(dx, offset.dy - tp.height / 2));
  }

  /// min ~ max 사이 영역을 반투명으로 채워서 범위를 시각화
  void _drawFillBetween(Canvas canvas, List<int?> minVals, List<int?> maxVals,
      double Function(int) xOf, double Function(double) yOf, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    // 위쪽 경계(max) 순방향
    bool started = false;
    for (int i = 0; i < maxVals.length; i++) {
      final v = maxVals[i];
      if (v == null) { started = false; continue; }
      if (!started) { path.moveTo(xOf(i), yOf(v.toDouble())); started = true; }
      else          { path.lineTo(xOf(i), yOf(v.toDouble())); }
    }
    // 아래쪽 경계(min) 역방향으로 닫기
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

// ── 월간 통계 그리드 ──────────────────────────────────────────────────────────
class _MonthlyStatGrid extends StatelessWidget {
  final MonthlyReportModel report;
  const _MonthlyStatGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.4,
      children: [
        _StatCard(
          icon: '💰',
          title: '월간 교통비',
          value: '${_fmt(report.monthlyTransportCost)}원',
          sub: '',
        ),
        _StatCard(
          icon: '🔥',
          title: '총 소모 칼로리',
          value: '${_fmt(report.monthlyBurnedCalories)} kcal',
          sub: '',
        ),
        _StatCard(
          icon: '⚠️',
          title: '지각 위기 횟수',
          value: '${report.lateRiskCount}회',
          sub: '',
          valueColor: report.lateRiskCount > 0 ? AppColors.warning : null,
        ),
        _StatCard(
          icon: '⏱️',
          title: '평균 소요 시간',
          value: report.avgCommuteTimeMin != null
              ? '${report.avgCommuteTimeMin!.average}분'
              : '-',
          sub: '',
        ),
      ],
    );
  }

  String _fmt(int n) => n
      .toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ── 공용 위젯 ─────────────────────────────────────────────────────────────────
class _PeriodNavigator extends StatelessWidget {
  final String label;
  final String subLabel;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _PeriodNavigator({
    required this.label,
    required this.subLabel,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
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
                onPressed: canPrev ? onPrev : null,
              ),
              Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              IconButton(
                icon: Icon(Icons.chevron_right,
                    color: canNext ? null : AppColors.textSecondary.withValues(alpha: 0.3)),
                onPressed: canNext ? onNext : null,
              ),
            ],
          ),
          Text(subLabel,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
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
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
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
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? AppColors.primary)),
              if (sub.isNotEmpty)
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

class _EmptyView extends StatelessWidget {
  final String message;
  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_outlined,
                  size: 56, color: AppColors.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6)),
            ],
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.warning),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
}