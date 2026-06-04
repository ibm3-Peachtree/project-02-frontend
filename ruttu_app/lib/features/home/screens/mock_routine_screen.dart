import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// ── Mock 데이터 ───────────────────────────────────
class _MockRoutineData {
  final String routineName;
  final String from;
  final String to;
  final List<String> dayLabels;
  final bool skipHoliday;
  final int estimatedDuration;
  final String targetArrivalTime;
  final int spareTime;
  final String recommendedDepartureTime;
  final bool isActive;

  const _MockRoutineData({
    required this.routineName,
    required this.from,
    required this.to,
    required this.dayLabels,
    this.skipHoliday = false,
    required this.estimatedDuration,
    required this.targetArrivalTime,
    required this.spareTime,
    required this.recommendedDepartureTime,
    this.isActive = true,
  });
}

const _mockRoutines = [
  _MockRoutineData(
    routineName: '출근',
    from: '집',
    to: '회사',
    dayLabels: ['월', '화', '수', '목', '금'],
    skipHoliday: true,
    estimatedDuration: 38,
    targetArrivalTime: '09:00',
    spareTime: 15,
    recommendedDepartureTime: '08:07',
    isActive: true,
  ),
  _MockRoutineData(
    routineName: '헬스장',
    from: '집',
    to: '헬스장',
    dayLabels: ['매일'],
    skipHoliday: false,
    estimatedDuration: 18,
    targetArrivalTime: '10:00',
    spareTime: 15,
    recommendedDepartureTime: '09:27',
    isActive: false,
  ),
  _MockRoutineData(
    routineName: '주말 외출',
    from: '집',
    to: '강남역',
    dayLabels: ['토', '일'],
    skipHoliday: false,
    estimatedDuration: 42,
    targetArrivalTime: '13:00',
    spareTime: 10,
    recommendedDepartureTime: '12:08',
    isActive: true,
  ),
];

// ── Mock 루틴 화면 ────────────────────────────────
class MockRoutineScreen extends StatefulWidget {
  const MockRoutineScreen({super.key});

  @override
  State<MockRoutineScreen> createState() => _MockRoutineScreenState();
}

class _MockRoutineScreenState extends State<MockRoutineScreen> {
  _DayFilter _filter = _DayFilter.all;

  List<_MockRoutineData> get _filtered {
    return switch (_filter) {
      _DayFilter.all => _mockRoutines,
      _DayFilter.weekday => _mockRoutines
          .where((r) => r.dayLabels.any((d) => ['월', '화', '수', '목', '금'].contains(d)))
          .toList(),
      _DayFilter.weekend => _mockRoutines
          .where((r) => r.dayLabels.any((d) => ['토', '일'].contains(d)))
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('내 루틴',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        centerTitle: false,
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary, size: 28),
            onPressed: () => _showAddRoutineSnackbar(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterChipRow(
            current: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 100 + MediaQuery.of(context).padding.bottom),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _MockRoutineCard(
                routine: _filtered[i],
                onTap: () {},
                onDelete: () => _showDeleteDialog(context, _filtered[i]),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRoutineSnackbar(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddRoutineSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('루틴 추가 기능은 앱 출시 후 이용 가능해요!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showDeleteDialog(
      BuildContext context, _MockRoutineData routine) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('루틴 삭제',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text('"${routine.routineName}"을(를) 삭제할까요?',
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
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
      (_DayFilter.all, '전체'),
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
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
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

// ── 루틴 카드 (실제 _RoutineCard 레이아웃 그대로) ─────
class _MockRoutineCard extends StatelessWidget {
  final _MockRoutineData routine;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MockRoutineCard({
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
                        Text(
                          routine.routineName,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${routine.from} → ${routine.to}',
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
                runSpacing: 4,
                children: [
                  ...routine.dayLabels.map((label) => Container(
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
                      )),
                  if (routine.skipHoliday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F4FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('공휴일 제외',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // 시간 정보
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_run,
                                size: 14,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '예상 ${routine.estimatedDuration}분',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time,
                                size: 14,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '목표 도착 ${routine.targetArrivalTime}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _InfoBadge(
                        icon: Icons.timer_outlined,
                        label: '여유 ${routine.spareTime}분',
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '권장 출발 시간: ${routine.recommendedDepartureTime}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
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
              leading:
                  const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: const Text('수정'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
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

// ── 정보 배지 ────────────────────────────────────
class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
