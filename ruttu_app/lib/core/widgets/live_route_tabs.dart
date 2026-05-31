import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/route_model.dart';
import '../providers/live_route_provider.dart';

/// 나의 경로 / 추천 경로 탭 UI
///
/// 사용법:
/// ```dart
/// LiveRouteTabs()
/// ```
///
/// ProviderScope 상위에 homeRepositoryProvider 가 override 되어 있어야 합니다.
class LiveRouteTabs extends ConsumerWidget {
  const LiveRouteTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(selectedRouteTabProvider);

    return Column(
      children: [
        // ── 탭 헤더 ────────────────────────────────────────
        _TabBar(currentTab: tab, onTabChanged: (t) {
          ref.read(selectedRouteTabProvider.notifier).state = t;
        }),
        const SizedBox(height: 16),
        // ── 탭 본문 ────────────────────────────────────────
        // IndexedStack 으로 두 탭을 살려두어 상태가 유지됨
        Expanded(
          child: IndexedStack(
            index: tab == RouteTab.my ? 0 : 1,
            children: const [
              _MyRouteTab(),
              _RecoRouteTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 탭 바 ────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.currentTab, required this.onTabChanged});

  final RouteTab currentTab;
  final void Function(RouteTab) onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabChip(
          label: '나의 경로',
          isSelected: currentTab == RouteTab.my,
          onTap: () => onTabChanged(RouteTab.my),
        ),
        const SizedBox(width: 8),
        _TabChip(
          label: '추천 경로',
          isSelected: currentTab == RouteTab.reco,
          onTap: () => onTabChanged(RouteTab.reco),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ── 나의 경로 탭 ─────────────────────────────────────────────────────────

class _MyRouteTab extends ConsumerWidget {
  const _MyRouteTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myRouteProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return _ErrorView(
        message: state.error!,
        onRetry: () => ref.read(myRouteProvider.notifier).startMyRoute(),
      );
    }

    // 아직 시작 전
    if (!state.isActive || state.route == null) {
      return _StartPrompt(
        description: '나의 설정 경로로 실시간 안내를 시작합니다.',
        buttonLabel: '시작',
        onStart: () => ref.read(myRouteProvider.notifier).startMyRoute(),
      );
    }

    // 활성화 — 경로 표시 (한 번 fetch된 route는 절대 교체되지 않음)
    return _RouteDetail(
      route: state.route!,
      currentSection: state.currentSection,
      onStop: () => ref.read(myRouteProvider.notifier).stopMyRoute(),
    );
  }
}

// ── 추천 경로 탭 ─────────────────────────────────────────────────────────

class _RecoRouteTab extends ConsumerWidget {
  const _RecoRouteTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recoRouteProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return _ErrorView(
        message: state.error!,
        onRetry: () => ref.read(recoRouteProvider.notifier).startRecoRoute(),
      );
    }

    if (!state.isActive || state.route == null) {
      return _StartPrompt(
        description: 'AI가 추천하는 최적 경로로 실시간 안내를 시작합니다.',
        buttonLabel: '이 경로로 변경',
        onStart: () => ref.read(recoRouteProvider.notifier).startRecoRoute(),
      );
    }

    return _RouteDetail(
      route: state.route!,
      currentSection: state.currentSection,
      onStop: () => ref.read(recoRouteProvider.notifier).stopRecoRoute(),
    );
  }
}

// ── 공통 위젯들 ───────────────────────────────────────────────────────────

class _StartPrompt extends StatelessWidget {
  const _StartPrompt({
    required this.description,
    required this.buttonLabel,
    required this.onStart,
  });

  final String description;
  final String buttonLabel;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_outlined, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          // 요약 칩 행
          _RouteSummaryRow(route: route),
          const SizedBox(height: 16),

          // 현재 위치 배너 (실시간 폴링 결과 반영)
          if (currentSection != null) ...[
            _CurrentSectionBanner(section: currentSection!),
            const SizedBox(height: 16),
          ],

          // 경로 구간 목록 (한 번 로드 후 고정 — 리프레시에도 변경 없음)
          ...route.path.asMap().entries.map(
            (e) => _PathSegmentCard(
              path: e.value,
              index: e.key,
              isLast: e.key == route.path.length - 1,
              currentSection: currentSection,
            ),
          ),
          const SizedBox(height: 24),

          // 종료 버튼
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

// ── 요약 칩 행 ────────────────────────────────────────────────────────────

class _RouteSummaryRow extends StatelessWidget {
  const _RouteSummaryRow({required this.route});
  final LiveRouteModel route;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // 소요시간 칩
        _SummaryChip(
          label: '${route.totalTime}분',
          backgroundColor: AppColors.chipTimeBg,
          textColor: AppColors.chipTime,
        ),
        // 요금 칩
        if (route.payment > 0)
          _SummaryChip(
            label: '${route.payment}원',
            backgroundColor: AppColors.chipRouteBg,
            textColor: AppColors.chipRoute,
          ),
        // 거리 칩
        if (route.totalDistance > 0)
          _SummaryChip(
            label: _formatDistance(route.totalDistance),
            backgroundColor: AppColors.chipStopsBg,
            textColor: AppColors.chipStops,
          ),
      ],
    );
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters}m';
  }
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

// ── 현재 위치 배너 (CurrentSection 폴링 결과) ────────────────────────────

class _CurrentSectionBanner extends StatelessWidget {
  const _CurrentSectionBanner({required this.section});
  final CurrentSectionModel section;

  @override
  Widget build(BuildContext context) {
    final current = section.currentXY;
    final sectionType = section.currentType;

    final (icon, color, label) = switch (sectionType) {
      'bus'    => (Icons.directions_bus_rounded, AppColors.bus, '버스 탑승 중 · ${section.currentBusNo ?? ''}번'),
      'subway' => (Icons.directions_subway_rounded, AppColors.subway, '지하철 탑승 중 · ${section.currentSubwayLine ?? ''}'),
      _        => (Icons.directions_walk_rounded, AppColors.walk, '도보 이동 중'),
    };

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
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (current?.stationName != null)
                  Text(
                    current!.stationName!,
                    style: TextStyle(
                      color: color.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          // 실시간 배지
          Container(
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
          ),
        ],
      ),
    );
  }
}

// ── 구간 카드 ────────────────────────────────────────────────────────────

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

  /// 이 구간이 현재 진행 중인 구간인지 판단
  bool _isCurrentSegment() {
    final cs = currentSection;
    if (cs == null) return false;
    final seg = cs.currentSection ?? '';
    if (path.isWalking) return seg == 'walk';
    if (path.isBus) {
      return path.busNumbers.any((n) => seg == 'bus:$n');
    }
    if (path.isSubway) {
      return path.no.any((n) => seg == 'subway:$n' || seg.contains(n));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = _isCurrentSegment();

    final (iconData, iconColor, bgColor) = switch (path.type) {
      'subway' => (Icons.directions_subway_rounded, AppColors.subway, AppColors.subwayBg),
      'bus'    => (Icons.directions_bus_rounded,    AppColors.bus,    AppColors.busBg),
      _        => (Icons.directions_walk_rounded,   AppColors.walk,   AppColors.walkBg),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 타임라인 선
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCurrent ? AppColors.primary : bgColor,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: AppColors.primary, width: 2)
                        : null,
                  ),
                  child: Icon(
                    iconData,
                    color: isCurrent ? Colors.white : iconColor,
                    size: 18,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 구간 내용
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '현재',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
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
                  // 노선명 / 버스번호
                  if (path.isSubway)
                    Text(
                      path.subwayLineName,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  if (path.isBus)
                    Text(
                      path.busNumbersLabel,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  // 승하차역
                  if (path.start != null && path.end != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${path.start} → ${path.end}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  // 정거장 수
                  if (!path.isWalking && path.displayStationCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
