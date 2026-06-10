import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/repositories/home_repository_provider.dart';
import '../../../data/models/routine_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/weather_model.dart';
import '../../../data/repositories/home_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/stomp_service.dart';
import 'home_state.dart';
import 'live_route_provider.dart' show recoRouteProvider;

// homeRepositoryProvider → home_repository_provider.dart

// ── STOMP 구독 destination ──────────────────────────────────────────────
// 백엔드 LiveLocationService.getMyCurrentSection()이
// /user/queue/location/my 로 CurrentSectionDto를 push함.
// Flutter는 이 push를 구독하여 routeCoordinates(폴리라인 좌표)를 실시간 갱신.
const _queueLocationMy = '/user/queue/location/my';

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  final notifier = HomeNotifier(ref.read(homeRepositoryProvider), ref);
  return notifier;
});

class HomeNotifier extends StateNotifier<HomeState> {
  final HomeRepository _repository;
  final Ref _ref;

  /// 실시간 폴링 타이머 (active 상태에서 주기적으로 백엔드 조회)
  Timer? _liveTimer;

  /// preActive 출발 시간 감시 타이머 (1분 간격으로 isDepartureImminent / isDepartureOverdue 갱신)
  Timer? _departureTimer;

  /// 폴링 주기 — 5초마다 status / section / recoRoute 갱신
  static const _pollInterval = Duration(seconds: 5);

  /// 출발 시간 감시 주기 — 1분마다 상태 갱신
  static const _departureCheckInterval = Duration(minutes: 1);

  /// 자동 시작 감시 주기 — 30초마다 GPS 위치 체크
  static const _autoStartInterval = Duration(seconds: 30);

  /// 자동 종료 감시 주기 — 15초마다 GPS 위치 체크
  static const _autoArriveInterval = Duration(seconds: 15);

  /// 출발지 이탈 감지 반경 (미터) — 이 이상 벗어나면 자동 시작
  static const _departureRadius = 150.0;

  /// 목적지 도착 감지 반경 (미터) — 이 이내로 들어오면 자동 종료
  static const _arrivalRadius = 100.0;

  /// 자동 시작 GPS 감시 타이머 (preActive + 출발 권장 시간대에서 활성화)
  Timer? _autoStartTimer;

  /// 자동 종료 GPS 감시 타이머 (active 상태에서 활성화)
  Timer? _autoArriveTimer;

  /// 자동 시작이 이미 한 번 트리거됐는지 방지 플래그
  bool _autoStartTriggered = false;

  final LocationService _locationService = LocationService();

  HomeNotifier(this._repository, this._ref) : super(const HomeState());

  Future<void> initialize({bool silent = false}) async {
    if (!silent) state = state.copyWith(isLoading: true);
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
      final isHoliday = await _checkIsHoliday();

      final hasTodayRoutine = routines.any((r) =>
          r.isActive &&
          r.days.contains(today) &&
          !(isHoliday && r.skipHoliday));

      if (!hasTodayRoutine) {
        state = HomeState(
          status: HomeStatus.noTodayRoutine,
          weather: weather,
        );
        return;
      }

      final todayRoutine = routines.firstWhere(
        (r) =>
            r.isActive &&
            r.days.contains(today) &&
            !(isHoliday && r.skipHoliday),
      );

      RoutineModel todayRoutineDetail = todayRoutine;
      try {
        todayRoutineDetail = await _repository.getRoutineDetail(todayRoutine.routineId);
      } catch (_) {}

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

      LiveRouteModel? recommendedRoute;
      try {
        recommendedRoute = await _repository.getRecommendedRoute(todayRoutineDetail.routineId);
      } catch (e) {
        debugPrint('[initialize] getRecommendedRoute 실패, null 유지: $e');
      }

      List<RouteModel> recoRouteList = [];
      List<RouteModel> detourRouteList = [];
      bool hasIncident = false;
      String? incidentMessage;
      debugPrint('[initialize] getRecoRouteListResponse 호출 시작');
      try {
        final recoResp = await _repository.getRecoRouteListResponse(todayRoutineDetail.routineId);
        recoRouteList = recoResp.recoList;
        detourRouteList = recoResp.detourList;
        hasIncident = recoResp.hasIncident;
        incidentMessage = recoResp.incidentMessage;
        debugPrint('[initialize] 성공: reco=${recoRouteList.length}, detour=${detourRouteList.length}, hasIncident=$hasIncident');
      } catch (e) {
        debugPrint('[initialize] getRecoRouteListResponse 실패: $e');
        _ref.read(recoRouteProvider.notifier).markLoadError();
      }

      const List<RouteXYModel> recoCoords = [];

      state = HomeState(
        status: HomeStatus.preActive,
        activeRoutine: todayRoutineDetail,
        weather: weather,
        myRoute: myRoute,
        recommendedRoute: recommendedRoute,
        routeCoordinates: todayRoutineDetail.routeXy,
        recoRouteCoordinates: recoCoords,
        recoRouteList: recoRouteList,
        detourRouteList: detourRouteList,
        hasIncident: hasIncident,
        incidentMessage: incidentMessage,
      );

      if (recoRouteList.isNotEmpty || detourRouteList.isNotEmpty) {
        _ref.read(recoRouteProvider.notifier).preloadList(
          RecoRouteListResponse(
            recoList:        recoRouteList,
            detourList:      detourRouteList,
            hasIncident:     hasIncident,
            incidentMessage: incidentMessage,
          ),
        );
      }

      // preActive 상태 진입 시 출발 시간 감시 타이머 시작
      _startDepartureTimer();
    } catch (e) {
      debugPrint('❌ initialize 실패: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// ✅ [버그 수정] 루틴 상세 화면의 "지금 출발하기"에서 호출.
  /// 홈 화면 새로고침 — preActive 상태에서 pull-to-refresh / 버튼 탭 시 호출.
  /// isLoading을 올리지 않고 silent 모드로 데이터를 다시 불러온다.
  Future<void> refresh() async {
    if (state.status == HomeStatus.active) return; // 이동 중에는 갱신 불가
    await initialize(silent: true);
    // recoRouteProvider도 강제 새로고침
    final routineId = state.activeRoutine?.routineId;
    if (routineId != null) {
      _ref.read(recoRouteProvider.notifier).loadRecoRouteList(routineId, force: true);
    }
  }

  /// 사용자가 선택한 특정 루틴을 activeRoutine으로 명시 지정한 뒤
  /// preActive 상태로 전환합니다.
  /// initialize()의 firstWhere 로직과 달리, 루틴이 여러 개일 때도
  /// 사용자가 보고 있는 루틴이 정확히 activeRoutine으로 반영됩니다.
  Future<void> initializeWithRoutine(RoutineModel routine) async {
    state = state.copyWith(isLoading: true);
    // 루틴 교체 — 이전 루틴의 추천 경로 목록을 초기화하여
    // 새 루틴의 데이터가 정상 주입되도록 보장
    _ref.read(recoRouteProvider.notifier).resetList();
    try {
      WeatherAirQualityModel? weather;
      try {
        weather = await _repository.getWeatherAirQuality();
      } catch (_) {}

      // 최신 상세 데이터 조회 (route, routeXy 포함)
      RoutineModel routineDetail = routine;
      try {
        routineDetail = await _repository.getRoutineDetail(routine.routineId);
      } catch (_) {}

      // route → LiveRouteModel 변환
      LiveRouteModel? myRoute;
      final routeData = routineDetail.route;
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

      // 추천 경로 카드 목록 (실패해도 무시)
      List<RouteModel> recoRouteList = [];
      List<RouteModel> detourRouteList = [];
      bool hasIncident = false;
      String? incidentMessage;
      try {
        final recoResp = await _repository.getRecoRouteListResponse(routineDetail.routineId);
        recoRouteList = recoResp.recoList;
        detourRouteList = recoResp.detourList;
        hasIncident = recoResp.hasIncident;
        incidentMessage = recoResp.incidentMessage;
      } catch (e) {
        debugPrint('[initializeWithRoutine] getRecoRouteListResponse 실패 (무시): $e');
        _ref.read(recoRouteProvider.notifier).markLoadError();
      }

      state = HomeState(
        status: HomeStatus.preActive,
        activeRoutine: routineDetail,
        weather: weather,
        myRoute: myRoute,
        routeCoordinates: routineDetail.routeXy,
        recoRouteCoordinates: const [],
        recoRouteList: recoRouteList,
        detourRouteList: detourRouteList,
        hasIncident: hasIncident,
        incidentMessage: incidentMessage,
      );

      if (recoRouteList.isNotEmpty || detourRouteList.isNotEmpty) {
        _ref.read(recoRouteProvider.notifier).preloadList(
          RecoRouteListResponse(
            recoList: recoRouteList,
            detourList: detourRouteList,
            hasIncident: hasIncident,
            incidentMessage: incidentMessage,
          ),
          force: true, // 루틴 교체이므로 기존 데이터를 반드시 덮어씀
        );
      }

      // preActive 상태 진입 시 출발 시간 감시 타이머 시작
      _startDepartureTimer();

      debugPrint('[initializeWithRoutine] 완료 — routineId=${routineDetail.routineId}');
    } catch (e) {
      debugPrint('❌ initializeWithRoutine 실패: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> startRoute() async {
    if (state.activeRoutine == null) return;
    // active 상태 전환 시 출발 감시 타이머 중단
    _departureTimer?.cancel();
    _departureTimer = null;
    state = state.copyWith(isLoading: true);

    final isReco = state.isUsingRecoRoute;

    LiveRouteModel? route = state.myRoute;
    if (!isReco) {
      try {
        route = await _repository.getMyRoute(state.activeRoutine!.routineId);
      } catch (e) {
        debugPrint('[startRoute] getMyRoute 실패: $e');
        route = state.myRoute;
      }
    }

    LiveRouteModel? recoRoute = state.recommendedRoute;
    List<RouteXYModel> recoCoords = state.recoRouteCoordinates;

    CurrentSectionModel? section;
    try {
      section = isReco
          ? await _repository.getRecoCurrentSection()
          : await _repository.getCurrentSection();
    } catch (e) {
      debugPrint('[startRoute] getCurrentSection 실패 (무시됨): $e');
    }

    final LiveStatusModel? liveStatus = null;

    final stepIndex = section != null && route != null
        ? _resolvePathIndex(section, route.path.length)
        : 0;

    debugPrint('[startRoute] isReco=$isReco section.idx=${section?.idx}, '
        'path.length=${route?.path.length}, resolved stepIndex=$stepIndex');

    List<RouteXYModel> myCoords = state.routeCoordinates;
    if (!isReco && section?.xy.isNotEmpty == true) {
      myCoords = section!.xy;
    } else if (!isReco && myCoords.isEmpty) {
      // section.xy도 없고 routeCoordinates도 비어있으면 routineDetail.routeXy 사용
      myCoords = state.activeRoutine?.routeXy ?? const [];
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
      myStepIndex: isReco ? state.myStepIndex : stepIndex,
      recoStepIndex: isReco ? stepIndex : state.recoStepIndex,
      stepRemainingMinutes: route != null ? _remainingMinutes(route, stepIndex) : 0,
      liveStatus: liveStatus,
      routeCoordinates: myCoords,
      recoRouteCoordinates: recoCoords,
      departureTime: DateTime.now(),
      myCurrentSectionData: isReco ? state.myCurrentSectionData : section,
      recoCurrentSectionData: isReco ? section : state.recoCurrentSectionData,
    );

    // ✅ 폴링 + STOMP /user/queue/location/my 구독 동시 시작
    _startPolling();
    _subscribeLocationMy();

    // 자동 시작 타이머 중단 (수동 시작 포함) + 자동 종료 타이머 시작
    _stopAutoStartMonitor();
    _startAutoArriveMonitor();
  }

  // ── STOMP /user/queue/location/my 구독 ────────────────────────────────
  //
  // 백엔드 흐름:
  //   앱 GPS → STOMP /app/location/my
  //     → LiveLocationController.myLocation()
  //       → liveLocationService.getMyCurrentSection()
  //         → messagingTemplate.convertAndSendToUser(
  //               principalName, "/queue/location/my",
  //               new CurrentSectionDto(nearestIndex, noList, routeXYList))
  //
  // CurrentSectionDto JSON 구조 (Flutter CurrentSectionModel.fromJson과 매핑):
  //   { "idx": int,           ← nearestIndex (가장 가까운 좌표 인덱스)
  //     "section": [String],  ← routeXYList.stream().map(RouteXYDto::getNo).toList()
  //     "xy": [RouteXYDto] }  ← 전체 경로 좌표 목록
  //
  // xy 배열이 있으면 routeCoordinates를 갱신 → 지도 폴리라인 재렌더링.
  // myCurrentSectionData도 갱신하여 _poll()의 stepIndex 계산에 반영.
  void _subscribeLocationMy() {
    StompService.instance.subscribe(
      _queueLocationMy,
      (json) {
        if (!mounted) return;
        // active 상태일 때만 처리 (추천 경로 모드면 나의 경로 폴리라인 갱신 불필요)
        if (state.status != HomeStatus.active || state.isUsingRecoRoute) return;
        try {
          final section = CurrentSectionModel.fromJson(json);

          final stepIndex = state.myRoute != null
              ? _resolvePathIndex(section, state.myRoute!.path.length)
              : state.myStepIndex;

          // xy가 있으면 폴리라인 좌표 갱신, 없으면 기존 좌표 유지
          final newCoords = section.xy.isNotEmpty
              ? section.xy
              : state.routeCoordinates;

          state = state.copyWith(
            routeCoordinates: newCoords,
            myCurrentSectionData: section,
            currentStepIndex: stepIndex,
            myStepIndex: stepIndex,
            stepRemainingMinutes: state.myRoute != null
                ? _remainingMinutes(state.myRoute!, stepIndex)
                : state.stepRemainingMinutes,
          );

          debugPrint('[HomeNotifier] /queue/location/my 수신 — '
              'idx=${section.idx} coords=${newCoords.length}개 stepIdx=$stepIndex');
        } catch (e) {
          debugPrint('[HomeNotifier] /queue/location/my 파싱 오류: $e\njson=$json');
        }
      },
      subscriberKey: 'homeProvider_my',
    );
    debugPrint('[HomeNotifier] /queue/location/my 구독 등록');
  }

  void _unsubscribeLocationMy() {
    StompService.instance.unsubscribe(
      _queueLocationMy,
      subscriberKey: 'homeProvider_my',
    );
    debugPrint('[HomeNotifier] /queue/location/my 구독 해제');
  }

  // ── preActive 출발 시간 감시 타이머 ──────────────────────────────────
  //
  // 1분마다 isDepartureImminent / isDepartureOverdue를 체크하여
  // state를 copyWith()으로 갱신 → UI가 자동으로 리빌드된다.
  // 실제 값이 바뀐 경우(imminent·overdue 전환점)에만 state 갱신을 발생시켜
  // 불필요한 리빌드를 최소화한다.
  void _startDepartureTimer() {
    _departureTimer?.cancel();
    if (state.activeRoutine == null) return;
    _departureTimer = Timer.periodic(_departureCheckInterval, (_) {
      if (!mounted) return;
      if (state.status != HomeStatus.preActive) {
        _departureTimer?.cancel();
        _departureTimer = null;
        return;
      }
      // state를 새로 copyWith하면 Riverpod이 computed getter
      // (isDepartureImminent / isDepartureOverdue)를 재평가하여 UI 갱신.
      // isLoading을 건드리지 않고 activeRoutine만 그대로 유지하는 no-op copyWith.
      state = state.copyWith();
      debugPrint('[DepartureTimer] 출발 시간 체크 — '
          'imminent=${state.isDepartureImminent} '
          'overdue=${state.isDepartureOverdue} '
          'minutesOverdue=${state.minutesOverdue}');

      // 출발 권장 시간대가 되면 자동 시작 감시 시작
      if ((state.isDepartureImminent || state.isDepartureOverdue) &&
          _autoStartTimer == null) {
        _startAutoStartMonitor();
      }
    });
    debugPrint('[DepartureTimer] 출발 시간 감시 타이머 시작');

    // 이미 출발 권장 시간대이면 즉시 자동 시작 감시 시작
    if (state.isDepartureImminent || state.isDepartureOverdue) {
      _startAutoStartMonitor();
    }
  }

  void _startPolling() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 자동 시작 감시 — preActive + 출발 권장 시간대에서 출발지 이탈 감지
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _startAutoStartMonitor() {
    if (_autoStartTimer != null) return; // 이미 실행 중
    _autoStartTriggered = false;
    debugPrint('[AutoStart] 출발 감지 타이머 시작 (반경 ${_departureRadius}m)');

    _autoStartTimer = Timer.periodic(_autoStartInterval, (_) async {
      if (!mounted) return;
      // preActive 상태가 아니거나 이미 트리거됐으면 중단
      if (state.status != HomeStatus.preActive || _autoStartTriggered) {
        _stopAutoStartMonitor();
        return;
      }
      await _checkAutoStart();
    });

    // 타이머 첫 tick을 기다리지 않고 즉시 한 번 체크
    _checkAutoStart();
  }

  void _stopAutoStartMonitor() {
    _autoStartTimer?.cancel();
    _autoStartTimer = null;
    debugPrint('[AutoStart] 출발 감지 타이머 중단');
  }

  Future<void> _checkAutoStart() async {
    if (!mounted || state.status != HomeStatus.preActive) return;

    // 출발 권장 시간대가 아니면 체크 안 함
    if (!state.isDepartureImminent && !state.isDepartureOverdue) return;

    // 출발지 좌표 가져오기 — routeXy 첫 번째 좌표 사용
    final coords = state.activeRoutine?.routeXy ?? [];
    if (coords.isEmpty) return;
    final origin = coords.first;
    if (origin.x == null || origin.y == null) return;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // x=경도(lng), y=위도(lat)
      final dist = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        origin.y!, origin.x!,
      );

      debugPrint('[AutoStart] 출발지까지 거리: ${dist.toStringAsFixed(0)}m '
          '(기준 ${_departureRadius}m)');

      if (dist > _departureRadius && !_autoStartTriggered) {
        _autoStartTriggered = true;
        _stopAutoStartMonitor();
        debugPrint('[AutoStart] 출발지 이탈 감지 → 자동 시작');
        await startRoute();
      }
    } catch (e) {
      debugPrint('[AutoStart] GPS 오류 (무시됨): $e');
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 자동 종료 감시 — active 상태에서 목적지 도착 감지
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _startAutoArriveMonitor() {
    if (_autoArriveTimer != null) return;
    debugPrint('[AutoArrive] 도착 감지 타이머 시작 (반경 ${_arrivalRadius}m)');

    _autoArriveTimer = Timer.periodic(_autoArriveInterval, (_) async {
      if (!mounted) return;
      if (state.status != HomeStatus.active) {
        _stopAutoArriveMonitor();
        return;
      }
      await _checkAutoArrive();
    });
  }

  void _stopAutoArriveMonitor() {
    _autoArriveTimer?.cancel();
    _autoArriveTimer = null;
    debugPrint('[AutoArrive] 도착 감지 타이머 중단');
  }

  Future<void> _checkAutoArrive() async {
    if (!mounted || state.status != HomeStatus.active) return;

    // 목적지 좌표 가져오기 — routeXy 마지막 좌표 사용
    final coords = state.activeRoutine?.routeXy ?? [];
    if (coords.isEmpty) return;
    final dest = coords.last;
    if (dest.x == null || dest.y == null) return;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final dist = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        dest.y!, dest.x!,
      );

      debugPrint('[AutoArrive] 목적지까지 거리: ${dist.toStringAsFixed(0)}m '
          '(기준 ${_arrivalRadius}m)');

      if (dist <= _arrivalRadius) {
        _stopAutoArriveMonitor();
        debugPrint('[AutoArrive] 목적지 도착 감지 → 자동 종료');
        await arriveByGps();
      }
    } catch (e) {
      debugPrint('[AutoArrive] GPS 오류 (무시됨): $e');
    }
  }

  Future<void> _poll() async {
    if (state.status != HomeStatus.active) {
      _liveTimer?.cancel();
      _liveTimer = null;
      return;
    }

    // 나의 경로 section은 STOMP push(_subscribeLocationMy)가 실시간으로 처리하므로
    // _poll()에서는 REST 호출을 생략하고 recoRoute section만 처리.
    // 단, isUsingRecoRoute=false일 때 STOMP가 끊긴 경우 fallback으로 REST 조회.
    CurrentSectionModel? mySection;
    if (!state.isUsingRecoRoute) {
      try {
        mySection = await _repository.getCurrentSection();
      } catch (e) {
        debugPrint('[LivePoll] getCurrentSection REST 실패 (무시됨): $e');
      }
    }

    if (!mounted) return;

    final myStepIdx = (mySection != null && state.myRoute != null)
        ? _resolvePathIndex(mySection, state.myRoute!.path.length)
        : state.myStepIndex;

    final recoSectionData = state.recoCurrentSectionData;
    final recoStepIdx = (recoSectionData != null && state.recommendedRoute != null)
        ? _resolvePathIndex(recoSectionData, state.recommendedRoute!.path.length)
        : state.recoStepIndex;

    final newRecoCoords = (recoSectionData?.xy.isNotEmpty == true)
        ? recoSectionData!.xy
        : state.recoRouteCoordinates;

    final stepIndex = state.isUsingRecoRoute ? recoStepIdx : myStepIdx;
    final activeRoute = state.isUsingRecoRoute ? state.recommendedRoute : state.myRoute;

    // 나의 경로 좌표: STOMP push가 이미 갱신했을 수 있으므로 REST section.xy가
    // 있을 때만 덮어씀. 없으면 현재 state 유지 (STOMP가 갱신한 값 보존).
    final newMyCoords = (mySection?.xy.isNotEmpty == true)
        ? mySection!.xy
        : state.routeCoordinates;

    state = state.copyWith(
      currentStepIndex: stepIndex,
      myStepIndex: myStepIdx,
      recoStepIndex: recoStepIdx,
      stepRemainingMinutes:
          activeRoute != null ? _remainingMinutes(activeRoute, stepIndex) : 0,
      routeCoordinates: newMyCoords,
      recoRouteCoordinates: newRecoCoords,
      myCurrentSectionData: mySection ?? state.myCurrentSectionData,
    );

    debugPrint('[LivePoll] 완료 — '
        'isReco:${state.isUsingRecoRoute} myStepIdx:$myStepIdx recoStepIdx:$recoStepIdx '
        'myCoords:${newMyCoords.length}개 recoCoords:${newRecoCoords.length}개 '
        'recoSection.idx=${recoSectionData?.idx} recoSection.type=${recoSectionData?.currentType}');
  }

  int _remainingMinutes(LiveRouteModel route, int stepIndex) {
    if (route.path.isEmpty || stepIndex >= route.path.length) return 0;
    return route.path
        .skip(stepIndex)
        .fold(0, (sum, p) => sum + p.sectionTime);
  }

  int _resolvePathIndex(CurrentSectionModel section, int pathLength) {
    if (pathLength == 0) return 0;

    final raw = section.section;
    // idx = nearestIndex (현재 위치, 0-based) → section[idx]가 현재 구간
    final currentRawIdx = section.idx.clamp(0, raw.length - 1);

    if (raw.isEmpty) return currentRawIdx.clamp(0, pathLength - 1);

    // raw section 배열을 연속 중복 제거(압축)하여 PathModel 인덱스에 매핑
    // 예: ['walk','walk','bus:5535','bus:5535','walk'] → ['walk','bus:5535','walk']
    //     rawIdx=2(bus) → compressedIdx=1
    String? prevType;
    int compressedIdx = 0;
    for (var i = 0; i <= currentRawIdx && i < raw.length; i++) {
      final t = raw[i];
      if (t != prevType) {
        if (prevType != null) compressedIdx++;
        prevType = t;
      }
    }

    debugPrint('[resolvePathIndex] raw=${raw.length}개 → rawIdx=$currentRawIdx (idx=${section.idx}) '
        '→ pathIdx=$compressedIdx (pathLength=$pathLength)');

    return compressedIdx.clamp(0, pathLength - 1);
  }

  Future<void> arriveByGps() async {
    if (state.status != HomeStatus.active) return;
    _liveTimer?.cancel();
    _liveTimer = null;
    _unsubscribeLocationMy(); // ✅ 도착 시 구독 해제
    _stopAutoArriveMonitor(); // 자동 종료 타이머 정리

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

    // preActive로 복귀 — 출발 감시 타이머 재시작
    _startDepartureTimer();
  }

  Future<void> stopRoute() async {
    _liveTimer?.cancel();
    _liveTimer = null;
    _unsubscribeLocationMy(); // ✅ 종료 시 구독 해제
    _stopAutoArriveMonitor(); // 자동 종료 타이머 정리
    _stopAutoStartMonitor();  // 혹시 남아있을 자동 시작 타이머 정리

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

    // preActive로 복귀 — 출발 감시 타이머 재시작
    _startDepartureTimer();
  }

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

  /// 나의 경로 안내 시작 직후, STOMP section이 아직 도착하기 전에
  /// routeXy 좌표로 지도 폴리라인을 미리 채워둔다.
  void seedMyRouteCoordinates(List<RouteXYModel> coords) {
    if (state.routeCoordinates.isNotEmpty) return; // 이미 있으면 덮어쓰지 않음
    state = state.copyWith(routeCoordinates: coords);
    debugPrint('[HomeNotifier] seedMyRouteCoordinates ${coords.length}개');
  }

  /// myRouteProvider STOMP /queue/location/my 수신 → homeProvider 동기화
  /// homeProvider.status が active でなくても（myRouteProvider 単独起動）動作するよう
  /// status チェックを isUsingRecoRoute のみに絞る。
  void updateMySection(CurrentSectionModel section) {
    // 추천 경로 안내 중에는 나의 경로 section으로 지도를 덮어쓰지 않는다
    if (state.isUsingRecoRoute) return;
    final route = state.myRoute;
    final stepIndex = route != null
        ? _resolvePathIndex(section, route.path.length)
        : state.myStepIndex;
    final newCoords = section.xy.isNotEmpty ? section.xy : state.routeCoordinates;
    state = state.copyWith(
      routeCoordinates:     newCoords,
      myCurrentSectionData: section,
      currentStepIndex:     stepIndex,
      myStepIndex:          stepIndex,
      stepRemainingMinutes: route != null
          ? _remainingMinutes(route, stepIndex)
          : state.stepRemainingMinutes,
    );
    debugPrint('[HomeNotifier] updateMySection idx=${section.idx} '
        'coords=${newCoords.length}개 stepIdx=$stepIndex');
  }

  void updateRecoSection(CurrentSectionModel section) {
    final recoStepIdx = state.recommendedRoute != null
        ? _resolvePathIndex(section, state.recommendedRoute!.path.length)
        : state.recoStepIndex;
    final newRecoCoords = section.xy.isNotEmpty ? section.xy : state.recoRouteCoordinates;
    state = state.copyWith(
      recoCurrentSectionData: section,
      recoStepIndex: recoStepIdx,
      recoRouteCoordinates: newRecoCoords,
      currentStepIndex: state.isUsingRecoRoute ? recoStepIdx : state.currentStepIndex,
      stepRemainingMinutes: state.isUsingRecoRoute && state.recommendedRoute != null
          ? _remainingMinutes(state.recommendedRoute!, recoStepIdx)
          : state.stepRemainingMinutes,
    );
    debugPrint('[HomeNotifier] updateRecoSection idx=${section.idx} '
        'type=${section.currentType} recoStepIdx=$recoStepIdx '
        'station=${section.currentXY?.stationName} recoCoords=${newRecoCoords.length}개');
  }

  Future<void> switchToRecommendedRoute(int recoId) async {
    state = state.copyWith(isLoading: true);

    try {
      await _repository.saveRecoRoute(recoId);
    } catch (e) {
      debugPrint('[switchToRecommendedRoute] saveRecoRoute 실패: $e');
      state = state.copyWith(isLoading: false);
      return;
    }

    LiveRouteModel? freshReco;
    try {
      freshReco = await _repository.getRecommendedRoute(state.activeRoutine!.routineId);
    } catch (e) {
      debugPrint('[switchToRecommendedRoute] getRecommendedRoute 실패: $e');
      freshReco = state.recommendedRoute;
    }

    CurrentSectionModel? recoSection;
    try {
      recoSection = await _repository.getRecoCurrentSection();
    } catch (e) {
      debugPrint('[switchToRecommendedRoute] getRecoCurrentSection 실패 (무시): $e');
    }

    final recoCoords = recoSection?.xy.isNotEmpty == true
        ? recoSection!.xy
        : state.recoRouteCoordinates;

    final recoStepIdx = (recoSection != null && freshReco != null)
        ? _resolvePathIndex(recoSection, freshReco.path.length)
        : 0;

    state = state.copyWith(
      isLoading: false,
      isUsingRecoRoute: true,
      recommendedRoute: freshReco,
      recoCurrentSectionData: recoSection,
      recoRouteCoordinates: recoCoords,
      recoStepIndex: recoStepIdx,
      currentStepIndex: recoStepIdx,
      stepRemainingMinutes: freshReco != null
          ? _remainingMinutes(freshReco, recoStepIdx)
          : 0,
      departureTime: state.departureTime ?? DateTime.now(),
    );

    // 추천 경로로 전환 시 나의 경로 STOMP 구독 해제 (불필요한 수신 방지)
    _unsubscribeLocationMy();

    // status를 active로 전환 후 polling 시작
    // (startRoute()를 호출하면 myRoute까지 같이 활성화되므로 직접 처리)
    if (state.status != HomeStatus.active) {
      state = state.copyWith(status: HomeStatus.active);
    }
    _startPolling();
  }

  /// 우회 경로 선택 후 "이 경로로 변경" 시 호출.
  /// saveAndStartDetourRoute()가 API 저장+상세 fetch를 담당하므로
  /// 여기서는 homeProvider 상태(isUsingRecoRoute, status) 전환만 수행.
  /// recommendedRoute는 saveAndStartDetourRoute 완료 후 recoRouteProvider.route에서
  /// 별도로 채워지므로, 임시로 기존 recommendedRoute를 유지한다.
  Future<void> switchToDetourRoute(int pathId) async {
    // 나의 경로 STOMP 구독 해제
    _unsubscribeLocationMy();

    state = state.copyWith(
      isUsingRecoRoute: true,
      departureTime:    state.departureTime ?? DateTime.now(),
    );

    // active 전환
    if (state.status != HomeStatus.active) {
      state = state.copyWith(status: HomeStatus.active);
    }
    _startPolling();
  }
  @override
void dispose() {
  
    _liveTimer?.cancel();
    _departureTimer?.cancel();
    _autoStartTimer?.cancel();
    _autoArriveTimer?.cancel();
    _unsubscribeLocationMy(); // ✅ dispose 시 구독 해제
    super.dispose();
  }

  String _todayKey() {
    const keys = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return keys[DateTime.now().weekday - 1];
  }

  Future<bool> _checkIsHoliday() async {
    try {
      // 서버에서 공휴일 여부 조회 시도 (백엔드가 준비되면 아래 주석 해제)
      // final res = await _repository.getTodayHolidayStatus();
      // return res;
    } catch (_) {}

    final now = DateTime.now();
    final month = now.month;
    final day = now.day;
    const fixedHolidays = {
      (1, 1), (3, 1), (5, 5), (6, 6), (8, 15),
      (10, 3), (10, 9), (12, 25),
    };
    return fixedHolidays.contains((month, day));
  }
}
