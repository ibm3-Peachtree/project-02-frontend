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
import 'live_route_provider.dart' show recoRouteProvider, myRouteProvider;

const _queueLocationMy   = '/user/queue/location/my';
const _queueLocationReco = '/user/queue/location/reco';

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  final notifier = HomeNotifier(ref.read(homeRepositoryProvider), ref);
  return notifier;
});

class HomeNotifier extends StateNotifier<HomeState> {
  final HomeRepository _repository;
  final Ref _ref;

  Timer? _liveTimer;
  Timer? _departureTimer;
  Timer? _autoStartTimer;
  Timer? _autoArriveTimer;

  static const _pollInterval             = Duration(seconds: 5);
  static const _departureCheckInterval   = Duration(minutes: 1);
  static const _autoStartInterval        = Duration(seconds: 30);
  static const _autoArriveInterval       = Duration(seconds: 15);
  static const _departureRadius          = 150.0;
  static const _arrivalRadius            = 100.0;

  bool _autoStartTriggered = false;

  final LocationService _locationService = LocationService();

  HomeNotifier(this._repository, this._ref) : super(const HomeState());

  // ══════════════════════════════════════════════════════════════════════════
  // 초기화
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> initialize({bool silent = false}) async {
    if (!silent) state = state.copyWith(isLoading: true);
    try {
      final routines = await _repository.getRoutines();

      WeatherAirQualityModel? weather;
      try { weather = await _repository.getWeatherAirQuality(); } catch (_) {}

      if (routines.isEmpty) {
        state = HomeState(status: HomeStatus.noRoutine, weather: weather);
        return;
      }

      final today     = _todayKey();
      final isHoliday = await _checkIsHoliday();

      final hasTodayRoutine = routines.any((r) =>
          r.isActive && r.days.contains(today) && !(isHoliday && r.skipHoliday));

      if (!hasTodayRoutine) {
        state = HomeState(status: HomeStatus.noTodayRoutine, weather: weather);
        return;
      }

      final todayRoutine = routines.firstWhere(
        (r) => r.isActive && r.days.contains(today) && !(isHoliday && r.skipHoliday),
      );

      RoutineModel routineDetail = todayRoutine;
      try { routineDetail = await _repository.getRoutineDetail(todayRoutine.routineId); } catch (_) {}

      final myRoute = _toMyRoute(routineDetail.route);

      // routineId를 알고 있으므로 /{routineId} 엔드포인트로 호출
      List<RouteModel> recoRouteList  = [];
      List<RouteModel> detourRouteList = [];
      bool hasIncident     = false;
      String? incidentMessage;
      try {
        final recoResp  = await _repository.getRecoRouteListResponse(routineDetail.routineId);
        recoRouteList    = recoResp.recoList;
        detourRouteList  = recoResp.detourList;
        hasIncident      = recoResp.hasIncident;
        incidentMessage  = recoResp.incidentMessage;
      } catch (e) {
        debugPrint('[initialize] getRecoRouteListResponse 실패: $e');
        _ref.read(recoRouteProvider.notifier).markLoadError();
      }

      state = HomeState(
        status:           HomeStatus.preActive,
        activeRoutine:    routineDetail,
        weather:          weather,
        myRoute:          myRoute,
        recommendedRoute: null, // recoRouteList에서 관리
        // 나의 경로 좌표는 routeXy로 초기 세팅
        myRouteCoords:    routineDetail.routeXy,
        recoRouteList:    recoRouteList,
        detourRouteList:  detourRouteList,
        hasIncident:      hasIncident,
        incidentMessage:  incidentMessage,
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

      _startDepartureTimer();
    } catch (e) {
      debugPrint('❌ initialize 실패: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    if (state.status == HomeStatus.active) return;
    await initialize(silent: true);
    final routineId = state.activeRoutine?.routineId;
    if (routineId != null) {
      _ref.read(recoRouteProvider.notifier).loadRecoRouteList(routineId, force: true);
    }
  }

  Future<void> initializeWithRoutine(RoutineModel routine) async {
    state = state.copyWith(isLoading: true);
    _ref.read(recoRouteProvider.notifier).resetList();
    try {
      WeatherAirQualityModel? weather;
      try { weather = await _repository.getWeatherAirQuality(); } catch (_) {}

      RoutineModel routineDetail = routine;
      try { routineDetail = await _repository.getRoutineDetail(routine.routineId); } catch (_) {}

      final myRoute = _toMyRoute(routineDetail.route);

      List<RouteModel> recoRouteList   = [];
      List<RouteModel> detourRouteList = [];
      bool hasIncident     = false;
      String? incidentMessage;
      try {
        final recoResp   = await _repository.getRecoRouteListResponse(routineDetail.routineId);
        recoRouteList     = recoResp.recoList;
        detourRouteList   = recoResp.detourList;
        hasIncident       = recoResp.hasIncident;
        incidentMessage   = recoResp.incidentMessage;
      } catch (e) {
        debugPrint('[initializeWithRoutine] getRecoRouteListResponse 실패 (무시): $e');
        _ref.read(recoRouteProvider.notifier).markLoadError();
      }

      state = HomeState(
        status:          HomeStatus.preActive,
        activeRoutine:   routineDetail,
        weather:         weather,
        myRoute:         myRoute,
        myRouteCoords:   routineDetail.routeXy,
        recoRouteList:   recoRouteList,
        detourRouteList: detourRouteList,
        hasIncident:     hasIncident,
        incidentMessage: incidentMessage,
      );

      if (recoRouteList.isNotEmpty || detourRouteList.isNotEmpty) {
        _ref.read(recoRouteProvider.notifier).preloadList(
          RecoRouteListResponse(
            recoList: recoRouteList, detourList: detourRouteList,
            hasIncident: hasIncident, incidentMessage: incidentMessage,
          ),
          force: true,
        );
      }

      _startDepartureTimer();
      debugPrint('[initializeWithRoutine] 완료 — routineId=${routineDetail.routineId}');
    } catch (e) {
      debugPrint('❌ initializeWithRoutine 실패: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 경로 시작/종료
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> startRoute() async {
    if (state.activeRoutine == null) return;
    _departureTimer?.cancel();
    _departureTimer = null;
    state = state.copyWith(isLoading: true);

    final isReco = state.selectedRouteType != RouteType.my;

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

    CurrentSectionModel? section;
    try {
      section = isReco
          ? await _repository.getRecoCurrentSection()
          : await _repository.getCurrentSection();
    } catch (e) {
      debugPrint('[startRoute] getCurrentSection 실패 (무시됨): $e');
    }

    final myStepIdx = (!isReco && section != null && route != null)
        ? _resolvePathIndex(section, route.path.length, paths: route.path)
        : state.myStepIndex;

    final recoStepIdx = (isReco && section != null && recoRoute != null)
        ? _resolvePathIndex(section, recoRoute.path.length, paths: recoRoute.path)
        : state.recoStepIndex;

    final activeStepIdx = isReco ? recoStepIdx : myStepIdx;
    final activeRoute   = isReco ? recoRoute : route;

    // 좌표: section.xy가 있으면 갱신, 없으면 기존 유지
    final newMyCoords = (!isReco && section?.xy.isNotEmpty == true)
        ? section!.xy
        : (state.myRouteCoords.isNotEmpty
            ? state.myRouteCoords
            : state.activeRoutine?.routeXy ?? const []);

    final newRecoCoords = (isReco && section?.xy.isNotEmpty == true)
        ? section!.xy
        : state.recoRouteCoords;

    debugPrint('[startRoute] isReco=$isReco myStepIdx=$myStepIdx recoStepIdx=$recoStepIdx');

    state = state.copyWith(
      status:                HomeStatus.active,
      myRoute:               route,
      recommendedRoute:      recoRoute,
      isLoading:             false,
      myStepIndex:           myStepIdx,
      recoStepIndex:         recoStepIdx,
      stepRemainingMinutes:  activeRoute != null ? _remainingMinutes(activeRoute, activeStepIdx) : 0,
      liveStatus:            null,
      myRouteCoords:         newMyCoords,
      recoRouteCoords:       newRecoCoords,
      departureTime:         DateTime.now(),
      myCurrentSectionData:  isReco ? state.myCurrentSectionData : section,
      recoCurrentSectionData: isReco ? section : state.recoCurrentSectionData,
      // ✅ [버그수정] 나의 경로 시작 시 selectedRouteType을 명시적으로 my로 세팅.
      // 이전에 reco/detour 타입이었으면 updateMySection guard가 조기 return해
      // myCurrentSectionData가 갱신되지 않는 버그 방지.
      selectedRouteType: isReco ? state.selectedRouteType : RouteType.my,
    );

    _startPolling();
    _subscribeLocationMy();
    _subscribeLocationReco();

    if (!_ref.read(myRouteProvider).isActive) {
      _ref.read(myRouteProvider.notifier).startMyRoute();
    }

    _stopAutoStartMonitor();
    _startAutoArriveMonitor();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STOMP 구독 — 좌표/section 갱신 전담 (poll과 역할 분리)
  //
  // 원칙:
  //   - _subscribeLocationMy  → myRouteCoords + myCurrentSectionData + myStepIndex 만 갱신
  //   - _subscribeLocationReco → recoRouteCoords + recoCurrentSectionData + recoStepIndex 만 갱신
  //   - _poll()은 이 두 필드를 절대 건드리지 않음 (race condition 원천 차단)
  // ══════════════════════════════════════════════════════════════════════════

  void _subscribeLocationMy() {
    StompService.instance.subscribe(
      _queueLocationMy,
      (json) {
        if (!mounted) return;
        try {
          final section = CurrentSectionModel.fromJson(json);

          final stepIdx = state.myRoute != null
              ? _resolvePathIndex(section, state.myRoute!.path.length, paths: state.myRoute!.path)
              : state.myStepIndex;

          // 나의 경로 전용 슬롯만 갱신 — recoRouteCoords 절대 건드리지 않음
          final newCoords = section.xy.isNotEmpty ? section.xy : state.myRouteCoords;

          state = state.copyWith(
            myRouteCoords:        newCoords,
            myCurrentSectionData: section,
            myStepIndex:          stepIdx,
            // 현재 활성 경로가 나의 경로일 때만 stepRemainingMinutes 갱신
            stepRemainingMinutes: state.selectedRouteType == RouteType.my && state.myRoute != null
                ? _remainingMinutes(state.myRoute!, stepIdx)
                : state.stepRemainingMinutes,
          );

          debugPrint('[STOMP/my] idx=${section.idx} coords=${newCoords.length}개 stepIdx=$stepIdx');
        } catch (e) {
          debugPrint('[STOMP/my] 파싱 오류: $e\njson=$json');
        }
      },
      subscriberKey: 'homeProvider_my',
    );
    debugPrint('[HomeNotifier] /queue/location/my 구독 등록');
  }

  void _subscribeLocationReco() {
    StompService.instance.subscribe(
      _queueLocationReco,
      (json) {
        if (!mounted) return;
        try {
          final section = CurrentSectionModel.fromJson(json);

          // ✅ [버그 수정] state.recommendedRoute가 null이면 recoRouteProvider.route로 fallback
          final recoRoute = state.recommendedRoute ?? _ref.read(recoRouteProvider).route;
          final recoStepIdx = recoRoute != null
              ? _resolvePathIndex(section, recoRoute.path.length, paths: recoRoute.path)
              : state.recoStepIndex;

          // 추천/우회 경로 전용 슬롯만 갱신 — myRouteCoords 절대 건드리지 않음
          final newCoords = section.xy.isNotEmpty ? section.xy : state.recoRouteCoords;

          state = state.copyWith(
            recoRouteCoords:        newCoords,
            recoCurrentSectionData: section,
            recoStepIndex:          recoStepIdx,
            // 현재 활성 경로가 reco/detour일 때만 stepRemainingMinutes 갱신
            stepRemainingMinutes: state.selectedRouteType != RouteType.my && recoRoute != null
                ? _remainingMinutes(recoRoute, recoStepIdx)
                : state.stepRemainingMinutes,
          );

          debugPrint('[STOMP/reco] idx=${section.idx} coords=${newCoords.length}개 stepIdx=$recoStepIdx');
        } catch (e) {
          debugPrint('[STOMP/reco] 파싱 오류: $e\njson=$json');
        }
      },
      subscriberKey: 'homeProvider_reco',
    );
    debugPrint('[HomeNotifier] /queue/location/reco 구독 등록');
  }

  void _unsubscribeLocationMy() {
    StompService.instance.unsubscribe(_queueLocationMy, subscriberKey: 'homeProvider_my');
    debugPrint('[HomeNotifier] /queue/location/my 구독 해제');
  }

  void _unsubscribeLocationReco() {
    StompService.instance.unsubscribe(_queueLocationReco, subscriberKey: 'homeProvider_reco');
    debugPrint('[HomeNotifier] /queue/location/reco 구독 해제');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 폴링 — stepIndex / remainingMinutes 재계산만 담당 (좌표 건드리지 않음)
  // ══════════════════════════════════════════════════════════════════════════

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

    if (!mounted) return;

    // ✅ 좌표는 STOMP 전담 — poll은 절대 coords를 덮어쓰지 않는다.
    // stepIndex / stepRemainingMinutes만 최신 section 기반으로 재계산.

    final mySection   = state.myCurrentSectionData;
    final recoSection = state.recoCurrentSectionData;

    final myStepIdx = (mySection != null && state.myRoute != null)
        ? _resolvePathIndex(mySection, state.myRoute!.path.length, paths: state.myRoute!.path)
        : state.myStepIndex;

    final recoStepIdx = (recoSection != null && state.recommendedRoute != null)
        ? _resolvePathIndex(recoSection, state.recommendedRoute!.path.length, paths: state.recommendedRoute!.path)
        : state.recoStepIndex;

    final activeStepIdx = state.selectedRouteType == RouteType.my ? myStepIdx : recoStepIdx;
    final activeRoute   = state.activeRoute;

    state = state.copyWith(
      myStepIndex:          myStepIdx,
      recoStepIndex:        recoStepIdx,
      stepRemainingMinutes: activeRoute != null ? _remainingMinutes(activeRoute, activeStepIdx) : 0,
      // coords は STOMP が更新するため ここでは触れない
    );

    debugPrint('[LivePoll] 완료 — '
        'routeType:${state.selectedRouteType.name} '
        'myStepIdx:$myStepIdx recoStepIdx:$recoStepIdx '
        'myCoords:${state.myRouteCoords.length}개 recoCoords:${state.recoRouteCoords.length}개 '
        'recoSection.idx=${recoSection?.idx} recoSection.type=${recoSection?.currentType}');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 경로 전환
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> switchToRecommendedRoute(int recoId) async {
    state = state.copyWith(isLoading: true);

    try {
      await _repository.saveRecoRoute(recoId);
    } catch (e) {
      debugPrint('[switchToRecommendedRoute] saveRecoRoute 실패 (계속 진행): $e');
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

    final newRecoCoords = recoSection?.xy.isNotEmpty == true
        ? recoSection!.xy
        : (state.recoRouteCoords.isNotEmpty ? state.recoRouteCoords : const <RouteXYModel>[]);

    final recoStepIdx = (recoSection != null && freshReco != null)
        ? _resolvePathIndex(recoSection, freshReco.path.length, paths: freshReco.path)
        : 0;

    state = state.copyWith(
      isLoading:              false,
      selectedRouteType:      RouteType.reco,
      recommendedRoute:       freshReco,
      recoCurrentSectionData: recoSection,
      recoRouteCoords:        newRecoCoords,
      recoStepIndex:          recoStepIdx,
      stepRemainingMinutes:   freshReco != null ? _remainingMinutes(freshReco, recoStepIdx) : 0,
      departureTime:          state.departureTime ?? DateTime.now(),
    );

    _unsubscribeLocationMy();
    _subscribeLocationReco();

    if (state.status != HomeStatus.active) {
      state = state.copyWith(status: HomeStatus.active);
    }
    _startPolling();
  }

  Future<void> switchToDetourRoute(int pathId) async {
    _unsubscribeLocationMy();
    _subscribeLocationReco();

    state = state.copyWith(
      selectedRouteType: RouteType.detour,
      departureTime:     state.departureTime ?? DateTime.now(),
    );

    if (state.status != HomeStatus.active) {
      state = state.copyWith(status: HomeStatus.active);
    }
    _startPolling();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // section 직접 갱신 (recoRouteProvider 등 외부 호출용)
  // ══════════════════════════════════════════════════════════════════════════

  void updateMySection(CurrentSectionModel section) {
    // reco/detour 안내 중에는 나의 경로 section으로 지도를 덮어쓰지 않는다
    if (state.selectedRouteType != RouteType.my) return;
    final route    = state.myRoute;
    final stepIdx  = route != null ? _resolvePathIndex(section, route.path.length, paths: route.path) : state.myStepIndex;
    final newCoords = section.xy.isNotEmpty ? section.xy : state.myRouteCoords;
    state = state.copyWith(
      myRouteCoords:        newCoords,
      myCurrentSectionData: section,
      myStepIndex:          stepIdx,
      stepRemainingMinutes: route != null ? _remainingMinutes(route, stepIdx) : state.stepRemainingMinutes,
    );
    debugPrint('[HomeNotifier] updateMySection idx=${section.idx} '
        'coords=${newCoords.length}개 stepIdx=$stepIdx');
  }

  void updateRecoSection(CurrentSectionModel section) {
    // ✅ [버그 수정] state.recommendedRoute가 null이면 recoRouteProvider.route로 fallback
    final recoRoute = state.recommendedRoute ?? _ref.read(recoRouteProvider).route;
    final recoStepIdx = recoRoute != null
        ? _resolvePathIndex(section, recoRoute.path.length, paths: recoRoute.path)
        : state.recoStepIndex;
    final newRecoCoords = section.xy.isNotEmpty ? section.xy : state.recoRouteCoords;
    state = state.copyWith(
      recoCurrentSectionData: section,
      recoStepIndex:          recoStepIdx,
      recoRouteCoords:        newRecoCoords,
      stepRemainingMinutes:   state.selectedRouteType != RouteType.my && recoRoute != null
          ? _remainingMinutes(recoRoute, recoStepIdx)
          : state.stepRemainingMinutes,
    );
    debugPrint('[HomeNotifier] updateRecoSection idx=${section.idx} '
        'type=${section.currentType} recoStepIdx=$recoStepIdx '
        'station=${section.currentXY?.stationName} recoCoords=${newRecoCoords.length}개');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 종료 / 도착
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> arriveByGps() async {
    if (state.status != HomeStatus.active) return;
    _liveTimer?.cancel(); _liveTimer = null;
    _unsubscribeLocationMy();
    _unsubscribeLocationReco();
    _stopAutoArriveMonitor();

    final departure = state.departureTime;
    final arrival   = DateTime.now();

    if (state.activeRoutine != null && departure != null) {
      try {
        if (state.selectedRouteType != RouteType.my) {
          await _repository.completeRecoRoute(departureTime: departure, arrivalTime: arrival);
        } else {
          await _repository.completeMyRoute(departureTime: departure, arrivalTime: arrival);
        }
        debugPrint('[arriveByGps] 루틴 완료 전송 성공 (${state.selectedRouteType.name})');
      } catch (e) {
        debugPrint('[arriveByGps] 루틴 완료 전송 실패 (무시됨): $e');
      }
    }

    state = HomeState(
      status:           HomeStatus.preActive,
      activeRoutine:    state.activeRoutine,
      weather:          state.weather,
      myRoute:          state.myRoute,
      recommendedRoute: state.recommendedRoute,
      myRouteCoords:    state.myRouteCoords,
      recoRouteCoords:  state.recoRouteCoords,
      liveStatus:       LiveStatusModel(
        status: '도착', updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    _startDepartureTimer();
  }

  Future<void> stopRoute() async {
    _liveTimer?.cancel(); _liveTimer = null;
    _unsubscribeLocationMy();
    _unsubscribeLocationReco();
    _stopAutoArriveMonitor();
    _stopAutoStartMonitor();

    final departure = state.departureTime;
    final arrival   = DateTime.now();
    final isReco    = state.selectedRouteType != RouteType.my;

    if (state.activeRoutine != null && departure != null) {
      try {
        if (isReco) {
          await _repository.completeRecoRoute(departureTime: departure, arrivalTime: arrival);
        } else {
          await _repository.completeMyRoute(departureTime: departure, arrivalTime: arrival);
        }
        debugPrint('[stopRoute] 루틴 완료 전송 성공 (${state.selectedRouteType.name})');
      } catch (e) {
        debugPrint('[stopRoute] 루틴 완료 전송 실패 (무시됨): $e');
      }
    }

    state = HomeState(
      status:           HomeStatus.preActive,
      activeRoutine:    state.activeRoutine,
      weather:          state.weather,
      myRoute:          state.myRoute,
      recommendedRoute: state.recommendedRoute,
      myRouteCoords:    state.myRouteCoords,
      recoRouteCoords:  state.recoRouteCoords,
    );

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
      if (state.selectedRouteType != RouteType.my) {
        await _repository.completeRecoRoute(
          departureTime: departureTime, arrivalTime: arrivalTime,
          satWaitTimeScore: satWaitTimeScore, satEtaScore: satEtaScore, satRouteScore: satRouteScore,
        );
      } else {
        await _repository.completeMyRoute(
          departureTime: departureTime, arrivalTime: arrivalTime,
          satWaitTimeScore: satWaitTimeScore, satEtaScore: satEtaScore, satRouteScore: satRouteScore,
        );
      }
      debugPrint('[completeRoutine] 루틴 완료 전송 성공 (${state.selectedRouteType.name})');
    } catch (e) {
      debugPrint('[completeRoutine] 루틴 완료 전송 실패 (무시됨): $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 기타 유틸
  // ══════════════════════════════════════════════════════════════════════════

  void seedMyRouteCoordinates(List<RouteXYModel> coords) {
    if (state.myRouteCoords.isNotEmpty) return;
    state = state.copyWith(myRouteCoords: coords);
    debugPrint('[HomeNotifier] seedMyRouteCoordinates ${coords.length}개');
  }

  void ensureActive({bool isReco = true}) {
    if (state.status == HomeStatus.active) return;
    state = state.copyWith(
      status:            HomeStatus.active,
      selectedRouteType: isReco ? RouteType.reco : RouteType.my,
      departureTime:     state.departureTime ?? DateTime.now(),
    );
    _startPolling();
    if (isReco) {
      _subscribeLocationReco();
    } else {
      _subscribeLocationMy();
    }
    debugPrint('[HomeNotifier] ensureActive: status → active (isReco=$isReco fallback)');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 출발 시간 감시 타이머
  // ══════════════════════════════════════════════════════════════════════════

  void _startDepartureTimer() {
    _departureTimer?.cancel();
    if (state.activeRoutine == null) return;
    _departureTimer = Timer.periodic(_departureCheckInterval, (_) {
      if (!mounted) return;
      if (state.status != HomeStatus.preActive) {
        _departureTimer?.cancel(); _departureTimer = null; return;
      }
      state = state.copyWith();
      debugPrint('[DepartureTimer] imminent=${state.isDepartureImminent} '
          'overdue=${state.isDepartureOverdue} minutesOverdue=${state.minutesOverdue}');
      if ((state.isDepartureImminent || state.isDepartureOverdue) && _autoStartTimer == null) {
        _startAutoStartMonitor();
      }
    });
    debugPrint('[DepartureTimer] 출발 시간 감시 타이머 시작');
    if (state.isDepartureImminent || state.isDepartureOverdue) _startAutoStartMonitor();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 자동 시작 / 자동 도착 감시
  // ══════════════════════════════════════════════════════════════════════════

  void _startAutoStartMonitor() {
    if (_autoStartTimer != null) return;
    _autoStartTriggered = false;
    debugPrint('[AutoStart] 출발 감지 타이머 시작 (반경 ${_departureRadius}m)');
    _autoStartTimer = Timer.periodic(_autoStartInterval, (_) async {
      if (!mounted) return;
      if (state.status != HomeStatus.preActive || _autoStartTriggered) {
        _stopAutoStartMonitor(); return;
      }
      await _checkAutoStart();
    });
    _checkAutoStart();
  }

  void _stopAutoStartMonitor() {
    _autoStartTimer?.cancel(); _autoStartTimer = null;
    debugPrint('[AutoStart] 출발 감지 타이머 중단');
  }

  Future<void> _checkAutoStart() async {
    if (!mounted || state.status != HomeStatus.preActive) return;
    if (!state.isDepartureImminent && !state.isDepartureOverdue) return;
    final coords = state.activeRoutine?.routeXy ?? [];
    if (coords.isEmpty) return;
    final origin = coords.first;
    if (origin.x == null || origin.y == null) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final pos  = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, origin.y!, origin.x!);
      debugPrint('[AutoStart] 출발지까지 거리: ${dist.toStringAsFixed(0)}m (기준 ${_departureRadius}m)');
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

  void _startAutoArriveMonitor() {
    if (_autoArriveTimer != null) return;
    debugPrint('[AutoArrive] 도착 감지 타이머 시작 (반경 ${_arrivalRadius}m)');
    _autoArriveTimer = Timer.periodic(_autoArriveInterval, (_) async {
      if (!mounted) return;
      if (state.status != HomeStatus.active) { _stopAutoArriveMonitor(); return; }
      await _checkAutoArrive();
    });
  }

  void _stopAutoArriveMonitor() {
    _autoArriveTimer?.cancel(); _autoArriveTimer = null;
    debugPrint('[AutoArrive] 도착 감지 타이머 중단');
  }

  Future<void> _checkAutoArrive() async {
    if (!mounted || state.status != HomeStatus.active) return;
    final coords = state.activeRoutine?.routeXy ?? [];
    if (coords.isEmpty) return;
    final dest = coords.last;
    if (dest.x == null || dest.y == null) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final pos  = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, dest.y!, dest.x!);
      debugPrint('[AutoArrive] 목적지까지 거리: ${dist.toStringAsFixed(0)}m (기준 ${_arrivalRadius}m)');
      if (dist <= _arrivalRadius) {
        _stopAutoArriveMonitor();
        debugPrint('[AutoArrive] 목적지 도착 감지 → 자동 종료');
        await arriveByGps();
      }
    } catch (e) {
      debugPrint('[AutoArrive] GPS 오류 (무시됨): $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 헬퍼
  // ══════════════════════════════════════════════════════════════════════════

  LiveRouteModel? _toMyRoute(dynamic routeData) {
    if (routeData == null) return null;
    return LiveRouteModel(
      totalDistance: routeData.totalDistance,
      totalTime:     routeData.totalTime,
      payment:       routeData.payment,
      startName:     routeData.startName,
      endName:       routeData.endName,
      path:          routeData.path,
    );
  }

  int _remainingMinutes(LiveRouteModel route, int stepIndex) {
    if (route.path.isEmpty || stepIndex >= route.path.length) return 0;
    return route.path.skip(stepIndex).fold(0, (sum, p) => sum + p.sectionTime);
  }

  /// CurrentSectionModel.idx(raw xy 인덱스) → PathModel 배열 기준 path 인덱스 변환
  ///
  /// [버그 수정] 기존 구현은 groupedSections 전환 횟수를 그대로 path 인덱스로 사용했는데,
  /// 버스 구간에 번호가 여러 개(예: 5516·5536)이면 section 배열에서는 별도 그룹 2개이지만
  /// PathModel(UI 카드)에서는 1개로 묶이므로 인덱스가 +1 밀리는 버그가 발생함.
  ///
  /// 수정: paths(PathModel 배열)를 받아 _PathSegmentCard._xyRangeForPath()와
  /// 동일한 로직으로 "현재 idx가 속하는 path index"를 역산.
  /// paths가 null이면 groupedSections 기준 fallback(하위 호환).
  int _resolvePathIndex(CurrentSectionModel section, int pathLength,
      {List<PathModel>? paths}) {
    if (pathLength == 0) return 0;
    final raw = section.section;
    if (raw.isEmpty) return 0;

    final currentRawIdx = section.idx.clamp(0, raw.length - 1);
    final groups = section.groupedSections;
    if (groups.isEmpty) return 0;

    // paths가 주어진 경우: PathModel 배열 기반 정확한 매핑
    if (paths != null && paths.isNotEmpty) {
      int groupCursor = 0;
      for (int pathIdx = 0; pathIdx < paths.length; pathIdx++) {
        if (groupCursor >= groups.length) break;
        final curPath = paths[pathIdx];

        bool Function(GroupedSection) sameType;
        if (curPath.isWalking)     sameType = (g) => g.isWalk;
        else if (curPath.isBus)    sameType = (g) => g.isBus;
        else if (curPath.isSubway) sameType = (g) => g.isSubway;
        else                       sameType = (_) => false;

        if (!sameType(groups[groupCursor])) break; // 타입 불일치 → fallback

        final startGroup = groupCursor;
        // 연속된 같은 타입 그룹 소비 (버스 복수 번호 등)
        while (groupCursor < groups.length && sameType(groups[groupCursor])) {
          groupCursor++;
        }

        final rangeStart = groups[startGroup].startIdx;
        final rangeEnd   = groups[groupCursor - 1].endIdx;

        if (currentRawIdx >= rangeStart && currentRawIdx <= rangeEnd) {
          debugPrint('[resolvePathIndex] idx=$currentRawIdx → pathIdx=$pathIdx '
              '(range=$rangeStart~$rangeEnd, pathLength=$pathLength)');
          return pathIdx.clamp(0, pathLength - 1);
        }
      }
      // paths 매핑 실패 시 아래 fallback으로 계속
    }

    // fallback: groupedSections 순서 기준 (paths 없거나 매핑 실패 시)
    for (int g = 0; g < groups.length; g++) {
      if (currentRawIdx <= groups[g].endIdx) {
        debugPrint('[resolvePathIndex] fallback idx=$currentRawIdx → groupIdx=$g '
            '(pathLength=$pathLength)');
        return g.clamp(0, pathLength - 1);
      }
    }
    return (groups.length - 1).clamp(0, pathLength - 1);
  }

  String _todayKey() {
    const keys = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return keys[DateTime.now().weekday - 1];
  }

  Future<bool> _checkIsHoliday() async {
    final now  = DateTime.now();
    const fixedHolidays = {
      (1, 1), (3, 1), (5, 5), (6, 6), (8, 15),
      (10, 3), (10, 9), (12, 25),
    };
    return fixedHolidays.contains((now.month, now.day));
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _departureTimer?.cancel();
    _autoStartTimer?.cancel();
    _autoArriveTimer?.cancel();
    _unsubscribeLocationMy();
    _unsubscribeLocationReco();
    super.dispose();
  }
}
