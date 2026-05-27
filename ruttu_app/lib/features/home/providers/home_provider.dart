import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/routine_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/weather_model.dart';
import '../../../data/repositories/home_repository.dart';
import '../../auth/providers/network_provider.dart';
import 'home_state.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  // ✅ Mock 데이터로 화면을 구성하되, sendLiveLocation만 실제 API 호출
  // 각 API가 완성되면 MockHomeRepository → ApiHomeRepository로 점진 전환
  return MockHomeRepository(ref.read(apiClientProvider).dio);
});

// ✅ 버그2 수정: addressRepositoryProvider는 address_provider.dart 에만 두고
//              home_provider.dart 에 있던 중복 선언 및
//              `Future<List<AddressModel>> getAddresses();` 부유 선언을 모두 제거했습니다.

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>(
  (ref) => HomeNotifier(ref.read(homeRepositoryProvider)),
);

class HomeNotifier extends StateNotifier<HomeState> {
  final HomeRepository _repository;
  Timer? _liveTimer;
  int _simulatedMinutes = 0;

  HomeNotifier(this._repository) : super(const HomeState());

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _repository.getRoutines(),
        _repository.getWeatherAirQuality(),
        _repository.getMyRoute(),
      ]);

      final routines = results[0] as List<RoutineModel>;
      final weather  = results[1] as WeatherAirQualityModel;
      final myRoute  = results[2] as RouteModel;

      if (routines.isEmpty) {
        state = HomeState(status: HomeStatus.noRoutine, weather: weather);
        return;
      }

      final today = _todayKey();
      final todayRoutine = routines.firstWhere(
        (r) => r.isActive && r.days.contains(today),
        orElse: () => routines.first,
      );

      state = HomeState(
        status: HomeStatus.preActive,
        activeRoutine: todayRoutine,
        weather: weather,
        myRoute: myRoute,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> startRoute() async {
    if (state.activeRoutine == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final route = await _repository.getMyRoute();
      final recoRoute = await _repository.getRecommendedRoute();
      _simulatedMinutes = 0;
      state = state.copyWith(
        status: HomeStatus.active,
        myRoute: route,
        recommendedRoute: recoRoute,
        isLoading: false,
        currentStepIndex: 0,
        stepRemainingMinutes: route.path.isNotEmpty ? route.path.first.sectionTime : 0,
        liveStatus: LiveStatusModel(
          status: _statusLabel(route.path, 0),
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      _startSimulation(route);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void _startSimulation(RouteModel route) {
    _liveTimer?.cancel();
    // 2초 = 시뮬레이션 1분 (데모용 20배속)
    _liveTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _simulatedMinutes++;
      _tickSimulation(route);
    });
  }

  void _tickSimulation(RouteModel route) {
    int elapsed = 0;
    for (int i = 0; i < route.path.length; i++) {
      final stepEnd = elapsed + route.path[i].sectionTime;
      if (_simulatedMinutes < stepEnd) {
        state = state.copyWith(
          currentStepIndex: i,
          stepRemainingMinutes: stepEnd - _simulatedMinutes,
          liveStatus: LiveStatusModel(
            status: _statusLabel(route.path, i),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        return;
      }
      elapsed += route.path[i].sectionTime;
    }
    // 전체 경로 완료
    _liveTimer?.cancel();
    _liveTimer = null;
    state = state.copyWith(
      stepRemainingMinutes: 0,
      liveStatus: LiveStatusModel(
        status: '도착',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  String _statusLabel(List<PathModel> paths, int index) {
    if (index >= paths.length) return '도착';
    final path = paths[index];
    if (path.isWalking) {
      final prevIsTransit = index > 0 && !paths[index - 1].isWalking;
      final nextIsTransit = index < paths.length - 1 && !paths[index + 1].isWalking;
      if (prevIsTransit && nextIsTransit) return '환승 중';
      return '도보 중';
    }
    if (path.isBus) return '버스 탑승 중';
    return '지하철 탑승 중';
  }

  /// GPS가 목적지 반경 내에 진입했을 때 호출됩니다.
  Future<void> arriveByGps() async {
    if (state.status != HomeStatus.active) return;
    _liveTimer?.cancel();
    _liveTimer = null;
    _simulatedMinutes = 0;
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
    _simulatedMinutes = 0;
    state = HomeState(
      status: HomeStatus.preActive,
      activeRoutine: state.activeRoutine,
      weather: state.weather,
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