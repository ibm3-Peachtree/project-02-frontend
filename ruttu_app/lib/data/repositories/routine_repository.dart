import '../models/routine_model.dart';
import '../models/address_model.dart';
import '../models/route_model.dart';

// POST /routines Request Body
class CreateRoutineRequest {
  final String routineName;
  final String targetArrivalTime;
  final int departureAddressId;
  final int arrivalAddressId;
  final int routeId;
  final List<String> days;

  const CreateRoutineRequest({
    required this.routineName,
    required this.targetArrivalTime,
    required this.departureAddressId,
    required this.arrivalAddressId,
    required this.routeId,
    required this.days,
  });

  Map<String, dynamic> toJson() => {
        'routineName':         routineName,
        'targetArrivalTime':   targetArrivalTime,
        'departureAddressId':  departureAddressId,
        'arrivalAddressId':    arrivalAddressId,
        'routeId':             routeId,
        'days':                days,
      };
}

abstract class RoutineRepository {
  Future<List<RoutineModel>> getRoutines();
  Future<RoutineModel> getRoutineDetail(int routineId);
  Future<int> createRoutine(CreateRoutineRequest request);
  Future<void> updateRoutine(int routineId, CreateRoutineRequest request);
  Future<void> deleteRoutine(int routineId);
  Future<List<AddressModel>> getAddresses();
  Future<AddressModel> addAddress({
    required String name,
    required String address,
    double? latitude,
    double? longitude,
  });
  Future<List<RouteModel>> searchRoutes({
    required int departureAddressId,
    required int arrivalAddressId,
    required String targetArrivalTime,
  });
}

class MockRoutineRepository implements RoutineRepository {
  final List<RoutineModel> _routines = [];
  int _nextId = 1;
  int _nextAddressId = 3;

  final _addresses = [
    const AddressModel(
      addressId: 1,
      name: '집',
      address: '서울특별시 강남구 테헤란로 123',
      latitude: 37.5012,
      longitude: 127.0396,
    ),
    const AddressModel(
      addressId: 2,
      name: '회사',
      address: '서울특별시 중구 을지로 100',
      latitude: 37.5663,
      longitude: 126.9997,
    ),
  ];

  @override
  Future<List<RoutineModel>> getRoutines() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_routines);
  }

  @override
  Future<RoutineModel> getRoutineDetail(int routineId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _routines.firstWhere((r) => r.routineId == routineId);
  }

  @override
  Future<int> createRoutine(CreateRoutineRequest request) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final dep = _addresses.firstWhere(
        (a) => a.addressId == request.departureAddressId,
        orElse: () => _addresses.first);
    final arr = _addresses.firstWhere(
        (a) => a.addressId == request.arrivalAddressId,
        orElse: () => _addresses.last);
    final newRoutine = RoutineModel(
      routineId: _nextId++,
      routineName: request.routineName,
      departureAddressName: dep.name,
      arrivalAddressName: arr.name,
      targetArrivalTime: request.targetArrivalTime,
      recommendedDepartureTime: _calcDeparture(request.targetArrivalTime, 32),
      estimatedDuration: 32,
      days: request.days,
    );
    _routines.add(newRoutine);
    return newRoutine.routineId;
  }

  @override
  Future<void> updateRoutine(int routineId, CreateRoutineRequest request) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _routines.indexWhere((r) => r.routineId == routineId);
    if (index == -1) return;
    final dep = _addresses.firstWhere(
        (a) => a.addressId == request.departureAddressId,
        orElse: () => _addresses.first);
    final arr = _addresses.firstWhere(
        (a) => a.addressId == request.arrivalAddressId,
        orElse: () => _addresses.last);
    _routines[index] = RoutineModel(
      routineId: routineId,
      routineName: request.routineName,
      departureAddressName: dep.name,
      arrivalAddressName: arr.name,
      targetArrivalTime: request.targetArrivalTime,
      recommendedDepartureTime: _calcDeparture(request.targetArrivalTime, 32),
      estimatedDuration: 32,
      days: request.days,
      isActive: _routines[index].isActive,
    );
  }

  @override
  Future<void> deleteRoutine(int routineId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _routines.removeWhere((r) => r.routineId == routineId);
  }

  @override
  Future<List<AddressModel>> getAddresses() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_addresses);
  }

  @override
  Future<AddressModel> addAddress({
    required String name,
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final newAddress = AddressModel(
      addressId: _nextAddressId++,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
    _addresses.add(newAddress);
    return newAddress;
  }

  @override
  Future<List<RouteModel>> searchRoutes({
    required int departureAddressId,
    required int arrivalAddressId,
    required String targetArrivalTime,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return [
      RouteModel(
        pathType: 3,
        totalDistance: 8200,
        trafficDistance: 6500,
        totalWalk: 1700,
        totalTime: 32,
        payment: 1400,
        path: [
          const PathModel(trafficType: 3, distance: 650, sectionTime: 8,
              startName: '출발지', endName: '강남역'),
          const PathModel(trafficType: 1, distance: 3200, sectionTime: 12,
              stationCount: 3, subwayCode: 2,
              startName: '강남역', endName: '을지로입구역', way: '성수 방향'),
          const PathModel(trafficType: 3, distance: 400, sectionTime: 5,
              startName: '을지로입구역', endName: '도착지'),
        ],
      ),
      RouteModel(
        pathType: 2,
        totalDistance: 9100,
        trafficDistance: 7800,
        totalWalk: 1300,
        totalTime: 38,
        payment: 1400,
        path: [
          const PathModel(trafficType: 3, distance: 300, sectionTime: 4,
              startName: '출발지', endName: '버스 정류장'),
          const PathModel(trafficType: 2, distance: 7000, sectionTime: 25,
              stationCount: 8, busNo: 147,
              startName: '버스 정류장', endName: '도착지 정류장'),
          const PathModel(trafficType: 3, distance: 300, sectionTime: 4,
              startName: '도착지 정류장', endName: '도착지'),
        ],
      ),
    ];
  }

  String _calcDeparture(String targetTime, int durationMin) {
    final parts = targetTime.split(':');
    final dt = DateTime(0, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    final dep = dt.subtract(Duration(minutes: durationMin + 5));
    return '${dep.hour.toString().padLeft(2, '0')}:${dep.minute.toString().padLeft(2, '0')}';
  }
}
