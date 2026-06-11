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
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      if (_tabController.index == 0) {
        _loadWeeklyIfNeeded();
      } else {
        _loadMonthlyIfNeeded();
      }
    });
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
        _PeriodNavigator(
          label: report.weekLabel,
          subLabel: '일요일 자동 생성',
          canPrev: canPrev,
          canNext: canNext,
          onPrev: notifier.prevWeek,
          onNext: notifier.nextWeek,
        ),
        const SizedBox(height: 16),
        _WeeklyBarCard(report: report),
        const SizedBox(height: 12),
        _WeeklyStatGrid(report: report),
      ],
    );
  }
}

// ── 요일별 바 차트 카드 ────────────────────────────────────────────────────────
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

    final times = entries.map((e) => e.value.commuteTimeMin).where((v) => v > 0).toList();
    final displayAvg = times.isEmpty
        ? report.avgCommuteTimeMin
        : (times.reduce((a, b) => a + b) / times.length).round();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('요일별 출근 소요 시간',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('일별 데이터가 없어요.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            )
          else
            ...entries.map((e) => _BarRow(
                  day: e.key,
                  minutes: e.value.commuteTimeMin,
                  isComfort: e.value.isComfort,
                  max: maxBar,
                  avg: report.avgCommuteTimeMin,
                )),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '이번 주 평균 ${displayAvg}분',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _MiniStatCard(
              icon: '🚌',
              title: '주간 교통비',
              value: '${_fmt(report.weeklyTransportCost)}원',
              sub: '일 평균 ${_fmt((report.weeklyTransportCost / 5).round())}원',
              valueColor: AppColors.primary,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MiniStatCard(
              icon: '🔥',
              title: '소모 칼로리',
              value: '${_fmt(report.weeklyBurnedCalories)} kcal',
              sub: '도보 구간 합산',
              valueColor: AppColors.primary,
            )),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _MiniStatCard(
              icon: '⚠️',
              title: '지각 횟수',
              value: '${report.lateRiskCount} / ${report.totalLateCount}회',
              sub: '비자의적 / 총 지각',
              valueColor: AppColors.primary,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MiniStatCard(
              icon: '🗺️',
              title: '추천 경로 이용',
              value: '${report.changeRouteCount.toStringAsFixed(report.changeRouteCount.truncateToDouble() == report.changeRouteCount ? 0 : 1)}회',
              sub: '이번 주 이용 횟수',
              valueColor: AppColors.secondary,
            )),
          ],
        ),
        const SizedBox(height: 10),
        _WeeklySatisfactionCard(report: report),
      ],
    );
  }

  String _fmt(int n) => n
      .toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ── 주간 만족도 카드 ───────────────────────────────────────────────────────────
class _WeeklySatisfactionCard extends StatelessWidget {
  final WeeklyReportModel report;
  const _WeeklySatisfactionCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final avg = report.avgSatisfactionScore;
    final avgStr = avg.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('⭐ 평균 만족도',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              Text('${avgStr}점',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 0.5, color: AppColors.border),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _SatItem(label: '대기', score: report.avgSatWaitTimeScore)),
                VerticalDivider(width: 1, thickness: 0.5, color: AppColors.border),
                Expanded(child: _SatItem(label: 'ETA', score: report.avgSatEtaScore)),
                VerticalDivider(width: 1, thickness: 0.5, color: AppColors.border),
                Expanded(child: _SatItem(label: '경로', score: report.avgSatRouteScore)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SatItem extends StatelessWidget {
  final String label;
  final double score;
  const _SatItem({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(score.toStringAsFixed(1),
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.secondary)),
      ],
    );
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
        _PeriodNavigator(
          label: report.monthLabel,
          subLabel: '매월 1일 자동 생성',
          canPrev: canPrev,
          canNext: canNext,
          onPrev: notifier.prevMonth,
          onNext: notifier.nextMonth,
        ),
        const SizedBox(height: 16),

        if (report.avgCommuteTimeMin != null)
          _MonthlyCommuteCard(
            report: report,
            comfortTime: report.recommendedComfortTime,
          ),
        if (report.avgCommuteTimeMin != null) const SizedBox(height: 12),

        _MonthlyStatGrid(report: report),
      ],
    );
  }
}

// ── 월간 소요 시간 꺾은선 차트 카드 (쾌적 툴팁 포함) ─────────────────────────
class _MonthlyCommuteCard extends StatefulWidget {
  final MonthlyReportModel report;
  final ComfortTimeModel? comfortTime;
  const _MonthlyCommuteCard({required this.report, this.comfortTime});

  @override
  State<_MonthlyCommuteCard> createState() => _MonthlyCommuteCardState();
}

class _MonthlyCommuteCardState extends State<_MonthlyCommuteCard> {
  static const _days = ['월', '화', '수', '목', '금', '토', '일'];

  // 터치된 쾌적 요일 인덱스 (-1 = 없음)
  int _hoveredComfortIdx = -1;
  Offset _tooltipPos = Offset.zero;

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
    final avgVals = _extractValues(widget.report.avgCommuteTimeMin);
    final maxVals = _extractValues(widget.report.maxCommuteTimeMin);
    final minVals = _extractValues(widget.report.minCommuteTimeMin);

    final allVals = [...avgVals, ...maxVals, ...minVals]
        .whereType<int>()
        .toList();
    if (allVals.isEmpty) return const SizedBox.shrink();

    final rawMin = allVals.reduce(math.min).toDouble();
    final rawMax = allVals.reduce(math.max).toDouble();
    final spread = rawMax - rawMin;
    final pad = spread < 10 ? 10.0 : spread * 0.2;
    final yMin = (rawMin - pad).clamp(0.0, double.infinity);
    final yMax = rawMax + pad;

    final avgNonNull = avgVals.whereType<int>().toList();
    final overallAvg = avgNonNull.isEmpty
        ? widget.report.avgCommuteTimeMin?.average ?? 0
        : (avgNonNull.reduce((a, b) => a + b) / avgNonNull.length).round();

    // 쾌적 시간대: 요일 인덱스 → 시간 문자열
    final comfortMap = <int, String>{};
    if (widget.comfortTime != null) {
      for (final e in widget.comfortTime!.toEntries()) {
        final idx = _days.indexOf(e.key);
        if (idx >= 0) comfortMap[idx] = e.value;
      }
    }
    final comfortIndices = comfortMap.keys.toList();

    return Card(
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
                  child: Text('평균 ${overallAvg}분',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _LegendDot(color: AppColors.warning, label: '최대'),
                const SizedBox(width: 12),
                _LegendDot(color: AppColors.primary, label: '평균'),
                const SizedBox(width: 12),
                _LegendDot(color: Colors.green, label: '최소'),
                if (comfortIndices.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _LegendDot(color: AppColors.secondary, label: '쾌적'),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // 차트 + 툴팁
       SizedBox(
  height: 180,
  child: Stack(
    children: [
      MouseRegion(
  onHover: (e) => _onTouch(e.localPosition, comfortMap),
  onExit: (_) => setState(() => _hoveredComfortIdx = -1),
  child: GestureDetector(
    onLongPressStart: (details) {
      _onTouch(details.localPosition, comfortMap);
    },
    onLongPressMoveUpdate: (details) {
      _onTouch(details.localPosition, comfortMap);
    },
    onLongPressEnd: (_) {
      setState(() => _hoveredComfortIdx = -1);
    },
    child: CustomPaint(
      painter: _LineChartPainter(
        avgValues: avgVals,
        maxValues: maxVals,
        minValues: minVals,
        labels: _days,
        yMin: yMin,
        yMax: yMax,
        comfortIndices: comfortIndices,
        hoveredComfortIdx: _hoveredComfortIdx,
      ),
      size: Size.infinite,
    ),
  ),
),
            
      if (_hoveredComfortIdx >= 0 &&
          comfortMap.containsKey(_hoveredComfortIdx))
        _ComfortTooltip(
          position: _tooltipPos,
          day: _days[_hoveredComfortIdx],
          time: comfortMap[_hoveredComfortIdx]!,
        ),
    ],
  ),
)
          ],
        ),
      ),
    );
  }

  void _onTouch(Offset localPos, Map<int, String> comfortMap) {
    // 차트 영역 내 x 좌표로 가장 가까운 쾌적 요일 찾기
    const leftPad = 36.0;
    const rightPad = 12.0;
    // 렌더박스 크기는 build 시 알 수 없으므로 context.size 사용
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final chartW = box.size.width - leftPad - rightPad;
    final colW = chartW / (_days.length - 1);

    int? nearest;
    double minDist = double.infinity;
    for (final idx in comfortMap.keys) {
      final cx = leftPad + idx * colW;
      final dist = (localPos.dx - cx).abs();
      if (dist < minDist && dist < colW * 0.6) {
        minDist = dist;
        nearest = idx;
      }
    }

    setState(() {
      _hoveredComfortIdx = nearest ?? -1;
      _tooltipPos = localPos;
    });
  }
}

// ── 쾌적 시간 툴팁 위젯 ────────────────────────────────────────────────────────
class _ComfortTooltip extends StatelessWidget {
  final Offset position;
  final String day;
  final String time;
  const _ComfortTooltip({
    required this.position,
    required this.day,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
const h = 56.0;
const w = 130.0;
    // 툴팁이 화면 밖으로 나가지 않도록 위치 조정
    final dx = (position.dx - w / 2).clamp(0.0, double.infinity);
    final dy = (position.dy - h - 8).clamp(0.0, double.infinity);

    return Positioned(
      left: dx,
      top: dy,
      child: IgnorePointer(
        child: Container(
          width: w,
          height: h,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day요일 쾌적 시간대',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w500),
              ),
              Text(
                time,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
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
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
  final List<int> comfortIndices;
  final int hoveredComfortIdx;

  const _LineChartPainter({
    required this.avgValues,
    required this.maxValues,
    required this.minValues,
    required this.labels,
    required this.yMin,
    required this.yMax,
    this.comfortIndices = const [],
    this.hoveredComfortIdx = -1,
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
      final v   = yMin + (yMax - yMin) * i / ySteps;
      final y   = yOf(v);
      canvas.drawLine(
          Offset(_leftPad, y), Offset(size.width - _rightPad, y), gridPaint);
      _drawText(canvas, '${v.round()}',
          Offset(_leftPad - 4, y), 10, const Color(0xFF9CA3AF), right: true);
    }

    // x축 레이블
    for (int i = 0; i < labels.length; i++) {
      _drawText(canvas, labels[i],
          Offset(xOf(i), size.height - _botPad + 8), 11,
          const Color(0xFF6B7280));
    }

    // 쾌적 시간대 하이라이트
    if (comfortIndices.isNotEmpty) {
      const halfW = 16.0;
      for (final idx in comfortIndices) {
        final isHovered = idx == hoveredComfortIdx;
        final hlPaint = Paint()
          ..color = AppColors.secondary.withValues(alpha: isHovered ? 0.22 : 0.10)
          ..style = PaintingStyle.fill;
        final hlBorderPaint = Paint()
          ..color = AppColors.secondary.withValues(alpha: isHovered ? 0.7 : 0.35)
          ..strokeWidth = isHovered ? 1.5 : 1.0
          ..style = PaintingStyle.stroke;
        final cx = xOf(idx);
        final rect = Rect.fromLTRB(cx - halfW, _topPad, cx + halfW, size.height - _botPad);
        canvas.drawRect(rect, hlPaint);
        canvas.drawRect(rect, hlBorderPaint);
      }
    }

    // min/max 사이 영역 채우기
    _drawFillBetween(canvas, minValues, maxValues, xOf, yOf,
        AppColors.primary.withValues(alpha: 0.06));

    // 선 그리기
    _drawLine(canvas, minValues, xOf, yOf, Colors.green,      size);
    _drawLine(canvas, avgValues, xOf, yOf, AppColors.primary, size);
    _drawLine(canvas, maxValues, xOf, yOf, AppColors.warning, size);

    // 점 그리기
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
      old.minValues != minValues ||
      old.comfortIndices != comfortIndices ||
      old.hoveredComfortIdx != hoveredComfortIdx;
}


class _MonthlySatisfactionCard extends StatelessWidget {
  final MonthlyReportModel report;
  const _MonthlySatisfactionCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final avg = report.avgSatisfactionScore;
    final avgStr = avg.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('⭐ 평균 만족도',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              Text('${avgStr}점',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 0.5, color: AppColors.border),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _SatItem(label: '대기', score: report.avgSatWaitTimeScore)),
                VerticalDivider(width: 1, thickness: 0.5, color: AppColors.border),
                Expanded(child: _SatItem(label: 'ETA', score: report.avgSatEtaScore)),
                VerticalDivider(width: 1, thickness: 0.5, color: AppColors.border),
                Expanded(child: _SatItem(label: '경로', score: report.avgSatRouteScore)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ── 월간 통계 그리드 ──────────────────────────────────────────────────────────
class _MonthlyStatGrid extends StatelessWidget {
  final MonthlyReportModel report;
  const _MonthlyStatGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    final dailyAvgCost = report.monthlyTransportCost > 0
        ? _fmt((report.monthlyTransportCost / 20).round())
        : '0';

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _MiniStatCard(
              icon: '💰',
              title: '월간 교통비',
              value: '${_fmt(report.monthlyTransportCost)}원',
              sub: '일 평균 $dailyAvgCost원',
              valueColor: AppColors.primary,
            )),
            const SizedBox(width: 10),
            Expanded(child: _MiniStatCard(
              icon: '🔥',
              title: '총 소모 칼로리',
              value: '${_fmt(report.monthlyBurnedCalories)} kcal',
              sub: '도보 구간 합산',
              valueColor: AppColors.primary,
            )),
          ],
        ),
 Row(
  children: [
    Expanded(
      child: _MiniStatCard(
        icon: '⚠️',
        title: '지각 횟수',
        value: '${report.lateRiskCount} / ${report.totalLateCount}회',
        sub: '비자의적 / 총 지각',
        valueColor: AppColors.primary,
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: _MiniStatCard(
        icon: '🗺️',
        title: '추천 경로 이용',
        value: '${report.changeRouteCount}회',
        sub: '이번 달 이용 횟수',
        valueColor: AppColors.secondary,
      ),
    ),
  ],
),
_MonthlySatisfactionCard(report: report)
      ],
    );
  }

  String _fmt(int n) => n
      .toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ── 공용: 작은 통계 카드 ──────────────────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final String sub;
  final Color valueColor;

  const _MiniStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.sub,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$icon $title',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: valueColor)),
          const SizedBox(height: 4),
          Text(sub,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── 공용: 기간 네비게이터 ─────────────────────────────────────────────────────
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              IconButton(
                icon: Icon(Icons.chevron_right,
                    color: canNext ? null : AppColors.textSecondary.withValues(alpha: 0.3)),
                onPressed: canNext ? onNext : null,
              ),
            ],
          ),
          Text(subLabel,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      );
}

// ── 공용: 바 행 (주간 차트용) ─────────────────────────────────────────────────
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
    final barColor = isComfort ? AppColors.secondary : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text(day,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text('${minutes}분',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.right),
          ),
          const SizedBox(width: 4),
          Text(isComfort ? '😊' : '  ',
              style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

// ── 공용: 에러·빈 화면 ────────────────────────────────────────────────────────
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
              const Icon(Icons.error_outline, size: 48, color: AppColors.warning),
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
