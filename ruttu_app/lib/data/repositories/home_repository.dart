import 'package:flutter/foundation.dart';
import '../models/routine_model.dart';
import '../models/route_model.dart';
import '../models/weather_model.dart';
import 'package:dio/dio.dart';
import 'package:ruttu_app/core/constants/api_constants.dart';

abstract class HomeRepository {
  Future<List<RoutineModel>> getRoutines();
  Future<RoutineModel> getRoutineDetail(int routineId);
  Future<RouteModel> getRouteDetail(int recoId);
  Future<LiveStatusModel> getLiveStatus();
  Future<LiveRouteModel> getMyRoute();
  Future<LiveRouteModel> getRecommendedRoute();
  Future<CurrentSectionModel?> getCurrentSection();
  Future<CurrentSectionModel?> getRecoCurrentSection();
  Future<List<IssueModel>> getTodayIssues();
  Future<WeatherAirQualityModel> getWeatherAirQuality();

  Future<void> sendLiveLocation({
    required double latitude,
    required double longitude,
    required double speed,
    required double accuracy,
  });

  /// POST /me/routines/active/complete/my  (나의 경로로 완료)
  Future<void> completeMyRoute({
    required DateTime departureTime,
    required DateTime arrivalTime,
    int? satWaitTimeScore,
    int? satEtaScore,
    int? satRouteScore,
  });

  /// POST /me/routines/active/complete/reco  (추천 경로로 완료)
  Future<void> completeRecoRoute({
    required DateTime departureTime,
    required DateTime arrivalTime,
    int? satWaitTimeScore,
    int? satEtaScore,
    int? satRouteScore,
  });

  /// POST /me/routines/active/complete (routineId 제외 반영)
  Future<void> completeRoutine({
    required DateTime departureTime,
    required DateTime arrivalTime,
    int? satWaitTimeScore,
    int? satEtaScore,
    int? satRouteScore,
  });
}

/// 실제 백엔드 API를 호출하는 구현체
class ApiHomeRepository implements HomeRepository {
  ApiHomeRepository(this._dio)
    : fastApiDio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.fastapiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: const {'Content-Type': 'application/json'},
        ),
      );
  final Dio _dio;
  final Dio fastApiDio;

  @override
  Future<List<RoutineModel>> getRoutines() async {
    final response = await _dio.get(ApiConstants.routines);
    return (response.data as List)
        .map((e) => RoutineModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RoutineModel> getRoutineDetail(int routineId) async {
    final response = await _dio.get(ApiConstants.routineById(routineId));
    return RoutineModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<RouteModel> getRouteDetail(int recoId) async {
    final response = await _dio.get(ApiConstants.routeRecommendDetail(recoId));
    return RouteModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<LiveStatusModel> getLiveStatus() async {
    final response = await _dio.get(ApiConstants.liveStatus);
    return LiveStatusModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<LiveRouteModel> getMyRoute() async {
    final response = await _dio.get(ApiConstants.liveMyRoute);
    return LiveRouteModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<LiveRouteModel> getRecommendedRoute() async {
    final response = await _dio.get(ApiConstants.liveRecoRoute);
    return LiveRouteModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<CurrentSectionModel?> getCurrentSection() async {
    final response = await _dio.get(ApiConstants.liveCurrentSection);
    return CurrentSectionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<CurrentSectionModel?> getRecoCurrentSection() async {
    final response = await _dio.get(ApiConstants.liveCurrentSectionReco);
    return CurrentSectionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<IssueModel>> getTodayIssues() async {
    final response = await _dio.get(ApiConstants.todayIssues);
    return (response.data as List)
        .map((e) => IssueModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<WeatherAirQualityModel> getWeatherAirQuality() async {
    final response = await fastApiDio.get(ApiConstants.briefingWeather);
    return WeatherAirQualityModel.fromJson(
      response.data as Map<String, dynamic>,
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
      debugPrint('[LiveLocation] 전송 성공: lat=$latitude, lng=$longitude');
    } catch (e) {
      debugPrint('[LiveLocation] 전송 실패 (무시됨): $e');
    }
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _completeBody({
    required DateTime departureTime,
    required DateTime arrivalTime,
    int? satWaitTimeScore,
    int? satEtaScore,
    int? satRouteScore,
  }) =>
      {
        'departureTime': _formatTime(departureTime),
        'arrivalTime': _formatTime(arrivalTime),
        'satWaitTimeScore': satWaitTimeScore,
        'satEtaScore': satEtaScore,
        'satRouteScore': satRouteScore,
      };

  @override
  Future<void> completeMyRoute({
    required DateTime departureTime,
    required DateTime arrivalTime,
    int? satWaitTimeScore,
    int? satEtaScore,
    int? satRouteScore,
  }) async {
    try {
      await _dio.post(
        ApiConstants.routineCompleteMyRoute,
        data: _completeBody(
          departureTime: departureTime,
          arrivalTime: arrivalTime,
          satWaitTimeScore: satWaitTimeScore,
          satEtaScore: satEtaScore,
          satRouteScore: satRouteScore,
        ),
      );
      debugPrint('[CompleteMyRoute] 전송 성공');
    } catch (e) {
      debugPrint('[CompleteMyRoute] 전송 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> completeRecoRoute({
    required DateTime departureTime,
    required DateTime arrivalTime,
    int? satWaitTimeScore,
    int? satEtaScore,
    int? satRouteScore,
  }) async {
    try {
      await _dio.post(
        ApiConstants.routineCompleteRecoRoute,
        data: _completeBody(
          departureTime: departureTime,
          arrivalTime: arrivalTime,
          satWaitTimeScore: satWaitTimeScore,
          satEtaScore: satEtaScore,
          satRouteScore: satRouteScore,
        ),
      );
      debugPrint('[CompleteRecoRoute] 전송 성공');
    } catch (e) {
      debugPrint('[CompleteRecoRoute] 전송 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> completeRoutine({
    required DateTime departureTime,
    required DateTime arrivalTime,
    int? satWaitTimeScore,
    int? satEtaScore,
    int? satRouteScore,
  }) async {
    try {
      await _dio.post(
        ApiConstants.routineComplete,
        data: _completeBody(
          departureTime: departureTime,
          arrivalTime: arrivalTime,
          satWaitTimeScore: satWaitTimeScore,
          satEtaScore: satEtaScore,
          satRouteScore: satRouteScore,
        ),
      );
      debugPrint('[CompleteRoutine] 전송 성공');
    } catch (e) {
      debugPrint('[CompleteRoutine] 전송 실패: $e');
      rethrow;
    }
  }
}