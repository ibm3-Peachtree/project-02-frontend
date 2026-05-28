import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_constants.dart';
import '../../../data/models/routine_model.dart';
import '../providers/routine_provider.dart';

class RoutineListScreen extends ConsumerStatefulWidget {
  const RoutineListScreen({super.key});

  @override
  ConsumerState<RoutineListScreen> createState() => _RoutineListScreenState();
}

class _RoutineListScreenState extends ConsumerState<RoutineListScreen> {
  _DayFilter _filter = _DayFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routineListProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncRoutines = ref.watch(routineListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('내 루틴',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary, size: 28),
            onPressed: () => context.push(RouteConstants.routineCreate),
          ),
        ],
      ),
      body: asyncRoutines.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final is503 = e.toString().contains('503') || e.toString().contains('Service Unavailable');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(is503 ? Icons.cloud_off_outlined : Icons.error_outline,
                      size: 56, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    is503 ? '서버 점검 중이에요' : '루틴을 불러오지 못했어요',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    is503 ? '잠시 후 다시 시도해주세요.' : '네트워크 상태를 확인해주세요.',
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(routineListProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          );
        },
        data: (routines) {
          if (routines.isEmpty) return const _EmptyRoutineBody();

          final filtered = _applyFilter(routines, _filter);

          return Column(
            children: [
              _FilterChipRow(
                current: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('해당 조건의 루틴이 없어요.',
                            style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 100 + MediaQuery.of(context).padding.bottom),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _RoutineCard(
                          routine: filtered[i],
                          onTap: () => context.push(
                            RouteConstants.routineDetail
                                .replaceFirst(':id', '${filtered[i].routineId}'),
                          ),
                          onDelete: () => _confirmDelete(context, filtered[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteConstants.routineCreate),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  List<RoutineModel> _applyFilter(List<RoutineModel> routines, _DayFilter filter) {
    return switch (filter) {
      _DayFilter.all => routines,
      _DayFilter.weekday => routines
          .where((r) => r.days.any((d) => ['MON', 'TUE', 'WED', 'THU', 'FRI'].contains(d)))
          .toList(),
      _DayFilter.weekend => routines
          .where((r) => r.days.any((d) => ['SAT', 'SUN'].contains(d)))
          .toList(),
    };
  }

  Future<void> _confirmDelete(BuildContext context, RoutineModel routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('루틴 삭제',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text('"${routine.routineName}"을(를) 삭제할까요?',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(routineListProvider.notifier).deleteRoutine(routine.routineId);
    }
  }
}

// ── 필터 열거형 ──────────────────────────────────
enum _DayFilter { all, weekday, weekend }

// ── 필터 칩 행 ───────────────────────────────────
class _FilterChipRow extends StatelessWidget {
  final _DayFilter current;
  final ValueChanged<_DayFilter> onChanged;

  const _FilterChipRow({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = [
      (_DayFilter.all,     '전체'),
      (_DayFilter.weekday, '평일'),
      (_DayFilter.weekend, '주말'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: items.map((item) {
          final (filter, label) = item;
          final selected = current == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => onChanged(filter),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
              checkmarkColor: Colors.white,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 루틴 카드 ─────────────────────────────────────
class _RoutineCard extends StatelessWidget {
  final RoutineModel routine;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RoutineCard({
    required this.routine,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 루틴 이름 (예: 출근)
                        Text(
                          routine.routineName,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary),
                        ),
                        const SizedBox(height: 2),
                        // 출발지 → 도착지
                        Text(
                          '${routine.departureAddressName} → ${routine.arrivalAddressName}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert,
                        color: AppColors.textSecondary, size: 20),
                    onPressed: () => _showMenu(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 요일 칩
              Wrap(
                spacing: 4,
                children: routine.dayLabelsKo.map((label) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              // 시간 정보
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '목표 도착 ${routine.targetArrivalTime}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.directions_run,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '예상 ${routine.estimatedDuration}분',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    '출발 ${routine.recommendedDepartureTime}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: const Text('수정'),
              onTap: () {
                Navigator.pop(context);
                context.push(RouteConstants.routineCreate, extra: routine);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('삭제',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 빈 상태 ──────────────────────────────────────
class _EmptyRoutineBody extends StatelessWidget {
  const _EmptyRoutineBody();

  @override
  Widget build(BuildContext context) {
    return Center(
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
              child: const Icon(Icons.repeat_outlined,
                  size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('등록된 루틴이 없어요',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            const Text('루틴을 추가하면 매일 최적 경로를\n자동으로 안내해드려요.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push(RouteConstants.routineCreate),
                icon: const Icon(Icons.add),
                label: const Text('루틴 추가하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}