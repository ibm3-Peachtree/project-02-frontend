import 'package:flutter/foundation.dart';
import '../models/routine_model.dart';
import '../models/route_model.dart';
import '../models/weather_model.dart';
import 'package:dio/dio.dart';
import 'package:ruttu_app/core/constants/api_constants.dart';

abstract class HomeRepository {
  Future<List<RoutineModel>> getRoutines();
  Future<LiveStatusModel> getLiveStatus();
  Future<LiveRouteModel> getMyRoute();
  Future<LiveRouteModel> getRecommendedRoute();
  Future<CurrentSectionModel?> getCurrentSection();
  Future<List<IssueModel>> getTodayIssues();
  Future<WeatherAirQualityModel> getWeatherAirQuality();

  Future<void> sendLiveLocation({
    required double latitude,
    required double longitude,
    required double speed,
    required double accuracy,
  });
}

/// 실제 백엔드 API를 호출하는 구현체
/// AI 브리핑(날씨) 외 모든 기능이 구현되어 있습니다.
class ApiHomeRepository implements HomeRepository {
  ApiHomeRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<RoutineModel>> getRoutines() async {
    final response = await _dio.get(ApiConstants.routines);
    final data = response.data as List<dynamic>;
    return data
        .map((e) => RoutineModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
    try {
      final response = await _dio.get(ApiConstants.liveCurrentSection);
      return CurrentSectionModel.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<IssueModel>> getTodayIssues() async {
    try {
      final response = await _dio.get(ApiConstants.todayIssues);
      final data = response.data as List<dynamic>;
      return data
          .map((e) => IssueModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// AI 브리핑 날씨 — FastAPI 서버에서 가져옵니다.
  /// 아직 미구현인 경우 예외를 던지며, home_provider에서 catch하여 null 처리합니다.
  @override
  Future<WeatherAirQualityModel> getWeatherAirQuality() async {
    final fastApiDio = Dio(BaseOptions(
      baseUrl: ApiConstants.fastapiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Content-Type': 'application/json'},
    ));
    // access token 주입
    final token = _dio.options.headers['Authorization'];
    if (token != null) fastApiDio.options.headers['Authorization'] = token;

    final response = await fastApiDio.get(ApiConstants.briefingWeather);
    return WeatherAirQualityModel.fromJson(response.data as Map<String, dynamic>);
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
}