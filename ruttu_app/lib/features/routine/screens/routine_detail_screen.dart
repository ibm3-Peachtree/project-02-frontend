import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/routine_model.dart';
import '../../../data/models/route_model.dart';
import '../providers/routine_provider.dart';
import '../../home/providers/home_provider.dart';

class RoutineDetailScreen extends ConsumerWidget {
  final int routineId;
  const RoutineDetailScreen({super.key, required this.routineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoutine = ref.watch(routineDetailProvider(routineId));

    return asyncRoutine.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('루틴 상세')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                const Text('루틴 정보를 불러오지 못했어요',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('$e', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(routineDetailProvider(routineId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (routine) => _RoutineDetailBody(routine: routine),
    );
  }
}

class _RoutineDetailBody extends ConsumerWidget {
  final RoutineModel routine;
  const _RoutineDetailBody({required this.routine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('루틴 상세',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () => context.push(RouteConstants.routineCreate, extra: routine),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showDeleteMenu(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 32 + MediaQuery.of(context).padding.bottom),
        children: [
          // ── 헤더 카드 (coral gradient)
          _HeaderCard(routine: routine),
          const SizedBox(height: 16),

          // ── 경로 상세 카드
          // route가 null이면 recoId로 별도 조회
          if (routine.route != null)
            _RouteDetailCard(route: routine.route!)
          else
            _RouteDetailFallback(
              recoId: routine.routineId,  // routineId로 경로 조회 시도
              routine: routine,
            ),
          const SizedBox(height: 16),

          // ── 통계 row
          _StatsRow(routine: routine),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // 오늘 요일 체크 — 이 루틴이 오늘 요일에 해당하는지 확인
                const dayKeys = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
                const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];
                final todayIdx = DateTime.now().weekday - 1; // 0=월 ~ 6=일
                final todayKey = dayKeys[todayIdx];
                final todayLabel = dayLabels[todayIdx];

                final isTodayRoutine = routine.days.contains(todayKey);

                if (!isTodayRoutine) {
                  // 오늘 루틴이 아닌 경우 안내 다이얼로그
                  if (!context.mounted) return;
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: const Text('오늘은 이 루틴이 없어요',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      content: Text(
                        '이 루틴은 ${routine.days.map((d) {
                          const k = ['MON','TUE','WED','THU','FRI','SAT','SUN'];
                          const l = ['월','화','수','목','금','토','일'];
                          final i = k.indexOf(d);
                          return i >= 0 ? '${l[i]}요일' : d;
                        }).join(', ')}에만 진행돼요.\n\n오늘($todayLabel요일)은 출발할 수 없어요.',
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary),
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('확인'),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                // ✅ [버그 수정] 오늘 루틴이면 이 루틴을 activeRoutine으로 명시 지정 후 출발.
                // 기존 방식(homeProvider.startRoute() 바로 호출)은 homeProvider의
                // activeRoutine이 이미 다른 루틴이거나 null일 때 동작하지 않는 문제가 있었음.
                // initializeWithRoutine()으로 현재 루틴을 homeProvider에 세팅한 뒤
                // startRoute()를 호출하여 루틴 2개 이상일 때도 정상 동작하도록 수정.
                if (!context.mounted) return;

                // ✅ [버그 수정] context.go() 보다 먼저 initializeWithRoutine()을 완료해야 함.
                // 기존 코드는 go() 후 await를 했기 때문에, 홈 화면의 _RecoRouteTab.initState()가
                // preloadList() 완료 전에 loadRecoRouteList()를 독자 호출하여
                // 추천 경로 탭에 데이터가 반영되지 않는 문제가 있었음.
                // homeProvider에 이 루틴을 activeRoutine으로 지정 (recoRouteList preload 포함)
                await ref.read(homeProvider.notifier).initializeWithRoutine(routine);

                if (!context.mounted) return;
                context.go(RouteConstants.home);

                // activeRoutine이 정상 세팅된 경우에만 출발
                if (ref.read(homeProvider).activeRoutine != null) {
                  ref.read(homeProvider.notifier).startRoute();
                }
              },
              child: const Text('지금 출발하기'),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('루틴 삭제',
                  style: TextStyle(color: AppColors.error)),
              onTap: () async {
                // 바텀시트를 먼저 닫고, 아닫히면 닫힐 전에 context가 심하는 검은 화면 출현
                Navigator.pop(sheetCtx);
                // 바텀시트 팝업 애니메이션이 완료된 후 다이얼로그 열기
                await Future.delayed(const Duration(milliseconds: 300));
                if (!context.mounted) return;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('루틴 삭제'),
                    content: Text('"${routine.routineName}"을(를) 삭제할까요?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('취소'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error),
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await ref
                      .read(routineListProvider.notifier)
                      .deleteRoutine(routine.routineId);
                  if (context.mounted) context.pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 헤더 카드 ──────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  final RoutineModel routine;
  const _HeaderCard({required this.routine});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFFFA8B5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  routine.routineName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              // excludeHoliday(skipHoliday)=true: 공휴일 제외 (밝은 파란 계열 강조)
              if (routine.skipHoliday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBBDEFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '공휴일 제외',
                    style: TextStyle(
                        color: Color(0xFF1565C0),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${routine.departureAddressName} → ${routine.arrivalAddressName}',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...routine.dayLabelsKo.map((label) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                '목표 도착 ${routine.targetArrivalTime}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                '권장 출발 ${routine.recommendedDepartureTime}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              _DetailBadge(
                icon: Icons.timer_outlined,
                label: '여유 ${routine.spareTime}분',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 경로 상세 카드 (route가 있을 때) ────────────────────
class _RouteDetailCard extends StatelessWidget {
  final RouteModel route;
  const _RouteDetailCard({required this.route});

  @override
  Widget build(BuildContext context) {
    final paths = route.path;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 영역
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Text('경로 상세',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${route.totalTime}분',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const Text(' · ',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                Text('${_formatMoney(route.payment)}원',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
          ),
          // 구분선
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          // 경로 단계 목록 (중첩 컨테이너 제거 — 바깥 Card가 이미 radius 처리)
          if (paths.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('경로 정보가 없습니다.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            Column(
              children: paths.asMap().entries
                  .map((e) => _PathStepItem(
                        path: e.value,
                        isLast: e.key == paths.length - 1,
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  static String _formatMoney(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── 경로 없을 때 — recoId로 fallback 조회 ──────────────
class _RouteDetailFallback extends ConsumerWidget {
  final int recoId;
  final RoutineModel routine;
  const _RouteDetailFallback({required this.recoId, required this.routine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoute = ref.watch(routeDetailProvider(recoId));
    return asyncRoute.when(
      loading: () => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(32),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text('경로 상세',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('경로 정보를 불러올 수 없어요.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
      data: (route) => _RouteDetailCard(route: route),
    );
  }
}

// ── 경로 단계 항목 ──────────────────────────────────────
// 카드 행 방식: 도보/버스/지하철 각각 배경색 구분,
// 도보엔 "도보" 텍스트 명시, 지하철도 버스처럼 칩으로 표시
class _PathStepItem extends StatefulWidget {
  final PathModel path;
  final bool isLast;
  const _PathStepItem({required this.path, required this.isLast});

  @override
  State<_PathStepItem> createState() => _PathStepItemState();
}

class _PathStepItemState extends State<_PathStepItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    final isLast = widget.isLast;

    final Color iconBg;
    final Color iconColor;
    final Color rowBg;

    if (path.isWalking) {
      iconBg    = AppColors.walkBg;
      iconColor = AppColors.walk;
      rowBg     = const Color(0xFFFAFAF9);
    } else if (path.isSubway) {
      iconBg    = AppColors.subway;
      iconColor = Colors.white;
      rowBg     = const Color(0xFFFAFAF9);
    } else {
      iconBg    = AppColors.bus;
      iconColor = Colors.white;
      rowBg     = const Color(0xFFFDFAF9);
    }

    final Color chipTextColor = AppColors.chipRoute;
    final Color chipBg        = AppColors.chipRouteBg;
    final Color subwayLineBg   = AppColors.chipRouteBg;
    final Color subwayLineText = AppColors.chipRoute;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: rowBg,
            border: Border(
              top: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
              bottom: isLast
                  ? BorderSide(color: AppColors.border.withValues(alpha: 0.5))
                  : BorderSide.none,
            ),
          ),
          padding: path.isWalking
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              : const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: path.isWalking
              // ── 도보 행: 한 줄
              ? Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                      child: Icon(Icons.directions_walk, size: 15, color: iconColor),
                    ),
                    const SizedBox(width: 10),
                    const Text('도보',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const Spacer(),
                    _Chip(
                      label: '${path.sectionTime}분',
                      bg: AppColors.chipTimeBg,
                      fg: AppColors.chipTime,
                    ),
                  ],
                )
              // ── 버스 / 지하철 행
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                      child: Icon(
                        path.isSubway
                            ? Icons.subway_outlined
                            : Icons.directions_bus_outlined,
                        size: 15,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 출발지 이름
                          if (path.start != null)
                            Text(path.start!,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),

                          // 지하철: 노선명 칩(파란 배경) + 방향 칩
                          if (path.isSubway && path.no.isNotEmpty) ...[
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                _Chip(
                                  label: path.subwayLineName,
                                  bg: subwayLineBg,
                                  fg: subwayLineText,
                                ),
                                if (path.way != null && path.way!.isNotEmpty)
                                  _Chip(
                                    label: '${path.way} 방향',
                                    bg: chipBg,
                                    fg: chipTextColor,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],

                          // 버스: 번호 칩 목록
                          if (path.isBus && path.busNumbers.isNotEmpty) ...[
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: path.busNumbers
                                  .map((n) => _Chip(
                                        label: '${n}번',
                                        bg: chipBg,
                                        fg: chipTextColor,
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 4),
                          ],

                          // 시간 + 정거장 수
                          Row(
                            children: [
                              _Chip(
                                label: '${path.sectionTime}분',
                                bg: AppColors.chipTimeBg,
                                fg: AppColors.chipTime,
                              ),
                              if (path.displayStationCount > 0) ...[
                                const SizedBox(width: 6),
                                _Chip(
                                  label: '${path.displayStationCount}정거장',
                                  bg: AppColors.chipStopsBg,
                                  fg: AppColors.chipStops,
                                ),
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
                                    _expanded
                                        ? '정류장 접기'
                                        : '정류장 ${path.stationName.length}개 모두 보기',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: chipTextColor,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  Icon(
                                    _expanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    size: 14,
                                    color: chipTextColor,
                                  ),
                                ],
                              ),
                            ),
                            if (_expanded) ...[
                              const SizedBox(height: 6),
                              ...path.stationName.map((station) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          margin: const EdgeInsets.only(left: 4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: chipTextColor.withValues(alpha: 0.5),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(station,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary)),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── 공용 소형 칩 ────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Chip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
      );
}

// ── 통계 row ───────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final RoutineModel routine;
  const _StatsRow({required this.routine});

  static String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final route = routine.route;
    final distanceKm = route != null
        ? '${(route.totalDistance / 1000).toStringAsFixed(1)}km'
        : '-';
    final payment = route != null
        ? '${_formatNumber(route.payment)}원'
        : '-';
    final stats = [
      ('총 거리', distanceKm),
      ('예상 요금', payment),
      ('소요 시간', routine.estimatedDuration > 0 ? '${routine.estimatedDuration}분' : '-'),
    ];

    return Row(
      children: stats.asMap().entries.map((entry) {
        final isLast = entry.key == stats.length - 1;
        final (label, value) = entry.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: isLast ? 0 : 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
// ── 헤더카드 내 반투명 배지 ─────────────────────────────
class _DetailBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
