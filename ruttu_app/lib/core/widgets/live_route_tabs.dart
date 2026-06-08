import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/route_model.dart';
import '../../features/home/providers/live_route_provider.dart';
import '../../features/home/providers/home_provider.dart';
import 'package:ruttu_app/features/home/screens/reco_live_route_screen.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 루트 위젯 — 페이지에 배치
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class LiveRouteTabs extends ConsumerStatefulWidget {
  const LiveRouteTabs({super.key});

  @override
  ConsumerState<LiveRouteTabs> createState() => _LiveRouteTabsState();
}

class _LiveRouteTabsState extends ConsumerState<LiveRouteTabs> {
  bool _incidentDialogShowing = false;

  @override
  void initState() {
    super.initState();
    // 나의 경로 활성 중 incident 수신 감지 — 첫 프레임 후 리스닝 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenIncident();
    });
  }

  void _listenIncident() {
    // ref.listen은 ConsumerState 내 build()에서만 쓸 수 있으므로
    // 초기 상태 체크 후 빌드 사이클에서 처리 (build 내 ref.listen 사용)
  }

  Future<void> _showIncidentDialog(String message) async {
    if (_incidentDialogShowing || !mounted) return;
    _incidentDialogShowing = true;

    final goToReco = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935), size: 22),
            SizedBox(width: 8),
            Text(
              '돌발 상황 발생',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          '돌발사고가 발생했습니다.\n\n새로운 경로를 안내받겠습니까?',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              '아니오',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('예',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    _incidentDialogShowing = false;

    if (goToReco == true && mounted) {
      // 추천 경로 탭으로 전환
      ref.read(selectedRouteTabProvider.notifier).state = RouteTab.reco;
    } else {
      // "현재 경로 유지" 선택 시 incident 상태 클리어
      ref.read(incidentDetourProvider.notifier).clearIncident();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(selectedRouteTabProvider);
    final myState = ref.watch(myRouteProvider);

    // 나의 경로 또는 추천 경로 안내 중일 때 incident 팝업 감지
    ref.listen<IncidentDetourState>(incidentDetourProvider, (prev, next) {
      final isMyRouteActive = myState.isActive;
      final isRecoRouteActive = ref.read(recoRouteProvider).isActive;
      final newIncident = next.incidentMessage;
      final prevIncident = prev?.incidentMessage;

      // 새 incident 메시지가 생겼고, 나의 경로 또는 추천 경로가 활성화 중이며, 팝업이 안 떠 있을 때
      if ((isMyRouteActive || isRecoRouteActive) &&
          newIncident != null &&
          newIncident != prevIncident &&
          !_incidentDialogShowing) {
        _showIncidentDialog(newIncident);
      }
    });

    return Column(
      children: [
        _TabBar(
          currentTab: tab,
          myRouteActive: myState.isActive,
          recoRouteActive: ref.watch(recoRouteProvider).isActive,
          onTabChanged: (t) =>
              ref.read(selectedRouteTabProvider.notifier).state = t,
        ),
        const SizedBox(height: 16),
        // ✅ 독립 실행: Offstage로 각 탭의 State를 항상 살려두되
        //    화면에는 선택된 탭만 표시. 두 탭은 서로 다른 provider를 사용하므로 완전 독립.
        Expanded(
          child: Stack(
            children: [
              Offstage(
                offstage: tab != RouteTab.my,
                child: const _MyRouteTab(),
              ),
              Offstage(
                offstage: tab != RouteTab.reco,
                child: const _RecoRouteTab(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 탭 바
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.currentTab,
    required this.onTabChanged,
    this.myRouteActive = false,
    this.recoRouteActive = false,
  });

  final RouteTab currentTab;
  final void Function(RouteTab) onTabChanged;
  final bool myRouteActive;
  final bool recoRouteActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabChip(
          label: '나의 경로',
          isSelected: currentTab == RouteTab.my,
          // 추천 경로가 활성 중이면 나의 경로 탭 비활성화
          disabled: recoRouteActive,
          onTap: recoRouteActive ? null : () => onTabChanged(RouteTab.my),
        ),
        const SizedBox(width: 8),
        _TabChip(
          label: '추천 경로',
          isSelected: currentTab == RouteTab.reco,
          // 나의 경로가 활성 중이면 추천 경로 탭 비활성화
          disabled: myRouteActive,
          onTap: myRouteActive ? null : () => onTabChanged(RouteTab.reco),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.isSelected,
    this.onTap,
    this.disabled = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.surface.withOpacity(0.5)
              : (isSelected ? AppColors.primary : AppColors.surface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: disabled
                ? AppColors.border.withOpacity(0.4)
                : (isSelected ? AppColors.primary : AppColors.border),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: disabled
                ? AppColors.textSecondary.withOpacity(0.4)
                : (isSelected ? Colors.white : AppColors.textSecondary),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 나의 경로 탭
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _MyRouteTab extends ConsumerStatefulWidget {
  final VoidCallback? onStart;
  const _MyRouteTab({this.onStart});

  @override
  ConsumerState<_MyRouteTab> createState() => _MyRouteTabState();
}

class _MyRouteTabState extends ConsumerState<_MyRouteTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 이미 route가 로드됐거나 로딩 중이면 재로드 스킵
      // (루틴 상세 → 나의 경로 선택 시 외부에서 loadMyRoute를 먼저 호출하므로 중복 방지)
      final myState = ref.read(myRouteProvider);
      if (myState.isRouteLoading || myState.route != null || myState.isActive) return;
      final routineId = ref.read(homeProvider).activeRoutine?.routineId ?? 0;
      ref.read(myRouteProvider.notifier).loadMyRoute(routineId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myRouteProvider);

    // route 최초 로딩 중
    if (state.isRouteLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.route == null) {
      return _ErrorView(
        message: state.error!,
        onRetry: () => ref.read(myRouteProvider.notifier).loadMyRoute(
              ref.read(homeProvider).activeRoutine?.routineId ?? 0),
      );
    }

    // route 로드 완료 — 시작 전
    if (!state.isActive) {
      return _StartPrompt(
        route: state.route,
        isSectionLoading: state.isSectionLoading,
        description: '나의 설정 경로로 실시간 안내를 시작합니다.',
        buttonLabel: '시작',
        onStart: () async {
                // 추천 경로가 활성화 중이면 나의 경로 시작 불가
                if (ref.read(recoRouteProvider).isActive) return;
                await ref.read(myRouteProvider.notifier).startMyRoute();
                // 바텀시트 진입 시 전달된 콜백 호출 (홈 이동 등)
                widget.onStart?.call();
              },
      );
    }

    // 활성화 — 실시간 경로 표시
    return _RouteDetail(
      route: state.route!,
      currentSection: state.currentSection,
      onStop: () => ref.read(myRouteProvider.notifier).stopMyRoute(),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 추천 경로 탭 — 카드 목록 선택 UI (시안 반영)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _RecoRouteTab extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final VoidCallback? onKeep;
  final VoidCallback? onRouteStarted;
  const _RecoRouteTab({this.scrollController, this.onKeep, this.onRouteStarted});

  @override
  ConsumerState<_RecoRouteTab> createState() => _RecoRouteTabState();
}

class _RecoRouteTabState extends ConsumerState<_RecoRouteTab> {
  bool _hasLaunched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryLoad();
      // incidentDetourProvider를 명시적으로 초기화 — STOMP /user/queue/incident 와
      // /user/queue/detour 구독이 확실히 시작되도록 보장.
      // (provider가 처음 read될 때 IncidentDetourNotifier 생성 → _subscribeAll() 호출)
      ref.read(incidentDetourProvider);
    });
  }

  void _tryLoad() {
    if (!mounted) return;
    final state = ref.read(recoRouteProvider);
    // 이미 로딩 중이면 스킵
    if (state.isRouteLoading) return;
    // 활성 안내 중(경로 변경 완료)이면 스킵
    if (state.isActive) return;
    // recoList 또는 detourList(REST)가 있으면 스킵.
    // detourModelList(STOMP)만 있는 경우 recoList가 비어있을 수 있으므로 로드 허용.
    if (state.error == null && (state.recoList.isNotEmpty ||
        state.detourList.isNotEmpty)) return;

    // ✅ [버그 수정] initializeWithRoutine()이 homeProvider에 recoRouteList를
    // preload한 상태로 진입한 경우, 독자 API 호출 대신 해당 데이터를 그대로 주입.
    // (루틴 상세 → 지금 출발하기 시 추천 경로 탭이 반영 안 되던 원인)
    final homeState = ref.read(homeProvider);
    if (homeState.recoRouteList.isNotEmpty || homeState.detourRouteList.isNotEmpty) {
      ref.read(recoRouteProvider.notifier).preloadList(
        RecoRouteListResponse(
          recoList:        homeState.recoRouteList,
          detourList:      homeState.detourRouteList,
          hasIncident:     homeState.hasIncident,
          incidentMessage: homeState.incidentMessage,
        ),
      );
      return;
    }

    final routineId = ref.read(homeProvider).activeRoutine?.routineId ?? 0;
    ref.read(recoRouteProvider.notifier).loadRecoRouteList(routineId);
  }

  Widget build(BuildContext context) {
    final state = ref.watch(recoRouteProvider);
    // incidentDetourProvider를 watch → STOMP로 incident/detour 수신 시 리빌드 트리거.
    // recoRouteProvider.applyIncidentDetour()가 이미 상태를 머지하지만,
    // provider 생성 타이밍 문제로 첫 수신이 누락될 수 있으므로 이중 안전장치로 watch.
    ref.watch(incidentDetourProvider);

    // ── 이동 중 (경로 변경 완료) → RecoLiveRouteScreen을 rootNavigator overlay로 push
    // 바텀 네비게이션 위로 전체 화면 오버레이되어 표시됨
    if (state.isActive && !_hasLaunched) {
      _hasLaunched = true;
      final activeRecoId = state.selectedRecoId ?? state.selectedDetourPathId ?? 0;
      final isDetour = state.selectedDetourPathId != null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true)
            .push(
          MaterialPageRoute<void>(
            builder: (_) => RecoLiveRouteScreen(
              key: ValueKey('reco_live_$activeRecoId'),
              recoId: activeRecoId,
              isDetour: isDetour,
            ),
          ),
        )
            .then((_) {
          if (mounted) {
            setState(() => _hasLaunched = false);
            ref.read(recoRouteProvider.notifier).stopRecoRoute();
          }
        });
      });
    }

    // isActive が false になったら _hasLaunched をリセット
    if (!state.isActive && _hasLaunched) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hasLaunched = false);
      });
    }

    // ✅ 버그 수정: "이 경로로 변경" 클릭 후 저장/로딩 중 상태 처리
    // isSaving=true 또는 isSectionLoading=true 인 경우 로딩 화면 표시
    // (isActive=false, route=null 상태에서 카드 목록으로 돌아가지 않도록)
    if (state.isSaving || state.isSectionLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              state.isSaving ? '경로를 변경하는 중...' : '구간 정보를 불러오는 중...',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // ── 상세 오버레이
    if (state.detailRoute != null || state.isDetailLoading) {
      final detailRoute = state.detailRoute;
      final isDetourDetail = detailRoute?.isDetour ?? false;
      return _RecoDetailOverlay(
        route: detailRoute,
        isLoading: state.isDetailLoading,
        isDetour: isDetourDetail,
        isSelected: detailRoute != null && (
          isDetourDetail
            ? state.selectedDetourPathId == detailRoute.recoId
            : state.selectedRecoId == detailRoute.recoId
        ),
        onBack: () => ref.read(recoRouteProvider.notifier).closeDetail(),
        onSelect: detailRoute == null
            ? null
            : () {
                if (isDetourDetail) {
                  ref.read(recoRouteProvider.notifier).selectDetour(detailRoute.recoId);
                } else {
                  ref.read(recoRouteProvider.notifier).selectReco(detailRoute.recoId);
                }
                ref.read(recoRouteProvider.notifier).closeDetail();
              },
      );
    }

    // ── 로딩
    if (state.isRouteLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ── 에러
    if (state.error != null && state.recoList.isEmpty && state.detourList.isEmpty) {
      return _ErrorView(
        message: state.error!,
        onRetry: () {
          // 에러 재시도: 가드를 무시하고 강제 재로드
          ref.read(recoRouteProvider.notifier).loadRecoRouteList(
              ref.read(homeProvider).activeRoutine?.routineId ?? 0, force: true);
        },
      );
    }

    // ── 목록 없음 (추천 경로도, 우회 경로도 없을 때)
    final hasIncident = state.hasIncident;
    final detourModelList = state.detourModelList; // STOMP push 우회 경로
    final detourList = state.detourList;            // REST 응답 우회 경로
    final recoList   = state.recoList;

    if (recoList.isEmpty && detourList.isEmpty && detourModelList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '추천 경로가 없습니다.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () =>
                  ref.read(recoRouteProvider.notifier).loadRecoRouteList(
                      ref.read(homeProvider).activeRoutine?.routineId ?? 0, force: true),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    // 전체 아이템 목록 구성
    // detour 있음 → [배너(incident 있을 때), 우회 섹션, ...detour 카드, 추천 섹션, ...reco 카드]
    // detour 없음 → [추천 섹션, ...reco 카드]
    final hasDetour = detourModelList.isNotEmpty || detourList.isNotEmpty;
    final items = <_ListItem>[];
    if (hasDetour) {
      // 배너는 incident 메시지가 있을 때만 (detour만 온 경우에도 hasIncident=true로 설정됨)
      if (hasIncident) {
        items.add(const _ListItem.incidentBanner());
      }
      // STOMP로 받은 DetourModel 카드
      if (detourModelList.isNotEmpty) {
        items.add(const _ListItem.sectionLabel(isDetour: true));
        for (final d in detourModelList) {
          items.add(_ListItem.detourCard(d));
        }
      }
      // REST 응답 우회 경로 카드 (fallback)
      if (detourModelList.isEmpty && detourList.isNotEmpty) {
        items.add(const _ListItem.sectionLabel(isDetour: true));
        for (final r in detourList) {
          items.add(_ListItem.routeCard(r, isDetour: true));
        }
      }
    }
    items.add(const _ListItem.sectionLabel(isDetour: false));
    for (final r in recoList) {
      items.add(_ListItem.routeCard(r, isDetour: false));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: items.length,
            separatorBuilder: (_, i) {
              final item = items[i];
              if (item.type == _ItemType.incidentBanner) return const SizedBox(height: 8);
              if (item.type == _ItemType.sectionLabel) return const SizedBox(height: 6);
              return const SizedBox(height: 10);
            },
            itemBuilder: (context, i) {
              final item = items[i];
              switch (item.type) {
                case _ItemType.incidentBanner:
                  return _IncidentBanner(
                    message: state.incidentMessage ??
                        '현재 경로에 돌발 상황이 발생했어요. 우회 경로를 확인해 보세요.',
                  );
                case _ItemType.sectionLabel:
                  return _SectionLabel(isDetour: item.isDetour);
                case _ItemType.detourModelCard:
                  final detour = item.detourModel!;
                  final isDetourSelected = state.selectedDetourPathId == detour.pathId;
                  return _DetourModelCard(
                    detour: detour,
                    isSelected: isDetourSelected,
                    onTap: () => ref
                        .read(recoRouteProvider.notifier)
                        .selectDetour(detour.pathId),
                    onDetailTap: () => ref
                        .read(recoRouteProvider.notifier)
                        .loadDetourDetail(detour.pathId),
                  );
                case _ItemType.routeCard:
                  final route = item.route!;
                  final isSelected = item.isDetour
                      ? state.selectedDetourPathId == route.recoId
                      : state.selectedRecoId == route.recoId;
                  return _RecoRouteCard(
                    route: route,
                    isSelected: isSelected,
                    isDetour: item.isDetour,
                    onTap: () {
                      if (item.isDetour) {
                        ref.read(recoRouteProvider.notifier).selectDetour(route.recoId);
                      } else {
                        ref.read(recoRouteProvider.notifier).selectReco(route.recoId);
                      }
                    },
                    onDetailTap: () {
                      if (item.isDetour) {
                        ref.read(recoRouteProvider.notifier).loadDetourDetail(route.recoId);
                      } else {
                        ref.read(recoRouteProvider.notifier).loadRecoDetail(route.recoId);
                      }
                    },
                  );
              }
            },
          ),
        ),
        // ── 하단 버튼
        _RecoRouteFooter(
          selectedRecoId: state.selectedRecoId,
          selectedDetourPathId: state.selectedDetourPathId,
          selectedRoute: state.selectedRecoId == null
              ? null
              : () {
                  final matches = [...detourList, ...recoList]
                      .where((r) => r.recoId == state.selectedRecoId)
                      .toList();
                  return matches.isEmpty ? null : matches.first;
                }(),
          isSaving: state.isSaving || state.isSectionLoading,
          onKeep: widget.onKeep ?? () => Navigator.of(context).pop(),
          onSwitch: () async {
            // 우회 경로 선택 시 → POST /me/routines/active/reco/detour/{pathId}
            final detourId = state.selectedDetourPathId;
            if (detourId != null) {
              if (!context.mounted) return;
              // 인라인 표시: Navigator.push 대신 recoRouteProvider.saveAndStartDetourRoute 호출
              // → isActive=true가 되면 _RecoRouteTab build()에서 RecoLiveRouteScreen이 인라인으로 표시됨
              await ref
                  .read(recoRouteProvider.notifier)
                  .saveAndStartDetourRoute(detourId);
              if (context.mounted) widget.onRouteStarted?.call();
              return;
            }
            // 추천 경로 선택 시 → POST /me/routines/active/reco/{recoId}
            final id = state.selectedRecoId;
            if (id == null) return;
            // 나의 경로가 활성화 중이면 추천 경로 시작 불가
            if (ref.read(myRouteProvider).isActive) return;
            // homeProvider에 isUsingRecoRoute=true 반영 → liveLocationProvider가
            // 이후 GPS를 /app/reco로 전송하여 서버가 /user/queue/location/reco를 push
            await ref
                .read(homeProvider.notifier)
                .switchToRecommendedRoute(id);
            if (!context.mounted) return;
            // 인라인 표시: Navigator.push 대신 recoRouteProvider.saveAndStartRecoRoute 호출
            await ref
                .read(recoRouteProvider.notifier)
                .saveAndStartRecoRoute(id);
            if (context.mounted) widget.onRouteStarted?.call();
          },
        ),
      ],
    );
  }
}

// ── 목록 아이템 타입 ────────────────────────────────────────────────────────

enum _ItemType { incidentBanner, sectionLabel, routeCard, detourModelCard }

class _ListItem {
  final _ItemType type;
  final bool isDetour;
  final RouteModel? route;
  final DetourModel? detourModel;

  const _ListItem._({required this.type, this.isDetour = false, this.route, this.detourModel});

  const _ListItem.incidentBanner()
      : type = _ItemType.incidentBanner,
        isDetour = false,
        route = null,
        detourModel = null;

  const _ListItem.sectionLabel({required bool isDetour})
      : type = _ItemType.sectionLabel,
        this.isDetour = isDetour,
        route = null,
        detourModel = null;

  _ListItem.routeCard(RouteModel r, {required bool isDetour})
      : type = _ItemType.routeCard,
        this.isDetour = isDetour,
        route = r,
        detourModel = null;

  _ListItem.detourCard(DetourModel d)
      : type = _ItemType.detourModelCard,
        isDetour = true,
        route = null,
        detourModel = d;
}

// ── 돌발 사고 배너 ──────────────────────────────────────────────────────────

class _IncidentBanner extends StatelessWidget {
  const _IncidentBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAEEDA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF9F27), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFFFAC775),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded,
                size: 15, color: Color(0xFF633806)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '돌발 사고 발생',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF633806),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF854F0B),
                    height: 1.5,
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

// ── 섹션 레이블 ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.isDetour});
  final bool isDetour;

  @override
  Widget build(BuildContext context) {
    final color = isDetour ? const Color(0xFF185FA5) : AppColors.primary;
    final label = isDetour ? '우회 경로' : '추천 경로';
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2, right: 2, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 우회 경로 카드 (STOMP DetourModel용) ────────────────────────────────

class _DetourModelCard extends StatefulWidget {
  const _DetourModelCard({
    required this.detour,
    required this.isSelected,
    required this.onTap,
    required this.onDetailTap,
  });

  final DetourModel detour;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDetailTap;

  @override
  State<_DetourModelCard> createState() => _DetourModelCardState();
}

class _DetourModelCardState extends State<_DetourModelCard> {
  @override
  Widget build(BuildContext context) {
    final detour = widget.detour;
    final isSelected = widget.isSelected;
    const accentColor = Color(0xFF185FA5);

    final totalMin = detour.totalDurationMin.round();


    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFFECECEC),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 상단: 라디오 + 정보 + 상세보기
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 라디오 버튼
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? accentColor : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? accentColor : const Color(0xFFCCCCCC),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Center(
                              child: CircleAvatar(
                                radius: 3,
                                backgroundColor: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 경로 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 교통수단 칩 행
                        _DetourSegmentChipRow(segments: detour.pathSegments),
                        const SizedBox(height: 6),
                        // 소요시간
                        Text(
                          '$totalMin분',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 환승
                        Row(
                          children: [
                            const Icon(Icons.sync_alt_rounded,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              detour.transferCount > 0
                                  ? '환승 ${detour.transferCount}회'
                                  : '환승 없음',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 상세보기
                  GestureDetector(
                    onTap: widget.onDetailTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          '상세보기',
                          style: TextStyle(
                            fontSize: 11,
                            color: accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 14, color: accentColor),
                      ],
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

// ── 우회 경로 교통수단 칩 행 ──────────────────────────────────────────────

class _DetourSegmentChipRow extends StatelessWidget {
  const _DetourSegmentChipRow({required this.segments});
  final List<DetourSegmentModel> segments;

  @override
  Widget build(BuildContext context) {
    // 도보(TRANSFER)는 아이콘으로, 대중교통(TRANSIT)은 칩으로
    final items = <Widget>[];
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (i > 0) {
        items.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Icon(Icons.arrow_forward,
              size: 12, color: AppColors.textSecondary),
        ));
      }
      if (seg.isWalk) {
        items.add(const Icon(Icons.directions_walk,
            size: 18, color: AppColors.textSecondary));
      } else {
        final bgColor = seg.isSubway ? AppColors.subwayBg : AppColors.busBg;
        final textColor = seg.isSubway ? const Color(0xFF0C447C) : AppColors.bus;
        items.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            seg.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ));
      }
    }
    return Wrap(
      spacing: 0,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items,
    );
  }
}


// ── 추천 경로 카드 ────────────────────────────────────────────────────────

class _RecoRouteCard extends StatefulWidget {
  const _RecoRouteCard({
    required this.route,
    required this.isSelected,
    required this.isDetour,
    required this.onTap,
    required this.onDetailTap,
  });

  final RouteModel route;
  final bool isSelected;
  final bool isDetour;
  final VoidCallback onTap;
  final VoidCallback onDetailTap;

  @override
  State<_RecoRouteCard> createState() => _RecoRouteCardState();
}

class _RecoRouteCardState extends State<_RecoRouteCard> {
  // 각 path 인덱스별 정류장 목록 펼침 여부
  final Map<int, bool> _expandedStops = {};

  void _toggleStops(int pathIndex) {
    setState(() {
      _expandedStops[pathIndex] = !(_expandedStops[pathIndex] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final isSelected = widget.isSelected;
    final isDetour = widget.isDetour;
    final accentColor = isDetour ? const Color(0xFF185FA5) : AppColors.primary;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFFECECEC),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 상단: 라디오 + 정보 + 상세보기
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 라디오 버튼
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? accentColor : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? accentColor
                              : const Color(0xFFCCCCCC),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Center(
                              child: CircleAvatar(
                                radius: 3,
                                backgroundColor: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 경로 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 교통수단 칩 행
                        _TransportChipRow(path: route.path),
                        const SizedBox(height: 6),
                        // 소요시간 + 요금
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${route.totalTime}분',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (!widget.isDetour && route.payment > 0)
                              Text(
                                _formatFare(route.payment),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            if (route.timeDelta != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                route.timeDelta!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF185FA5),
                                ),
                              ),
                            ],
                            if (route.isCurrent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAECE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '이용 중',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF993C1D),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 거리 + 환승
                        Row(
                          children: [
                            if (route.totalDistance > 0) ...[
                              const Icon(Icons.map_outlined,
                                  size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 3),
                              Text(
                                _formatDist(route.totalDistance),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 10),
                            ],
                            const Icon(Icons.sync_alt_rounded,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              _transferLabel(route.path),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 상세보기
                  GestureDetector(
                    onTap: widget.onDetailTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          '상세보기',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF185FA5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 14, color: Color(0xFF185FA5)),
                      ],
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

  String _formatFare(int fare) {
    final s = fare.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf}원';
  }

  String _formatDist(int m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)}km' : '${m}m';

  String _transferLabel(List<PathModel> path) {
    final transits = path.where((p) => !p.isWalking).length;
    if (transits <= 1) return '환승 없음';
    return '환승 ${transits - 1}회';
  }

  IconData _iconForPath(PathModel p) {
    if (p.isSubway) return Icons.directions_subway_rounded;
    if (p.isBus) return Icons.directions_bus_rounded;
    return Icons.directions_walk_rounded;
  }

  Color _bgForPath(PathModel p) {
    if (p.isSubway) return AppColors.subwayBg;
    if (p.isBus) return AppColors.busBg;
    return AppColors.walkBg;
  }

  Color _iconColorForPath(PathModel p) {
    if (p.isSubway) return AppColors.subway;
    if (p.isBus) return AppColors.bus;
    return AppColors.walk;
  }

  String _labelForPath(PathModel p) {
    if (p.isSubway) return '${p.subwayLineName} 지하철';
    if (p.isBus) {
      final start = p.start;
      if (start != null && start.isNotEmpty) return '$start 승차';
      return '버스 승차';
    }
    return '도보 이동';
  }
}

// ── 서브 칩 (노선번호 / 정거장 수 등) ──────────────────────────────────────
class _SubChip extends StatelessWidget {
  const _SubChip({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ── 교통수단 칩 행 ──────────────────────────────────────────────────────

class _TransportChipRow extends StatelessWidget {
  const _TransportChipRow({required this.path});
  final List<PathModel> path;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    for (int i = 0; i < path.length; i++) {
      final p = path[i];
      if (i > 0) {
        widgets.add(const Text('›',
            style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 12)));
        widgets.add(const SizedBox(width: 4));
      }
      if (p.isWalking) {
        widgets.add(const Icon(Icons.directions_walk_rounded,
            size: 14, color: Color(0xFFAAAAAA)));
      } else if (p.isSubway) {
        widgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.subwayBg,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              p.subwayLineName,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0C447C),
              ),
            ),
          ),
        );
      } else if (p.isBus) {
        widgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.busBg,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              p.busNumbersLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF633806),
              ),
            ),
          ),
        );
      }
      widgets.add(const SizedBox(width: 4));
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      children: widgets,
    );
  }
}

// ── 추천 경로 하단 버튼 ───────────────────────────────────────────────────

class _RecoRouteFooter extends StatelessWidget {
  const _RecoRouteFooter({
    required this.selectedRecoId,
    required this.selectedDetourPathId,
    required this.selectedRoute,
    required this.isSaving,
    required this.onKeep,
    required this.onSwitch,
  });

  final int? selectedRecoId;
  final int? selectedDetourPathId;
  final RouteModel? selectedRoute;
  final bool isSaving;
  final VoidCallback onKeep;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final hasDetourSelected = selectedDetourPathId != null;
    final isCurrentSelected = selectedRoute?.isCurrent == true;
    final canSwitch = (selectedRecoId != null || hasDetourSelected) &&
        !isSaving && !isCurrentSelected;
    final isDetourSelected = hasDetourSelected || (selectedRoute?.isDetour == true);
    final btnColor = isDetourSelected
        ? const Color(0xFF185FA5)
        : AppColors.primary;

    String btnLabel;
    if (isCurrentSelected) {
      btnLabel = '현재 이용 중인 경로';
    } else {
      btnLabel = '이 경로로 변경';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E5E5), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onKeep,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD0D0D0)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '현재 경로 유지',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: canSwitch ? onSwitch : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                disabledBackgroundColor: const Color(0xFFE8E8E8),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      btnLabel,
                      style: TextStyle(
                        color: (canSwitch || isCurrentSelected)
                            ? Colors.white
                            : const Color(0xFFBBBBBB),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 추천 경로 상세 오버레이 ──────────────────────────────────────────────

class _RecoDetailOverlay extends StatelessWidget {
  const _RecoDetailOverlay({
    required this.route,
    required this.isLoading,
    required this.onBack,
    this.onSelect,
    this.isSelected = false,
    this.isDetour = false,
  });

  final RouteModel? route;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback? onSelect;
  final bool isSelected;
  final bool isDetour;

  String _formatPayment(int p) {
    final s = p.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 헤더 — 이미지4 스타일
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Color(0xFF444444)),
              ),
              const SizedBox(width: 10),
              const Text('경로 상세',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // 컨텐츠
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : route == null
                  ? const Center(child: Text('정보를 불러오지 못했어요.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 요약 — 이미지4: 큰 분 + 아이콘 요금·거리
                          Text(
                            '${route!.totalTime}분',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (!isDetour && route!.payment > 0) ...[
                                const Icon(Icons.monetization_on_outlined,
                                    size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 3),
                                Text('${_formatPayment(route!.payment)}원',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary)),
                                const SizedBox(width: 14),
                              ],
                              if (route!.totalDistance > 0) ...[
                                const Icon(Icons.straighten_outlined,
                                    size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 3),
                                Text(
                                  route!.totalDistance >= 1000
                                      ? '${(route!.totalDistance / 1000).toStringAsFixed(1)}km'
                                      : '${route!.totalDistance}m',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                          const SizedBox(height: 20),
                          const Text('경로 안내',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              )),
                          const SizedBox(height: 14),
                          // 단계 목록 — _DetailPathItem 스타일
                          ...route!.path.asMap().entries.map((e) {
                            return _RecoDetailPathItem(
                              path: e.value,
                              isLast: e.key == route!.path.length - 1,
                            );
                          }),
                        ],
                      ),
                    ),
        ),
        // 선택 버튼 (하단 고정)
        if (!isLoading && route != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E5E5), width: 0.5)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSelect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? const Color(0xFF4CAF50) : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      isSelected ? '선택됨' : '이 경로 선택',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── 추천경로 상세보기 단계 아이템 (_DetailPathItem 스타일) ────────────────────

class _RecoDetailPathItem extends StatefulWidget {
  const _RecoDetailPathItem({required this.path, required this.isLast});
  final PathModel path;
  final bool isLast;

  @override
  State<_RecoDetailPathItem> createState() => _RecoDetailPathItemState();
}

class _RecoDetailPathItemState extends State<_RecoDetailPathItem> {
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

    final IconData icon = path.isWalking
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
        // 왼쪽 타임라인
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
              ),
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
        // 오른쪽 내용
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 타이틀 + 펼치기 아이콘
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
                // 지하철 노선 + 방향 칩 (이미지2: 다크 pill + 아웃라인 pill)
                if (path.isSubway && path.subwayLineName.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // 노선명 — 다크 배경 흰 글씨
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF44403C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(path.subwayLineName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                      // 방향 — 회색 아웃라인 pill
                      if (path.way != null && path.way!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFD4D4D0), width: 1),
                          ),
                          child: Text('${path.way} 방향',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF57534E))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                // 버스 번호 칩 — 다크 배경 흰 글씨 (이미지2 스타일)
                if (path.isBus && path.busNumbers.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: path.busNumbers
                        .map((n) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF44403C),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${n}번',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                ],
                // 시간 + 정거장 수 — 연회색 pill (이미지2 스타일)
                Wrap(
                  spacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EFED),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${path.sectionTime}분',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF57534E))),
                    ),
                    if (hasStations && !path.isWalking)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EFED),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(path.stationCountLabel,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF57534E))),
                      ),
                  ],
                ),
                // 정류장 목록 (펼침)
                if (hasStations && _expanded) ...[
                  const SizedBox(height: 8),
                  ...path.stationName.asMap().entries.map((e) {
                    final isFirst = e.key == 0;
                    final isLastStation =
                        e.key == path.stationName.length - 1;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 16,
                          child: Column(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (isFirst || isLastStation)
                                      ? color
                                      : color.withValues(alpha: 0.3),
                                  border:
                                      Border.all(color: color, width: 1.5),
                                ),
                              ),
                              if (!isLastStation)
                                Container(
                                  width: 2,
                                  height: 20,
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 시작 전 화면 — route 미리 표시 + 버튼
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _StartPrompt extends StatelessWidget {
  const _StartPrompt({
    required this.route,
    required this.isSectionLoading,
    required this.description,
    required this.buttonLabel,
    required this.onStart,
  });

  final LiveRouteModel? route;
  final bool isSectionLoading;
  final String description;
  final String buttonLabel;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // route가 이미 로드됐으면 미리 보여줌
          if (route != null) ...[
            _RouteSummaryRow(route: route!),
            const SizedBox(height: 16),
            ...route!.path.asMap().entries.map(
              (e) => _PathSegmentCard(
                path: e.value,
                index: e.key,
                isLast: e.key == route!.path.length - 1,
                currentSection: null, // 시작 전 → 색칠 없음
              ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            const SizedBox(height: 32),
            Center(
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          // 시작 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSectionLoading ? null : onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSectionLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 에러 뷰
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 활성화 경로 상세 화면
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _RouteDetail extends StatelessWidget {
  const _RouteDetail({
    required this.route,
    required this.currentSection,
    required this.onStop,
  });

  final LiveRouteModel route;
  final CurrentSectionModel? currentSection;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RouteSummaryRow(route: route),
          const SizedBox(height: 16),

          if (currentSection != null) ...[
            _CurrentSectionBanner(section: currentSection!, route: route),
            const SizedBox(height: 16),
          ],

          ...route.path.asMap().entries.map(
            (e) => _PathSegmentCard(
              path: e.value,
              index: e.key,
              isLast: e.key == route.path.length - 1,
              currentSection: currentSection,
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onStop,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '경로 안내 종료',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 요약 칩 행
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _RouteSummaryRow extends StatelessWidget {
  const _RouteSummaryRow({required this.route});
  final LiveRouteModel route;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SummaryChip(
          label: '${route.totalTime}분',
          backgroundColor: AppColors.chipTimeBg,
          textColor: AppColors.chipTime,
        ),
        if (route.payment > 0)
          _SummaryChip(
            label: '${route.payment}원',
            backgroundColor: AppColors.chipRouteBg,
            textColor: AppColors.chipRoute,
          ),
        if (route.totalDistance > 0)
          _SummaryChip(
            label: _formatDistance(route.totalDistance),
            backgroundColor: AppColors.chipStopsBg,
            textColor: AppColors.chipStops,
          ),
      ],
    );
  }

  String _formatDistance(int meters) =>
      meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)}km' : '${meters}m';
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 현재 위치 배너 (LIVE)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _CurrentSectionBanner extends StatelessWidget {
  const _CurrentSectionBanner({required this.section, required this.route});
  final CurrentSectionModel section;
  final LiveRouteModel route;

  @override
  Widget build(BuildContext context) {
    final current = section.currentXY;
    final sectionType = section.currentType;

    final (icon, color, label) = switch (sectionType) {
      'bus'    => (
          Icons.directions_bus_rounded,
          AppColors.bus,
          '버스 탑승 중 · ${section.currentBusNo ?? ''}번',
        ),
      'subway' => (
          Icons.directions_subway_rounded,
          AppColors.subway,
          '지하철 탑승 중 · ${section.currentSubwayLine ?? ''}',
        ),
      _ => (Icons.directions_walk_rounded, AppColors.walk, '도보 이동 중'),
    };

    // 현재 구간 이후 다음 구간 파악
    final paths = route.path;
    final currentIdx = section.idx;
    // section.idx 기반으로 현재 PathModel 인덱스 추정 (축적 구간 매핑)
    String? nextLabel;
    if (paths.isNotEmpty) {
      // 현재 타입과 다음 타입 확인
      // 현재 sectionType 기준으로 현재 path를 찾고, 그 다음 path를 가져옴
      int? currentPathIdx;
      for (int i = 0; i < paths.length; i++) {
        final p = paths[i];
        if (sectionType == 'walk' && p.isWalking) { currentPathIdx = i; break; }
        if (sectionType == 'bus' && p.isBus) { currentPathIdx = i; break; }
        if (sectionType == 'subway' && p.isSubway) { currentPathIdx = i; break; }
      }
      if (currentPathIdx != null && currentPathIdx + 1 < paths.length) {
        final next = paths[currentPathIdx + 1];
        if (next.isWalking) nextLabel = '도보';
        else if (next.isBus) nextLabel = '버스 ${next.busNumbersLabel}';
        else if (next.isSubway) nextLabel = '지하철 ${next.subwayLineName}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 현재 구간 → 다음 구간 표시
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (nextLabel != null) ...[ 
                      Text(
                        ' → ',
                        style: TextStyle(
                          color: color.withOpacity(0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        nextLabel,
                        style: TextStyle(
                          color: color.withOpacity(0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                if (current?.stationName != null)
                  Text(
                    '현재 위치: ${current!.stationName!}',
                    style: TextStyle(
                      color: color.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          _LiveBadge(),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 구간 카드 — idx 기준 색칠 로직 포함
//
// [색칠 규칙]
// currentSection이 없으면 모두 기본색(회색)
// currentSection이 있으면:
//   - xy[0] ~ xy[idx] 범위에 속하는 정류장 → 완료/진행 색 (primary)
//   - xy[idx+1] 이후 정류장 → 미도달 색 (border/dim)
//   - idx가 이 PathModel에 해당하는 구간 안에 있으면 → 현재 구간 강조
//
// [구간↔xy 매핑]
// CurrentSectionModel.section 배열과 xy 배열은 1:1 대응
// PathModel의 순서(path index)와 section 배열은 직접 매핑되지 않으므로
// PathModel의 타입·번호로 section 식별자를 찾아 xy 인덱스 범위를 결정
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PathSegmentCard extends StatelessWidget {
  const _PathSegmentCard({
    required this.path,
    required this.index,
    required this.isLast,
    required this.currentSection,
  });

  final PathModel path;
  final int index;
  final bool isLast;
  final CurrentSectionModel? currentSection;

  // 이 PathModel에 해당하는 section 식별자 목록
  // walk → 'walk', bus:5535 → 'bus:5535', subway:2호선 → 'subway:2호선'
  List<String> _sectionKeysForPath() {
    if (path.isWalking) return ['walk'];
    if (path.isBus) return path.busNumbers.map((n) => 'bus:$n').toList();
    if (path.isSubway) return path.no.map((n) {
      // subwayLineName 정규화 적용
      final name = path.subwayLineName; // "2호선" 등
      return 'subway:$name';
    }).toList();
    return [];
  }

  /// 이 구간에 해당하는 xy 인덱스 범위 [start, end] 반환
  /// 없으면 null
  _XyRange? _xyRangeForPath(CurrentSectionModel cs) {
    final keys = _sectionKeysForPath();
    int? start;
    int? end;
    for (int i = 0; i < cs.section.length; i++) {
      final s = cs.section[i];
      final match = keys.any((k) => s == k || s.contains(k.split(':').last));
      if (match) {
        start ??= i;
        end = i;
      } else if (start != null) {
        break; // 연속 구간이 끝났으면 중단
      }
    }
    if (start == null) return null;
    return _XyRange(start!, end!);
  }

  /// 현재 구간인지 (idx가 이 path 범위 안)
  bool _isCurrent(CurrentSectionModel cs) {
    final range = _xyRangeForPath(cs);
    if (range == null) return false;
    return cs.idx >= range.start && cs.idx <= range.end;
  }

  /// 이 구간이 이미 완료된 구간인지 (idx가 range.end 초과)
  bool _isDone(CurrentSectionModel cs) {
    final range = _xyRangeForPath(cs);
    if (range == null) return false;
    return cs.idx > range.end;
  }

  @override
  Widget build(BuildContext context) {
    final cs = currentSection;
    final isCurrent = cs != null && _isCurrent(cs);
    final isDone = cs != null && _isDone(cs);

    // 타임라인 색상 결정
    final timelineColor = isDone
        ? AppColors.primary           // 완료 구간 → primary 색
        : isCurrent
            ? AppColors.primary       // 현재 구간 → primary 색
            : cs != null
                ? AppColors.border    // 미도달 구간 → dim
                : AppColors.border;   // 시작 전 → 기본

    // 연결선 색상 (현재 이후는 dim)
    final lineColor = isDone ? AppColors.primary : AppColors.border;

    final (iconData, iconColor, bgColor) = switch (path.type) {
      'subway' => (Icons.directions_subway_rounded, AppColors.subway, AppColors.subwayBg),
      'bus'    => (Icons.directions_bus_rounded, AppColors.bus, AppColors.busBg),
      _        => (Icons.directions_walk_rounded, AppColors.walk, AppColors.walkBg),
    };

    // 아이콘 원 색상
    final Color circleBg;
    final Color circleIcon;
    if (isCurrent) {
      circleBg = AppColors.primary;
      circleIcon = Colors.white;
    } else if (isDone) {
      circleBg = AppColors.primary.withOpacity(0.15);
      circleIcon = AppColors.primary;
    } else if (cs != null) {
      // 미도달
      circleBg = AppColors.border.withOpacity(0.5);
      circleIcon = AppColors.textSecondary.withOpacity(0.4);
    } else {
      circleBg = bgColor;
      circleIcon = iconColor;
    }

    // 텍스트 opacity (미도달이면 dim)
    final double textOpacity = (cs != null && !isCurrent && !isDone) ? 0.4 : 1.0;

    // 현재 구간 내 정류장 목록 (색칠 포함)
    final List<_StationProgress> stations = _buildStations(cs);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 타임라인
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: circleBg,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: AppColors.primary, width: 2)
                        : null,
                  ),
                  child: Icon(iconData, color: circleIcon, size: 18),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: lineColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 내용
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Opacity(
                opacity: textOpacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 구간 제목 행
                    Row(
                      children: [
                        Text(
                          path.typeLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '현재',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          '${path.sectionTime}분',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (path.isSubway)
                      Text(path.subwayLineName,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    if (path.isBus)
                      Text(path.busNumbersLabel,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    if (path.start != null && path.end != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${path.start} → ${path.end}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    if (!path.isWalking && path.displayStationCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.chipStopsBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            path.stationCountLabel,
                            style: const TextStyle(
                              color: AppColors.chipStops,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    // 정류장 진행 표시 (현재 구간만)
                    if (stations.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _StationProgressRow(stations: stations),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 이 path에 속하는 정류장 목록과 각 정류장의 도달 여부를 계산
  /// idx까지 도달 = 색칠, idx 초과 = 미도달
  List<_StationProgress> _buildStations(CurrentSectionModel? cs) {
    if (cs == null) return [];
    final range = _xyRangeForPath(cs);
    if (range == null) return [];

    final result = <_StationProgress>[];
    for (int i = range.start; i <= range.end; i++) {
      if (i >= cs.xy.length) break;
      final xy = cs.xy[i];
      final name = xy.stationName;
      if (name == null) continue;
      // idx까지(포함)는 도달, idx 이후는 미도달
      result.add(_StationProgress(
        name: name,
        isReached: i <= cs.idx, // idx 포함까지 색칠
      ));
    }
    return result;
  }
}

class _XyRange {
  final int start;
  final int end;
  const _XyRange(this.start, this.end);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 정류장 진행 표시 위젯 (A●━━━━●━━━━◯ B)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _StationProgress {
  final String name;
  final bool isReached; // true = 지나온/현재, false = 아직 미도달

  const _StationProgress({required this.name, required this.isReached});
}

class _StationProgressRow extends StatelessWidget {
  const _StationProgressRow({required this.stations});
  final List<_StationProgress> stations;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: stations.asMap().entries.map((e) {
        final i = e.key;
        final s = e.value;
        final isLast = i == stations.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽 도트 + 연결선
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.isReached ? AppColors.primary : AppColors.border,
                      border: s.isReached
                          ? null
                          : Border.all(color: AppColors.border),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 20,
                      color: s.isReached
                          ? AppColors.primary.withOpacity(0.4)
                          : AppColors.border,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  s.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: s.isReached
                        ? AppColors.textPrimary
                        : AppColors.textSecondary.withOpacity(0.5),
                    fontWeight:
                        s.isReached ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Public wrapper — home_screen.dart에서 추천 경로 탭 내용으로 사용
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class RecoRouteTabContent extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  /// 추천 경로 탭에서 "현재 경로 유지" 버튼을 눌렀을 때 호출되는 콜백.
  /// DraggableScrollableSheet 안의 TabBarView에서 사용할 때는 Navigator.pop() 대신
  /// TabController.animateTo(0) 등으로 탭을 전환하도록 호출자가 구현해야 한다.
  final VoidCallback? onKeep;
  /// 추천 경로 안내가 시작(경로 변경 완료)될 때 호출되는 콜백.
  /// 루틴 상세 바텀시트 진입 시 홈 이동 등 추가 동작을 수행할 수 있다.
  final VoidCallback? onRouteStarted;
  const RecoRouteTabContent({super.key, this.scrollController, this.onKeep, this.onRouteStarted});

  @override
  ConsumerState<RecoRouteTabContent> createState() => _RecoRouteTabContentState();
}

class _RecoRouteTabContentState extends ConsumerState<RecoRouteTabContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryLoad();
    });
  }

  void _tryLoad() {
    if (!mounted) return;
    final state = ref.read(recoRouteProvider);
    if (state.isRouteLoading) return;
    if (state.isActive) return;
    // recoList 또는 detourList(REST)가 이미 있으면 스킵
    if (state.error == null && (state.recoList.isNotEmpty ||
        state.detourList.isNotEmpty)) return;

    // ✅ [버그 수정] initializeWithRoutine() / initialize()가 homeProvider에
    // preload한 데이터가 있으면 독자 API 호출 없이 해당 데이터를 주입.
    // (루틴 상세 → 지금 출발하기 경로에서 추천 경로 탭 미반영 버그 수정)
    final homeState = ref.read(homeProvider);
    if (homeState.recoRouteList.isNotEmpty || homeState.detourRouteList.isNotEmpty) {
      ref.read(recoRouteProvider.notifier).preloadList(
        RecoRouteListResponse(
          recoList:        homeState.recoRouteList,
          detourList:      homeState.detourRouteList,
          hasIncident:     homeState.hasIncident,
          incidentMessage: homeState.incidentMessage,
        ),
      );
      return;
    }

    // ✅ [버그 수정] routineId를 homeProvider.activeRoutine에서 가져와
    // getRecoRouteListResponse(routineId)에 올바르게 전달
    final routineId = homeState.activeRoutine?.routineId ?? 0;
    ref.read(recoRouteProvider.notifier).loadRecoRouteList(routineId);
  }

  @override
  Widget build(BuildContext context) => _RecoRouteTab(
    scrollController: widget.scrollController,
    onKeep: widget.onKeep,
    onRouteStarted: widget.onRouteStarted,
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Public wrapper — home_screen.dart에서 나의 경로 탭 내용으로 사용
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class MyRouteTabContent extends ConsumerStatefulWidget {
  /// 나의 경로 안내가 시작될 때 호출되는 콜백.
  /// 루틴 상세에서 바텀시트를 통해 진입할 때 홈 이동 등 추가 동작을 수행할 수 있다.
  final VoidCallback? onStart;
  const MyRouteTabContent({super.key, this.onStart});

  @override
  ConsumerState<MyRouteTabContent> createState() => _MyRouteTabContentState();
}

class _MyRouteTabContentState extends ConsumerState<MyRouteTabContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final myState = ref.read(myRouteProvider);
      if (myState.isRouteLoading || myState.route != null || myState.isActive) return;
      final routineId = ref.read(homeProvider).activeRoutine?.routineId ?? 0;
      ref.read(myRouteProvider.notifier).loadMyRoute(routineId);
    });
  }

  @override
  Widget build(BuildContext context) => _MyRouteTab(onStart: widget.onStart);
}