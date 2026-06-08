import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../constants/route_constants.dart';
import 'live_route_tabs.dart';
import '../../data/models/routine_model.dart';
import '../../features/home/providers/home_provider.dart';
import '../../features/home/providers/live_route_provider.dart';

/// "지금 출발하기" 버튼 클릭 시 표시되는 경로 선택 바텀시트.
///
/// 1단계: 나의 경로 / 추천 경로 선택
/// 2단계-A (나의 경로): 경로 미리보기 → 시작 버튼 → 홈 화면으로 이동 후 나의 경로 안내 시작
/// 2단계-B (추천 경로): 추천 경로 목록 → 선택 → 홈 화면으로 이동 후 추천 경로 안내 시작
Future<void> showRouteSelectionBottomSheet(
  BuildContext context, {
  required RoutineModel routine,
  required WidgetRef ref,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RouteSelectionSheet(routine: routine, ref: ref),
  );
}

class _RouteSelectionSheet extends ConsumerStatefulWidget {
  const _RouteSelectionSheet({required this.routine, required this.ref});
  final RoutineModel routine;
  final WidgetRef ref;

  @override
  ConsumerState<_RouteSelectionSheet> createState() =>
      _RouteSelectionSheetState();
}

enum _SheetStep { selection, myRoute, recoRoute }

class _RouteSelectionSheetState extends ConsumerState<_RouteSelectionSheet> {
  _SheetStep _step = _SheetStep.selection;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      height: _sheetHeight(context),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── 핸들
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),

          // ── 헤더
          _buildHeader(),

          // ── 내용
          Expanded(child: _buildBody(bottomInset)),
        ],
      ),
    );
  }

  double _sheetHeight(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    switch (_step) {
      case _SheetStep.selection:
        return 320 + bottomPadding;
      case _SheetStep.myRoute:
        return screenH * 0.75;
      case _SheetStep.recoRoute:
        return screenH * 0.85;
    }
  }

  Widget _buildHeader() {
    String title;
    switch (_step) {
      case _SheetStep.selection:
        title = '경로 선택';
        break;
      case _SheetStep.myRoute:
        title = '나의 경로';
        break;
      case _SheetStep.recoRoute:
        title = '추천 경로';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (_step != _SheetStep.selection)
            GestureDetector(
              onTap: () => setState(() => _step = _SheetStep.selection),
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Color(0xFF444444)),
              ),
            ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close_rounded,
                size: 22, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(double bottomInset) {
    switch (_step) {
      case _SheetStep.selection:
        return _SelectionStep(
          routine: widget.routine,
          onMyRoute: () => setState(() => _step = _SheetStep.myRoute),
          onRecoRoute: () => setState(() => _step = _SheetStep.recoRoute),
        );
      case _SheetStep.myRoute:
        return _MyRouteStep(
          routine: widget.routine,
          outerRef: widget.ref,
        );
      case _SheetStep.recoRoute:
        return RecoRouteTabContent(
          onKeep: () => setState(() => _step = _SheetStep.selection),
          onRouteStarted: () {
            // 추천 경로 안내 시작 시 바텀시트 닫고 홈으로 이동
            Navigator.of(context).pop();
            if (context.mounted) context.go(RouteConstants.home);
          },
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1단계: 경로 선택 버튼 2개
// ─────────────────────────────────────────────────────────────────────────────

class _SelectionStep extends StatelessWidget {
  const _SelectionStep({
    required this.routine,
    required this.onMyRoute,
    required this.onRecoRoute,
  });

  final RoutineModel routine;
  final VoidCallback onMyRoute;
  final VoidCallback onRecoRoute;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 루틴 요약
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.route_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine.routineName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${routine.departureAddressName} → ${routine.arrivalAddressName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '어떤 경로로 출발할까요?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // 나의 경로 버튼
          _RouteOptionCard(
            icon: Icons.person_pin_rounded,
            title: '나의 경로',
            description: '저장된 나만의 경로로 실시간 안내를 시작합니다',
            color: AppColors.primary,
            onTap: onMyRoute,
          ),
          const SizedBox(height: 10),
          // 추천 경로 버튼
          _RouteOptionCard(
            icon: Icons.stars_rounded,
            title: '추천 경로',
            description: '현재 교통 상황에 맞는 최적 경로 목록을 확인합니다',
            color: const Color(0xFF185FA5),
            onTap: onRecoRoute,
          ),
        ],
      ),
    );
  }
}

class _RouteOptionCard extends StatelessWidget {
  const _RouteOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5E5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2단계-A: 나의 경로 시작
// ─────────────────────────────────────────────────────────────────────────────

class _MyRouteStep extends ConsumerStatefulWidget {
  const _MyRouteStep({required this.routine, required this.outerRef});
  final RoutineModel routine;
  final WidgetRef outerRef;

  @override
  ConsumerState<_MyRouteStep> createState() => _MyRouteStepState();
}

class _MyRouteStepState extends ConsumerState<_MyRouteStep> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // homeProvider에 activeRoutine 설정 후 나의 경로 로드
      ref
          .read(myRouteProvider.notifier)
          .loadMyRoute(widget.routine.routineId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MyRouteTabContent(
      onStart: () async {
        // 바텀시트 닫기
        Navigator.of(context).pop();
        // 홈으로 이동
        if (context.mounted) context.go(RouteConstants.home);
        // 나의 경로 안내 시작
        await ref.read(myRouteProvider.notifier).startMyRoute();
      },
    );
  }
}
