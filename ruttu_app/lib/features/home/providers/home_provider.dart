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

  /// 폴링 주기 — 5초마다 status / section / recoRoute 갱신
  static const _pollInterval = Duration(seconds: 5);

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

      // preActive 추천 경로: /me/routines/active/reco 로 직접 조회
      LiveRouteModel? recommendedRoute;
      try {
        recommendedRoute = await _repository.getRecommendedRoute();
      } catch (e) {
        debugPrint('[initialize] getRecommendedRoute 실패, myRoute로 fallback: $e');
        recommendedRoute = myRoute;
      }

      // 추천 경로 초기 좌표:
      // preActive 상태에서는 /active/location/reco API가 403을 반환할 수 있으므로
      // 호출하지 않는다. recoRouteCoordinates는 startRoute() 후 _poll()이
      // getRecoCurrentSection()을 통해 채워줄 때까지 빈 상태로 유지.
      // (추천 경로 탭 지도는 출발 후에만 좌표가 표시됨)
      const List<RouteXYModel> recoCoords = [];

      state = HomeState(
        status: HomeStatus.preActive,
        activeRoutine: todayRoutineDetail,
        weather: weather,
        myRoute: myRoute,
        recommendedRoute: recommendedRoute,
        // ✅ 나의 경로 좌표 (루틴 상세에서 받은 routeXy)
        routeCoordinates: todayRoutineDetail.routeXy,
        // 추천 경로 좌표는 출발 후 _poll()에서 채워짐
        recoRouteCoordinates: recoCoords,
      );
    } catch (e) {
      debugPrint('❌ initialize 실패: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> startRoute() async {
    if (state.activeRoutine == null) return;
    state = state.copyWith(isLoading: true);

    final isReco = state.isUsingRecoRoute;

    // ── 나의 경로 ─────────────────────────────────────────────────────
    // isUsingRecoRoute=true일 때는 이미 switchToRecommendedRoute()에서
    // myRoute가 reco로 설정되어 있으므로 API 재조회하지 않음.
    // (재조회하면 내 경로 값으로 덮어쓰여 추천 경로가 사라지는 버그 발생)
    LiveRouteModel? route = state.myRoute;
    if (!isReco) {
      try {
        route = await _repository.getMyRoute();
      } catch (e) {
        debugPrint('[startRoute] getMyRoute 실패: $e');
        route = state.myRoute; // 실패 시 기존 유지
      }
    }

    // ── 추천 경로 ────────────────────────────────────────────────────
    // 항상 최신 추천 경로를 가져오되, recommendedRoute는 별도 유지
    LiveRouteModel? recoRoute = state.recommendedRoute;
    List<RouteXYModel> recoCoords = state.recoRouteCoordinates;

    // ── 현재 구간 (section) ──────────────────────────────────────────
    CurrentSectionModel? section;
    try {
      section = isReco
          ? await _repository.getRecoCurrentSection()
          : await _repository.getCurrentSection();
    } catch (e) {
      debugPrint('[startRoute] getCurrentSection 실패 (무시됨): $e');
    }

    // ── liveStatus ───────────────────────────────────────────────────
    LiveStatusModel? liveStatus;
    try {
      liveStatus = await _repository.getLiveStatus();
    } catch (e) {
      debugPrint('[startRoute] getLiveStatus 실패 (무시됨): $e');
    }

    final stepIndex = section != null && route != null
        ? _resolvePathIndex(section, route.path.length)
        : 0;

    debugPrint('[startRoute] isReco=$isReco section.idx=${section?.idx}, '
        'path.length=${route?.path.length}, resolved stepIndex=$stepIndex');

    // ── routeCoordinates: 탭별 독립 좌표 ───────────────────────────
    // 나의 경로 좌표(routeCoordinates)와 추천 경로 좌표(recoRouteCoordinates)를
    // 각각 유지한다. section.xy가 있으면 현재 활성 탭의 좌표만 갱신.
    List<RouteXYModel> myCoords = state.routeCoordinates;
    if (!isReco && section?.xy.isNotEmpty == true) {
      myCoords = section!.xy;
    } else if (!isReco && myCoords.isEmpty) {
      myCoords = state.routeCoordinates;
    }
    if (isReco && section?.xy.isNotEmpty == true) {
      recoCoords = section!.xy;
    }

    state = state.copyWith(
      status: HomeStatus.active,
      myRoute: route,
      recommendedRoute: recoRoute,
      isLoading: false,
      currentStepIndex: stepIndex,
      stepRemainingMinutes: route != null ? _remainingMinutes(route, stepIndex) : 0,
      liveStatus: liveStatus,
      routeCoordinates: myCoords,
      recoRouteCoordinates: recoCoords,
      departureTime: DateTime.now(),
      currentSectionData: section,
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

    // ── liveStatus: 실패 시 폴링 전체를 중단하지 않고 기존 유지 ──
    LiveStatusModel? liveStatus;
    try {
      liveStatus = await _repository.getLiveStatus();
    } catch (e) {
      debugPrint('[LivePoll] getLiveStatus 실패 (무시됨): $e');
      return; // status 없이 좌표만 갱신하면 오히려 혼란 → 이번 폴링 스킵
    }

    // ── section: isUsingRecoRoute에 따라 해당 API만 호출 ──────────
    // 두 API를 동시에 호출하면 403 에러가 항상 발생함:
    //  - my 경로 중일 때 reco section API → 403
    //  - reco 경로 중일 때 my section API → 403 (서버 정책)
    CurrentSectionModel? mySection;
    CurrentSectionModel? recoSection;

    if (!state.isUsingRecoRoute) {
      try {
        mySection = await _repository.getCurrentSection();
      } catch (e) {
        debugPrint('[LivePoll] getCurrentSection 실패 (무시됨): $e');
      }
    } else {
      try {
        recoSection = await _repository.getRecoCurrentSection();
      } catch (e) {
        debugPrint('[LivePoll] getRecoCurrentSection 실패 (무시됨): $e');
        // 403은 서버가 아직 reco 세션 미준비 상태 → 이번 폴링은 liveStatus만 반영
      }
    }

    // 현재 활성 경로에 따른 section 선택
    final activeSection = state.isUsingRecoRoute ? recoSection : mySection;

    // stepIndex: 활성 경로의 path 길이 기준
    final myRoute = state.myRoute;
    final stepIndex = (activeSection != null && myRoute != null)
        ? _resolvePathIndex(activeSection, myRoute.path.length)
        : state.currentStepIndex;

    // ── 좌표: 각 탭 전용 좌표를 독립적으로 갱신 ─────────────────
    final newMyCoords = (mySection?.xy.isNotEmpty == true)
        ? mySection!.xy
        : state.routeCoordinates;

    final newRecoCoords = (recoSection?.xy.isNotEmpty == true)
        ? recoSection!.xy
        : state.recoRouteCoordinates;

    // ── recommendedRoute: 항상 최신 추천 반영 (myRoute 건드리지 않음) ──
    LiveRouteModel? recoRoute;
    try {
      recoRoute = await _repository.getRecommendedRoute();
    } catch (_) {
      recoRoute = state.recommendedRoute;
    }

    state = state.copyWith(
      liveStatus: liveStatus,
      recommendedRoute: recoRoute,
      currentStepIndex: stepIndex,
      stepRemainingMinutes:
          myRoute != null ? _remainingMinutes(myRoute, stepIndex) : 0,
      routeCoordinates: newMyCoords,
      recoRouteCoordinates: newRecoCoords,
      currentSectionData: activeSection ?? state.currentSectionData,
    );

    debugPrint('[LivePoll] 완료 — status:${liveStatus.status} '
        'isReco:${state.isUsingRecoRoute} stepIdx:$stepIndex '
        'myCoords:${newMyCoords.length}개 recoCoords:${newRecoCoords.length}개');

    if (liveStatus.status == '도착') {
      _liveTimer?.cancel();
      _liveTimer = null;
    }
  }

  /// 현재 구간 이후 남은 예상 시간(분) 계산
  int _remainingMinutes(LiveRouteModel route, int stepIndex) {
    if (route.path.isEmpty || stepIndex >= route.path.length) return 0;
    return route.path
        .skip(stepIndex)
        .fold(0, (sum, p) => sum + p.sectionTime);
  }

  /// section 배열(["walk","bus","bus","bus","walk"])에서
  /// 연속된 동일 type을 하나로 합쳐 path 인덱스로 변환합니다.
  ///
  /// 예: section = ["walk","bus","bus","bus","bus","bus","bus","walk"], idx=1
  ///     압축 → ["walk","bus","walk"]  (0,1,2)
  ///     idx=1 → section[1]="bus" → 압축 후 인덱스 1 → pathIdx=1
  /// idx = 도착 예정 구간 인덱스 (raw section 배열 기준).
  /// 현재 이동 중인 구간 = idx - 1.
  /// path 인덱스는 raw section을 run-length 압축한 결과 기준.
  int _resolvePathIndex(CurrentSectionModel section, int pathLength) {
    if (pathLength == 0) return 0;

    final raw = section.section; // ["walk","bus","bus",...,"walk"]
    // idx는 도착 예정 → 현재 구간 = idx - 1
    final currentRawIdx = (section.idx - 1).clamp(0, raw.length - 1);

    if (raw.isEmpty) return currentRawIdx.clamp(0, pathLength - 1);

    // 연속 중복 제거 (run-length 압축)
    final compressed = <String>[];
    for (final type in raw) {
      if (compressed.isEmpty || compressed.last != type) {
        compressed.add(type);
      }
    }

    // 현재 구간(currentRawIdx)이 압축 후 어느 인덱스인지 계산
    final targetType = raw[currentRawIdx];

    // raw[0..currentRawIdx] 까지 순회하며 type 변화 횟수로 압축 인덱스 결정
    String? prevType;
    int compressedIdx = 0;
    for (var i = 0; i <= currentRawIdx && i < raw.length; i++) {
      final t = raw[i];
      if (t != prevType) {
        if (prevType != null) compressedIdx++;
        prevType = t;
      }
    }

    debugPrint('[resolvePathIndex] raw=${raw.length}개 → compressed=${compressed.length}개 '
        'rawIdx=$currentRawIdx (idx=${section.idx}-1) → pathIdx=$compressedIdx (pathLength=$pathLength)');

    return compressedIdx.clamp(0, pathLength - 1);
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
        if (state.isUsingRecoRoute) {
          await _repository.completeRecoRoute(
            departureTime: departure,
            arrivalTime: arrival,
          );
        } else {
          await _repository.completeMyRoute(
            departureTime: departure,
            arrivalTime: arrival,
          );
        }
        debugPrint('[arriveByGps] 루틴 완료 전송 성공 (${state.isUsingRecoRoute ? "reco" : "my"})');
      } catch (e) {
        debugPrint('[arriveByGps] 루틴 완료 전송 실패 (무시됨): $e');
      }
    }

    state = HomeState(
      status: HomeStatus.preActive,
      activeRoutine: state.activeRoutine,
      weather: state.weather,
      myRoute: state.myRoute,
      recommendedRoute: state.recommendedRoute,
      routeCoordinates: state.routeCoordinates,
      recoRouteCoordinates: state.recoRouteCoordinates,
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
    final isReco = state.isUsingRecoRoute;

    if (routineId != null && departure != null) {
      try {
        if (isReco) {
          await _repository.completeRecoRoute(
            departureTime: departure,
            arrivalTime: arrival,
          );
        } else {
          await _repository.completeMyRoute(
            departureTime: departure,
            arrivalTime: arrival,
          );
        }
        debugPrint('[stopRoute] 루틴 완료 전송 성공 (${isReco ? "reco" : "my"})');
      } catch (e) {
        debugPrint('[stopRoute] 루틴 완료 전송 실패 (무시됨): $e');
      }
    }

    state = HomeState(
      status: HomeStatus.preActive,
      activeRoutine: state.activeRoutine,
      weather: state.weather,
      myRoute: state.myRoute,
      recommendedRoute: state.recommendedRoute,
      routeCoordinates: state.routeCoordinates,
      recoRouteCoordinates: state.recoRouteCoordinates,
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
      if (state.isUsingRecoRoute) {
        await _repository.completeRecoRoute(
          departureTime: departureTime,
          arrivalTime: arrivalTime,
          satWaitTimeScore: satWaitTimeScore,
          satEtaScore: satEtaScore,
          satRouteScore: satRouteScore,
        );
      } else {
        await _repository.completeMyRoute(
          departureTime: departureTime,
          arrivalTime: arrivalTime,
          satWaitTimeScore: satWaitTimeScore,
          satEtaScore: satEtaScore,
          satRouteScore: satRouteScore,
        );
      }
      debugPrint('[completeRoutine] 루틴 완료 전송 성공 (${state.isUsingRecoRoute ? "reco" : "my"})');
    } catch (e) {
      debugPrint('[completeRoutine] 루틴 완료 전송 실패 (무시됨): $e');
    }
  }

  /// 루틴 생성/수정 후 경로 데이터 재조회 (추천 경로 0개 문제 해결)
  Future<void> refresh() async {
    await initialize();
  }

  /// 추천 경로를 선택 (세 번째 화면 "이 경로로 변경" 버튼)
  /// myRoute는 건드리지 않고, isUsingRecoRoute 플래그만 true로 설정.
  /// 지도/패널은 isUsingRecoRoute를 보고 각자 recommendedRoute / recoRouteCoordinates를 표시.
  void switchToRecommendedRoute() {
    final reco = state.recommendedRoute;
    if (reco == null) return;
    state = state.copyWith(
      currentStepIndex: 0,
      stepRemainingMinutes: reco.path.isNotEmpty ? reco.path.first.sectionTime : 0,
      isUsingRecoRoute: true, // ← 추천 경로로 전환됨을 기록 (myRoute는 유지)
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