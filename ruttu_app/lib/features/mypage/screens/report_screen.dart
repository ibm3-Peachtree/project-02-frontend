import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
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
          _WeeklyReport(),
          _MonthlyReport(),
        ],
      ),
    );
  }
}

// ── 주간 리포트 ──────────────────────────────────────
class _WeeklyReport extends StatelessWidget {
  const _WeeklyReport();

  static const _weekLabel = '2026년 5월 3주차';
  static final _barData = <String, int>{
    '월': 34,
    '화': 31,
    '수': 38,
    '목': 29,
    '금': 32,
  };
  static const _avg = 32;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
      children: [
        // 주차 네비게이터
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
                icon: const Icon(Icons.chevron_left), onPressed: () {}),
            Text(_weekLabel,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            IconButton(
                icon: const Icon(Icons.chevron_right), onPressed: () {}),
          ],
        ),
        const Text('일요일 자동 생성',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 16),

        // ① 요일별 소요 시간
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('요일별 출근 소요 시간',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                ..._barData.entries.map((e) => _BarRow(
                      day: e.key,
                      minutes: e.value,
                      max: 50,
                      avg: _avg,
                    )),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('이번 주 평균 32분',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ② 통계 그리드
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: const [
            _StatCard(
                icon: '💰',
                title: '주간 교통비',
                value: '14,000원',
                sub: '일 평균 2,800원'),
            _StatCard(
                icon: '🔥',
                title: '소모 칼로리',
                value: '280 kcal',
                sub: '도보 구간 합산'),
            _StatCard(
                icon: '⚠️',
                title: '지각 위기',
                value: '1회',
                sub: '비자의적 지각 기준',
                valueColor: AppColors.warning),
            _StatCard(
                icon: '⏳',
                title: '평균 대기 시간',
                value: '4분',
                sub: '정류장·승강장 합산'),
          ],
        ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final String day;
  final int minutes;
  final int max;
  final int avg;

  const _BarRow(
      {required this.day,
      required this.minutes,
      required this.max,
      required this.avg});

  @override
  Widget build(BuildContext context) {
    final ratio = minutes / max;
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
                      color: AppColors.primary.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text('$minutes분',
                style: const TextStyle(fontSize: 13)),
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
              Text(sub,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

// ── 월간 리포트 ──────────────────────────────────────
class _MonthlyReport extends StatelessWidget {
  const _MonthlyReport();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
      children: [
        // 월 네비게이터
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
                icon: const Icon(Icons.chevron_left), onPressed: () {}),
            const Text('2026년 5월',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            IconButton(
                icon: const Icon(Icons.chevron_right), onPressed: () {}),
          ],
        ),
        const Text('매월 1일 자동 생성',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 16),

        // AI 인사이트
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
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
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    '이번 달 가장 쾌적했던 출발 시간은 오전 7:45이에요.',
                    style: TextStyle(fontSize: 14, height: 1.6)),
              ),
            ],
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
            _StatCard(
                icon: '💰',
                title: '월간 교통비',
                value: '58,000원',
                sub: ''),
            _StatCard(
                icon: '⏱️',
                title: '평균 소요 시간',
                value: '31분',
                sub: ''),
            _StatCard(
                icon: '🔥',
                title: '총 소모 칼로리',
                value: '1,120 kcal',
                sub: ''),
            _StatCard(
                icon: '⚠️',
                title: '지각 위기 횟수',
                value: '3회',
                sub: '',
                valueColor: AppColors.warning),
            _StatCard(
                icon: '⏳',
                title: '평균 대기 시간',
                value: '4분',
                sub: ''),
            _StatCard(
                icon: '📅',
                title: '출근일 수',
                value: '22일',
                sub: '',
                valueColor: AppColors.textSecondary),
          ],
        ),
      ],
    );
  }
}
