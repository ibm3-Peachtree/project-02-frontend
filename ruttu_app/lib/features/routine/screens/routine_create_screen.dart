import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/widgets/kakao_postcode_page.dart';
import '../../../data/models/address_model.dart';
import '../../../data/models/routine_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/repositories/routine_repository.dart';
import '../providers/routine_provider.dart';
import '../../home/providers/home_provider.dart';
import '../../auth/providers/network_provider.dart';

class RoutineCreateScreen extends ConsumerStatefulWidget {
  final RoutineModel? editRoutine;
  const RoutineCreateScreen({super.key, this.editRoutine});

  @override
  ConsumerState<RoutineCreateScreen> createState() =>
      _RoutineCreateScreenState();
}

class _RoutineCreateScreenState extends ConsumerState<RoutineCreateScreen> {
  int _step = 0;

  // Step 1
  final _nameController = TextEditingController();
  final _step1Key = GlobalKey<FormState>();
  final Set<String> _selectedDays = {};
  TimeOfDay _targetArrivalTime = const TimeOfDay(hour: 9, minute: 0);
  int _spareTime = 15; // 여유 시간 (분)
  bool _skipHoliday = false; // 공휴일 제외

  // Step 2
  AddressModel? _departure;
  AddressModel? _arrival;

  // Step 3
  List<RouteModel> _routes = [];
  int? _selectedRouteIndex;
  bool _loadingRoutes = false;

  static const _allDays = [
    ('MON', '월'), ('TUE', '화'), ('WED', '수'),
    ('THU', '목'), ('FRI', '금'), ('SAT', '토'), ('SUN', '일'),
  ];

  @override
  void initState() {
    super.initState();
    final routine = widget.editRoutine;
    if (routine != null) {
      _nameController.text = routine.routineName;
      _selectedDays.addAll(routine.days);
      _spareTime = routine.spareTime;
      _skipHoliday = routine.skipHoliday;
      final parts = routine.targetArrivalTime.split(':');
      _targetArrivalTime = TimeOfDay(
          hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final addresses = await ref.read(addressListProvider.future);
        if (!mounted) return;
        setState(() {
          _departure = addresses.where(
              (a) => a.name == routine.departureAddressName).firstOrNull;
          _arrival = addresses.where(
              (a) => a.name == routine.arrivalAddressName).firstOrNull;
        });
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _arrivalTimeStr =>
      '${_targetArrivalTime.hour.toString().padLeft(2, '0')}:${_targetArrivalTime.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _targetArrivalTime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _targetArrivalTime = picked);
  }

  Future<void> _loadRoutes() async {
    if (_departure == null || _arrival == null) return;
    setState(() {
      _loadingRoutes = true;
      _selectedRouteIndex = null;
    });
    try {
      final routes = await ref
          .read(routineRepositoryProvider)
          .searchRoutes(
            departureAddressId: _departure!.addressId,
            arrivalAddressId: _arrival!.addressId,
            targetArrivalTime: _arrivalTimeStr,
          );
      // 수정 모드: 기존 recoId와 일치하는 경로를 자동 선택
      int? autoSelect;
      final existingRecoId = widget.editRoutine?.route?.recoId;
      if (existingRecoId != null && existingRecoId > 0) {
        final idx = routes.indexWhere((r) => r.recoId == existingRecoId);
        if (idx != -1) autoSelect = idx;
        else autoSelect = 0; // 일치하는 경로 없으면 첫 번째 선택
      }
      setState(() {
        _routes = routes;
        _loadingRoutes = false;
        if (autoSelect != null) _selectedRouteIndex = autoSelect;
      });
    } catch (_) {
      setState(() => _loadingRoutes = false);
    }
  }

  Future<void> _showRouteDetail(RouteModel summary, int index) async {
    RouteModel detail = summary;
    try {
      detail = await ref
          .read(routineRepositoryProvider)
          .getRouteDetail(summary.recoId);
    } catch (_) {}
    if (!mounted) return;
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
          child: _RouteDetailSheet(
            route: detail,
            scrollController: controller,
          ),
        ),
      ),
    );
    if (selected == true && mounted) {
      setState(() => _selectedRouteIndex = index);
    }
  }

  // GPS sendLiveLocation 관련:
  // 이 파일이 아닌 위치추적 서비스(예: LocationService/LiveTrackingNotifier)에서
  // Geolocator.getPositionStream()으로 position을 받은 뒤, 아래처럼 호출해야 해요:
  //
  //   await repository.sendLiveLocation(
  //     latitude: position.latitude,
  //     longitude: position.longitude,
  //     speed: position.speed < 0 ? 0.0 : position.speed,  // 음수(-1.0) 방어 처리
  //     accuracy: position.accuracy,
  //   );
  //
  // DI에서 MockHomeRepository가 아닌 ApiHomeRepository가 주입됐는지도 확인하세요.
  Future<void> _save() async {
    final routineName = _nameController.text.trim();

    // 수정 모드: 새 경로를 선택하지 않았으면 기존 recoId 사용
    final int recoId;
    if (_selectedRouteIndex != null) {
      recoId = _routes[_selectedRouteIndex!].recoId ?? _selectedRouteIndex!;
    } else if (widget.editRoutine?.route?.recoId != null && widget.editRoutine!.route!.recoId > 0) {
      recoId = widget.editRoutine!.route!.recoId;
    } else {
      // 신규 등록인데 경로 미선택
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('경로를 선택해주세요.'), backgroundColor: Colors.red),
      );
      return;
    }

    final request = CreateRoutineRequest(
      routineName: routineName,
      targetArrivalTime: _arrivalTimeStr,
      originAlias: _departure!.name,
      origin: _departure!.address,
      destinationAlias: _arrival!.name,
      destination: _arrival!.address,
      recoId: recoId,
      days: _selectedDays.toList(),
      spareTime: _spareTime,
      skipHoliday: _skipHoliday,
    );
    try {
      if (widget.editRoutine != null) {
        await ref
            .read(routineListProvider.notifier)
            .updateRoutine(widget.editRoutine!.routineId, request);
      } else {
        await ref.read(routineListProvider.notifier).createRoutine(request);
      }
      // ✅ 루틴 생성/수정 후 홈 화면 추천 경로 재조회
      if (mounted) {
        ref.invalidate(routineDetailProvider);
        // routineListProvider는 create/update 내부에서 이미 AsyncData로 갱신하므로
        // invalidate 금지 (무한 로딩 유발)
        // homeProvider는 await 없이 백그라운드 갱신
        ref.read(homeProvider.notifier).refresh();
        if (mounted) context.pop();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      // 서버 응답이 JSON Map일 수도, plain String일 수도 있어서 안전하게 처리
      final data = e.response?.data;
      final serverMessage = switch (data) {
        Map()    => (data['message'] ?? data['error'] ?? '').toString(),
        String() => data,
        _        => '',
      };
      final isDuplicateTime = e.response?.statusCode == 409 &&
          (serverMessage.contains('동일 시간대') ||
           serverMessage.contains('DuplicateRoutineTargetArrivalTime'));

      final isDuplicateName = e.response?.statusCode == 409 &&
          (serverMessage.contains('동일 이름') ||
           serverMessage.contains('DuplicateRoutineName'));

      final isRoutineInUse = e.response?.statusCode == 409 &&
          (serverMessage.contains('RoutineInUse') ||
           serverMessage.contains('사용 중') ||
           serverMessage.contains('in_use') ||
           serverMessage.contains('routine_in_use'));

      if (isRoutineInUse) {
        await showDialog<void>(
          context: context,
          builder: (dCtx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text('루틴을 수정할 수 없어요',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            content: const Text(
              '현재 이동 중인 루틴은 수정할 수 없어요.\n이동이 완료된 후 다시 시도해 주세요.',
              style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.textSecondary),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dCtx),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('확인',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else if (isDuplicateTime) {
        final days = _selectedDays.map((d) {
          const map = {
            'MON': '월', 'TUE': '화', 'WED': '수',
            'THU': '목', 'FRI': '금', 'SAT': '토', 'SUN': '일',
          };
          return map[d] ?? d;
        }).join(', ');

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('시간이 겹쳐요'),
            content: Text(
              '[$days] $_arrivalTimeStr 에 이미 등록된 루틴이 있어요.\n'
              '시간을 겹치지 않게 설정해주세요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('시간 변경하기'),
              ),
            ],
          ),
        );

        if (confirmed == true && mounted) {
          // Step 1(기본 정보)로 이동 후 바로 시간 선택 피커 열기
          setState(() => _step = 0);
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) _pickTime();
        }
      } else if (isDuplicateName) {
        // Step 1으로 이동해서 이름 필드 포커스
        setState(() => _step = 0);
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                '이름 중복',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              content: const Text('이미 사용 중인 루틴 이름이에요.\n다른 이름을 입력해주세요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      } else {
        // 보안상 서버 에러 상세 코드/메시지 노출 방지
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('루틴 저장에 실패했어요. 잠시 후 다시 시도해주세요.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('루틴 저장에 실패했어요. 잠시 후 다시 시도해주세요.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.editRoutine != null ? '루틴 수정' : '루틴 추가',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(currentStep: _step),
          Expanded(
            child: [
              _Step1(
                formKey: _step1Key,
                nameController: _nameController,
                selectedDays: _selectedDays,
                allDays: _allDays,
                arrivalTimeStr: _arrivalTimeStr,
                onDayToggle: (day) =>
                    setState(() {
                      _selectedDays.contains(day)
                          ? _selectedDays.remove(day)
                          : _selectedDays.add(day);
                      // 토/일이 포함되면 공휴일 제외 강제 off
                      if (_selectedDays.contains('SAT') || _selectedDays.contains('SUN')) {
                        _skipHoliday = false;
                      }
                    }),
                onPickTime: _pickTime,
                existingNames: ref.read(routineListProvider).valueOrNull
                    ?.where((r) => r.routineId != widget.editRoutine?.routineId)
                    .map((r) => r.routineName)
                    .toList() ?? [],
                spareTime: _spareTime,
                onSpareTimeChanged: (v) => setState(() => _spareTime = v),
                skipHoliday: _skipHoliday,
                onSkipHolidayChanged: (v) => setState(() => _skipHoliday = v),
                onNext: () async {
                  if (!_step1Key.currentState!.validate()) return;
                  if (_selectedDays.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('요일을 하나 이상 선택해주세요.')));
                    return;
                  }
                  // 동시간대 프론트 체크 — 중복 루틴이 있으면 수정 유도 다이얼로그 표시
                  final conflictRoutine = (ref.read(routineListProvider).valueOrNull ?? [])
                      .where((r) => r.routineId != widget.editRoutine?.routineId)
                      .where((r) => r.targetArrivalTime == _arrivalTimeStr)
                      .where((r) => r.days.any((d) => _selectedDays.contains(d)))
                      .firstOrNull;
                  if (conflictRoutine != null) {
                    final overlappingDays = _selectedDays
                        .where((d) => conflictRoutine.days.contains(d))
                        .map((d) {
                          const map = {
                            'MON': '월', 'TUE': '화', 'WED': '수',
                            'THU': '목', 'FRI': '금', 'SAT': '토', 'SUN': '일',
                          };
                          return map[d] ?? d;
                        })
                        .join(', ');

                    final action = await showDialog<String>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: const Text('같은 시간대 루틴이 있어요',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        content: Text(
                          '[$overlappingDays] $_arrivalTimeStr 에\n'
                          "'${conflictRoutine.routineName}' 루틴이 이미 등록되어 있어요.\n\n"
                          '기존 루틴을 수정하거나, 이 루틴의 시간을 바꿔주세요.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'cancel'),
                            child: const Text('취소',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context, 'changeTime'),
                            child: const Text('시간 변경'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary),
                            onPressed: () => Navigator.pop(context, 'editConflict'),
                            child: const Text('기존 루틴 수정',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );

                    if (action == 'changeTime' && mounted) {
                      await Future.delayed(const Duration(milliseconds: 100));
                      if (mounted) _pickTime();
                    } else if (action == 'editConflict' && mounted) {
                      // 현재 생성 화면을 닫고 기존 루틴 수정 화면으로 교체
                      context.pop();
                      if (mounted) {
                        context.push(
                          RouteConstants.routineCreate,
                          extra: conflictRoutine,
                        );
                      }
                    }
                    return;
                  }
                  setState(() => _step = 1);
                },
              ),
              _Step2(
                departure: _departure,
                arrival: _arrival,
                onSelectDeparture: (a) =>
                    setState(() => _departure = a),
                onSelectArrival: (a) =>
                    setState(() => _arrival = a),
                onNext: () {
                  if (_departure == null || _arrival == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('출발지와 도착지를 모두 선택해주세요.')));
                    return;
                  }
                  setState(() => _step = 2);
                  _loadRoutes();
                },
                onBack: () => setState(() => _step = 0),
              ),
              _Step3(
                routes: _routes,
                isLoading: _loadingRoutes,
                selectedIndex: _selectedRouteIndex,
                onSelect: (i) => setState(() => _selectedRouteIndex = i),
                onDetail: _showRouteDetail,
                onSave: _save,
                onBack: () => setState(() => _step = 1),
                routineName: _nameController.text.trim(),
                departureName: _departure?.name ?? '',
                arrivalName: _arrival?.name ?? '',
              ),
            ][_step],
          ),
        ],
      ),
    );
  }
}

// ── 상단 진행 표시 ────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const labels = ['기본 정보', '경로 설정', '경로 선택'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          Row(
            children: List.generate(3, (i) {
              final active = i <= currentStep;
              return Expanded(
                child: Row(
                  children: [
                    _StepCircle(index: i + 1, active: active,
                        done: i < currentStep),
                    if (i < 2)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i < currentStep
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.asMap().entries.map((e) {
              final active = e.key <= currentStep;
              return Text(e.value,
                  style: TextStyle(
                      fontSize: 12,
                      color: active
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: active
                          ? FontWeight.w600
                          : FontWeight.normal));
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int index;
  final bool active;
  final bool done;
  const _StepCircle(
      {required this.index, required this.active, required this.done});

  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? AppColors.primary : AppColors.border,
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text('$index',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.textSecondary)),
        ),
      );
}

// ── Step 1: 기본 정보 ─────────────────────────────
class _Step1 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final Set<String> selectedDays;
  final List<(String, String)> allDays;
  final String arrivalTimeStr;
  final VoidCallback onPickTime;
  final void Function(String) onDayToggle;
  final Future<void> Function() onNext;
  final List<String> existingNames;
  final int spareTime;
  final void Function(int) onSpareTimeChanged;
  final bool skipHoliday;
  final void Function(bool) onSkipHolidayChanged;

  const _Step1({
    required this.formKey,
    required this.nameController,
    required this.selectedDays,
    required this.allDays,
    required this.arrivalTimeStr,
    required this.onPickTime,
    required this.onDayToggle,
    required this.onNext,
    required this.existingNames,
    required this.spareTime,
    required this.onSpareTimeChanged,
    required this.skipHoliday,
    required this.onSkipHolidayChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('루틴 이름',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: nameController,
              maxLength: 20,
              decoration: const InputDecoration(
                  hintText: '예: 출근 루틴', counterText: ''),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '루틴 이름을 입력해주세요.';
                if (existingNames.any((n) => n.trim() == v.trim())) {
                  return '이미 사용 중인 루틴 이름이에요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const Text('반복 요일',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: allDays.map((item) {
                final (key, label) = item;
                final selected = selectedDays.contains(key);
                return GestureDetector(
                  onTap: () => onDayToggle(key),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.primary : Colors.white,
                      border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border),
                    ),
                    child: Center(
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('목표 도착 시간',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onPickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(arrivalTimeStr,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // ── 여유 시간 슬라이더 ──────────────────────
            Row(
              children: [
                const Text('여유 시간',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: const Text('NEW',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('0분',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                      Expanded(
                        child: Slider(
                          value: spareTime.toDouble(),
                          min: 0,
                          max: 60,
                          divisions: 12,
                          activeColor: AppColors.primary,
                          inactiveColor: AppColors.border,
                          onChanged: (v) =>
                              onSpareTimeChanged(v.round()),
                        ),
                      ),
                      const Text('60분',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                      Text('$spareTime분',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '권장 출발 = 소요 시간 + 여유 $spareTime분 역산',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 예상 출발 시간 프리뷰 배너
            _SpareTimePreviewBanner(
              arrivalTimeStr: arrivalTimeStr,
              spareTime: spareTime,
            ),
            const SizedBox(height: 16),
            // ── 공휴일 제외 토글 ──────────────────────────
            Builder(builder: (context) {
              final hasWeekend = selectedDays.contains('SAT') || selectedDays.contains('SUN');
              return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('공휴일 제외',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: hasWeekend
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          hasWeekend
                              ? '토/일이 포함된 경우 공휴일 제외를 사용할 수 없어요'
                              : skipHoliday
                                  ? '공휴일에는 루틴 알림 및 실시간 경로 안내가 없어요'
                                  : '공휴일에도 루틴을 정상 실행해요',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: hasWeekend ? false : skipHoliday,
                    activeColor: AppColors.primary,
                    onChanged: hasWeekend ? null : onSkipHolidayChanged,
                  ),
                ],
              ),
            );
            }),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => onNext(),
                child: const Text('다음'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: 경로 설정 ─────────────────────────────
class _Step2 extends ConsumerWidget {
  final AddressModel? departure;
  final AddressModel? arrival;
  final void Function(AddressModel) onSelectDeparture;
  final void Function(AddressModel) onSelectArrival;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step2({
    required this.departure,
    required this.arrival,
    required this.onSelectDeparture,
    required this.onSelectArrival,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAddresses = ref.watch(addressListProvider);

    return asyncAddresses.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('주소를 불러올 수 없어요: $e')),
      data: (addresses) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AddressPickerField(
              label: '출발지',
              icon: Icons.my_location,
              selected: departure,
              addresses: addresses,
              onSelect: onSelectDeparture,
            ),
            const SizedBox(height: 16),
            _AddressPickerField(
              label: '도착지',
              icon: Icons.flag_outlined,
              selected: arrival,
              addresses: addresses,
              onSelect: onSelectArrival,
            ),
            const SizedBox(height: 12),
            // 저장 주소 목록
            const Text('저장된 주소',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...addresses.map((a) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined,
                      color: AppColors.primary),
                  title: Text(a.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(a.address,
                      style: const TextStyle(fontSize: 13)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => onSelectDeparture(a),
                        style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8)),
                        child: const Text('출발',
                            style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => onSelectArrival(a),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8)),
                        child: const Text('도착',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onBack,
                    child: const Text('이전'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onNext,
                    child: const Text('경로 검색'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressPickerField extends ConsumerWidget {
  final String label;
  final IconData icon;
  final AddressModel? selected;
  final List<AddressModel> addresses;
  final void Function(AddressModel) onSelect;

  const _AddressPickerField({
    required this.label,
    required this.icon,
    required this.selected,
    required this.addresses,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showPicker(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected != null ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected != null
                    ? AppColors.primary
                    : AppColors.textSecondary,
                size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    selected?.name ?? '$label 선택',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary),
                  ),
                  if (selected != null)
                    Text(selected!.address,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) {
        final bottomPad = MediaQuery.of(sheetCtx).viewPadding.bottom;
        // 항목 수에 따라 초기 높이를 동적으로 설정 (최소 0.4, 최대 0.85)
        final itemCount = addresses.length + 2; // 헤더 + 목록 + 새 주소 추가
        final estimatedHeight = itemCount * 72.0 + 80;
        final screenHeight = MediaQuery.of(sheetCtx).size.height;
        final initialSize = (estimatedHeight / screenHeight).clamp(0.4, 0.85);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: initialSize,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 드래그 핸들
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text('$label 선택',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(bottom: bottomPad),
                  children: [
                    ...addresses.map((a) => ListTile(
                          leading: const Icon(Icons.location_on_outlined,
                              color: AppColors.primary),
                          title: Text(a.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(a.address),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            onSelect(a);
                          },
                        )),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.add_location_alt_outlined,
                          color: AppColors.primary),
                      title: const Text('새 주소 추가',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                      onTap: () async {
                        final newAddr = await _showAddAddressSheet(sheetCtx, ref);
                        if (newAddr != null && sheetCtx.mounted) {
                          Navigator.pop(sheetCtx);
                          onSelect(newAddr);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<AddressModel?> _showAddAddressSheet(
      BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<AddressModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _AddAddressSheet(
        onSave: (name, roadAddress, jibunAddress, lat, lng) async {
          try {
            final apiClient = ref.read(apiClientProvider);
            final res = await apiClient.dio.post('/address', data: {
              'name': name,
              'roadAddress': roadAddress,
              'jibunAddress': jibunAddress,
            });
            final newAddr = AddressModel.fromJson(res.data as Map<String, dynamic>);
            ref.invalidate(addressListProvider);
            if (ctx.mounted) Navigator.pop(ctx, newAddr);
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('주소 저장에 실패했어요: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }
}

// ── Step 3: 경로 선택 ─────────────────────────────
class _Step3 extends StatelessWidget {
  final List<RouteModel> routes;
  final bool isLoading;
  final int? selectedIndex;
  final void Function(int) onSelect;
  final Future<void> Function(RouteModel, int) onDetail;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final String routineName;
  final String departureName;
  final String arrivalName;

  const _Step3({
    required this.routes,
    required this.isLoading,
    required this.selectedIndex,
    required this.onSelect,
    required this.onDetail,
    required this.onSave,
    required this.onBack,
    required this.routineName,
    required this.departureName,
    required this.arrivalName,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('경로를 검색하는 중...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8 + MediaQuery.of(context).padding.bottom),
            children: [
              const Text('추천 경로',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              // 루틴 이름 + 출발지→도착지 요약
              if (routineName.isNotEmpty) ...[
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    children: [
                      TextSpan(
                        text: routineName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(text: '$departureName → $arrivalName'),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text('${routes.length}가지 경로를 찾았어요.',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              ...routes.asMap().entries.map((e) => _RouteOptionCard(
                    route: e.value,
                    index: e.key,
                    isSelected: selectedIndex == e.key,
                    onTap: () => onSelect(e.key),
                    onDetail: onDetail,
                  )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onBack,
                    child: const Text('이전'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: selectedIndex != null ? onSave : null,
                    child: const Text('이 경로로 루틴 저장'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}

class _RouteOptionCard extends StatelessWidget {
  final RouteModel route;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final Future<void> Function(RouteModel, int) onDetail;

  const _RouteOptionCard({
    required this.route,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 교통수단 칩 row
                Expanded(child: _TransitChips(paths: route.path)),
                TextButton(
                  onPressed: () => onDetail(route, index),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('상세보기',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${route.totalTime}분',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
                const SizedBox(width: 8),
                Text('${route.payment}원',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
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

class _TransitChips extends StatelessWidget {
  final List<PathModel> paths;
  const _TransitChips({required this.paths});

  @override
  Widget build(BuildContext context) {
    final nonWalking =
        paths.where((p) => !p.isWalking).toList();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (int i = 0; i < paths.length; i++) ...[
          if (paths[i].isWalking)
            const Icon(Icons.directions_walk,
                size: 18, color: AppColors.textSecondary)
          else if (paths[i].isSubway)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.subwayBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                paths[i].subwayLineName,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.subway),
              ),
            )
          else
            // 버스: no 목록의 모든 번호를 각각 칩으로 표시
            Wrap(
              spacing: 4,
              children: paths[i].no.map((busNo) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.busBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$busNo번',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.bus),
                ),
              )).toList(),
            ),
          if (i < paths.length - 1 && nonWalking.isNotEmpty)
            const Icon(Icons.arrow_forward,
                size: 12, color: AppColors.textSecondary),
        ],
      ],
    );
  }
}

// ── 경로 상세 바텀 시트 (Screen 4-B) ─────────────
class _RouteDetailSheet extends StatelessWidget {
  final RouteModel route;
  final ScrollController scrollController;

  const _RouteDetailSheet({
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
        // 헤더 (좌우 padding 16 통일)
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
              Text('${route.payment}원',
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
            padding: EdgeInsets.fromLTRB(16, 20, 16, 20 + MediaQuery.of(context).padding.bottom),
            children: [
              ...route.path.asMap().entries.map((e) =>
                  _DetailPathItem(
                      path: e.value,
                      isLast: e.key == route.path.length - 1)),
            ],
          ),
        ),
        // 하단 합계 바 (border 없이 배경색으로만 구분)
        const Divider(height: 1, thickness: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryItem('총 소요', '${route.totalTime}분'),
              _SummaryItem('요금', '${route.payment}원'),
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

    // 교통수단별 색상 — AppColors 통일
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

    // 타이틀: 승차역 이름만 (노선명은 칩으로)
    final String title = path.isWalking
        ? '도보'
        : path.start != null && path.start!.isNotEmpty
            ? '${path.start} 승차'
            : path.isSubway ? '지하철 승차' : '버스 승차';

    final bool hasStations = path.stationName.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 타임라인 아이콘 + 연결선
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
                // 제목 행
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
                // 칩 영역: 지하철 노선 + 방향 / 버스 번호
                if (path.isSubway && path.no.isNotEmpty) ...[
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      // 노선명 칩 → 다크
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
                      // 방향 칩 → 원래 오렌지
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
                    // 버스 번호 칩 → 다크
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
                // 시간 + 정거장 수 칩
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
                // 정류장 수직 목록 (펼쳤을 때)
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

// ── 새 주소 추가 바텀 시트 ────────────────────────────
class _AddAddressSheet extends StatefulWidget {
  final Future<void> Function(String name, String roadAddress, String jibunAddress, double? lat, double? lng) onSave;
  const _AddAddressSheet({required this.onSave});

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _nameCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  KakaoPostcodeResult? _kakaoResult;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchAddress() async {
    final result = await Navigator.of(context, rootNavigator: true).push<KakaoPostcodeResult>(
      MaterialPageRoute(builder: (_) => const KakaoPostcodePage()),
    );
    if (result != null && mounted) setState(() => _kakaoResult = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_kakaoResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주소를 검색하여 선택해주세요.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final detail = _detailCtrl.text.trim();
      final fullAddress = detail.isEmpty
          ? _kakaoResult!.roadAddress
          : '${_kakaoResult!.roadAddress} $detail';
      await widget.onSave(
        _nameCtrl.text.trim(),
        fullAddress,
        _kakaoResult!.jibunAddress,
        null,
        null,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final navBar = MediaQuery.of(context).viewPadding.bottom;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, inset + navBar + 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('새 주소 추가',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),

              // 별칭
              const Text('별칭',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                maxLength: 10,
                decoration: const InputDecoration(
                    hintText: '예: 학교, 병원', counterText: ''),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '별칭을 입력해주세요.' : null,
              ),
              const SizedBox(height: 16),

              // 주소
              const Text('주소',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),

              if (_kakaoResult == null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _searchAddress,
                    icon: const Icon(Icons.search),
                    label: const Text('주소 검색'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ] else ...[
                // 선택된 주소 카드
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_kakaoResult!.zonecode.isNotEmpty)
                              Text('[${_kakaoResult!.zonecode}]',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                            Text(_kakaoResult!.roadAddress,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            if (_kakaoResult!.jibunAddress.isNotEmpty)
                              Text(_kakaoResult!.jibunAddress,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _searchAddress,
                        child: const Text('다시 검색',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _detailCtrl,
                  decoration: const InputDecoration(
                      hintText: '상세 주소 입력 (예: 101호, 3층) — 선택'),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('저장하기',
                          style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ── 여유 시간 프리뷰 배너 ──────────────────────────
class _SpareTimePreviewBanner extends StatelessWidget {
  final String arrivalTimeStr;
  final int spareTime;

  const _SpareTimePreviewBanner({
    required this.arrivalTimeStr,
    required this.spareTime,
  });

  String _calcDeparture(String arrival, int spare, {int estimatedMinutes = 0}) {
    // 예상 소요 시간이 없을 때는 spare만 반영 (경로 미선택 상태)
    final parts = arrival.split(':');
    if (parts.length != 2) return '--:--';
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final totalMin = h * 60 + m - spare - estimatedMinutes;
    if (totalMin < 0) {
      final absMin = totalMin.abs();
      return '전날 ${(absMin ~/ 60).toString().padLeft(2, '0')}:${(absMin % 60).toString().padLeft(2, '0')}';
    }
    return '${(totalMin ~/ 60).toString().padLeft(2, '0')}:${(totalMin % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (spareTime == 0) return const SizedBox.shrink();
    final depTime = _calcDeparture(arrivalTimeStr, spareTime);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              const Text('예상 권장 출발 시간',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(depTime,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              const SizedBox(width: 8),
              const Text('출발  →',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Text(arrivalTimeStr,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D7A6B))),
              const SizedBox(width: 4),
              const Text('도착',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '소요 시간 + 여유 $spareTime분 = ${spareTime}분 전 출발 (경로 소요 제외 기준)',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}