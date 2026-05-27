import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../providers/live_location_provider.dart' show liveLocationProvider; // ✅ liveLocationProvider만 선택 import
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('경로를 종료할까요?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text(
          '현재 진행 중인 루틴이 종료됩니다.\n목적지에 도달하지 않았어도 종료할 수 있어요.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('계속 진행',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // stopRoute() 먼저 → state가 preActive로 바뀜
              ref.read(homeProvider.notifier).stopRoute();
              // HomeScreen은 살아있으므로 안전하게 모달 표시
              if (mounted) _showFeedbackModal(context, routine);
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
      HomeStatus.preActive => _PreActiveView(home: home),
      HomeStatus.active    => _ActiveView(home: home, onStopTap: _onStopTap),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

// ───────────────────────────────────────────────
// 2-A: 루틴 없음
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
          SliverToBoxAdapter(child: _CoralHeader(nickname: nickname, weather: weather)),
          SliverToBoxAdapter(child: _BriefingCard(weather: weather)),
          const SliverFillRemaining(hasScrollBody: false, child: _EmptyRoutineSection()),
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
          Text('안녕하세요, $nickname님! 👋',
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
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
                  Text('$skyEmoji${tmp != null ? ' $tmp°' : ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                  const Text(' · ',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text('미세먼지 $pm10',
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
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
                  child: const Icon(Icons.wb_sunny_outlined,
                      color: AppColors.secondary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('오늘의 AI 브리핑',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      Text('루틴을 등록하면 AI가 맞춤 브리핑을 제공해요.',
                          style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _EmptyRoutineSection extends StatelessWidget {
  const _EmptyRoutineSection();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_bus_outlined,
                    size: 52, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text('등록된 루틴이 없어요',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              const Text(
                '루틴을 추가하면 실시간으로\n최적 경로를 안내해드려요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go(RouteConstants.routine),
                  icon: const Icon(Icons.add),
                  label: const Text('루틴 추가하기'),
                ),
              ),
            ],
          ),
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onStartTap() {
    _showRouteSelectionSheet(
      context,
      widget.home.activeRoutine!.targetArrivalTime,
      () => ref.read(homeProvider.notifier).startRoute(),
    );
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
        label: const Text('시작',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: Stack(
        children: [
         NaverMap(
  options: const NaverMapViewOptions(
    initialCameraPosition: NCameraPosition(
      target: NLatLng(37.5665, 126.9780),
      zoom: 14,
    ),
    mapType: NMapType.basic,
    activeLayerGroups: [NLayerGroup.transit],
  ),
),          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        '${routine.departureAddressName} → ${routine.arrivalAddressName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
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
                            aiSummary: ref.watch(briefingProvider).aiSummary?.summary,
                            myRoute: widget.home.myRoute,
                          ),
                        ),
                        SingleChildScrollView(
                          controller: scrollController,
                          child: _RecommendedPanel(
                            route: widget.home.recommendedRoute,
                            hasIncident: false,
                            onKeep: () => _tabController.animateTo(0),
                            onSwitch: _onStartTap,
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
    final routine = widget.home.activeRoutine!;
    final route   = widget.home.myRoute;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Container(color: const Color(0xFFE8EFF4)),
          Center(child: Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade400)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        '${routine.departureAddressName} → ${routine.arrivalAddressName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
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
                            liveStatusText: widget.home.liveStatus?.status ?? '도보 중',
                            stepRemainingMinutes: widget.home.stepRemainingMinutes,
                            onStop: () => widget.onStopTap(widget.home.activeRoutine),
                          ),
                        ),
                        SingleChildScrollView(
                          controller: scrollController,
                          child: _RecommendedPanel(
                            route: widget.home.recommendedRoute,
                            hasIncident: false,
                            onKeep: () => _tabController.animateTo(0),
                            onSwitch: () {
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
                offset: const Offset(0, 2)),
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
        tabs: const [Tab(text: '나의 경로'), Tab(text: '추천 경로')],
      );
}

class _PreActivePanel extends StatefulWidget {
  final RoutineModel routine;
  final bool isImminent;
  final String? aiSummary;
  final RouteModel? myRoute;

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
                const Icon(Icons.auto_awesome, size: 18, color: AppColors.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI 브리핑',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary)),
                      const SizedBox(height: 4),
                      Text(
                        widget.aiSummary ?? 'AI 브리핑을 불러오는 중...',
                        style: TextStyle(
                            fontSize: 13,
                            fontStyle: widget.aiSummary == null ? FontStyle.italic : FontStyle.normal,
                            color: AppColors.textPrimary,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _PanelCard(
            color: widget.isImminent ? AppColors.amber.withValues(alpha: 0.3) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.isImminent ? Icons.directions_run : Icons.access_time,
                      size: 15,
                      color: widget.isImminent ? AppColors.warning : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isImminent ? '곧 출발하세요!' : '출발 예정',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.isImminent ? AppColors.warning : AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.routine.recommendedDepartureTime,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '출발  →  ${widget.routine.targetArrivalTime} 도착',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('약 ${widget.routine.estimatedDuration}분 소요',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                          style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showDetail ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 18, color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  if (_showDetail) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ...paths.asMap().entries.map((e) => _PathItem(path: e.value, isCurrent: false, isLast: e.key == paths.length - 1)),
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
  final RouteModel? route;
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(liveStatusText), size: 16, color: statusColor),
                    const SizedBox(width: 4),
                    Text(liveStatusText,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusColor)),
                  ],
                ),
              ),
              if (stepRemainingMinutes > 0) ...[
                const SizedBox(width: 8),
                Text('이 구간 $stepRemainingMinutes분 남음',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _RoutineStepDots(paths: paths, currentStep: currentStepIndex),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('예상 도착 ', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              Text(routine.targetArrivalTime,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
              if (route != null)
                Text('  약 ${route!.totalTime}분 소요',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              OutlinedButton(
                onPressed: onStop,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            ...paths.asMap().entries.map((entry) =>
                _PathItem(path: entry.value, isCurrent: entry.key == currentStepIndex, isLast: entry.key == paths.length - 1)),
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
  final RouteModel? route;
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
                  Text('⚠️ 현재 경로 돌발 상황 감지',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.warning)),
                  SizedBox(height: 4),
                  Text('2호선 신호 장애 · 교체 경로 제안',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.secondary, size: 16),
                SizedBox(width: 6),
                Text('AI 우회 경로',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondary)),
                SizedBox(width: 8),
                Text('FastAPI 분석 완료', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
              child: const Text('현재 경로 정상',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green)),
            ),
            const SizedBox(height: 12),
            const Text('AI가 추천하는 최적 경로',
                style: TextStyle(fontSize: 13, color: AppColors.secondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hasIncident ? AppColors.secondary : AppColors.border, width: hasIncident ? 2 : 1),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('${route?.totalTime ?? 32}분',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: hasIncident ? AppColors.secondary : AppColors.primary)),
                ]),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: [
                    _RouteChip(label: '🚶', color: AppColors.textSecondary),
                    _RouteChip(label: hasIncident ? '신분당선' : '2호선', color: hasIncident ? Colors.red : Colors.green),
                    _RouteChip(label: '🚶', color: AppColors.textSecondary),
                    _RouteChip(label: hasIncident ? '3200번' : '147번', color: Colors.orange),
                    _RouteChip(label: '🚶', color: AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 8),
                Text('예상 요금 ${hasIncident ? '1,600원' : '1,400원'}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                if (hasIncident) ...[
                  const SizedBox(height: 4),
                  const Text('+6분 (돌발 우회)',
                      style: TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (hasIncident) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSwitch,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                child: const Text('우회 경로로 변경', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: onKeep, child: const Text('기존 경로 유지')),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: onKeep, child: const Text('현재 경로 유지'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: onSwitch, child: const Text('이 경로로 변경'))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteChip extends StatelessWidget {
  final String label;
  final Color color;
  const _RouteChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      );
}

class _RouteTransitRow extends StatelessWidget {
  final List<PathModel> paths;
  const _RouteTransitRow({required this.paths});

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return const Text('경로 정보 없음', style: TextStyle(fontSize: 13, color: AppColors.textSecondary));
    }

    final chips = <Widget>[];
    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      if (path.isWalking) {
        chips.add(const Icon(Icons.directions_walk, size: 18, color: AppColors.textSecondary));
      } else if (path.isSubway) {
        chips.add(_RouteChip(label: '${path.no.isNotEmpty ? path.no.first : ''}호선', color: Colors.blue));
      } else {
        chips.add(_RouteChip(label: '${path.no.isNotEmpty ? path.no.first : ''}번', color: Colors.orange));
      }
      if (i < paths.length - 1) {
        chips.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.arrow_forward, size: 12, color: AppColors.border),
        ));
      }
    }

    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: chips));
  }
}

// ───────────────────────────────────────────────
// 경로 선택 바텀시트
// ───────────────────────────────────────────────
void _showRouteSelectionSheet(BuildContext context, String arrivalTime, VoidCallback onConfirm) {
  int selectedIndex = 0;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => DraggableScrollableSheet(
        initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('경로를 선택해주세요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('선택하지 않으면 기존 경로로 자동 진행됩니다',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                    child: const Text('⏱ 15초 후 자동 선택',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
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
                    label: '추천', labelColor: AppColors.primary, route: '2호선 → 도보 5분',
                    minutes: 32, fare: '1,400원', arrivalTime: arrivalTime,
                    isSelected: selectedIndex == 0, onTap: () => setSheetState(() => selectedIndex = 0),
                  ),
                  const SizedBox(height: 10),
                  _RouteOptionCard(
                    label: '현재 경로', labelColor: AppColors.textSecondary, route: '신분당선 → 버스',
                    minutes: 38, fare: '1,600원', arrivalTime: arrivalTime,
                    isSelected: selectedIndex == 1, onTap: () => setSheetState(() => selectedIndex = 1),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16,
                  MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).viewPadding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(ctx); onConfirm(); },
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
    required this.label, required this.labelColor, required this.route,
    required this.minutes, required this.fare, this.arrivalTime,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final departureTime = arrivalTime != null ? _calcDeparture(arrivalTime!, minutes) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: labelColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
            ),
            const SizedBox(height: 10),
            Text(route, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('$minutes분', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(width: 12),
                Text(fare, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
                      Text(departureTime, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      const Text('출발', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Expanded(child: Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 8), color: AppColors.border)),
                          const Icon(Icons.arrow_forward, size: 12, color: AppColors.border),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(arrivalTime!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const Text('목표 도착', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
void _showFeedbackModal(BuildContext context, RoutineModel? routine) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => _FeedbackSheet(routine: routine),
  );
}

class _FeedbackSheet extends StatefulWidget {
  final RoutineModel? routine;
  const _FeedbackSheet({this.routine});

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final List<int> _ratings = [0, 0, 0];
  static const _questions = ['대기 시간이 예상과 맞았나요?', '예상 소요 시간이 정확했나요?', '경로가 만족스러웠나요?'];

  @override
  Widget build(BuildContext context) {
    final routeName = widget.routine != null
        ? '${widget.routine!.departureAddressName} → ${widget.routine!.arrivalAddressName}'
        : '루틴';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20,
          MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('오늘 이동은 어떠셨나요?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(routeName, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ...List.generate(_questions.length, (i) => _StarRatingRow(
                question: _questions[i], rating: _ratings[i],
                onRate: (r) => setState(() => _ratings[i] = r),
              )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('제출하기')),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('건너뛰기', style: TextStyle(color: AppColors.textSecondary)),
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

  const _StarRatingRow({required this.question, required this.rating, required this.onRate});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => onRate(i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i < rating ? AppColors.primary : AppColors.border, size: 32,
                  ),
                ),
              )),
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
    final labels = paths.isEmpty
        ? ['도보', '지하철', '환승', '버스', '도착']
        : paths.map((p) => p.typeLabel).toList()..add('도착');

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
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone || isCurrent ? AppColors.primary : Colors.transparent,
                        border: isDone || isCurrent ? null : Border.all(color: AppColors.border, width: 2),
                      ),
                      child: isDone
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : isCurrent
                              ? const Icon(Icons.circle, size: 8, color: Colors.white)
                              : null,
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: TextStyle(
                      fontSize: 10,
                      color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    )),
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
class _PathItem extends StatelessWidget {
  final PathModel path;
  final bool isCurrent;
  final bool isLast;

  const _PathItem({required this.path, required this.isCurrent, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final icon = path.isWalking ? Icons.directions_walk
        : path.isSubway ? Icons.subway_outlined
        : Icons.directions_bus_outlined;
    final color = path.isWalking ? AppColors.textSecondary
        : path.isSubway ? Colors.blue
        : Colors.green;
    final lineColor = path.isWalking ? AppColors.border
        : path.isSubway ? Colors.blue.withValues(alpha: 0.4)
        : Colors.green.withValues(alpha: 0.4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Column(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent ? color : color.withValues(alpha: 0.12),
                  border: isCurrent ? Border.all(color: color, width: 2) : null,
                ),
                child: Icon(icon, size: 16, color: isCurrent ? Colors.white : color),
              ),
              if (!isLast)
                Container(
                  width: 2, height: 36,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  decoration: path.isWalking
                      ? BoxDecoration(color: Colors.transparent, border: Border(left: BorderSide(color: lineColor, width: 2)))
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
                Text('${path.start ?? ''} → ${path.end ?? ''}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${path.sectionTime}분'
                  '${path.stationCount != null ? ' · ${path.stationCount}정거장' : ''}'
                  '${path.way != null ? ' · ${path.way}' : ''}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}