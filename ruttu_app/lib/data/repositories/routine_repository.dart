import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/address_model.dart';
import '../models/route_model.dart';
import '../models/routine_model.dart';

/// POST /me/routines 요청 (RoutineDto)
class CreateRoutineRequest {
  final String routineName;
  final String targetArrivalTime;
  final String originAlias;
  final String origin;
  final String destinationAlias;
  final String destination;
  final int recoId;
  final List<String> days;

  const CreateRoutineRequest({
    required this.routineName,
    required this.targetArrivalTime,
    required this.originAlias,
    required this.origin,
    required this.destinationAlias,
    required this.destination,
    required this.recoId,
    required this.days,
  });

  Map<String, dynamic> toJson() => {
        'routineName': routineName,
        'targetArrivalTime': _toLocalTime(targetArrivalTime),
        'originAlias': originAlias,
        'origin': origin,
        'destinationAlias': destinationAlias,
        'destination': destination,
        'recoId': recoId,
        'dow': _daysToDow(days),
      };

  static String _toLocalTime(String hhmm) {
    if (hhmm.length == 5) return '$hhmm:00';
    return hhmm;
  }

  static List<bool> _daysToDow(List<String> days) {
    const order = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return order.map((day) => days.contains(day)).toList();
  }
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
    required String roadAddress,
    String? jibunAddress,
    double? latitude,
    double? longitude,
  });
  Future<List<RouteModel>> searchRoutes({
    required int departureAddressId,
    required int arrivalAddressId,
    required String targetArrivalTime,
  });
  Future<RouteModel> getRouteDetail(int recoId);
}

class ApiRoutineRepository implements RoutineRepository {
  ApiRoutineRepository(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  @override
  Future<List<RoutineModel>> getRoutines() async {
    final response = await _dio.get(ApiConstants.routines);
    final data = response.data as List<dynamic>;
    return data
        .map((e) => RoutineModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RoutineModel> getRoutineDetail(int routineId) async {
    final response = await _dio.get(ApiConstants.routineById(routineId));
    return RoutineModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<int> createRoutine(CreateRoutineRequest request) async {
    await _dio.post(ApiConstants.routines, data: request.toJson());
    return 0;
  }

  @override
  Future<void> updateRoutine(
    int routineId,
    CreateRoutineRequest request,
  ) async {
    await _dio.put(
      ApiConstants.routineById(routineId),
      data: request.toJson(),
    );
  }

  @override
  Future<void> deleteRoutine(int routineId) async {
    await _dio.delete(ApiConstants.routineById(routineId));
  }

  @override
  Future<List<RouteModel>> searchRoutes({
    required int departureAddressId,
    required int arrivalAddressId,
    required String targetArrivalTime,
  }) async {
    final response = await _dio.get(
      ApiConstants.routeRecommend,
      queryParameters: {
        'originId': departureAddressId,
        'destinationId': arrivalAddressId,
      },
    );
    final data = response.data as List<dynamic>;
    return data
        .map((e) => RouteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RouteModel> getRouteDetail(int recoId) async {
    final response = await _dio.get(ApiConstants.routeRecommendDetail(recoId));
    return RouteModel.fromJson(response.data as Map<String, dynamic>);
  }

  // 주소 API 미구현 — Mock 데이터 사용
  @override
  Future<List<AddressModel>> getAddresses() =>
      MockRoutineRepository().getAddresses();

  @override
  Future<AddressModel> addAddress({
    required String name,
    required String roadAddress,
    String? jibunAddress,
    double? latitude,
    double? longitude,
  }) =>
      MockRoutineRepository().addAddress(
        name: name,
        roadAddress: roadAddress,
        jibunAddress: jibunAddress,
        latitude: latitude,
        longitude: longitude,
      );
}

class MockRoutineRepository implements RoutineRepository {
  @override
  Future<List<RoutineModel>> getRoutines() async => [];

  @override
  Future<RoutineModel> getRoutineDetail(int routineId) async =>
      throw UnimplementedError();

  @override
  Future<int> createRoutine(CreateRoutineRequest request) async => 1;

  @override
  Future<void> updateRoutine(
    int routineId,
    CreateRoutineRequest request,
  ) async {
    return;
  }

  @override
  Future<void> deleteRoutine(int routineId) async {
    return;
  }

  @override
  Future<List<AddressModel>> getAddresses() async {
    return [
      AddressModel(
        addressId: 4,
        name: "집",
        roadAddress: "서울특별시 강남구 테헤란로 123",
        latitude: 37.5012,
        longitude: 127.0396,
      ),
      AddressModel(
        addressId: 5,
        name: "회사",
        roadAddress: "서울특별시 중구 세종대로 110",
        latitude: 37.5665,
        longitude: 126.9780,
      ),
      AddressModel(
        addressId: 6,
        name: "헬스장",
        roadAddress: "서울특별시 서초구 서초대로 74길 11",
        latitude: 37.4842,
        longitude: 127.0348,
      ),
    ];
  }

  @override
  Future<AddressModel> addAddress({
    required String name,
    required String roadAddress,
    String? jibunAddress,
    double? latitude,
    double? longitude,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<RouteModel>> searchRoutes({
    required int departureAddressId,
    required int arrivalAddressId,
    required String targetArrivalTime,
  }) async =>
      [];

  @override
  Future<RouteModel> getRouteDetail(int recoId) async =>
      throw UnimplementedError();
}