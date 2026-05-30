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

                // 오늘 루틴이면 홈 화면으로 이동 후 startRoute() 호출
                if (!context.mounted) return;
                context.go(RouteConstants.home);
                await Future.delayed(const Duration(milliseconds: 300));
                ref.read(homeProvider.notifier).startRoute();
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
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('루틴 삭제',
                  style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('루틴 삭제'),
                    content: Text('"${routine.routineName}"을(를) 삭제할까요?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
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
          colors: [AppColors.primary, Color(0xFFFF8C55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            routine.routineName,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800),
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
            children: routine.dayLabelsKo.map((label) {
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
            }).toList(),
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
              const SizedBox(width: 12),
              const Icon(Icons.schedule, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                '권장 출발 ${routine.recommendedDepartureTime}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('경로 상세',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                // 요금 / 소요시간 요약
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
            const SizedBox(height: 16),
            if (paths.isEmpty)
              const Text('경로 정보가 없습니다.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              ...paths.asMap().entries.map((e) =>
                  _PathStepItem(path: e.value, isLast: e.key == paths.length - 1)),
          ],
        ),
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
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('경로 상세',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              SizedBox(height: 12),
              Text('경로 정보를 불러올 수 없어요.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
      data: (route) => _RouteDetailCard(route: route),
    );
  }
}

// ── 경로 단계 항목 ──────────────────────────────────────
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 타임라인 선 + 아이콘
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(vertical: 2),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 출발 → 도착
                if (path.start != null || path.end != null)
                  Text(
                    '${path.start ?? ''} → ${path.end ?? ''}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 6),

                if (path.isWalking) ...[
                  // 도보: 시간만 강조
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F0FC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${path.sectionTime}분',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1155CC)),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // 지하철/버스: 노선 배지 (상단에만 표시)
                  if (path.no.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        path.isSubway
                            ? '${path.subwayLineName}${path.way != null && path.way!.isNotEmpty ? " (${path.way} 방향)" : ""}'
                            : '${path.no.first}번 버스',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  // 시간 + 정거장 수 강조 배지 (중복 없이)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F0FC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${path.sectionTime}분',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1155CC)),
                        ),
                      ),
                      if (path.stationName.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4EA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            path.stationCountLabel,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E6B30)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // 정거장 목록 펼치기/접기 — stationName 또는 stationCount 기준
                  if (path.stationName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Row(
                        children: [
                          Text(
                            _expanded
                                ? '정류장 접기'
                                : '정류장 ${path.stationName.length}개 모두 보기',
                            style: TextStyle(
                                fontSize: 12,
                                color: color,
                                fontWeight: FontWeight.w500),
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
                      ...path.stationName.map((station) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color.withValues(alpha: 0.5),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
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
          child: Card(
            margin: EdgeInsets.only(right: isLast ? 0 : 8),
            child: Padding(
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
          ),
        );
      }).toList(),
    );
  }
}