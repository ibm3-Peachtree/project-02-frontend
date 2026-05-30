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
      final todayRoutine = routines.firstWhere(
        (r) => r.isActive && r.days.contains(today),
        orElse: () => routines.first,
      );

      LiveRouteModel? myRoute;
      try {
        myRoute = await _repository.getMyRoute();
      } catch (_) {}

      state = HomeState(
        status: HomeStatus.preActive,
        activeRoutine: todayRoutine,
        weather: weather,
        myRoute: myRoute,
      );
    } catch (e) {
      debugPrint('❌ initialize 실패: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> startRoute() async {
    if (state.activeRoutine == null) return;
    state = state.copyWith(isLoading: true);
    try {
      // 내 경로 + 추천 경로 + 현재 구간(xy 포함) + 현재 상태 한 번에 초기 로드
      final route = await _repository.getMyRoute();
      final recoRoute = await _repository.getRecommendedRoute();
      final section = await _repository.getCurrentSection();
      final liveStatus = await _repository.getLiveStatus();

      final stepIndex = section?.idx ?? 0;

      state = state.copyWith(
        status: HomeStatus.active,
        myRoute: route,
        recommendedRoute: recoRoute,
        isLoading: false,
        currentStepIndex: stepIndex,
        stepRemainingMinutes: _remainingMinutes(route, stepIndex),
        liveStatus: liveStatus,
        // xy 좌표 저장 → 지도 폴리라인에 사용
        routeCoordinates: section?.xy ?? const [],
      );

      _startPolling();
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
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
    state = HomeState(
      status: HomeStatus.preActive,
      activeRoutine: state.activeRoutine,
      weather: state.weather,
    );
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