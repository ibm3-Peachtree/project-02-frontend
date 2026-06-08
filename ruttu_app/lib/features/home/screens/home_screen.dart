import 'dart:async';
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
import '../../auth/providers/auth_state.dart';
import '../../auth/screens/onboarding_screen.dart';
import '../../briefing/providers/briefing_provider.dart';
// ✅ 버그 수정: live_location_provider import 제거 → homeProvider 충돌 해소
//   live_location_provider 는 home_provider.dart 에서만 import
import '../providers/home_provider.dart';
import '../providers/home_state.dart';
import '../providers/live_location_provider.dart'
    show liveLocationProvider; // ✅ liveLocationProvider만 선택 import
import '../providers/live_route_provider.dart' show liveStatusProvider;
import '../../../data/services/stomp_service.dart';
import '../../routine/providers/routine_provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../../../core/widgets/live_route_tabs.dart';
import '../providers/live_route_provider.dart' show incidentDetourProvider, recoRouteProvider, myRouteProvider;
import 'mock_briefing_screen.dart';
import 'mock_community_screen.dart';
import 'mock_report_screen.dart';
import 'mock_routine_screen.dart';

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
      // STOMP 연결 — 구독 등록보다 먼저 연결되어야 incident/detour 수신 가능
      StompService.instance.connect();
      // incidentDetourProvider를 앱 시작 시점에 미리 생성:
      // 탭을 누르기 전에도 STOMP /user/queue/incident·detour 구독이 시작되도록 보장.
      // (탭 진입 시 처음 read하면 /reco GET 응답 이후 push가 이미 도착해도 놓칠 수 있음)
      ref.read(incidentDetourProvider);
      // recoRouteProvider도 미리 생성 — incidentDetourProvider listener 등록 보장
      ref.read(recoRouteProvider);
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
    final status = ref.watch(homeProvider.select((s) => s.status));
    final isLoading = ref.watch(homeProvider.select((s) => s.isLoading));
    final authStatus = ref.watch(authProvider).status;

    // 최초 가입 온보딩: 홈 위에 슬라이드 오버레이
    if (authStatus == AuthStatus.needsOnboarding) {
      return const _HomeOnboardingOverlay();
    }

    if (isLoading && status == HomeStatus.noRoutine) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // noRoutine / noTodayRoutine은 별도 처리
    if (status == HomeStatus.noRoutine) return _NoRoutineView();
    if (status == HomeStatus.noTodayRoutine) return _NoTodayRoutineView();

    // preActive / active: Offstage로 동시에 트리에 유지 → State가 절대 destroy되지 않아
    // 탭 위치, 지도 컨트롤러 등 모든 상태가 보존됨.
    final isActive = status == HomeStatus.active;
    return Stack(
      children: [
        Offstage(
          offstage: isActive,
          child: _PreActiveView(),
        ),
        Offstage(
          offstage: !isActive,
          child: _ActiveView(onStopTap: _onStopTap),
        ),
      ],
    );
  }
}

// ── 최초 가입 온보딩 오버레이 (홈 화면에서 보여주는 슬라이드) ──────
class _HomeOnboardingOverlay extends ConsumerStatefulWidget {
  const _HomeOnboardingOverlay();

  @override
  ConsumerState<_HomeOnboardingOverlay> createState() =>
      _HomeOnboardingOverlayState();
}

class _HomeOnboardingOverlayState
    extends ConsumerState<_HomeOnboardingOverlay> {
  final _controller = PageController();
  int _currentPage = 0;
  static const _totalPages = 4;

  void _next() {
    if (_currentPage < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    ref.read(authProvider.notifier).completeOnboarding();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _totalPages - 1;

    return PopScope(
      // 첫 페이지면 뒤로 가기 막음, 아니면 이전 페이지로
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentPage > 0) {
          _controller.previousPage(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text(
                  '건너뛰기',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: const [
                  OnbPage1(),
                  OnbPage2(),
                  OnbPage3(),
                  OnbPage4(),
                ],
              ),
            ),
            // 페이지 인디케이터
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _totalPages,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppColors.primary
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    isLast ? '시작하기' : '다음',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ), // Scaffold
    ); // PopScope
  }
}

// ───────────────────────────────────────────────
// 2-A: 루틴 없음
// ───────────────────────────────────────────────
// ───────────────────────────────────────────────
// 2-A-1: 오늘 루틴 없음 (루틴은 있지만 오늘 요일 해당 없음)
// ───────────────────────────────────────────────
class _NoTodayRoutineView extends ConsumerWidget {
  const _NoTodayRoutineView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(homeProvider.select((s) => s.weather));
    final user = ref.watch(authProvider).user;
    final nickname = user?.nickname ?? '루뚜';
    final today = _todayKo();
    // 공휴일 제외 루틴이 있는지 확인 (오늘 요일에 해당하는 루틴이 skipHoliday로 인해 제외됐는지)
    final routineListAsync = ref.watch(routineListProvider);
    final routines = routineListAsync.valueOrNull ?? [];
    final todayKey = _todayKeyFromKo(today);
    final isHolidaySkip = routines.any(
      (r) => r.isActive && r.days.contains(todayKey) && r.skipHoliday,
    );

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
                                      isHolidaySkip
                                          ? '오늘은 공휴일이에요 🎉'
                                          : '오늘($today)은 루틴이 없어요',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      isHolidaySkip
                                          ? '공휴일 제외 설정으로 오늘은 쉬어가세요'
                                          : '$today요일 루틴을 등록하시겠어요?',
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

String _todayKeyFromKo(String ko) {
  const map = {'월': 'MON', '화': 'TUE', '수': 'WED', '목': 'THU', '금': 'FRI', '토': 'SAT', '일': 'SUN'};
  return map[ko] ?? 'MON';
}

// ───────────────────────────────────────────────
// 2-A-2: 루틴 없음 (아예 등록 안 함)
// ───────────────────────────────────────────────
class _NoRoutineView extends ConsumerWidget {
  const _NoRoutineView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(homeProvider.select((s) => s.weather));
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

    // 하늘 상태 텍스트 변환
    String skyText = '맑음';
    final cur = w?.current;
    if (cur != null) {
      if (cur.pty == '1') skyText = '비';
      else if (cur.pty == '3') skyText = '눈';
      else {
        switch (cur.sky) {
          case '1': skyText = '맑음'; break;
          case '3': skyText = '구름많음'; break;
          case '4': skyText = '흐림'; break;
          default: skyText = '맑음';
        }
      }
    }

    // 요일 표시
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final dayLabel = weekdays[DateTime.now().weekday - 1];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFFFA8B5A)],
        ),
        borderRadius: BorderRadius.zero,
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 왼쪽: 인사 + 닉네임
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '안녕하세요',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$nickname님',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // 오른쪽: 날씨 텍스트 (이미지 없음)
          if (w != null)
            Text(
              '$dayLabel · $skyText${tmp != null ? ' $tmp°' : ''}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
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
                colors: [AppColors.primary, Color(0xFFFA8B5A)],
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
          // ── 메뉴 설명 ──────────────────────────────────
          const Text(
            '메뉴 설명',
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
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MockRoutineScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickMenuCard(
                  icon: Icons.wb_sunny_outlined,
                  label: 'AI 브리핑',
                  color: AppColors.secondary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MockBriefingScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickMenuCard(
                  icon: Icons.people_outline_rounded,
                  label: '커뮤니티',
                  color: const Color(0xFF6366F1),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MockCommunityScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickMenuCard(
                  icon: Icons.bar_chart_rounded,
                  label: '리포트',
                  color: const Color(0xFF0D7A6B),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MockReportScreen()),
                  ),
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
  const _PreActiveView();

  @override
  ConsumerState<_PreActiveView> createState() => _PreActiveViewState();
}

class _PreActiveViewState extends ConsumerState<_PreActiveView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  NaverMapController? _mapController;

  /// routeCoordinates 중 첫 번째 유효 좌표를 초기 카메라 위치로 반환.
  /// 유효 좌표가 없으면 null 반환 → null이면 현재 위치로 이동.
  NCameraPosition? _initialCameraPosition() {
    final coords = ref.read(homeProvider).routeCoordinates;
    for (final c in coords) {
      if (c.hasCoord) {
        return NCameraPosition(target: NLatLng(c.y!, c.x!), zoom: 14);
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ✅ [버그 수정] homeProvider.myRoute는 RoutineModel.route에서 변환한
      // 로컬 값이므로 API에서 실제 경로 데이터를 한 번 명시적으로 로드한다.
      // (getMyRoute(routineId) → myRouteProvider.route 갱신)
      final routineId = ref.read(homeProvider).activeRoutine?.routineId;
      if (routineId != null) {
        ref.read(myRouteProvider.notifier).loadMyRoute(routineId);
      }

      final briefing = ref.read(briefingProvider);
      if (briefing.weather == null && !briefing.isLoading) {
        ref.read(briefingProvider.notifier).load();
      }
    });
  }

  @override
  void didUpdateWidget(_PreActiveView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // home prop이 제거됐으므로 routeCoordinates 변화를 직접 감지할 수 없음.
    // _drawRouteOnMap은 onMapReady + GPS 갱신 시 호출되므로 여기서는 생략.
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
          return AppColors.subway;
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
    final home = ref.watch(homeProvider);
    final routine = home.activeRoutine!;
    final isImminent = home.isDepartureImminent;
    final isOverdue = home.isDepartureOverdue;
    final minutesOverdue = home.minutesOverdue;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final isRecoTab = _tabController.index == 1;
          final isUsingReco = ref.watch(
            homeProvider.select((s) => s.isUsingRecoRoute),
          );
          // 추천 경로 탭: 항상 FAB 숨김 (선택 전이든 안내 중이든)
          if (isRecoTab) return const SizedBox.shrink();
          // 추천 경로로 전환 후 안내 중: 나의 경로 탭에서도 FAB 숨김
          if (isUsingReco) return const SizedBox.shrink();
          return FloatingActionButton.extended(
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
          );
        },
      ),
      body: Stack(
        children: [
          NaverMap(
            key: const ValueKey('preactive_map'),
            options: NaverMapViewOptions(
              initialCameraPosition: _initialCameraPosition() ??
                  const NCameraPosition(
                    target: NLatLng(37.5665, 126.9780), // 좌표 없을 때 fallback
                    zoom: 14,
                  ),
              mapType: NMapType.basic,
              activeLayerGroups: const [NLayerGroup.transit],
            ),
            onMapReady: (controller) {
              _mapController = controller;
              // 탭에 무관하게 나의 경로 좌표 표시 (preActive 지도는 항상 나의 경로)
              if (home.routeCoordinates.isNotEmpty) {
                _drawRouteOnMap(controller, home.routeCoordinates);
              } else {
                _moveToCurrentLocation(controller);
              }
            },
          ),
          // 줌 컨트롤 버튼
          Builder(
            builder: (context) {
              final screenH = MediaQuery.of(context).size.height;
              final minPanelH = screenH * 0.35 + 16;
              return Positioned(
                right: 12,
                bottom: minPanelH,
                child: Column(
                  children: [
                    _MapZoomButton(
                      icon: Icons.add,
                      onTap: () async {
                        if (_mapController == null) return;
                        await _mapController!.updateCamera(NCameraUpdate.zoomIn());
                      },
                    ),
                    const SizedBox(height: 6),
                    _MapZoomButton(
                      icon: Icons.remove,
                      onTap: () async {
                        if (_mapController == null) return;
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
              );
            },
          ),
          // ── 줌 컨트롤 버튼 (active 지도) ──────────────────────────────
          Builder(
            builder: (context) {
              final screenH = MediaQuery.of(context).size.height;
              final minPanelH = screenH * 0.45 + 16;
              return Positioned(
                right: 12,
                bottom: minPanelH,
                child: Column(
                  children: [
                    _MapZoomButton(
                      icon: Icons.add,
                      onTap: () async {
                        if (_mapController == null) return;
                        await _mapController!.updateCamera(NCameraUpdate.zoomIn());
                      },
                    ),
                    const SizedBox(height: 6),
                    _MapZoomButton(
                      icon: Icons.remove,
                      onTap: () async {
                        if (_mapController == null) return;
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
              );
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
                color: AppColors.background,
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
                            isOverdue: isOverdue,
                            minutesOverdue: minutesOverdue,
                            aiSummary: ref
                                .watch(briefingProvider)
                                .aiSummary
                                ?.summary,
                            myRoute: home.myRoute,
                          ),
                        ),
                        // ── 추천 경로 탭 ──────────────────────────────────
                        // RecoRouteTabContent: recoRouteProvider 기반으로
                        // 카드 목록 선택 → 실시간 구간 안내(이미지2)까지 모두 처리
                        RecoRouteTabContent(
                          scrollController: scrollController,
                          // "현재 경로 유지" 버튼: Navigator.pop() 대신 탭 전환
                          // (DraggableScrollableSheet 내 TabBarView에 있으므로 pop하면 홈이 사라짐)
                          onKeep: () => _tabController.animateTo(0),
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

class _ActiveView extends ConsumerStatefulWidget {
  final void Function(RoutineModel? routine) onStopTap;
  const _ActiveView({required this.onStopTap});

  @override
  ConsumerState<_ActiveView> createState() => _ActiveViewState();
}

class _ActiveViewState extends ConsumerState<_ActiveView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  NaverMapController? _mapController;
  StreamSubscription<Position>? _gpsSub;
  Position? _currentGpsPosition;
  bool _routeDrawn = false; // ✅ 경로 폴리라인이 그려졌는지 추적

  /// 활성 경로 좌표 중 현재 구간(idx) 이후 첫 번째 유효 좌표를 초기 카메라 위치로 반환.
  /// 없으면 null → 현재 위치로 이동.
  NCameraPosition? _initialCameraPosition() {
    final home = ref.read(homeProvider);
    final isReco = home.isUsingRecoRoute;
    final coords = isReco ? home.recoRouteCoordinates : home.routeCoordinates;
    final idx = ref.read(homeProvider).currentStepIndex;
    // 현재 구간부터 탐색, 없으면 전체에서 탐색
    final searchList = idx < coords.length ? coords.skip(idx) : coords;
    for (final c in searchList) {
      if (c.hasCoord) {
        return NCameraPosition(target: NLatLng(c.y!, c.x!), zoom: 15);
      }
    }
    for (final c in coords) {
      if (c.hasCoord) {
        return NCameraPosition(target: NLatLng(c.y!, c.x!), zoom: 15);
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // isUsingRecoRoute가 이미 true인 상태로 진입하면 탭 1로 시작
    final initialIndex = ref.read(homeProvider).isUsingRecoRoute ? 1 : 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialIndex);
    _startGpsStream();
  }

  void _startGpsStream() {
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // 5m 이상 이동할 때만 갱신
      ),
    ).listen((pos) {
      _currentGpsPosition = pos;
      // 지도가 준비된 상태면 마커만 갱신 (경로 폴리라인은 유지)
      if (_mapController != null) {
        _updateGpsMarkerOnly(_mapController!, pos);
      }
    }, onError: (_) {});
  }

  /// GPS 마커 + 카메라 갱신. 경로가 아직 안 그려진 경우 전체 경로도 그린다.
  Future<void> _updateGpsMarkerOnly(NaverMapController controller, Position pos) async {
    try {
      // 경로가 아직 안 그려진 경우 전체 재드로우 (GPS 이벤트가 onMapReady보다 늦을 수 있음)
      if (!_routeDrawn) {
        final home = ref.read(homeProvider);
        final activeCoords = home.isUsingRecoRoute
            ? home.recoRouteCoordinates
            : home.routeCoordinates;
        await _drawRouteOnMap(controller, activeCoords);
        return; // _drawRouteOnMap 내부에서 GPS 마커 + 카메라도 처리
      }

      // 경로는 이미 그려진 상태 → GPS 마커와 카메라만 갱신
      final target = NLatLng(pos.latitude, pos.longitude);
      final marker = NMarker(id: 'gps_pos', position: target);
      marker.setCaption(const NOverlayCaption(
        text: '현재 위치',
        textSize: 11,
        color: Color(0xFF1A73E8),
      ));
      await controller.addOverlay(marker);
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: target, zoom: 15),
      );
    } catch (_) {}
  }

  @override

  void didUpdateWidget(_ActiveView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // home prop이 제거됐으므로 Consumer + ref.listen으로 지도 갱신 처리.
    // build()에서 ref.watch를 통해 homeProvider 변화를 감지하면
    // NaverMapController가 있을 때 _drawRouteOnMap이 호출됨.
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
    await controller.clearOverlays();
    _routeDrawn = false;

    final section = ref.read(homeProvider).currentSectionData;
    // idx = 도착 예정 구간 인덱스 (현재 이동 중 구간 = idx - 1)
    final currentIdx = section != null ? (section.idx - 1).clamp(0, coords.length - 1) : -1;

    // ── 1. 좌표 포인트 수집 ─────────────────────────────────
    final allPoints = <({NLatLng pt, String type, int xyIdx})>[];
    for (var i = 0; i < coords.length; i++) {
      final c = coords[i];
      if (c.hasCoord) {
        allPoints.add((pt: NLatLng(c.y!, c.x!), type: c.type ?? 'walk', xyIdx: i));
      } else if (c.type == 'walk') {
        NLatLng? prev;
        for (var j = i - 1; j >= 0; j--) {
          if (coords[j].hasCoord) { prev = NLatLng(coords[j].y!, coords[j].x!); break; }
        }
        NLatLng? next;
        for (var j = i + 1; j < coords.length; j++) {
          if (coords[j].hasCoord) { next = NLatLng(coords[j].y!, coords[j].x!); break; }
        }
        if (prev != null && allPoints.isEmpty) allPoints.add((pt: prev, type: 'walk', xyIdx: i));
        if (next != null) allPoints.add((pt: next, type: 'walk', xyIdx: i));
      }
    }

    // ── 2. 세그먼트 분리 후 폴리라인 그리기 ─────────────────
    if (allPoints.length >= 2) {
      final segments = <({String type, List<NLatLng> points, bool isPast})>[];
      String currentType = allPoints.first.type;
      bool isPast = allPoints.first.xyIdx < currentIdx;
      List<NLatLng> currentPoints = [allPoints.first.pt];

      for (var i = 1; i < allPoints.length; i++) {
        final item = allPoints[i];
        final itemPast = item.xyIdx < currentIdx;
        if (item.type != currentType || itemPast != isPast) {
          if (currentPoints.length >= 2) {
            segments.add((type: currentType, points: List.of(currentPoints), isPast: isPast));
          }
          currentType = item.type;
          isPast = itemPast;
          currentPoints = [currentPoints.last, item.pt];
        } else {
          currentPoints.add(item.pt);
        }
      }
      if (currentPoints.length >= 2) {
        segments.add((type: currentType, points: List.of(currentPoints), isPast: isPast));
      }

      Color segColor(String type, bool past) {
        if (past) return const Color(0xFFCBD5E1); // 지나온 구간: 연회색
        return switch (type) {
          'subway' => AppColors.subway,
          'bus'    => const Color(0xFF22C55E),
          _        => const Color(0xFF9CA3AF),
        };
      }
      double segWidth(String type, bool past) => past ? 4.0 : (type == 'walk' ? 3.0 : 6.0);

      for (var i = 0; i < segments.length; i++) {
        final seg = segments[i];
        if (seg.points.length < 2) continue;
        await controller.addOverlay(
          NPolylineOverlay(
            id: 'seg_$i',
            coords: seg.points,
            color: segColor(seg.type, seg.isPast),
            width: segWidth(seg.type, seg.isPast),
          ),
        );
      }
    }

    // ── 3. getCurrentSection xy[idx] → 현재 위치 마커 ────────
    NLatLng? sectionTarget;
    if (section != null && section.idx < coords.length) {
      final xyPoint = coords[section.idx];
      if (xyPoint.hasCoord) {
        sectionTarget = NLatLng(xyPoint.y!, xyPoint.x!);
        final stationName = xyPoint.stationName;
        final sectionMarker = NMarker(id: 'section_pos', position: sectionTarget);
        sectionMarker.setCaption(NOverlayCaption(
          text: stationName != null && stationName.isNotEmpty ? stationName : '현재 위치',
          textSize: 12,
          color: const Color(0xFFE65100),
        ));
        await controller.addOverlay(sectionMarker);
      }
    }

    // ── 4. GPS 현재 위치 마커 ────────────────────────────────
    NLatLng? gpsTarget;
    if (_currentGpsPosition != null) {
      gpsTarget = NLatLng(_currentGpsPosition!.latitude, _currentGpsPosition!.longitude);
      final marker = NMarker(id: 'gps_pos', position: gpsTarget);
      marker.setCaption(const NOverlayCaption(
        text: '현재 위치',
        textSize: 11,
        color: Color(0xFF1A73E8),
      ));
      await controller.addOverlay(marker);
    }

    // ── 5. 카메라: GPS 우선, 없으면 section 위치로 이동 ──────
    final cameraTarget = gpsTarget ?? sectionTarget;
    if (cameraTarget != null) {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: cameraTarget, zoom: 15),
      );
    }

    _routeDrawn = true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gpsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);

    // 추천 경로로 전환되는 순간 탭을 1로 자동 이동 (State가 살아있으므로 안전)
    ref.listen<bool>(
      homeProvider.select((s) => s.isUsingRecoRoute),
      (prev, next) {
        if (next && prev == false) {
          _tabController.animateTo(1);
        }
      },
    );

    // 폴링으로 좌표/구간이 바뀌면 지도 다시 그리기
    // 현재 활성 탭(나의 경로 vs 추천 경로)에 맞는 좌표를 사용
    ref.listen<HomeState>(homeProvider, (prev, next) {
      if (_mapController == null) return;
      final isReco = next.isUsingRecoRoute;
      final activeCoords = isReco ? next.recoRouteCoordinates : next.routeCoordinates;
      final prevActiveCoords = isReco ? prev?.recoRouteCoordinates : prev?.routeCoordinates;
      final coordsChanged = prevActiveCoords != activeCoords;
      final stepChanged = prev?.currentStepIndex != next.currentStepIndex;
      final sectionChanged = prev?.currentSectionData?.idx != next.currentSectionData?.idx;
      if (coordsChanged || stepChanged || sectionChanged) {
        _drawRouteOnMap(_mapController!, activeCoords);
      }
    });

    final routine = home.activeRoutine!;
    final route = home.myRoute;
    // 현재 활성 탭에 맞는 경로 및 좌표
    final isUsingReco = home.isUsingRecoRoute;
    final activeRoute = isUsingReco ? home.recommendedRoute : home.myRoute;
    final activeCoords = isUsingReco ? home.recoRouteCoordinates : home.routeCoordinates;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          NaverMap(
            key: const ValueKey('active_map'),
            options: NaverMapViewOptions(
              initialCameraPosition: _initialCameraPosition() ??
                  const NCameraPosition(
                    target: NLatLng(37.5665, 126.9780), // 좌표 없을 때 fallback
                    zoom: 14,
                  ),
              mapType: NMapType.basic,
              activeLayerGroups: const [NLayerGroup.transit],
            ),
            onMapReady: (controller) {
              _mapController = controller;
              if (activeCoords.isNotEmpty) {
                // 현재 활성 탭의 좌표로 지도 그리기
                _drawRouteOnMap(controller, activeCoords);
              } else {
                // 추천 경로 좌표가 아직 없으면 (출발 직후 폴링 전) GPS 위치로 이동
                _moveToCurrentLocation(controller);
              }
            },
          ),
          // ── 줌 / 현위치 버튼 (active 지도) ───────────────────────────────
          Builder(
            builder: (context) {
              final screenH = MediaQuery.of(context).size.height;
              final minPanelH = screenH * 0.35 + 16;
              return Positioned(
                right: 12,
                bottom: minPanelH,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MapZoomButton(
                      icon: Icons.add,
                      onTap: () async {
                        if (_mapController == null) return;
                        await _mapController!.updateCamera(NCameraUpdate.zoomIn());
                      },
                    ),
                    const SizedBox(height: 6),
                    _MapZoomButton(
                      icon: Icons.remove,
                      onTap: () async {
                        if (_mapController == null) return;
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
              );
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
                color: AppColors.background,
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
                            currentStepIndex: home.myStepIndex,
                            liveStatusText:
                                ref.watch(liveStatusProvider)?.status ?? '대기중',
                            stepRemainingMinutes: home.myStepRemainingMinutes,
                            stopsRemaining: home.myStopsRemaining,
                            currentStationName: home.myCurrentStationName,
                            isWalking: home.myIsWalking,
                            sectionData: home.myCurrentSectionData,
                            onStop: () =>
                                widget.onStopTap(home.activeRoutine),
                          ),
                        ),
                        // ── 추천 경로 탭 ──────────────────────────────────
                        // RecoRouteTabContent: recoRouteProvider 기반으로
                        // 카드 목록 선택 → 실시간 구간 안내(이미지2)까지 모두 처리
                        RecoRouteTabContent(
                          scrollController: scrollController,
                          // "현재 경로 유지" 버튼: Navigator.pop() 대신 탭 전환
                          onKeep: () => _tabController.animateTo(0),
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
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(16),
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
  final bool isOverdue;
  final int minutesOverdue;
  final String? aiSummary;
  final LiveRouteModel? myRoute;

  const _PreActivePanel({
    required this.routine,
    required this.isImminent,
    this.isOverdue = false,
    this.minutesOverdue = 0,
    this.aiSummary,
    this.myRoute,
  });

  @override
  State<_PreActivePanel> createState() => _PreActivePanelState();
}

class _PreActivePanelState extends State<_PreActivePanel> {
  @override
  Widget build(BuildContext context) {
    final paths = widget.myRoute?.path ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
          // ── 출발/도착 강조 카드 ──────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isOverdue
                    ? [const Color(0xFFFFF0EE), const Color(0xFFFFDDD9)]
                    : widget.isImminent
                        ? [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)]
                        : [Colors.white, const Color(0xFFFFF5F2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isOverdue
                    ? AppColors.error.withValues(alpha: 0.5)
                    : widget.isImminent
                        ? AppColors.warning.withValues(alpha: 0.5)
                        : AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 레이블 행 — 좌: 출발 예정 텍스트 / 우: 늦어도~칩
                Row(
                  children: [
                    Icon(
                      widget.isOverdue
                          ? Icons.directions_run
                          : widget.isImminent
                              ? Icons.directions_run
                              : Icons.access_time_rounded,
                      size: 13,
                      color: widget.isOverdue
                          ? AppColors.error
                          : widget.isImminent
                              ? AppColors.warning
                              : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.isOverdue
                          ? '지금 출발하세요!'
                          : widget.isImminent
                              ? '곧 출발하세요!'
                              : '출발 예정',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.isOverdue
                            ? AppColors.error
                            : widget.isImminent
                                ? AppColors.warning
                                : AppColors.textSecondary,
                      ),
                    ),
                    if (widget.isOverdue) ...[
                      const SizedBox(width: 6),
                      Text(
                        '권장 출발 시간이 ${widget.minutesOverdue}분 지났어요',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.error.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // ── 늦어도 ~ 칩 (우측 상단, 도착시간 - 소요시간)
                    if (!widget.isOverdue && widget.routine.spareTime >= 0)
                      Builder(builder: (context) {
                        final parts = widget.routine.targetArrivalTime.split(':');
                        if (parts.length < 2) return const SizedBox.shrink();
                        final totalMinutes =
                            (int.tryParse(parts[0]) ?? 0) * 60 +
                            (int.tryParse(parts[1]) ?? 0) -
                            widget.routine.estimatedDuration;
                        final deadlineH = (totalMinutes ~/ 60).clamp(0, 23);
                        final deadlineM = (totalMinutes % 60).clamp(0, 59);
                        final deadline =
                            '${deadlineH.toString().padLeft(2, '0')}:${deadlineM.toString().padLeft(2, '0')}';
                        final chipBg = widget.isImminent
                            ? const Color(0xFFFFF3CD)
                            : const Color(0xFFFFFDE7);
                        final chipBorder = widget.isImminent
                            ? const Color(0xFFFFCA28)
                            : const Color(0xFFFFEE88);
                        final chipColor = widget.isImminent
                            ? const Color(0xFF7A5100)
                            : const Color(0xFF8A6500);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: chipBorder, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.alarm_rounded,
                                  size: 11, color: chipColor),
                              const SizedBox(width: 3),
                              Text(
                                '늦어도 $deadline에는 출발',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: chipColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
                const SizedBox(height: 10),
                // 출발 시각 ←→ 도착 시각 강조 행
                Row(
                  children: [
                    // 출발
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '출발',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary.withValues(alpha: 0.7),
                            ),
                          ),
                          Text(
                            widget.routine.recommendedDepartureTime,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: widget.isOverdue
                                  ? AppColors.error
                                  : AppColors.primary,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 화살표 (소요시간 뱃지)
                    Column(
                      children: [
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '약 ${widget.routine.estimatedDuration}분',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // 도착
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '도착',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary.withValues(alpha: 0.7),
                            ),
                          ),
                          Text(
                            widget.routine.targetArrivalTime,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppColors.secondary,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ── 경로 단계 카드
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: paths.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(Icons.route_outlined, size: 40, color: AppColors.border),
                        const SizedBox(height: 8),
                        const Text('경로를 불러오는 중이에요',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : Column(
                    children: paths.asMap().entries.map((e) => _PathItem(
                      path: e.value,
                      isCurrent: false,
                      isFirst: e.key == 0,
                      isLast: e.key == paths.length - 1,
                    )).toList(),
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
  final int? stopsRemaining;
  final String? currentStationName;
  final bool isWalking;
  final VoidCallback onStop;
  final CurrentSectionModel? sectionData;

  const _ActivePanel({
    required this.routine,
    required this.route,
    required this.currentStepIndex,
    required this.liveStatusText,
    required this.stepRemainingMinutes,
    required this.onStop,
    this.stopsRemaining,
    this.currentStationName,
    this.isWalking = false,
    this.sectionData,
  });

  static IconData _statusIcon(String status) {
    if (status.contains('버스')) return Icons.directions_bus_outlined;
    if (status.contains('지하철')) return Icons.subway_outlined;
    if (status.contains('환승')) return Icons.transfer_within_a_station;
    if (status == '도착') return Icons.flag_outlined;
    return Icons.directions_walk;
  }

  static Color _statusColor(String status) {
    if (status.contains('버스')) return AppColors.bus;
    if (status.contains('지하철')) return AppColors.subway;
    if (status.contains('환승')) return AppColors.secondary;
    if (status == '도착') return AppColors.success;
    return AppColors.success;
  }

  /// 하차 알림 배너 — 버스/지하철: 정거장 기반, 도보: 다음 정류장 안내
  Widget? _stopAlertBanner() {
    // ✅ 도보 중일 때: 다음 정류장 이름 안내
    if (isWalking) {
      if (currentStationName == null) return null;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_walk, size: 18, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '도보 이동 중',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (currentStationName != null) '다음 승차 위치: $currentStationName',
                      if (_nextSectionLabel() != null) '→ ${_nextSectionLabel()}',
                    ].join('  '),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ✅ 버스/지하철 중: 남은 정거장 기반 하차 알림
    final stops = stopsRemaining;
    if (stops == null || stops > 2) {
      // 2개 초과여도 현재 정류장 이름은 표시
      if (currentStationName != null) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.subway.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.subway.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.place_outlined, size: 16, color: AppColors.subway),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '현재 위치: $currentStationName${stops != null ? "  ·  $stops정거장 남음" : ""}${_nextSectionLabel() != null ? "  →  다음: ${_nextSectionLabel()}" : ""}',
                  style: const TextStyle(fontSize: 12, color: AppColors.subway),
                ),
              ),
            ],
          ),
        );
      }
      return null;
    }

    final bool isUrgent = stops <= 1;
    final color = isUrgent ? Colors.orange : const Color(0xFFF59E0B);
    final bgColor = isUrgent
        ? Colors.orange.withValues(alpha: 0.12)
        : const Color(0xFFFEF3C7);
    final borderColor = isUrgent
        ? Colors.orange.withValues(alpha: 0.5)
        : const Color(0xFFF59E0B).withValues(alpha: 0.5);

    final String message = stops == 0
        ? '🔔 다음 정류장에서 하차하세요!'
        : stops == 1
            ? '⚠️ 1정거장 후 하차 — 준비하세요'
            : '🔔 2정거장 후 하차 예정입니다';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                // 현재 위치 + 다음 구간 표시
                if (currentStationName != null || _nextSectionLabel() != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (currentStationName != null) '현재 위치: $currentStationName',
                      if (_nextSectionLabel() != null) '다음: ${_nextSectionLabel()}',
                    ].join('  →  '),
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withValues(alpha: 0.8),
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


  /// 다음 구간 레이블 (없으면 null)
  String? _nextSectionLabel() {
    final paths = route?.path ?? [];
    final nextIdx = currentStepIndex + 1;
    if (nextIdx >= paths.length) return null;
    final next = paths[nextIdx];
    if (next.isWalking) return '도보';
    if (next.isBus) return '버스 ${next.busNumbersLabel}';
    if (next.isSubway) return '지하철 ${next.subwayLineName}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final paths = route?.path ?? [];
    final statusColor = _statusColor(liveStatusText);
    final banner = _stopAlertBanner();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 하차 알림 배너 (2정거장 이하일 때만)
          if (banner != null) ...[
            banner,
            const SizedBox(height: 10),
          ],
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
              if (stopsRemaining != null && stopsRemaining! > 2) ...[
                const SizedBox(width: 8),
                Text(
                  '$stopsRemaining정거장 남음',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else if (stepRemainingMinutes > 0 && stopsRemaining == null) ...[
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
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              children: [
                _RoutineStepDots(paths: paths, currentStep: currentStepIndex, sectionData: sectionData),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Flexible(
                      child: Row(
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
                            Flexible(
                              child: Text(
                                '  약 ${route!.totalTime}분 소요',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onStop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('■ 종료', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (paths.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: paths.asMap().entries.map(
                  (entry) => _PathItem(
                    path: entry.value,
                    isCurrent: entry.key == currentStepIndex,
                    isFirst: entry.key == 0,
                    isLast: entry.key == paths.length - 1,
                    currentStationName: entry.key == currentStepIndex
                        ? currentStationName
                        : null,
                  ),
                ).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────
// ───────────────────────────────────────────────
// 추천 경로 탭 — 카드 목록 패널
// ───────────────────────────────────────────────
class _RecoRouteListPanel extends ConsumerStatefulWidget {
  final List<RouteModel> recoList;
  final List<RouteModel> detourList;
  final bool hasIncident;
  final String? incidentMessage;
  final VoidCallback onKeep;
  final void Function(int recoId) onSwitch;

  const _RecoRouteListPanel({
    required this.recoList,
    required this.detourList,
    required this.hasIncident,
    this.incidentMessage,
    required this.onKeep,
    required this.onSwitch,
  });

  @override
  ConsumerState<_RecoRouteListPanel> createState() => _RecoRouteListPanelState();
}

class _RecoRouteListPanelState extends ConsumerState<_RecoRouteListPanel> {
  int? _selectedRecoId;

  Future<void> _showDetail(RouteModel summary) async {
    // recoRouteProvider를 통해 상세 조회 (homeRepositoryProvider 직접 참조 불필요)
    await ref.read(recoRouteProvider.notifier).loadRecoDetail(summary.recoId);
    if (!mounted) return;
    final detail = ref.read(recoRouteProvider).detailRoute ?? summary;

    final selected = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          color: Colors.white,
          child: _RecoRouteDetailSheet(
            route: detail,
            scrollController: controller,
          ),
        ),
      ),
    );
    ref.read(recoRouteProvider.notifier).closeDetail();
    if (selected == true && mounted) {
      setState(() => _selectedRecoId = summary.recoId);
      widget.onSwitch(summary.recoId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEmpty = widget.recoList.isEmpty && widget.detourList.isEmpty;
    final isSwitching = ref.watch(homeProvider.select((s) => s.isLoading));

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 돌발 사고 배너 ──────────────────────────────
          if (widget.hasIncident) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.incidentMessage ?? '돌발 사고 발생',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 로딩/빈 상태 ────────────────────────────────
          if (allEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                children: const [
                  Icon(Icons.schedule_rounded, size: 16, color: AppColors.border),
                  SizedBox(width: 6),
                  Text('추천 경로를 분석 중이에요',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),

          // ── 우회 경로 목록 ──────────────────────────────
          if (widget.detourList.isNotEmpty) ...[
            _RouteGroupLabel(label: '우회 경로'),
            const SizedBox(height: 8),
            ...widget.detourList.map((route) => _RecoRouteCard(
              route: route,
              isSelected: _selectedRecoId == route.recoId,
              onTap: () => setState(() => _selectedRecoId = route.recoId),
              onDetail: () => _showDetail(route),
            )),
            const SizedBox(height: 16),
          ],

          // ── 추천 경로 목록 ──────────────────────────────
          if (widget.recoList.isNotEmpty) ...[
            _RouteGroupLabel(label: '추천 경로'),
            const SizedBox(height: 8),
            ...widget.recoList.map((route) => _RecoRouteCard(
              route: route,
              isSelected: _selectedRecoId == route.recoId,
              onTap: () => setState(() => _selectedRecoId = route.recoId),
              onDetail: () => _showDetail(route),
            )),
            const SizedBox(height: 20),
          ],

          // ── 버튼 영역 ───────────────────────────────────
          if (!allEmpty)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onKeep,
                    child: const Text('현재 경로 유지'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_selectedRecoId != null && !isSwitching)
                        ? () => widget.onSwitch(_selectedRecoId!)
                        : null,
                    child: isSwitching
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('이 경로로 변경'),
                  ),
                ),
              ],
            ),
        ],
      ),
        ),
        // 경로 전환 중 — 전체 오버레이 로딩
        if (isSwitching)
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha: 0.7),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _RouteGroupLabel extends StatelessWidget {
  final String label;
  const _RouteGroupLabel({required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}

class _RecoRouteCard extends StatelessWidget {
  final RouteModel route;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDetail;

  const _RecoRouteCard({
    required this.route,
    required this.isSelected,
    required this.onTap,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 교통수단 칩 + 상세보기 ────────────────────
            Row(
              children: [
                Expanded(child: _RouteTransitRow(paths: route.path)),
                TextButton(
                  onPressed: onDetail,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('상세보기',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // ── 소요시간 + 요금 ───────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${route.totalTime}분',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: route.isDetour ? AppColors.secondary : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_formatPayment(route.payment)}원',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
                if (route.isCurrent) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('이용 중',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary)),
                  ),
                ],
                if (route.timeDelta != null) ...[
                  const SizedBox(width: 6),
                  Text(route.timeDelta!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w500)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // ── 선택 체크박스 ─────────────────────────────
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 2,
                    ),
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
                const Text('이 경로 선택',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────
// 추천 경로 상세 바텀시트
// ───────────────────────────────────────────────
class _RecoRouteDetailSheet extends StatelessWidget {
  final RouteModel route;
  final ScrollController scrollController;

  const _RecoRouteDetailSheet({
    required this.route,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 드래그 핸들
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2)),
        ),
        // 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: [
              const Text('경로 상세',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${route.totalTime}분',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const Text('  ·  ',
                  style: TextStyle(color: AppColors.textSecondary)),
              Text('${_formatPayment(route.payment)}원',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: AppColors.border),
        // 단계별 리스트
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
                16, 20, 16, 20 + MediaQuery.of(context).padding.bottom),
            children: [
              ...route.path.asMap().entries.map((e) => _DetailPathItem(
                    path: e.value,
                    isLast: e.key == route.path.length - 1,
                  )),
            ],
          ),
        ),
        // 하단 요약 바
        const Divider(height: 1, thickness: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryItem('총 소요', '${route.totalTime}분'),
              _SummaryItem('요금', '${_formatPayment(route.payment)}원'),
              _SummaryItem('거리',
                  '${(route.totalDistance / 1000).toStringAsFixed(1)}km'),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('이 경로 선택하기'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────
// 경로 상세 — 단계별 아이템 (펼침/접힘)
// ───────────────────────────────────────────────
class _DetailPathItem extends StatefulWidget {
  final PathModel path;
  final bool isLast;
  const _DetailPathItem({required this.path, required this.isLast});

  @override
  State<_DetailPathItem> createState() => _DetailPathItemState();
}

class _DetailPathItemState extends State<_DetailPathItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    final isLast = widget.isLast;

    final Color color = path.isWalking
        ? AppColors.textSecondary
        : path.isSubway
            ? AppColors.subway
            : AppColors.bus;
    final Color chipBg = path.isWalking
        ? AppColors.walkBg
        : path.isSubway
            ? AppColors.subwayBg
            : AppColors.busBg;

    final icon = path.isWalking
        ? Icons.directions_walk
        : path.isSubway
            ? Icons.subway_outlined
            : Icons.directions_bus_outlined;

    final String title = path.isWalking
        ? '도보'
        : path.start != null && path.start!.isNotEmpty
            ? '${path.start} 승차'
            : path.isSubway ? '지하철 승차' : '버스 승차';

    final bool hasStations = path.stationName.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15)),
              child: Icon(icon, size: 18, color: color),
            ),
            if (!isLast)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 2,
                height: hasStations && _expanded
                    ? 44.0 + path.stationName.length * 28.0
                    : 40,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: hasStations
                      ? () => setState(() => _expanded = !_expanded)
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      if (hasStations)
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                if (path.isSubway && path.no.isNotEmpty) ...[
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.chipRouteDetailBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(path.subwayLineName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.chipRouteDetail)),
                      ),
                      if (path.way != null && path.way!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${path.way} 방향',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (path.isBus && path.busNumbers.isNotEmpty) ...[
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: path.busNumbers.map((n) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.chipRouteDetailBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${n}번',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.chipRouteDetail)),
                    )).toList(),
                  ),
                  const SizedBox(height: 6),
                ],
                Wrap(
                  spacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.subwayBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${path.sectionTime}분',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.subway)),
                    ),
                    if (hasStations)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.busBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(path.stationCountLabel,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.bus)),
                      ),
                  ],
                ),
                if (hasStations && _expanded) ...[
                  const SizedBox(height: 8),
                  ...path.stationName.asMap().entries.map((e) {
                    final isFirst = e.key == 0;
                    final isLastStation = e.key == path.stationName.length - 1;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 16,
                          child: Column(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (isFirst || isLastStation)
                                      ? color
                                      : color.withValues(alpha: 0.3),
                                  border: Border.all(color: color, width: 1.5),
                                ),
                              ),
                              if (!isLastStation)
                                Container(
                                  width: 2, height: 20,
                                  color: color.withValues(alpha: 0.25),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(e.value,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: (isFirst || isLastStation)
                                      ? color
                                      : AppColors.textSecondary,
                                  fontWeight: (isFirst || isLastStation)
                                      ? FontWeight.w600
                                      : FontWeight.normal)),
                        ),
                      ],
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryItem(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      );
}

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
          // ── 소요시간 + 요금 요약 ──────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              route != null
                  ? Text(
                      '${route!.totalTime}분',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: hasIncident ? AppColors.secondary : AppColors.primary,
                      ),
                    )
                  : const Text('분석 중…',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
              if (route != null) ...[
                const SizedBox(width: 8),
                Text('예상 요금 ${_formatPayment(route!.payment)}원',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
              if (hasIncident) ...[
                const SizedBox(width: 6),
                const Text('+6분 (돌발 우회)',
                    style: TextStyle(fontSize: 12, color: AppColors.secondary,
                        fontWeight: FontWeight.w500)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // ── 경로 단계 목록 ────────────────────────────────
          if (route == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: AppColors.border),
                  const SizedBox(width: 6),
                  const Text('추천 경로를 분석 중이에요',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            )
          else if (route!.path.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: route!.path.asMap().entries.map((e) => _PathItem(
                  path: e.value,
                  isCurrent: false,
                  isLast: e.key == route!.path.length - 1,
                )).toList(),
              ),
            )
          else
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: AppColors.border),
                const SizedBox(width: 6),
                const Text('경로를 불러오는 중이에요',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
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
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
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

    // 도보는 아이콘, 버스는 번호 전체를 한 칩에, 지하철은 노선명 칩
    final chips = <Widget>[];
    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      if (path.isWalking) {
        chips.add(
          const Icon(Icons.directions_walk, size: 18, color: AppColors.textSecondary),
        );
      } else if (path.isSubway) {
        chips.add(_RouteChip(label: path.subwayLineName, color: AppColors.subway));
      } else {
        // 버스: 번호 전체를 "5535 · 8551(출근맞춤버스) · 500" 한 칩으로
        final nums = path.no.where((n) => n.isNotEmpty).toList();
        if (nums.isNotEmpty) {
          chips.add(_RouteChip(label: nums.join(' · '), color: AppColors.bus));
        }
      }
      if (i < paths.length - 1) {
        chips.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Icon(Icons.arrow_forward, size: 12, color: AppColors.border),
          ),
        );
      }
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 1,
                          color: AppColors.border,
                        ),
                        const Icon(
                          Icons.arrow_forward,
                          size: 12,
                          color: AppColors.border,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
  final CurrentSectionModel? sectionData;
  const _RoutineStepDots({
    required this.paths,
    required this.currentStep,
    this.sectionData,
  });

  /// section 배열(["walk","bus","bus","bus","walk"])을 압축해
  /// 레이블 목록("도보","버스:5535","지하철:수도권 1호선","도착")을 만들고 현재 위치도 계산.
  List<String> _sectionLabels() {
    final raw = sectionData?.section ?? [];
    if (raw.isEmpty) return [];
    // 연속 중복 제거 (typeKey 기준 — "bus:5535","bus:5535" → "bus:5535" 하나로)
    final compressed = <String>[];
    for (final t in raw) {
      if (compressed.isEmpty || compressed.last != t) compressed.add(t);
    }
    return compressed.map((t) {
      if (t == 'walk') return '도보';
      if (t.startsWith('bus:')) return '버스:${t.substring(4)}';
      if (t.startsWith('subway:')) {
        final raw = t.substring(7); // e.g. "수도권 1호선"
        // 이미 "호선"/"선" 포함 → 그대로, 숫자 코드 → "N호선"
        final line = (raw.contains('호선') || raw.contains('선')) ? raw : '${raw}호선';
        return '지하철:$line';
      }
      return '도보';
    }).toList()..add('도착');
  }

  /// section.idx (도착 예정 구간) → 압축 후 현재 인덱스
  int _sectionCurrentStep() {
    final sec = sectionData;
    if (sec == null) return currentStep;
    final raw = sec.section;
    final currentRawIdx = (sec.idx - 1).clamp(0, raw.length - 1);
    String? prev;
    int ci = 0;
    for (var i = 0; i <= currentRawIdx && i < raw.length; i++) {
      final t = raw[i];
      if (t != prev) { if (prev != null) ci++; prev = t; }
    }
    return ci;
  }

  @override
  Widget build(BuildContext context) {
    // section 데이터 우선, 없으면 paths 기반
    final sectionLabels = _sectionLabels();
    final labels = sectionLabels.isNotEmpty
        ? sectionLabels
        : (paths.isEmpty ? null : (paths.map((p) {
              if (p.isWalking) return '도보';
              if (p.isSubway) return '지하철:${p.subwayLineName}';
              // 버스: 번호가 있으면 첫 번째만 도트 진행바에 표시
              final nums = p.busNumbers;
              return nums.isNotEmpty ? '버스:${nums.first}' : '버스';
            }).toList()..add('도착')));
    final effectiveStep = sectionLabels.isNotEmpty ? _sectionCurrentStep() : currentStep;

    if (labels == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            '구간 정보를 불러오는 중...',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Row(
      children: labels.asMap().entries.map((entry) {
        final i = entry.key;
        final label = entry.value;
        final isDone = i < effectiveStep;
        final isCurrent = i == effectiveStep;
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
                    _StepLabel(
                      label: label,
                      isCurrent: isCurrent,
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
// 진행 바 라벨: "버스:5535" → 두 줄로 분리해 표시
// ───────────────────────────────────────────────
class _StepLabel extends StatelessWidget {
  final String label;
  final bool isCurrent;
  const _StepLabel({required this.label, required this.isCurrent});

  /// "버스:5535" → ('버스', '5535')
  /// "지하철:수도권 1호선" → ('지하철', '수도권 1호선')
  /// "도보" / "도착" → ('도보', null)
  (String, String?) _split() {
    final colon = label.indexOf(':');
    if (colon == -1) return (label, null);
    return (label.substring(0, colon), label.substring(colon + 1));
  }

  @override
  Widget build(BuildContext context) {
    final (top, sub) = _split();
    final color = isCurrent ? AppColors.primary : AppColors.textSecondary;
    final weight = isCurrent ? FontWeight.w600 : FontWeight.normal;

    return Column(
      children: [
        Text(
          top,
          style: TextStyle(fontSize: 10, color: color, fontWeight: weight),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        if (sub != null)
          Text(
            sub,
            style: TextStyle(fontSize: 9, color: color, fontWeight: weight),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

// ───────────────────────────────────────────────
// 공통 위젯: 경로 단계 항목 (카드 행 방식)
// ───────────────────────────────────────────────
// 도보: 회색 배경 한 줄 / 버스: 연두 배경 / 지하철: 연파랑 배경
// isCurrent=true 이면 좌측에 강조 border 추가
// currentStationName 이 있으면 해당 정류장 하이라이트
class _PathItem extends StatefulWidget {
  final PathModel path;
  final bool isCurrent;
  final bool isLast;
  final bool isFirst;
  final String? currentStationName;

  const _PathItem({
    required this.path,
    required this.isCurrent,
    this.isLast = false,
    this.isFirst = false,
    this.currentStationName,
  });

  @override
  State<_PathItem> createState() => _PathItemState();
}

class _PathItemState extends State<_PathItem> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isCurrent && !widget.path.isWalking;
  }

  @override
  void didUpdateWidget(_PathItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !widget.path.isWalking && !_expanded) {
      setState(() => _expanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    final isCurrent = widget.isCurrent;

    final Color iconBg;
    final Color iconColor;
    final Color rowBg;
    final Color chipTextColor;
    final Color chipBg;

    if (path.isWalking) {
      iconBg        = AppColors.walkBg;
      iconColor     = AppColors.walk;
      rowBg         = Colors.white;
      chipTextColor = AppColors.chipRoute;
      chipBg        = AppColors.chipRouteBg;
    } else if (path.isSubway) {
      iconBg        = AppColors.subway;
      iconColor     = Colors.white;
      rowBg         = Colors.white;
      chipTextColor = AppColors.chipRoute;
      chipBg        = AppColors.chipRouteBg;
    } else {
      iconBg        = AppColors.bus;
      iconColor     = Colors.white;
      rowBg         = Colors.white;
      chipTextColor = AppColors.chipRoute;
      chipBg        = AppColors.chipRouteBg;
    }

    return Container(
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(
          left: isCurrent
              ? BorderSide(
                  color: path.isSubway ? AppColors.subway : AppColors.bus,
                  width: 3,
                )
              : BorderSide.none,
          top: widget.isFirst
              ? BorderSide.none
              : BorderSide(color: AppColors.border),
          bottom: BorderSide.none,
        ),
      ),
      padding: path.isWalking
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: path.isWalking
          // ── 도보 행
          ? Row(
              children: [
                if (isCurrent)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('현재',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Icon(Icons.directions_walk, size: 15, color: iconColor),
                ),
                const SizedBox(width: 10),
                const Text('도보',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const Spacer(),
                _HomeChip(label: '${path.sectionTime}분', bg: AppColors.chipTimeBg, fg: AppColors.chipTime),
              ],
            )
          // ── 버스 / 지하철 행
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Icon(
                    path.isSubway ? Icons.subway_outlined : Icons.directions_bus_outlined,
                    size: 15, color: iconColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 현재 구간 배지
                      if (isCurrent) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: path.isSubway ? AppColors.subway : AppColors.bus,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('현재 구간',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                      // 출발지
                      if (path.start != null)
                        Text(path.start!,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isCurrent
                                    ? (path.isSubway ? AppColors.subway : AppColors.bus)
                                    : AppColors.textPrimary)),
                      const SizedBox(height: 4),

                      // 지하철: 노선명 칩(채운 파란 배경) + 방향 칩
                      if (path.isSubway && path.no.isNotEmpty) ...[
                        Wrap(
                          spacing: 4, runSpacing: 4,
                          children: [
                            _HomeChip(label: path.subwayLineName, bg: AppColors.chipRouteBg, fg: AppColors.chipRoute),
                            if (path.way != null && path.way!.isNotEmpty)
                              _HomeChip(label: '${path.way} 방향', bg: AppColors.chipRouteBg, fg: AppColors.chipRoute),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],

                      // 버스: 번호 칩
                      if (path.isBus && path.busNumbers.isNotEmpty) ...[
                        Wrap(
                          spacing: 4, runSpacing: 4,
                          children: path.busNumbers
                              .map((n) => _HomeChip(label: '${n}번', bg: AppColors.chipRouteBg, fg: AppColors.chipRoute))
                              .toList(),
                        ),
                        const SizedBox(height: 4),
                      ],

                      // 시간 + 정거장
                      Row(
                        children: [
                          _HomeChip(label: '${path.sectionTime}분', bg: AppColors.chipTimeBg, fg: AppColors.chipTime),
                          if (path.displayStationCount > 0) ...[
                            const SizedBox(width: 6),
                            _HomeChip(label: '${path.displayStationCount}정거장', bg: AppColors.chipStopsBg, fg: AppColors.chipStops),
                          ],
                        ],
                      ),

                      // 정류장 목록 펼치기/접기
                      if (path.stationName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _expanded ? '정류장 접기' : '정류장 ${path.stationName.length}개 보기',
                                style: TextStyle(fontSize: 12, color: chipTextColor, fontWeight: FontWeight.w500),
                              ),
                              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  size: 14, color: chipTextColor),
                            ],
                          ),
                        ),
                        if (_expanded) ...[
                          const SizedBox(height: 6),
                          ...path.stationName.map((station) {
                            final isCurrentStation = widget.currentStationName != null &&
                                station == widget.currentStationName;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  if (isCurrentStation)
                                    Container(
                                      width: 18, height: 18,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: chipTextColor),
                                      child: const Icon(Icons.my_location, size: 10, color: Colors.white),
                                    )
                                  else
                                    Container(
                                      width: 6, height: 6,
                                      margin: const EdgeInsets.only(left: 6),
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: chipTextColor.withValues(alpha: 0.5)),
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(station,
                                        style: TextStyle(
                                            fontSize: isCurrentStation ? 13 : 12,
                                            fontWeight: isCurrentStation ? FontWeight.w700 : FontWeight.normal,
                                            color: isCurrentStation ? chipTextColor : AppColors.textSecondary)),
                                  ),
                                  if (isCurrentStation)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: chipTextColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4)),
                                      child: Text('현재',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: chipTextColor)),
                                    ),
                                ],
                              ),
                            );
                          }),
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

// ── 홈 화면용 소형 칩 ───────────────────────────────────
class _HomeChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _HomeChip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      );
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