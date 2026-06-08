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

  // ── REST 전용 ─────────────────────────────────────────────────────────
  // 이 아래 메서드들은 REST API 호출로 초기 1회 fetch 또는 저장 용도로만 사용.
  // 실시간 STREAM 수신은 StompService를 직접 구독하는 Provider에서 처리한다.

  /// REST GET /me/routines/active/route/{routineId} — 나의 경로 정보 (초기 1회 fetch)
  Future<LiveRouteModel> getMyRoute(int routineId);

  /// REST GET /me/routines/active/reco/{routineId} — 추천 경로 정보 (초기 1회 fetch)
  Future<LiveRouteModel> getRecommendedRoute(int routineId);

  /// REST GET /me/routines/active/reco/{routineId} — 추천 경로 목록 (RouteListDto[])
  Future<List<RouteModel>> getRecoRouteList(int routineId);

  /// REST GET /me/routines/active/reco/{routineId} — 추천 경로 목록 + 돌발/우회 래퍼
  /// ※ 실시간 사고/우회 경로는 STOMP /user/queue/incident·detour 로 수신
  Future<RecoRouteListResponse> getRecoRouteListResponse(int routineId);

  /// REST POST /me/routines/active/reco/{recoId} — 추천 경로 선택 저장
  Future<void> saveRecoRoute(int recoId);

  /// REST GET /me/routines/active/reco/{recoId} — 추천 경로 상세
  Future<RouteModel> getRecoRouteDetail(int recoId);

  /// REST GET /me/routines/active/reco/detour/{pathId}
  /// — 우회 경로 상세 (DetourModel 기반 → RouteModel 변환)
  Future<RouteModel> getDetourDetail(int pathId);

  /// REST POST /me/routines/active/reco/detour/{pathId} — 우회 경로 선택 저장
  Future<void> saveDetourRoute(int pathId);

  /// REST GET /me/routines/active/location/my
  /// — 나의 경로 현재 구간 초기 1회 fetch
  /// ※ 이후 실시간 갱신은 STOMP /user/queue/location/my 구독으로 처리
  Future<CurrentSectionModel?> getCurrentSection();

  /// REST GET /me/routines/active/location/reco
  /// — 추천 경로 현재 구간 초기 1회 fetch
  /// ※ 이후 실시간 갱신은 STOMP /user/queue/location/reco 구독으로 처리
  Future<CurrentSectionModel?> getRecoCurrentSection();

  Future<List<IssueModel>> getTodayIssues();
  Future<WeatherAirQualityModel> getWeatherAirQuality();

  /// STOMP /app/location/my 또는 /app/location/reco 로 위치 전송
  /// ※ StompService.send()를 직접 사용하므로 이 메서드는 내부적으로
  ///   StompService를 위임 호출한다.
  Future<void> sendLiveLocation({
    required double latitude,
    required double longitude,
    required double speed,
    required double accuracy,
  });

  /// REST POST /me/routines/active/complete/my  (나의 경로로 완료)
  Future<void> completeMyRoute({
    required DateTime departureTime,
    required DateTime arrivalTime,
    int? satWaitTimeScore,
    int? satEtaScore,
    int? satRouteScore,
  });

  /// REST POST /me/routines/active/complete/reco  (추천 경로로 완료)
  Future<void> completeRecoRoute({
    required DateTime departureTime,
    required DateTime arrivalTime,
    int? satWaitTimeScore,
    int? satEtaScore,
    int? satRouteScore,
  });

  /// REST POST /me/routines/active/complete
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

  // ── REST: 나의 경로 초기 fetch ────────────────────────────────────────
  // 실시간 갱신: STOMP /user/queue/location/my (MyRouteNotifier 구독)
  @override
  Future<LiveRouteModel> getMyRoute(int routineId) async {
    final response = await _dio.get(ApiConstants.liveMyRoute(routineId));
    return LiveRouteModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ── REST: 추천 경로 초기 fetch ────────────────────────────────────────
  // 실시간 갱신: STOMP /user/queue/location/reco (RecoRouteNotifier 구독)
  @override
  Future<LiveRouteModel> getRecommendedRoute(int routineId) async {
    final response = await _dio.get(ApiConstants.liveRecoRouteList(routineId));
    return LiveRouteModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<RouteModel>> getRecoRouteList(int routineId) async {
    final response = await _dio.get(ApiConstants.liveRecoRouteList(routineId));
    final list = response.data as List<dynamic>;
    return list
        .map((e) => RouteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── REST: 추천 경로 목록 초기 fetch ─────────────────────────────────
  // 돌발 사고·우회 경로 실시간 갱신:
  //   STOMP /user/queue/incident  (IncidentDetourNotifier.subscribeRaw)
  //   STOMP /user/queue/detour    (IncidentDetourNotifier.subscribeRaw)
  @override
  Future<RecoRouteListResponse> getRecoRouteListResponse(int routineId) async {
    final response = await _dio.get(ApiConstants.liveRecoRouteList(routineId));
    return RecoRouteListResponse.fromJson(response.data);
  }

  @override
  Future<void> saveRecoRoute(int recoId) async {
    await _dio.post(ApiConstants.liveRecoSave(recoId));
  }

  @override
  Future<RouteModel> getRecoRouteDetail(int recoId) async {
    final response = await _dio.get(ApiConstants.liveRecoRouteDetail(recoId));
    return RouteModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<RouteModel> getDetourDetail(int pathId) async {
    final response = await _dio.get(ApiConstants.liveRecoDetourDetail(pathId));

    // 서버가 List<DetourDto> 배열로 응답하는 경우 — pathId로 찾아 변환
    if (response.data is List) {
      final list = (response.data as List<dynamic>)
          .map((e) => DetourModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final found = list.firstWhere(
        (d) => d.pathId == pathId,
        orElse: () => list.first,
      );
      return _detourToRouteModel(found);
    }

    // 단건 Map 응답
    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('path_segments')) {
      final detour = DetourModel.fromJson(data);
      return _detourToRouteModel(detour);
    }
    return RouteModel.fromJson(data);
  }

  RouteModel _detourToRouteModel(DetourModel detour) {
    final paths = detour.pathSegments.map((seg) {
      // DetourSegmentModel.type은 "TRANSIT" | "TRANSFER"이지만
      // PathModel은 "walk" | "bus" | "subway"를 기대한다.
      // TRANSFER → "walk"
      // TRANSIT  → displayName으로 지하철/버스 구분
      String mappedType;
      if (seg.isWalk) {
        mappedType = 'walk';
      } else if (seg.isSubway) {
        mappedType = 'subway';
      } else {
        mappedType = 'bus';
      }
      return PathModel(
        type: mappedType,
        sectionTime: seg.segmentDurationMin.round(),
        no: seg.displayName,
        stationCount: seg.stopCount,
        stationName: seg.stations.map((s) => s.name).toList(),
      );
    }).toList();
    return RouteModel(
      recoId: detour.pathId,
      totalDistance: detour.pathSegments.fold(0, (s, e) => s + e.totalDistanceM),
      totalTime: detour.totalDurationMin.round(),
      payment: 0,
      path: paths,
      isDetour: true,
    );
  }

  @override
  Future<void> saveDetourRoute(int pathId) async {
    await _dio.post(ApiConstants.liveDetourSave(pathId));
  }

  // ── REST: 나의 경로 현재 구간 초기 1회 fetch ─────────────────────────
  // 이후 실시간 갱신: STOMP /user/queue/location/my
  @override
  Future<CurrentSectionModel?> getCurrentSection() async {
    final response = await _dio.get(ApiConstants.liveCurrentSection);
    return CurrentSectionModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ── REST: 추천 경로 현재 구간 초기 1회 fetch ─────────────────────────
  // 이후 실시간 갱신: STOMP /user/queue/location/reco
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

  // ── STOMP 위치 전송 ───────────────────────────────────────────────────
  // liveLocationProvider에서 StompService.send()를 직접 호출하므로
  // 이 메서드는 더 이상 사용되지 않는다. 인터페이스 호환성을 위해 유지.
  @override
  Future<void> sendLiveLocation({
    required double latitude,
    required double longitude,
    required double speed,
    required double accuracy,
  }) async {
    // STOMP 전송은 liveLocationProvider → StompService.send() 로 처리됨.
    // REST fallback이 필요한 경우 아래 코드를 활성화할 것.
    debugPrint('[sendLiveLocation] STOMP로 처리됨 — REST 호출 생략');
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
