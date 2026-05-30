import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kakao_postcode_page.dart';
import '../../../data/models/address_model.dart';
import '../../../data/models/routine_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/repositories/routine_repository.dart';
import '../providers/routine_provider.dart';
import '../../home/providers/home_provider.dart';

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
      setState(() {
        _routes = routes;
        _loadingRoutes = false;
      });
    } catch (_) {
      setState(() => _loadingRoutes = false);
    }
  }

  Future<void> _showRouteDetail(RouteModel summary) async {
    RouteModel detail = summary;
    try {
      detail = await ref
          .read(routineRepositoryProvider)
          .getRouteDetail(summary.recoId);
    } catch (_) {}
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, controller) => _RouteDetailSheet(
          route: detail,
          scrollController: controller,
        ),
      ),
    );
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
    if (_selectedRouteIndex == null) return;
    final selectedRoute = _routes[_selectedRouteIndex!];
    final routineName = _nameController.text.trim();
    final request = CreateRoutineRequest(
      routineName: routineName,
      targetArrivalTime: _arrivalTimeStr,
      originAlias: _departure!.name,
      origin: _departure!.address,
      destinationAlias: _arrival!.name,
      destination: _arrival!.address,
      recoId: selectedRoute.recoId ?? _selectedRouteIndex!,
      days: _selectedDays.toList(),
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
        ref.read(homeProvider.notifier).refresh();
        context.pop();
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

      if (isDuplicateTime) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 사용 중인 루틴 이름이에요. 다른 이름을 입력해주세요.'),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        final msg = serverMessage.isNotEmpty ? serverMessage : '루틴 저장에 실패했어요. (${e.response?.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('루틴 저장에 실패했어요: $e'), backgroundColor: AppColors.error),
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
                    setState(() => _selectedDays.contains(day)
                        ? _selectedDays.remove(day)
                        : _selectedDays.add(day)),
                onPickTime: _pickTime,
                existingNames: ref.read(routineListProvider).valueOrNull
                    ?.where((r) => r.routineId != widget.editRoutine?.routineId)
                    .map((r) => r.routineName)
                    .toList() ?? [],
                onNext: () {
                  if (!_step1Key.currentState!.validate()) return;
                  if (_selectedDays.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('요일을 하나 이상 선택해주세요.')));
                    return;
                  }
                  // 동시간대 프론트 체크
                  final conflictRoutine = (ref.read(routineListProvider).valueOrNull ?? [])
                      .where((r) => r.routineId != widget.editRoutine?.routineId)
                      .where((r) => r.targetArrivalTime == _arrivalTimeStr)
                      .where((r) => r.days.any((d) => _selectedDays.contains(d)))
                      .firstOrNull;
                  if (conflictRoutine != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$_arrivalTimeStr 에 이미 \'${conflictRoutine.routineName}\' 루틴이 있어요. '
                          '시간을 겹치지 않게 설정해주세요.',
                        ),
                        backgroundColor: AppColors.error,
                        action: SnackBarAction(
                          label: '시간 변경',
                          textColor: Colors.white,
                          onPressed: _pickTime,
                        ),
                      ),
                    );
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
  final VoidCallback onNext;
  final List<String> existingNames;

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
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onNext,
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) {
        final bottomPad = MediaQuery.of(sheetCtx).viewPadding.bottom;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('$label 선택',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            ),
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
            SizedBox(height: 8 + bottomPad),
          ],
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
        onSave: (name, address, lat, lng) async {
          final newAddr =
              await ref.read(routineRepositoryProvider).addAddress(
                    name: name,
                    address: address,
                    latitude: lat,   // null until backend geocoding
                    longitude: lng,  // null until backend geocoding
                  );
          ref.invalidate(addressListProvider);
          if (ctx.mounted) Navigator.pop(ctx, newAddr);
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
  final Future<void> Function(RouteModel) onDetail;
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
                    onDetail: () => onDetail(e.value),
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
  final VoidCallback onDetail;

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
                  onPressed: onDetail,
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
      children: [
        for (int i = 0; i < paths.length; i++) ...[
          if (paths[i].isWalking)
            const Icon(Icons.directions_walk,
                size: 18, color: AppColors.textSecondary)
          else
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: paths[i].isSubway
                    ? Colors.blue.withValues(alpha: 0.12)
                    : Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                paths[i].isSubway
                    ? '${paths[i].no.isNotEmpty ? paths[i].no.first : ''}호선'
                    : '${paths[i].no.isNotEmpty ? paths[i].no.first : ''}번',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: paths[i].isSubway ? Colors.blue : Colors.green),
              ),
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
        // 드래그 핸들 + 헤더
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('경로 상세',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('${route.totalTime}분',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Text('${route.payment}원',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 단계별 리스트
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
            children: [
              ...route.path.asMap().entries.map((e) =>
                  _DetailPathItem(
                      path: e.value,
                      isLast: e.key == route.path.length - 1)),
            ],
          ),
        ),
        // 하단 합계 바
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          color: AppColors.background,
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
                onPressed: () => Navigator.pop(context),
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
    final color = path.isWalking
        ? AppColors.textSecondary
        : path.isSubway
            ? Colors.blue
            : Colors.green;
    final icon = path.isWalking
        ? Icons.directions_walk
        : path.isSubway
            ? Icons.subway_outlined
            : Icons.directions_bus_outlined;

    final String title = path.isWalking
        ? '도보'
        : path.isSubway
            ? '${path.start ?? ''} 승차 — ${path.no.isNotEmpty ? path.no.first : ''}호선'
            : '${path.start ?? ''} 승차 — ${path.no.isNotEmpty ? path.no.first : ''}번';

    final String subtitle = '${path.sectionTime}분'
        '${path.stationCount != null ? ' · ${path.stationCount}정거장' : ''}'
        '${path.way != null ? ' · ${path.way}' : ''}';

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
                  color: color.withValues(alpha: 0.12)),
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
                // 제목 행 (정거장 있으면 클릭 시 토글)
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
                const SizedBox(height: 4),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1155CC)),
                      ),
                    ),
                    if (hasStations) ...[
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
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E6B30)),
                        ),
                      ),
                    ],
                    if (path.way != null) ...[
                      const SizedBox(width: 6),
                      Text(path.way!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
                // 정류장 수직 목록 (펼쳤을 때)
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
                                width: 8, height: 8,
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
  final Future<void> Function(String name, String address, double? lat, double? lng) onSave;
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
    final result = await Navigator.push<KakaoPostcodeResult>(
      context,
      MaterialPageRoute(builder: (_) => const KakaoPostcodePage()),
    );
    if (result != null) setState(() => _kakaoResult = result);
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
      await widget.onSave(_nameCtrl.text.trim(), fullAddress, null, null);
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