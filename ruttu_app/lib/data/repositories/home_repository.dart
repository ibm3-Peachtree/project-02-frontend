import '../models/routine_model.dart';
import '../models/route_model.dart';
import '../models/weather_model.dart';
import '../models/address_model.dart'; // ✅ 버그 수정: AddressModel/AddressRepository import 추가
import 'address_repository.dart';      // ✅ AddressRepository import
import 'package:dio/dio.dart';
import 'package:ruttu_app/core/constants/api_constants.dart';

// ✅ MockAddressRepository는 address_repository.dart 에만 존재하므로
//    home_repository.dart 에서는 삭제 (중복 선언 제거)

abstract class HomeRepository {
  Future<List<RoutineModel>> getRoutines();
  Future<LiveStatusModel> getLiveStatus();
  Future<RouteModel> getMyRoute();
  Future<RouteModel> getRecommendedRoute();
  Future<List<IssueModel>> getTodayIssues();
  Future<WeatherAirQualityModel> getWeatherAirQuality();

  Future<void> sendLiveLocation({
    required double latitude,
    required double longitude,
    required double speed,
    required double accuracy,
  });
}

/// Mock 데이터로 UI를 구성하되, sendLiveLocation만 실제 API를 호출합니다.
/// 각 API가 완성되면 해당 메서드만 ApiHomeRepository로 이전하세요.
class MockHomeRepository implements HomeRepository {
  MockHomeRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<RoutineModel>> getRoutines() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      RoutineModel(
        routineId: 1,
        routineName: '수원 → 여의도 출근',
        departureAddressName: '집',
        arrivalAddressName: '회사',
        targetArrivalTime: '09:00',
        recommendedDepartureTime: '07:37',
        estimatedDuration: 83,
        days: ['MON', 'TUE', 'WED', 'THU', 'FRI'],
        isActive: true,
      ),
    ];
  }

  @override
  Future<LiveStatusModel> getLiveStatus() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const LiveStatusModel(status: '도보 중', updatedAt: 0);
  }

  @override
  Future<RouteModel> getMyRoute() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return RouteModel(
      recoId: 1,
      totalDistance: 41200,
      totalTime: 83,
      payment: 2500,
      startName: '수원시 팔달구 자택',
      endName: '여의도 회사',
      path: [
        const PathModel(type: 'walk', sectionTime: 5, start: '수원시 팔달구 자택', end: '수원역 버스 정류장'),
        PathModel(
          type: 'bus', sectionTime: 35, no: const ['7770'], stationCount: 12,
          start: '수원역 버스터미널', end: '사당역 버스 정류장',
          stationName: const ['수원역','매탄동','화서역','안양역','명학역','금정역','산본역','수리산역','안양1번가','이수역','총신대입구역','사당역'],
        ),
        const PathModel(type: 'walk', sectionTime: 4, start: '사당역 버스 정류장', end: '사당역 2호선 승강장'),
        PathModel(
          type: 'subway', sectionTime: 18, no: const ['2'], stationCount: 6,
          start: '사당역', end: '당산역', way: '성수 방향',
          stationName: const ['사당역','방배역','서초역','교대역','강남역','역삼역','선릉역','당산역'],
        ),
        const PathModel(type: 'walk', sectionTime: 3, start: '당산역 2호선 승강장', end: '당산역 9호선 승강장'),
        PathModel(
          type: 'subway', sectionTime: 8, no: const ['9'], stationCount: 2,
          start: '당산역', end: '여의도역', way: '김포공항 방향',
          stationName: const ['당산역','국회의사당역','여의도역'],
        ),
        const PathModel(type: 'walk', sectionTime: 10, start: '여의도역', end: '여의도 회사'),
      ],
    );
  }

  @override
  Future<RouteModel> getRecommendedRoute() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return RouteModel(
      recoId: 2,
      totalDistance: 38500,
      totalTime: 70,
      payment: 2800,
      startName: '수원시 팔달구 자택',
      endName: '여의도 회사',
      path: [
        const PathModel(type: 'walk', sectionTime: 5, start: '수원시 팔달구 자택', end: '수원역 지하철 1호선'),
        PathModel(
          type: 'subway', sectionTime: 42, no: const ['1'], stationCount: 11,
          start: '수원역', end: '노량진역', way: '서울역 방향',
          stationName: const ['수원역','세류역','병점역','서동탄역','오산역','오산대역','진위역','송탄역','서정리역','평택역','지제역','천안역'],
        ),
        const PathModel(type: 'walk', sectionTime: 6, start: '노량진역 1호선', end: '노량진역 9호선 승강장'),
        PathModel(
          type: 'subway', sectionTime: 10, no: const ['9'], stationCount: 3,
          start: '노량진역', end: '여의도역', way: '김포공항 방향',
          stationName: const ['노량진역','샛강역','여의도역'],
        ),
        const PathModel(type: 'walk', sectionTime: 7, start: '여의도역', end: '여의도 회사'),
      ],
    );
  }

  @override
  Future<List<IssueModel>> getTodayIssues() async => [];

  @override
  Future<WeatherAirQualityModel> getWeatherAirQuality() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return WeatherAirQualityModel(
      weather: [
        WeatherModel(
          dateTime: DateTime.now().toIso8601String(),
          tmp: 23, wsd: '2.5', sky: '1', pty: '0',
          pop: 10, pcp: '없음', reh: 45, sno: '없음',
        ),
      ],
      airQuality: AirQualityModel(
        pm10: const AirQualityRegionModel(seoul: '좋음', gyeonggi: '좋음'),
        pm25: const AirQualityRegionModel(seoul: '좋음', gyeonggi: '좋음'),
      ),
    );
  }

  @override
  Future<void> sendLiveLocation({
    required double latitude,
    required double longitude,
    required double speed,
    required double accuracy,
  }) async {
    try {
      await _dio.patch(
        ApiConstants.liveLocation,
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'speed': speed,
          'accuracy': accuracy,
        },
      );
      print('[LiveLocation] 전송 성공: lat=$latitude, lng=$longitude');
    } catch (e) {
      print('[LiveLocation] 전송 실패 (무시됨): $e');
    }
  }
}

class ApiHomeRepository implements HomeRepository {
  ApiHomeRepository(this._dio);
  final Dio _dio;

  @override
  Future<void> sendLiveLocation({
    required double latitude,
    required double longitude,
    required double speed,
    required double accuracy,
  }) async {
    await _dio.patch(
      ApiConstants.liveLocation,
      data: {'latitude': latitude, 'longitude': longitude, 'speed': speed, 'accuracy': accuracy},
    );
  }

  @override Future<List<RoutineModel>> getRoutines() => throw UnimplementedError();
  @override Future<LiveStatusModel> getLiveStatus() => throw UnimplementedError();
  @override Future<RouteModel> getMyRoute() => throw UnimplementedError();
  @override Future<RouteModel> getRecommendedRoute() => throw UnimplementedError();
  @override Future<List<IssueModel>> getTodayIssues() => throw UnimplementedError();
  @override Future<WeatherAirQualityModel> getWeatherAirQuality() => throw UnimplementedError();
}