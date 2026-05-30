import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/routine_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/weather_model.dart';
import '../../../data/repositories/home_repository.dart';
import '../../auth/providers/network_provider.dart';
import 'home_state.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return ApiHomeRepository(ref.read(apiClientProvider).dio);
});

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>(
  (ref) => HomeNotifier(ref.read(homeRepositoryProvider)),
);

class HomeNotifier extends StateNotifier<HomeState> {
  final HomeRepository _repository;

  /// 실시간 폴링 타이머 (active 상태에서 주기적으로 백엔드 조회)
  Timer? _liveTimer;

  /// 폴링 주기 — 10초마다 status / section / recoRoute 갱신
  static const _pollInterval = Duration(seconds: 10);

  HomeNotifier(this._repository) : super(const HomeState());

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      final routines = await _repository.getRoutines();

      WeatherAirQualityModel? weather;
      try {
        weather = await _repository.getWeatherAirQuality();
      } catch (_) {}

      if (routines.isEmpty) {
        state = HomeState(status: HomeStatus.noRoutine, weather: weather);
        return;
      }

      final today = _todayKey();
      final hasTodayRoutine = routines.any((r) => r.isActive && r.days.contains(today));

      if (!hasTodayRoutine) {
        state = HomeState(
          status: HomeStatus.noTodayRoutine,
          weather: weather,
          // 루틴 목록은 state에 없으므로 activeRoutine만 null로 둠
        );
        return;
      }

      final todayRoutine = routines.firstWhere(
        (r) => r.isActive && r.days.contains(today),
      );

      // preActive 상태에서는 루틴 상세의 route 데이터를 사용
      // active 엔드포인트(/me/routines/active/*)는 출발 후에만 유효하므로 여기서 호출하지 않음
      RoutineModel todayRoutineDetail = todayRoutine;
      try {
        todayRoutineDetail = await _repository.getRoutineDetail(todayRoutine.routineId);
      } catch (_) {}

      // 루틴 상세의 route → LiveRouteModel로 변환
      LiveRouteModel? myRoute;
      final routeData = todayRoutineDetail.route;
      if (routeData != null) {
        myRoute = LiveRouteModel(
          totalDistance: routeData.totalDistance,
          totalTime: routeData.totalTime,
          payment: routeData.payment,
          startName: routeData.startName,
          endName: routeData.endName,
          path: routeData.path,
        );
      }

      // preActive 추천 경로: recoId 기반으로 조회, 실패 시 myRoute와 동일하게 표시
      LiveRouteModel? recommendedRoute;
      final recoId = routeData?.recoId;
      if (recoId != null && recoId > 0) {
        try {
          final recoDetail = await _repository.getRouteDetail(recoId);
          recommendedRoute = LiveRouteModel(
            totalDistance: recoDetail.totalDistance,
            totalTime: recoDetail.totalTime,
            payment: recoDetail.payment,
            startName: recoDetail.startName,
            endName: recoDetail.endName,
            path: recoDetail.path,
          );
        } catch (e) {
          debugPrint('[initialize] getRouteDetail 실패, myRoute로 fallback: $e');
          recommendedRoute = myRoute; // 조회 실패 시 내 경로와 동일하게 표시
        }
      } else {
        // recoId 없음 → 내 경로를 추천 경로로도 표시
        recommendedRoute = myRoute;
      }

      state = HomeState(
        status: HomeStatus.preActive,
        activeRoutine: todayRoutineDetail,
        weather: weather,
        myRoute: myRoute,
        recommendedRoute: recommendedRoute,
      );
    } catch (e) {
      debugPrint('❌ initialize 실패: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> startRoute() async {
    if (state.activeRoutine == null) return;
    state = state.copyWith(isLoading: true);

    // 각 API를 독립적으로 호출 — 하나 실패해도 나머지는 계속 진행
    LiveRouteModel? route;
    try {
      route = await _repository.getMyRoute();
    } catch (e) {
      debugPrint('[startRoute] getMyRoute 실패: $e');
      route = state.myRoute; // preActive에서 로드한 경로 재사용
    }

    LiveRouteModel? recoRoute;
    try {
      recoRoute = await _repository.getRecommendedRoute();
    } catch (e) {
      debugPrint('[startRoute] getRecommendedRoute 실패: $e');
      recoRoute = state.recommendedRoute ?? route; // 실패 시 내 경로로 fallback
    }

    CurrentSectionModel? section;
    try {
      section = await _repository.getCurrentSection();
    } catch (e) {
      debugPrint('[startRoute] getCurrentSection 실패 (무시됨): $e');
    }

    LiveStatusModel? liveStatus;
    try {
      liveStatus = await _repository.getLiveStatus();
    } catch (e) {
      debugPrint('[startRoute] getLiveStatus 실패 (무시됨): $e');
    }

    final stepIndex = section?.idx ?? 0;

    // route가 없어도 active 상태로 전환 (경로 없이도 이동 시작 가능)
    state = state.copyWith(
      status: HomeStatus.active,
      myRoute: route,
      recommendedRoute: recoRoute,
      isLoading: false,
      currentStepIndex: stepIndex,
      stepRemainingMinutes: route != null ? _remainingMinutes(route, stepIndex) : 0,
      liveStatus: liveStatus,
      routeCoordinates: section?.xy ?? const [],
      departureTime: DateTime.now(),
    );

    _startPolling();
  }

  /// 백엔드를 주기적으로 폴링하여 상태를 갱신합니다.
  /// - /me/routines/active/status   → liveStatus
  /// - /me/routines/active/location → currentStepIndex
  /// - /me/routines/active/reco     → recommendedRoute (추천 경로 실시간 반영)
  void _startPolling() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (state.status != HomeStatus.active) {
      _liveTimer?.cancel();
      _liveTimer = null;
      return;
    }

    try {
      // 현재 상태 (도보중 / 대기중 / 탑승중)
      final liveStatus = await _repository.getLiveStatus();

      // 현재 구간 인덱스
      final section = await _repository.getCurrentSection();
      final stepIndex = section?.idx ?? state.currentStepIndex;

      // 추천 경로 — 실시간으로 최신 추천 반영
      LiveRouteModel? recoRoute;
      try {
        recoRoute = await _repository.getRecommendedRoute();
      } catch (_) {
        recoRoute = state.recommendedRoute; // 실패 시 기존 유지
      }

      final myRoute = state.myRoute;

      state = state.copyWith(
        liveStatus: liveStatus,
        recommendedRoute: recoRoute,
        currentStepIndex: stepIndex,
        stepRemainingMinutes:
            myRoute != null ? _remainingMinutes(myRoute, stepIndex) : 0,
        // xy 좌표가 있으면 업데이트 (없으면 기존 유지)
        routeCoordinates: (section != null && section.xy.isNotEmpty)
            ? section.xy
            : state.routeCoordinates,
      );

      // '도착' 상태면 폴링 종료
      if (liveStatus.status == '도착') {
        _liveTimer?.cancel();
        _liveTimer = null;
      }
    } catch (e) {
      debugPrint('[LivePoll] 폴링 실패 (무시됨): $e');
    }
  }

  /// 현재 구간 이후 남은 예상 시간(분) 계산
  int _remainingMinutes(LiveRouteModel route, int stepIndex) {
    if (route.path.isEmpty || stepIndex >= route.path.length) return 0;
    return route.path
        .skip(stepIndex)
        .fold(0, (sum, p) => sum + p.sectionTime);
  }

  /// GPS가 목적지 반경 내에 진입했을 때 호출됩니다.
  Future<void> arriveByGps() async {
    if (state.status != HomeStatus.active) return;
    _liveTimer?.cancel();
    _liveTimer = null;

    final routineId = state.activeRoutine?.routineId;
    final departure = state.departureTime;
    final arrival = DateTime.now();

    if (routineId != null && departure != null) {
      try {
        await _repository.completeRoutine(
          departureTime: departure,
          arrivalTime: arrival,
        );
        debugPrint('[arriveByGps] 루틴 완료 전송 성공');
      } catch (e) {
        debugPrint('[arriveByGps] 루틴 완료 전송 실패 (무시됨): $e');
      }
    }

    state = HomeState(
      status: HomeStatus.preActive,
      activeRoutine: state.activeRoutine,
      weather: state.weather,
      liveStatus: LiveStatusModel(
        status: '도착',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> stopRoute() async {
    _liveTimer?.cancel();
    _liveTimer = null;

    final routineId = state.activeRoutine?.routineId;
    final departure = state.departureTime;
    final arrival = DateTime.now();

    if (routineId != null && departure != null) {
      try {
        await _repository.completeRoutine(
          departureTime: departure,
          arrivalTime: arrival,
        );
        debugPrint('[stopRoute] 루틴 완료 전송 성공');
      } catch (e) {
        debugPrint('[stopRoute] 루틴 완료 전송 실패 (무시됨): $e');
      }
    }

    state = HomeState(
      status: HomeStatus.preActive,
      activeRoutine: state.activeRoutine,
      weather: state.weather,
    );
  }

  /// 피드백 모달에서 직접 호출 — 점수 포함 루틴 완료 전송
  Future<void> completeRoutine({
    required DateTime departureTime,
    required DateTime arrivalTime,
    int? satWaitTimeScore,
    int? satEtaScore,
    int? satRouteScore,
  }) async {
    try {
      await _repository.completeRoutine(
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        satWaitTimeScore: satWaitTimeScore,
        satEtaScore: satEtaScore,
        satRouteScore: satRouteScore,
      );
      debugPrint('[completeRoutine] 루틴 완료 전송 성공');
    } catch (e) {
      debugPrint('[completeRoutine] 루틴 완료 전송 실패 (무시됨): $e');
    }
  }

  /// 루틴 생성/수정 후 경로 데이터 재조회 (추천 경로 0개 문제 해결)
  Future<void> refresh() async {
    await initialize();
  }

  /// 추천 경로를 내 경로로 채택 (세 번째 화면 "이 경로로 변경" 버튼)
  void switchToRecommendedRoute() {
    final reco = state.recommendedRoute;
    if (reco == null) return;
    state = state.copyWith(
      myRoute: reco,
      currentStepIndex: 0,
      stepRemainingMinutes: reco.path.isNotEmpty ? reco.path.first.sectionTime : 0,
    );
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  String _todayKey() {
    const keys = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return keys[DateTime.now().weekday - 1];
  }
}