import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/routine_model.dart';
import '../../../data/models/address_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/repositories/routine_repository.dart';

final routineRepositoryProvider = Provider<RoutineRepository>(
  (_) => MockRoutineRepository(),
);

// 루틴 목록
final routineListProvider =
    StateNotifierProvider<RoutineListNotifier, AsyncValue<List<RoutineModel>>>(
  (ref) => RoutineListNotifier(ref.read(routineRepositoryProvider)),
);

class RoutineListNotifier
    extends StateNotifier<AsyncValue<List<RoutineModel>>> {
  final RoutineRepository _repository;

  RoutineListNotifier(this._repository) : super(const AsyncLoading());

  Future<void> load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.getRoutines());
  }

  Future<void> deleteRoutine(int routineId) async {
    await _repository.deleteRoutine(routineId);
    await load();
  }

  Future<int> createRoutine(CreateRoutineRequest request) async {
    final id = await _repository.createRoutine(request);
    await load();
    return id;
  }

  Future<void> updateRoutine(int routineId, CreateRoutineRequest request) async {
    await _repository.updateRoutine(routineId, request);
    await load();
  }
}

// 루틴 상세
final routineDetailProvider =
    FutureProvider.family<RoutineModel, int>((ref, routineId) {
  return ref.read(routineRepositoryProvider).getRoutineDetail(routineId);
});

// 주소 목록
final addressListProvider = FutureProvider<List<AddressModel>>((ref) {
  return ref.read(routineRepositoryProvider).getAddresses();
});

// 경로 검색 결과
final routeSearchProvider =
    FutureProvider.family<List<RouteModel>, RouteSearchParams>(
  (ref, params) => ref.read(routineRepositoryProvider).searchRoutes(
        departureAddressId: params.departureAddressId,
        arrivalAddressId: params.arrivalAddressId,
        targetArrivalTime: params.targetArrivalTime,
      ),
);

class RouteSearchParams {
  final int departureAddressId;
  final int arrivalAddressId;
  final String targetArrivalTime;

  const RouteSearchParams({
    required this.departureAddressId,
    required this.arrivalAddressId,
    required this.targetArrivalTime,
  });

  @override
  bool operator ==(Object other) =>
      other is RouteSearchParams &&
      other.departureAddressId == departureAddressId &&
      other.arrivalAddressId == arrivalAddressId &&
      other.targetArrivalTime == targetArrivalTime;

  @override
  int get hashCode =>
      Object.hash(departureAddressId, arrivalAddressId, targetArrivalTime);
}
