import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_constants.dart';
import '../../../data/models/routine_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/weather_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../briefing/providers/briefing_provider.dart';
// ✅ 버그 수정: live_location_provider import 제거 → homeProvider 충돌 해소
//   live_location_provider 는 home_provider.dart 에서만 import
import '../providers/home_provider.dart';
import '../providers/home_state.dart';
import '../providers/live_location_provider.dart'
    show liveLocationProvider; // ✅ liveLocationProvider만 선택 import
import 'package:flutter_naver_map/flutter_naver_map.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeProvider.notifier).initialize();
    });
  }

  /// 종료 확인 다이얼로그 → stopRoute() → 피드백 모달
  /// HomeScreen 레벨에서 처리해야 _ActiveView unmount 후에도 context/ref가 살아있음
  void _onStopTap(RoutineModel? routine) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '경로를 종료할까요?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          '현재 진행 중인 루틴이 종료됩니다.\n목적지에 도달하지 않았어도 종료할 수 있어요.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              '계속 진행',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await Future.delayed(const Duration(milliseconds: 400));
              if (!mounted) return;
              final departure = ref.read(homeProvider).departureTime ?? DateTime.now();
              final arrival = DateTime.now();
              ref.read(homeProvider.notifier).stopRoute();
              await Future.delayed(const Duration(milliseconds: 400));
              if (mounted) _showFeedbackModal(context, routine, departure, arrival);
            },
            child: const Text('종료하기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ GPS keepAlive: build 안에서 watch하여 Provider가 항상 살아있도록 유지
    ref.watch(liveLocationProvider);
    final home = ref.watch(homeProvider);

    if (home.isLoading && home.status == HomeStatus.noRoutine) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return switch (home.status) {
      HomeStatus.noRoutine => _NoRoutineView(weather: home.weather),
      HomeStatus.noTodayRoutine => _NoTodayRoutineView(weather: home.weather),
      HomeStatus.preActive => _PreActiveView(home: home),
      HomeStatus.active => _ActiveView(home: home, onStopTap: _onStopTap),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

// ───────────────────────────────────────────────
// 2-A: 루틴 없음
// ───────────────────────────────────────────────
// ───────────────────────────────────────────────
// 2-A-1: 오늘 루틴 없음 (루틴은 있지만 오늘 요일 해당 없음)
// ───────────────────────────────────────────────
class _NoTodayRoutineView extends ConsumerWidget {
  final WeatherAirQualityModel? weather;
  const _NoTodayRoutineView({this.weather});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final nickname = user?.nickname ?? '루뚜';
    final today = _todayKo();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _CoralHeader(nickname: nickname, weather: weather),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              child: Column(
                children: [
                  // 오늘 루틴 없음 — 강조 유도 카드
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 상단 강조 배너
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 24,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 26,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '오늘($today)은 루틴이 없어요',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$today요일 루틴을 등록하시겠어요?',
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
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Text(
                                '루틴을 등록하면 매일 자동으로\n경로 안내와 출발 알림을 받을 수 있어요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => context.push(
                                    RouteConstants.routineCreate,
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('지금 루틴 등록하기'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: () =>
                                    context.go(RouteConstants.routine),
                                child: const Text(
                                  '기존 루틴 요일 변경하기',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickMenuCard(
                          icon: Icons.add_circle_outline_rounded,
                          label: '루틴 추가',
                          color: AppColors.primary,
                          onTap: () => context.go(RouteConstants.routine),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickMenuCard(
                          icon: Icons.wb_sunny_outlined,
                          label: 'AI 브리핑',
                          color: AppColors.secondary,
                          onTap: () => context.go(RouteConstants.briefing),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickMenuCard(
                          icon: Icons.people_outline_rounded,
                          label: '커뮤니티',
                          color: const Color(0xFF6366F1),
                          onTap: () => context.go(RouteConstants.community),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _todayKo() {
    const keys = ['월', '화', '수', '목', '금', '토', '일'];
    return keys[DateTime.now().weekday - 1];
  }
}

// ───────────────────────────────────────────────
// 2-A-2: 루틴 없음 (아예 등록 안 함)
// ───────────────────────────────────────────────
class _NoRoutineView extends ConsumerWidget {
  final WeatherAirQualityModel? weather;
  const _NoRoutineView({this.weather});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final nickname = user?.nickname ?? '루뚜';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _CoralHeader(nickname: nickname, weather: weather),
          ),
          SliverToBoxAdapter(child: _BriefingCard(weather: weather)),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyRoutineSection(),
          ),
        ],
      ),
    );
  }
}

class _CoralHeader extends StatelessWidget {
  final String nickname;
  final WeatherAirQualityModel? weather;
  const _CoralHeader({required this.nickname, this.weather});

  @override
  Widget build(BuildContext context) {
    final w = weather;
    final tmp = w?.current?.tmp;
    final skyEmoji = w?.skyEmoji ?? '🌤';
    final pm10 = w?.pm10Label ?? '—';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFFFF8C55)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '안녕하세요, $nickname님! 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (w != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$skyEmoji${tmp != null ? ' $tmp°' : ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const Text(
                    ' · ',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    '미세먼지 $pm10',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BriefingCard extends StatelessWidget {
  final WeatherAirQualityModel? weather;
  const _BriefingCard({this.weather});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.wb_sunny_outlined,
                color: AppColors.secondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘의 AI 브리핑',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '루틴을 등록하면 AI가 맞춤 브리핑을 제공해요.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── 루틴 없을 때 빠른 액션 + 안내 섹션 ──────────────────
class _EmptyRoutineSection extends StatelessWidget {
  const _EmptyRoutineSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 루틴 등록 유도 카드 ────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFFFF8C55)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '루틴을 만들어보세요! 🚀',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'AI가 최적 경로를 찾아주고\n실시간으로 안내해드려요.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => context.go(RouteConstants.routine),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '루틴 추가하기',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ── 빠른 메뉴 ──────────────────────────────────
          const Text(
            '빠른 메뉴',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickMenuCard(
                  icon: Icons.add_circle_outline_rounded,
                  label: '루틴 추가',
                  color: AppColors.primary,
                  onTap: () => context.go(RouteConstants.routine),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickMenuCard(
                  icon: Icons.wb_sunny_outlined,
                  label: 'AI 브리핑',
                  color: AppColors.secondary,
                  onTap: () => context.go(RouteConstants.briefing),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickMenuCard(
                  icon: Icons.people_outline_rounded,
                  label: '커뮤니티',
                  color: const Color(0xFF6366F1),
                  onTap: () => context.go(RouteConstants.community),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ── 루틴이란? 안내 카드 ────────────────────────
          const Text(
            '루틴이 뭔가요?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            emoji: '🗺',
            title: '맞춤 경로 안내',
            desc: '출발지·도착지를 설정하면 AI가 최적 경로를 추천해요.',
            onTap: () => _showFeaturePreview(context, _FeatureType.route),
          ),
          const SizedBox(height: 8),
          _FeatureCard(
            emoji: '⏰',
            title: '출발 권장 알림',
            desc: '제시간에 도착하도록 출발 시간을 알려드려요.',
            onTap: () => _showFeaturePreview(context, _FeatureType.alarm),
          ),
          const SizedBox(height: 8),
          _FeatureCard(
            emoji: '📍',
            title: '실시간 위치 추적',
            desc: '이동 중 돌발 상황이 생기면 대체 경로를 안내해요.',
            onTap: () => _showFeaturePreview(context, _FeatureType.live),
          ),
        ],
      ),
    );
  }
}

class _QuickMenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickMenuCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FeatureCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;
  const _FeatureCard({
    required this.emoji,
    required this.title,
    required this.desc,
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.border,
            ),
        ],
      ),
    ),
  );
}

// ── 기능 미리보기 ────────────────────────────────────────

enum _FeatureType { route, alarm, live }

void _showFeaturePreview(BuildContext context, _FeatureType type) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FeaturePreviewSheet(type: type),
  );
}

class _FeaturePreviewSheet extends StatefulWidget {
  final _FeatureType type;
  const _FeaturePreviewSheet({required this.type});

  @override
  State<_FeaturePreviewSheet> createState() => _FeaturePreviewSheetState();
}

class _FeaturePreviewSheetState extends State<_FeaturePreviewSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  int _step = 0;
  static const _stepInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _anim.forward();
    _advanceSteps();
  }

  void _advanceSteps() {
    Future.delayed(_stepInterval, () {
      if (!mounted) return;
      final maxStep = _maxStep;
      if (_step < maxStep) {
        setState(() => _step++);
        _anim.reset();
        _anim.forward();
        _advanceSteps();
      }
    });
  }

  int get _maxStep {
    switch (widget.type) {
      case _FeatureType.route:
        return 2;
      case _FeatureType.alarm:
        return 2;
      case _FeatureType.live:
        return 2;
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewPadding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // 제목
          Text(
            _title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          // 스텝 인디케이터
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _maxStep + 1,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _step == i ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _step == i ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 미리보기 카드
          FadeTransition(opacity: _fade, child: _buildPreview()),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go(RouteConstants.routine);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                '루틴 만들러 가기',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _title {
    switch (widget.type) {
      case _FeatureType.route:
        return '🗺 맞춤 경로 안내';
      case _FeatureType.alarm:
        return '⏰ 출발 권장 알림';
      case _FeatureType.live:
        return '📍 실시간 위치 추적';
    }
  }

  Widget _buildPreview() {
    switch (widget.type) {
      case _FeatureType.route:
        return _RoutePreview(step: _step);
      case _FeatureType.alarm:
        return _AlarmPreview(step: _step);
      case _FeatureType.live:
        return _LivePreview(step: _step);
    }
  }
}

// ── 맞춤 경로 안내 미리보기 ──────────────────────────────
class _RoutePreview extends StatelessWidget {
  final int step;
  const _RoutePreview({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _PreviewStep(
        icon: Icons.edit_location_alt_rounded,
        color: AppColors.primary,
        label: '1단계: 출발지·도착지 설정',
        content: Column(
          children: [
            _MockAddressRow(
              icon: Icons.home_rounded,
              label: '출발지',
              value: '집 (서울 강남구)',
            ),
            const SizedBox(height: 8),
            _MockAddressRow(
              icon: Icons.flag_rounded,
              label: '도착지',
              value: '회사 (서울 중구)',
            ),
          ],
        ),
        caption: '루틴에 출발지와 도착지를 등록해요.',
      ),
      _PreviewStep(
        icon: Icons.auto_awesome_rounded,
        color: AppColors.secondary,
        label: '2단계: AI가 경로 분석',
        content: Column(
          children: [
            _MockRouteCard(
              label: '추천',
              route: '2호선 → 도보 5분',
              minutes: 32,
              highlighted: true,
            ),
            const SizedBox(height: 6),
            _MockRouteCard(
              label: '대안',
              route: '신분당선 → 버스 11번',
              minutes: 38,
              highlighted: false,
            ),
          ],
        ),
        caption: 'AI가 실시간 교통 상황을 반영해 최적 경로를 골라줘요.',
      ),
      _PreviewStep(
        icon: Icons.directions_transit_rounded,
        color: const Color(0xFF6366F1),
        label: '3단계: 경로 안내 시작',
        content: _MockStepProgress(),
        caption: '각 구간별로 도보·지하철·버스 안내를 받아요.',
      ),
    ];

    final s = steps[step.clamp(0, steps.length - 1)];
    return _StepCard(step: s);
  }
}

// ── 출발 권장 알림 미리보기 ──────────────────────────────
class _AlarmPreview extends StatelessWidget {
  final int step;
  const _AlarmPreview({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _PreviewStep(
        icon: Icons.schedule_rounded,
        color: AppColors.warning,
        label: '1단계: 목표 도착 시간 설정',
        content: _MockTimeCard(time: '09:00', label: '목표 도착 시간'),
        caption: '몇 시까지 도착해야 하는지 루틴에 설정해요.',
      ),
      _PreviewStep(
        icon: Icons.notifications_active_rounded,
        color: AppColors.primary,
        label: '2단계: 출발 시간 계산',
        content: Column(
          children: [
            _MockTimeCard(time: '08:22', label: '권장 출발 시간', primary: true),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.directions_run_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '곧 출발하세요!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        caption: '소요 시간을 역산해 정확한 출발 시간을 알려줘요.',
      ),
      _PreviewStep(
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        label: '3단계: 여유 있게 도착',
        content: _MockArrivalCard(),
        caption: '매일 아침 알림 없이도 제시간에 출발할 수 있어요.',
      ),
    ];

    final s = steps[step.clamp(0, steps.length - 1)];
    return _StepCard(step: s);
  }
}

// ── 실시간 위치 추적 미리보기 ────────────────────────────
class _LivePreview extends StatelessWidget {
  final int step;
  const _LivePreview({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _PreviewStep(
        icon: Icons.my_location_rounded,
        color: AppColors.primary,
        label: '1단계: 이동 중 위치 추적',
        content: _MockLiveStatus(),
        caption: 'GPS로 현재 위치를 실시간으로 파악해요.',
      ),
      _PreviewStep(
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        label: '2단계: 돌발 상황 감지',
        content: _MockIncidentCard(),
        caption: '지연·혼잡 상황이 생기면 즉시 감지해요.',
      ),
      _PreviewStep(
        icon: Icons.alt_route_rounded,
        color: AppColors.secondary,
        label: '3단계: 대체 경로 제안',
        content: _MockRecoCard(),
        caption: 'AI가 최적의 대체 경로를 바로 제안해드려요.',
      ),
    ];

    final s = steps[step.clamp(0, steps.length - 1)];
    return _StepCard(step: s);
  }
}

// ── 공통 스텝 카드 ────────────────────────────────────────
class _PreviewStep {
  final IconData icon;
  final Color color;
  final String label;
  final Widget content;
  final String caption;
  const _PreviewStep({
    required this.icon,
    required this.color,
    required this.label,
    required this.content,
    required this.caption,
  });
}

class _StepCard extends StatelessWidget {
  final _PreviewStep step;
  const _StepCard({required this.step});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: step.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(step.icon, size: 20, color: step.color),
          ),
          const SizedBox(width: 10),
          Text(
            step.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      step.content,
      const SizedBox(height: 10),
      Text(
        step.caption,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    ],
  );
}

// ── 목업 위젯들 ───────────────────────────────────────────
class _MockAddressRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MockAddressRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _MockRouteCard extends StatelessWidget {
  final String label;
  final String route;
  final int minutes;
  final bool highlighted;
  const _MockRouteCard({
    required this.label,
    required this.route,
    required this.minutes,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: highlighted
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: highlighted ? AppColors.primary : AppColors.border,
        width: highlighted ? 1.5 : 1,
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: highlighted ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: highlighted ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            route,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
        ),
        Text(
          '$minutes분',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: highlighted ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _MockStepProgress extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      ('🚶', '도보 3분', true),
      ('🚇', '2호선 강남역 승차', true),
      ('🚶', '도보 5분', false),
    ];
    return Column(
      children: items.asMap().entries.map((e) {
        final done = e.value.$3;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(e.value.$1, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  e.value.$2,
                  style: TextStyle(
                    fontSize: 13,
                    color: done
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontWeight: done ? FontWeight.w400 : FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (done)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppColors.success,
                ),
              if (!done)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MockTimeCard extends StatelessWidget {
  final String time;
  final String label;
  final bool primary;
  const _MockTimeCard({
    required this.time,
    required this.label,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: primary
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: primary ? AppColors.primary : AppColors.border,
        width: primary ? 1.5 : 1,
      ),
    ),
    child: Column(
      children: [
        Text(
          time,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: primary ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _MockArrivalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
    ),
    child: const Row(
      children: [
        Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '09:00 도착 완료 🎉',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '목표 시간보다 2분 일찍 도착했어요!',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MockLiveStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '실시간 추적 중',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Icon(
              Icons.directions_walk_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '현재 도보 이동 중',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '2호선 강남역까지 3분',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MockIncidentCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
    ),
    child: const Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '2호선 강남 구간 지연',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '+6분 지연 예상 · 대체 경로를 찾고 있어요',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MockRecoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.secondary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: AppColors.secondary,
            ),
            SizedBox(width: 6),
            Text(
              'AI 추천 대체 경로',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Expanded(
              child: Text(
                '신분당선 강남역 → 버스 146',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '34분',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '기존보다 4분 더 빨라요',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

// ───────────────────────────────────────────────
// 2-B: 출발 전 (루틴 있음, 미시작)
// ───────────────────────────────────────────────
class _PreActiveView extends ConsumerStatefulWidget {
  final HomeState home;
  const _PreActiveView({required this.home});

  @override
  ConsumerState<_PreActiveView> createState() => _PreActiveViewState();
}

class _PreActiveViewState extends ConsumerState<_PreActiveView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  NaverMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final briefing = ref.read(briefingProvider);
      if (briefing.weather == null && !briefing.isLoading) {
        ref.read(briefingProvider.notifier).load();
      }
    });
  }

  @override
  void didUpdateWidget(_PreActiveView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapController != null &&
        widget.home.routeCoordinates != oldWidget.home.routeCoordinates) {
      _drawRouteOnMap(_mapController!, widget.home.routeCoordinates);
    }
  }

  /// 전체 경로를 지도에 폴리라인으로 그리고, 전체 경로가 보이도록 카메라를 맞춥니다.
  Future<void> _drawRouteOnMap(
    NaverMapController controller,
    List<RouteXYModel> coords,
  ) async {
    if (coords.isEmpty) return;

    await controller.clearOverlays();

    final validCoords = coords.where((c) => c.hasCoord).toList();
    if (validCoords.isEmpty) return;

    final allPoints = <({NLatLng pt, String type})>[];
    for (var i = 0; i < coords.length; i++) {
      final c = coords[i];
      if (c.hasCoord) {
        allPoints.add((pt: NLatLng(c.y!, c.x!), type: c.type ?? 'walk'));
      } else if (c.type == 'walk') {
        NLatLng? prev;
        for (var j = i - 1; j >= 0; j--) {
          if (coords[j].hasCoord) {
            prev = NLatLng(coords[j].y!, coords[j].x!);
            break;
          }
        }
        NLatLng? next;
        for (var j = i + 1; j < coords.length; j++) {
          if (coords[j].hasCoord) {
            next = NLatLng(coords[j].y!, coords[j].x!);
            break;
          }
        }
        if (prev != null && allPoints.isEmpty)
          allPoints.add((pt: prev, type: 'walk'));
        if (next != null) allPoints.add((pt: next, type: 'walk'));
      }
    }

    if (allPoints.length < 2) return;

    // type별 세그먼트 그룹핑
    final segments = <({String type, List<NLatLng> points})>[];
    String currentType = allPoints.first.type;
    List<NLatLng> currentPoints = [allPoints.first.pt];

    for (var i = 1; i < allPoints.length; i++) {
      final item = allPoints[i];
      if (item.type != currentType) {
        if (currentPoints.length >= 2) {
          segments.add((type: currentType, points: List.of(currentPoints)));
        }
        currentType = item.type;
        currentPoints = [currentPoints.last, item.pt];
      } else {
        currentPoints.add(item.pt);
      }
    }
    if (currentPoints.length >= 2) {
      segments.add((type: currentType, points: List.of(currentPoints)));
    }

    Color typeColor(String type) {
      switch (type) {
        case 'subway':
          return Colors.blue;
        case 'bus':
          return const Color(0xFF22C55E);
        default:
          return const Color(0xFF9CA3AF);
      }
    }

    double typeWidth(String type) => type == 'walk' ? 3.0 : 6.0;

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.points.length < 2) continue;
      await controller.addOverlay(
        NPolylineOverlay(
          id: 'pre_seg_$i',
          coords: seg.points,
          color: typeColor(seg.type),
          width: typeWidth(seg.type),
        ),
      );
    }

    // 출발지 마커
    final startPt = allPoints.first.pt;
    await controller.addOverlay(
      NMarker(id: 'pre_start', position: startPt)
        ..setCaption(NOverlayCaption(text: '출발', textSize: 12)),
    );

    // 도착지 마커
    final endPt = allPoints.last.pt;
    await controller.addOverlay(
      NMarker(id: 'pre_end', position: endPt)
        ..setCaption(NOverlayCaption(text: '도착', textSize: 12)),
    );

    // 전체 경로가 보이도록 bounds fit (padding 60px)
    final lats = allPoints.map((e) => e.pt.latitude).toList();
    final lngs = allPoints.map((e) => e.pt.longitude).toList();
    final sw = NLatLng(
      lats.reduce((a, b) => a < b ? a : b),
      lngs.reduce((a, b) => a < b ? a : b),
    );
    final ne = NLatLng(
      lats.reduce((a, b) => a > b ? a : b),
      lngs.reduce((a, b) => a > b ? a : b),
    );
    await controller.updateCamera(
      NCameraUpdate.fitBounds(
        NLatLngBounds(southWest: sw, northEast: ne),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  Future<void> _moveToCurrentLocation(NaverMapController controller) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
          zoom: 15,
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onStartTap() {
    // 경로는 "추천 경로" 탭에서 미리 확인 가능 → 바로 출발
    ref.read(homeProvider.notifier).startRoute();
  }

  @override
  Widget build(BuildContext context) {
    final routine = widget.home.activeRoutine!;
    final isImminent = widget.home.isDepartureImminent;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onStartTap,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
        label: const Text(
          '시작',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      body: Stack(
        children: [
          NaverMap(
            key: const ValueKey('preactive_map'),
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.5665, 126.9780),
                zoom: 14,
              ),
              mapType: NMapType.basic,
              activeLayerGroups: [NLayerGroup.transit],
            ),
            onMapReady: (controller) {
              _mapController = controller;
              if (widget.home.routeCoordinates.isNotEmpty) {
                _drawRouteOnMap(controller, widget.home.routeCoordinates);
              } else {
                _moveToCurrentLocation(controller);
              }
            },
          ),
          // 줌 컨트롤 버튼
          Positioned(
            right: 12,
            bottom: 220,
            child: Column(
              children: [
                _MapZoomButton(
                  icon: Icons.add,
                  onTap: () async {
                    if (_mapController == null) return;
                    final zoom = await _mapController!.getCameraPosition();
                    await _mapController!.updateCamera(NCameraUpdate.zoomIn());
                  },
                ),
                const SizedBox(height: 6),
                _MapZoomButton(
                  icon: Icons.remove,
                  onTap: () async {
                    if (_mapController == null) return;
                    final zoom = await _mapController!.getCameraPosition();
                    await _mapController!.updateCamera(NCameraUpdate.zoomOut());
                  },
                ),
                const SizedBox(height: 6),
                _MapZoomButton(
                  icon: Icons.my_location,
                  onTap: () {
                    if (_mapController != null) {
                      _moveToCurrentLocation(_mapController!);
                    }
                  },
                ),
              ],
            ),
          ),
          // 줌 컨트롤 버튼
          Positioned(
            right: 12,
            bottom: 220,
            child: Column(
              children: [
                _MapZoomButton(
                  icon: Icons.add,
                  onTap: () async {
                    if (_mapController == null) return;
                    final zoom = await _mapController!.getCameraPosition();
                    await _mapController!.updateCamera(NCameraUpdate.zoomIn());
                  },
                ),
                const SizedBox(height: 6),
                _MapZoomButton(
                  icon: Icons.remove,
                  onTap: () async {
                    if (_mapController == null) return;
                    final zoom = await _mapController!.getCameraPosition();
                    await _mapController!.updateCamera(NCameraUpdate.zoomOut());
                  },
                ),
                const SizedBox(height: 6),
                _MapZoomButton(
                  icon: Icons.my_location,
                  onTap: () {
                    if (_mapController != null) {
                      _moveToCurrentLocation(_mapController!);
                    }
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${routine.routineName}: ${routine.departureAddressName} → ${routine.arrivalAddressName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _DragHandle(),
                  _PanelTabBar(controller: _tabController),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        SingleChildScrollView(
                          controller: scrollController,
                          child: _PreActivePanel(
                            routine: routine,
                            isImminent: isImminent,
                            aiSummary: ref
                                .watch(briefingProvider)
                                .aiSummary
                                ?.summary,
                            myRoute: widget.home.myRoute,
                          ),
                        ),
                        SingleChildScrollView(
                          controller: scrollController,
                          child: _RecommendedPanel(
                            route: widget.home.recommendedRoute,
                            hasIncident: false,
                            onKeep: () => _tabController.animateTo(0),
                            onSwitch: () {
                              ref
                                  .read(homeProvider.notifier)
                                  .switchToRecommendedRoute();
                              _tabController.animateTo(0);
                            },
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
      ),
    );
  }
}

// ───────────────────────────────────────────────
// 2-C: 경로 진행 중
// ───────────────────────────────────────────────
class _ActiveView extends ConsumerStatefulWidget {
  final HomeState home;
  final void Function(RoutineModel? routine) onStopTap;
  const _ActiveView({required this.home, required this.onStopTap});

  @override
  ConsumerState<_ActiveView> createState() => _ActiveViewState();
}

class _ActiveViewState extends ConsumerState<_ActiveView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  NaverMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didUpdateWidget(_ActiveView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 좌표가 바뀌면 지도 폴리라인 다시 그리기
    if (_mapController != null &&
        widget.home.routeCoordinates != oldWidget.home.routeCoordinates) {
      _drawRouteOnMap(_mapController!, widget.home.routeCoordinates);
    }
  }

  Future<void> _moveToCurrentLocation(NaverMapController controller) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
          zoom: 15,
        ),
      );
    } catch (_) {}
  }

  /// RouteXYModel 목록을 지도에 폴리라인으로 그립니다.
  /// - walk 구간: x/y가 null → 앞뒤 유효 좌표를 직선으로 연결
  /// - bus/subway 구간: 정류장 순서대로 연결
  Future<void> _drawRouteOnMap(
    NaverMapController controller,
    List<RouteXYModel> coords,
  ) async {
    if (coords.isEmpty) return;

    await controller.clearOverlays();

    // 유효 좌표만 추출 (null 좌표 건너뜀)
    final validCoords = coords.where((c) => c.hasCoord).toList();
    if (validCoords.isEmpty) return;

    // 전체 경로를 하나의 NLatLng 목록으로 만든 뒤 type별로 색상 분할
    // → walk 구간은 앞뒤 정류장 사이를 직선으로 이어붙임
    // → 연속된 좌표 목록을 type별 세그먼트로 그룹핑
    final allPoints = <({NLatLng pt, String type})>[];
    for (var i = 0; i < coords.length; i++) {
      final c = coords[i];
      if (c.hasCoord) {
        allPoints.add((pt: NLatLng(c.y!, c.x!), type: c.type ?? 'walk'));
      } else if (c.type == 'walk') {
        // walk이고 좌표 없음 → 앞뒤 유효점 사이 중간점 추가 (자연스러운 연결)
        // 앞 유효 좌표
        NLatLng? prev;
        for (var j = i - 1; j >= 0; j--) {
          if (coords[j].hasCoord) {
            prev = NLatLng(coords[j].y!, coords[j].x!);
            break;
          }
        }
        // 뒤 유효 좌표
        NLatLng? next;
        for (var j = i + 1; j < coords.length; j++) {
          if (coords[j].hasCoord) {
            next = NLatLng(coords[j].y!, coords[j].x!);
            break;
          }
        }
        // prev → next 직선 연결을 위해 양쪽 끝점만 추가 (중복 없이)
        if (prev != null && allPoints.isEmpty) {
          allPoints.add((pt: prev, type: 'walk'));
        }
        if (next != null) {
          allPoints.add((pt: next, type: 'walk'));
        }
      }
    }

    if (allPoints.length < 2) return;

    // type별 연속 세그먼트 그룹핑
    final segments = <({String type, List<NLatLng> points})>[];
    String currentType = allPoints.first.type;
    List<NLatLng> currentPoints = [allPoints.first.pt];

    for (var i = 1; i < allPoints.length; i++) {
      final item = allPoints[i];
      if (item.type != currentType) {
        if (currentPoints.length >= 2) {
          segments.add((type: currentType, points: List.of(currentPoints)));
        }
        // 경계 연결: 이전 마지막 점을 새 세그먼트 첫 점으로
        currentType = item.type;
        currentPoints = [currentPoints.last, item.pt];
      } else {
        currentPoints.add(item.pt);
      }
    }
    if (currentPoints.length >= 2) {
      segments.add((type: currentType, points: List.of(currentPoints)));
    }

    Color typeColor(String type) {
      switch (type) {
        case 'subway':
          return Colors.blue;
        case 'bus':
          return const Color(0xFF22C55E); // 초록
        default:
          return const Color(0xFF9CA3AF); // 도보: 회색 점선 느낌
      }
    }

    double typeWidth(String type) => type == 'walk' ? 3.0 : 6.0;

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.points.length < 2) continue;
      await controller.addOverlay(
        NPolylineOverlay(
          id: 'seg_$i',
          coords: seg.points,
          color: typeColor(seg.type),
          width: typeWidth(seg.type),
        ),
      );
    }

    // 현재 위치 마커 — idx 기준으로 유효 좌표 찾기
    final curIdx = widget.home.currentStepIndex;
    RouteXYModel? curPoint;
    // idx 근처에서 유효 좌표 탐색
    for (var offset = 0; offset < coords.length; offset++) {
      final fwd = curIdx + offset;
      final bwd = curIdx - offset;
      if (fwd < coords.length && coords[fwd].hasCoord) {
        curPoint = coords[fwd];
        break;
      }
      if (bwd >= 0 && coords[bwd].hasCoord) {
        curPoint = coords[bwd];
        break;
      }
    }
    if (curPoint != null) {
      await controller.addOverlay(
        NMarker(id: 'current_pos', position: NLatLng(curPoint.y!, curPoint.x!)),
      );
      // 현재 위치로 카메라 이동
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(curPoint.y!, curPoint.x!),
          zoom: 15,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routine = widget.home.activeRoutine!;
    final route = widget.home.myRoute;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          NaverMap(
            key: const ValueKey('active_map'),
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.5665, 126.9780),
                zoom: 14,
              ),
              mapType: NMapType.basic,
              activeLayerGroups: [NLayerGroup.transit],
            ),
            onMapReady: (controller) {
              _mapController = controller;
              _moveToCurrentLocation(controller);
              // 좌표가 이미 있으면 바로 경로 그리기
              if (widget.home.routeCoordinates.isNotEmpty) {
                _drawRouteOnMap(controller, widget.home.routeCoordinates);
              }
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${routine.routineName}: ${routine.departureAddressName} → ${routine.arrivalAddressName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _DragHandle(),
                  _PanelTabBar(controller: _tabController),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        SingleChildScrollView(
                          controller: scrollController,
                          child: _ActivePanel(
                            routine: routine,
                            route: route,
                            currentStepIndex: widget.home.currentStepIndex,
                            liveStatusText:
                                widget.home.liveStatus?.status ?? '도보 중',
                            stepRemainingMinutes:
                                widget.home.stepRemainingMinutes,
                            onStop: () =>
                                widget.onStopTap(widget.home.activeRoutine),
                          ),
                        ),
                        SingleChildScrollView(
                          controller: scrollController,
                          child: _RecommendedPanel(
                            route: widget.home.recommendedRoute,
                            hasIncident: false,
                            onKeep: () => _tabController.animateTo(0),
                            onSwitch: () {
                              ref
                                  .read(homeProvider.notifier)
                                  .switchToRecommendedRoute();
                              _tabController.animateTo(0);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('추천 경로로 변경되었어요.')),
                              );
                            },
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
      ),
    );
  }
}

// ───────────────────────────────────────────────
// 공통 패널 위젯
// ───────────────────────────────────────────────
class _PanelCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _PanelCard({required this.child, this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _PanelTabBar extends StatelessWidget {
  final TabController controller;
  const _PanelTabBar({required this.controller});

  @override
  Widget build(BuildContext context) => TabBar(
    controller: controller,
    indicatorColor: AppColors.primary,
    labelColor: AppColors.primary,
    unselectedLabelColor: AppColors.textSecondary,
    labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    tabs: const [
      Tab(text: '나의 경로'),
      Tab(text: '추천 경로'),
    ],
  );
}

class _PreActivePanel extends StatefulWidget {
  final RoutineModel routine;
  final bool isImminent;
  final String? aiSummary;
  final LiveRouteModel? myRoute;

  const _PreActivePanel({
    required this.routine,
    required this.isImminent,
    this.aiSummary,
    this.myRoute,
  });

  @override
  State<_PreActivePanel> createState() => _PreActivePanelState();
}

class _PreActivePanelState extends State<_PreActivePanel> {
  bool _showDetail = false;

  @override
  Widget build(BuildContext context) {
    final paths = widget.myRoute?.path ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI 브리핑',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.aiSummary ?? 'AI 브리핑을 불러오는 중...',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: widget.aiSummary == null
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _PanelCard(
            color: widget.isImminent
                ? AppColors.amber.withValues(alpha: 0.3)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.isImminent
                          ? Icons.directions_run
                          : Icons.access_time,
                      size: 15,
                      color: widget.isImminent
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isImminent ? '곧 출발하세요!' : '출발 예정',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.isImminent
                            ? AppColors.warning
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.routine.recommendedDepartureTime,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '출발  →  ${widget.routine.targetArrivalTime} 도착',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F0FC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '약 ${widget.routine.estimatedDuration}분 소요',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1155CC),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _PanelCard(
            child: Column(
              children: [
                _RouteTransitRow(paths: paths),
                if (paths.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _showDetail = !_showDetail),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _showDetail ? '경로 상세 접기' : '경로 상세 보기',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showDetail
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  if (_showDetail) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ...paths.asMap().entries.map(
                      (e) => _PathItem(
                        path: e.value,
                        isCurrent: false,
                        isLast: e.key == paths.length - 1,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivePanel extends StatelessWidget {
  final RoutineModel routine;
  final LiveRouteModel? route;
  final int currentStepIndex;
  final String liveStatusText;
  final int stepRemainingMinutes;
  final VoidCallback onStop;

  const _ActivePanel({
    required this.routine,
    required this.route,
    required this.currentStepIndex,
    required this.liveStatusText,
    required this.stepRemainingMinutes,
    required this.onStop,
  });

  static IconData _statusIcon(String status) {
    if (status.contains('버스')) return Icons.directions_bus_outlined;
    if (status.contains('지하철')) return Icons.subway_outlined;
    if (status.contains('환승')) return Icons.transfer_within_a_station;
    if (status == '도착') return Icons.flag_outlined;
    return Icons.directions_walk;
  }

  static Color _statusColor(String status) {
    if (status.contains('버스')) return Colors.orange;
    if (status.contains('지하철')) return Colors.blue;
    if (status.contains('환승')) return AppColors.secondary;
    if (status == '도착') return AppColors.success;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final paths = route?.path ?? [];
    final statusColor = _statusColor(liveStatusText);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _statusIcon(liveStatusText),
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      liveStatusText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (stepRemainingMinutes > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '이 구간 $stepRemainingMinutes분 남음',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _RoutineStepDots(paths: paths, currentStep: currentStepIndex),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                '예상 도착 ',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              Text(
                routine.targetArrivalTime,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              if (route != null)
                Text(
                  '  약 ${route!.totalTime}분 소요',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              const Spacer(),
              OutlinedButton(
                onPressed: onStop,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('■ 종료'),
              ),
            ],
          ),
          if (paths.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ...paths.asMap().entries.map(
              (entry) => _PathItem(
                path: entry.value,
                isCurrent: entry.key == currentStepIndex,
                isLast: entry.key == paths.length - 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────
// 추천 경로 패널
// ───────────────────────────────────────────────
class _RecommendedPanel extends StatelessWidget {
  final LiveRouteModel? route;
  final bool hasIncident;
  final VoidCallback onKeep;
  final VoidCallback onSwitch;

  const _RecommendedPanel({
    required this.route,
    required this.hasIncident,
    required this.onKeep,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasIncident) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ 현재 경로 돌발 상황 감지',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '2호선 신호 장애 · 교체 경로 제안',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.secondary, size: 16),
                SizedBox(width: 6),
                Text(
                  'AI 우회 경로',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'FastAPI 분석 완료',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '현재 경로 정상',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'AI가 추천하는 최적 경로',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasIncident ? AppColors.secondary : AppColors.border,
                width: hasIncident ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                route != null
                    ? Text(
                        '${route!.totalTime}분',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: hasIncident
                              ? AppColors.secondary
                              : AppColors.primary,
                        ),
                      )
                    : const Text(
                        '분석 중...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                const SizedBox(height: 8),
                // 실제 API 데이터로 경로 칩 표시
                Builder(
                  builder: (context) {
                    final r = route;
                    if (r == null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: AppColors.border,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                '추천 경로를 분석 중이에요',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '잠시 후 최적 경로가 제안됩니다',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.border,
                            ),
                          ),
                        ],
                      );
                    }
                    if (r.path.isNotEmpty) {
                      return Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: r.path.map((p) {
                          if (p.isWalking) {
                            return _RouteChip(
                              label: '🚶',
                              color: AppColors.textSecondary,
                            );
                          } else if (p.isSubway) {
                            return _RouteChip(
                              label: p.subwayLineName,
                              color: Colors.blue,
                            );
                          } else {
                            return _RouteChip(
                              label: p.no.isNotEmpty ? '${p.no.first}번' : '버스',
                              color: Colors.orange,
                            );
                          }
                        }).toList(),
                      );
                    }
                    return Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: AppColors.border,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '경로를 불러오는 중이에요',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final r = route;
                    if (r == null) return const SizedBox.shrink();
                    return Text(
                      '예상 요금 ${_formatPayment(r.payment)}원',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    );
                  },
                ),
                if (hasIncident) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '+6분 (돌발 우회)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                // 구간 상세도 표시
                Builder(
                  builder: (context) {
                    final r = route;
                    if (r != null && r.path.isNotEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          ...r.path.asMap().entries.map(
                            (e) => _PathItem(
                              path: e.value,
                              isCurrent: false,
                              isLast: e.key == r.path.length - 1,
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (hasIncident) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSwitch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                ),
                child: const Text(
                  '우회 경로로 변경',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onKeep,
                child: const Text('기존 경로 유지'),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onKeep,
                    child: const Text('현재 경로 유지'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSwitch,
                    child: const Text('이 경로로 변경'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _formatPayment(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class _RouteChip extends StatelessWidget {
  final String label;
  final Color color;
  const _RouteChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

class _RouteTransitRow extends StatelessWidget {
  final List<PathModel> paths;
  const _RouteTransitRow({required this.paths});

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            const Text(
              '경로를 불러오는 중이에요',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '잠시 후 경로가 표시됩니다',
              style: TextStyle(fontSize: 12, color: AppColors.border),
            ),
          ],
        ),
      );
    }

    final chips = <Widget>[];
    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      if (path.isWalking) {
        chips.add(
          const Icon(
            Icons.directions_walk,
            size: 18,
            color: AppColors.textSecondary,
          ),
        );
      } else if (path.isSubway) {
        chips.add(
          _RouteChip(
            label: path.subwayLineName,
            color: Colors.blue,
          ),
        );
      } else {
        chips.add(
          _RouteChip(
            label: '${path.no.isNotEmpty ? path.no.first : ''}번',
            color: Colors.orange,
          ),
        );
      }
      if (i < paths.length - 1) {
        chips.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward, size: 12, color: AppColors.border),
          ),
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }
}

// ───────────────────────────────────────────────
// 경로 선택 바텀시트
// ───────────────────────────────────────────────
void _showRouteSelectionSheet(
  BuildContext context,
  String arrivalTime,
  VoidCallback onConfirm,
) {
  int selectedIndex = 0;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '경로를 선택해주세요',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '선택하지 않으면 기존 경로로 자동 진행됩니다',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '⏱ 15초 후 자동 선택',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _RouteOptionCard(
                    label: '추천',
                    labelColor: AppColors.primary,
                    route: '2호선 → 도보 5분',
                    minutes: 32,
                    fare: '1,400원',
                    arrivalTime: arrivalTime,
                    isSelected: selectedIndex == 0,
                    onTap: () => setSheetState(() => selectedIndex = 0),
                  ),
                  const SizedBox(height: 10),
                  _RouteOptionCard(
                    label: '현재 경로',
                    labelColor: AppColors.textSecondary,
                    route: '신분당선 → 버스',
                    minutes: 38,
                    fare: '1,600원',
                    arrivalTime: arrivalTime,
                    isSelected: selectedIndex == 1,
                    onTap: () => setSheetState(() => selectedIndex = 1),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).viewPadding.bottom +
                    16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onConfirm();
                  },
                  child: const Text('이 경로로 이동'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _calcDeparture(String arrivalTime, int minutes) {
  final parts = arrivalTime.split(':');
  final total = int.parse(parts[0]) * 60 + int.parse(parts[1]) - minutes;
  return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
}

class _RouteOptionCard extends StatelessWidget {
  final String label;
  final Color labelColor;
  final String route;
  final int minutes;
  final String fare;
  final String? arrivalTime;
  final bool isSelected;
  final VoidCallback onTap;

  const _RouteOptionCard({
    required this.label,
    required this.labelColor,
    required this.route,
    required this.minutes,
    required this.fare,
    this.arrivalTime,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final departureTime = arrivalTime != null
        ? _calcDeparture(arrivalTime!, minutes)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: labelColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              route,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '$minutes분',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  fare,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (departureTime != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        departureTime,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const Text(
                        '출발',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              color: AppColors.border,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward,
                            size: 12,
                            color: AppColors.border,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        arrivalTime!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Text(
                        '목표 도착',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────
// 루틴 종료 후 피드백 모달
// ───────────────────────────────────────────────
void _showFeedbackModal(
  BuildContext context,
  RoutineModel? routine,
  DateTime departureTime,
  DateTime arrivalTime,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _FeedbackSheet(
      routine: routine,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
    ),
  );
}

class _FeedbackSheet extends ConsumerStatefulWidget {
  final RoutineModel? routine;
  final DateTime departureTime;
  final DateTime arrivalTime;
  const _FeedbackSheet({
    this.routine,
    required this.departureTime,
    required this.arrivalTime,
  });

  @override
  ConsumerState<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<_FeedbackSheet> {
  final List<int> _ratings = [0, 0, 0];
  static const _questions = [
    '대기 시간이 예상과 맞았나요?',
    '예상 소요 시간이 정확했나요?',
    '경로가 만족스러웠나요?',
  ];

  @override
  Widget build(BuildContext context) {
    final routeName = widget.routine != null
        ? '${widget.routine!.routineName}: ${widget.routine!.departureAddressName} → ${widget.routine!.arrivalAddressName}'
        : '루틴';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '오늘 이동은 어떠셨나요?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            routeName,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ...List.generate(
            _questions.length,
            (i) => _StarRatingRow(
              question: _questions[i],
              rating: _ratings[i],
              onRate: (r) => setState(() => _ratings[i] = r),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await ref.read(homeProvider.notifier).completeRoutine(
                  departureTime: widget.departureTime,
                  arrivalTime: widget.arrivalTime,
                  satWaitTimeScore: _ratings[0],
                  satEtaScore: _ratings[1],
                  satRouteScore: _ratings[2],
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('제출하기'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await ref.read(homeProvider.notifier).completeRoutine(
                departureTime: widget.departureTime,
                arrivalTime: widget.arrivalTime,
              );
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('건너뛰기'),
          ),
        ],
      ),
    );
  }
}

class _StarRatingRow extends StatelessWidget {
  final String question;
  final int rating;
  final ValueChanged<int> onRate;

  const _StarRatingRow({
    required this.question,
    required this.rating,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(
            5,
            (i) => GestureDetector(
              onTap: () => onRate(i + 1),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: i < rating ? AppColors.primary : AppColors.border,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ───────────────────────────────────────────────
// 공통 위젯: 스텝 도트
// ───────────────────────────────────────────────
class _RoutineStepDots extends StatelessWidget {
  final List<PathModel> paths;
  final int currentStep;
  const _RoutineStepDots({required this.paths, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final labels =
        paths.isEmpty
              ? ['도보', '지하철', '환승', '버스', '도착']
              : paths.map((p) => p.typeLabel).toList()
          ..add('도착');

    return Row(
      children: labels.asMap().entries.map((entry) {
        final i = entry.key;
        final label = entry.value;
        final isDone = i < currentStep;
        final isCurrent = i == currentStep;
        final isLast = i == labels.length - 1;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone || isCurrent
                            ? AppColors.primary
                            : Colors.transparent,
                        border: isDone || isCurrent
                            ? null
                            : Border.all(color: AppColors.border, width: 2),
                      ),
                      child: isDone
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : isCurrent
                          ? const Icon(
                              Icons.circle,
                              size: 8,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: isCurrent
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: isCurrent
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isDone ? AppColors.primary : AppColors.border,
                    margin: const EdgeInsets.only(bottom: 18),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ───────────────────────────────────────────────
// 공통 위젯: 경로 단계 항목
// ───────────────────────────────────────────────
class _PathItem extends StatefulWidget {
  final PathModel path;
  final bool isCurrent;
  final bool isLast;

  const _PathItem({
    required this.path,
    required this.isCurrent,
    this.isLast = false,
  });

  @override
  State<_PathItem> createState() => _PathItemState();
}

class _PathItemState extends State<_PathItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    final isCurrent = widget.isCurrent;
    final isLast = widget.isLast;

    final icon = path.isWalking
        ? Icons.directions_walk
        : path.isSubway
        ? Icons.subway_outlined
        : Icons.directions_bus_outlined;
    final color = path.isWalking
        ? AppColors.textSecondary
        : path.isSubway
        ? Colors.blue
        : Colors.green;
    final lineColor = path.isWalking
        ? AppColors.border
        : path.isSubway
        ? Colors.blue.withValues(alpha: 0.4)
        : Colors.green.withValues(alpha: 0.4);

    return Container(
      decoration: isCurrent
          ? BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            )
          : null,
      padding: isCurrent
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
          : EdgeInsets.zero,
      margin: isCurrent
          ? const EdgeInsets.symmetric(vertical: 2)
          : EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent ? color : color.withValues(alpha: 0.12),
                    border: isCurrent
                        ? Border.all(color: color, width: 2)
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isCurrent ? Colors.white : color,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 36,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: path.isWalking
                        ? BoxDecoration(
                            color: Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                color: lineColor,
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                            ),
                          )
                        : BoxDecoration(color: lineColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 현재 구간 배지
                  if (isCurrent) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '현재 구간',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  // 출발/도착 정류장
                  Text(
                    (path.start != null && path.end != null)
                        ? '${path.start} → ${path.end}'
                        : path.typeLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? color : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 노선 번호 칩
                  if (!path.isWalking && path.no.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 2, bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        path.isSubway
                            ? '${path.subwayLineName}${path.way != null ? " (${path.way})" : ""}'
                            : '${path.no.first}번',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  Text(
                    '${path.sectionTime}분'
                    '${path.stationName.isNotEmpty
                        ? ' · ${path.displayStationCount}정거장'
                        : path.stationCount != null
                        ? ' · ${path.stationCount}정거장'
                        : ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  // 정거장 상세 펼치기 (버스/지하철만)
                  if (!path.isWalking && path.stationName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Row(
                        children: [
                          Text(
                            _expanded
                                ? '정류장 접기'
                                : '정류장 ${path.stationName.length}개 보기',
                            style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 14,
                            color: color,
                          ),
                        ],
                      ),
                    ),
                    if (_expanded) ...[
                      const SizedBox(height: 6),
                      ...path.stationName.map(
                        (station) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                station,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────
// 지도 줌 컨트롤 버튼
// ───────────────────────────────────────────────
class _MapZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}