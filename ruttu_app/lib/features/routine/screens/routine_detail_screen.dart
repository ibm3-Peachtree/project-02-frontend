import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/routine_model.dart';
import '../../../data/models/route_model.dart';
import '../providers/routine_provider.dart';

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
        body: Center(child: Text('오류: $e')),
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
          _RouteDetailCard(routine: routine),
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
              onPressed: () => context.pop(),
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
            '${routine.departureAddressName} → ${routine.arrivalAddressName}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700),
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
          Text(
            '목표 도착 ${routine.targetArrivalTime} · 예상 ${routine.estimatedDuration}분',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _RouteDetailCard extends StatelessWidget {
  final RoutineModel routine;
  const _RouteDetailCard({required this.routine});

  // Mock 경로 단계 — 실제 서버 연동 시 GET /routines/{id} 응답의 route 필드로 교체
  static const _mockPaths = [
    PathModel(type: 'walk', sectionTime: 8,
        start: '집', end: '강남역'),
    PathModel(type: 'subway', sectionTime: 12,
        no: ['2'], stationCount: 3,
        start: '강남역', end: '을지로입구역', way: '성수 방향'),
    PathModel(type: 'walk', sectionTime: 5,
        start: '을지로입구역', end: '회사'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('경로 상세',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ..._mockPaths.asMap().entries.map((e) =>
                _PathStepItem(path: e.value, isLast: e.key == _mockPaths.length - 1)),
          ],
        ),
      ),
    );
  }
}

class _PathStepItem extends StatelessWidget {
  final PathModel path;
  final bool isLast;
  const _PathStepItem({required this.path, required this.isLast});

  @override
  Widget build(BuildContext context) {
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
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${path.start ?? ''} → ${path.end ?? ''}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${path.typeLabel} ${path.sectionTime}분'
                  '${path.stationCount != null ? ' · ${path.stationCount}정거장' : ''}'
                  '${path.way != null ? ' · ${path.way}' : ''}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final RoutineModel routine;
  const _StatsRow({required this.routine});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('총 거리', '3.2km'),
      ('예상 요금', '1,400원'),
      ('혼잡도', '보통'),
    ];

    return Row(
      children: stats.map((item) {
        final (label, value) = item;
        return Expanded(
          child: Card(
            margin: EdgeInsets.only(
              right: label != '혼잡도' ? 8 : 0,
            ),
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