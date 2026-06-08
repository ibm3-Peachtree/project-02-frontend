import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/home_repository_provider.dart';
import '../../../data/models/routine_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/weather_model.dart';
import '../../../data/repositories/home_repository.dart';
import 'home_state.dart';
import 'live_route_provider.dart' show recoRouteProvider;

// homeRepositoryProvider → home_repository_provider.dart

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  final notifier = HomeNotifier(ref.read(homeRepositoryProvider), ref);
  return notifier;
});

class HomeNotifier extends StateNotifier<HomeState> {
  final HomeRepository _repository;
  final Ref _ref;

  /// 실시간 폴링 타이머 (active 상태에서 주기적으로 백엔드 조회)
  Timer? _liveTimer;

  /// 폴링 주기 — 5초마다 status / section / recoRoute 갱신
  static const _pollInterval = Duration(seconds: 5);

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
      // 공휴일 여부 확인 (간단 구현: 실제 공휴일 API 연동 시 교체)
      final isHoliday = await _checkIsHoliday();

      // 공휴일 + skipHoliday가 켜진 루틴은 오늘 루틴에서 제외
      final hasTodayRoutine = routines.any((r) =>
          r.isActive &&
          r.days.contains(today) &&
          !(isHoliday && r.skipHoliday));

      if (!hasTodayRoutine) {
        state = HomeState(
          status: HomeStatus.noTodayRoutine,
          weather: weather,
          // 루틴 목록은 state에 없으므로 activeRoutine만 null로 둠
        );
        return;
      }

      final todayRoutine = routines.firstWhere(
        (r) =>
            r.isActive &&
            r.days.contains(today) &&
            !(isHoliday && r.skipHoliday),
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
        // ✅ 버그 수정: myRoute로 fallback하면 두 탭이 같은 데이터를 갖게 됨.
        //    실패 시 null 유지 — 추천 경로 탭은 카드 목록 선택 후 switchToRecommendedRoute()에서 채워짐.
        debugPrint('[initialize] getRecommendedRoute 실패, null 유지: $e');
      }

      // 추천 경로 카드 목록: /me/routines/active/reco/list
      List<RouteModel> recoRouteList = [];
      List<RouteModel> detourRouteList = [];
      bool hasIncident = false;
      String? incidentMessage;
      debugPrint('[initialize] getRecoRouteListResponse 호출 시작');
      try {
        final recoResp = await _repository.getRecoRouteListResponse();
        recoRouteList = recoResp.recoList;
        detourRouteList = recoResp.detourList;
        hasIncident = recoResp.hasIncident;
        incidentMessage = recoResp.incidentMessage;
        debugPrint('[initialize] 성공: reco=${recoRouteList.length}, detour=${detourRouteList.length}, hasIncident=$hasIncident');
      } catch (e) {
        debugPrint('[initialize] getRecoRouteListResponse 실패: $e');
        // 실패 시 recoRouteProvider에 에러 상태를 전파 → 탭 진입 시 재시도 버튼 표시
        _ref.read(recoRouteProvider.notifier).markLoadError();
      }

      // 추천 경로 초기 좌표:
      // preActive 상태에서는 /active/location/reco API가 403을 반환할 수 있으므로
      // 호출하지 않는다. recoRouteCoordinates는 출발 후 STOMP push →
      // updateRecoSection()을 통해 채워질 때까지 빈 상태로 유지.
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
        recoRouteList: recoRouteList,
        detourRouteList: detourRouteList,
        hasIncident: hasIncident,
        incidentMessage: incidentMessage,
      );

      // ✅ 추천 경로 데이터를 recoRouteProvider에 미리 주입.
      // TabBarView 특성상 탭을 눌러야 RecoRouteTabContent.initState()가 실행되므로,
      // initialize() 시점에 직접 주입하여 탭 진입 즉시 목록이 보이도록 한다.
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
    // liveStatusProvider(STOMP /user/queue/status)가 담당하므로 REST 호출 불필요
    final LiveStatusModel? liveStatus = null;

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

    // ── section REST 호출 ────────────────────────────────────────────
    // 나의 경로 중: /location/my REST 폴링
    // 추천 경로 중: STOMP /user/queue/location/reco 구독으로 처리됨
    //              (recoLiveRouteProvider → updateRecoSection() 경유)
    //              REST GET /me/routines/active/location/reco 호출 제거.
    CurrentSectionModel? mySection;

    if (!state.isUsingRecoRoute) {
      try {
        mySection = await _repository.getCurrentSection();
      } catch (e) {
        debugPrint('[LivePoll] getCurrentSection 실패 (무시됨): $e');
      }
    }

    // 나의 경로 stepIndex
    final myStepIdx = (mySection != null && state.myRoute != null)
        ? _resolvePathIndex(mySection, state.myRoute!.path.length)
        : state.myStepIndex;

    // 추천 경로 stepIndex: STOMP push(updateRecoSection)가 갱신한 값 그대로 사용
    final recoSectionData = state.recoCurrentSectionData;
    final recoStepIdx = (recoSectionData != null && state.recommendedRoute != null)
        ? _resolvePathIndex(recoSectionData, state.recommendedRoute!.path.length)
        : state.recoStepIndex;

    // 추천 경로 좌표: STOMP section의 xy 우선, 없으면 기존 유지
    final newRecoCoords = (recoSectionData?.xy.isNotEmpty == true)
        ? recoSectionData!.xy
        : state.recoRouteCoordinates;

    final stepIndex = state.isUsingRecoRoute ? recoStepIdx : myStepIdx;

    final activeRoute = state.isUsingRecoRoute ? state.recommendedRoute : state.myRoute;

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
      // recoCurrentSectionData는 updateRecoSection()이 단독 관리 — _poll()에서 덮어쓰지 않음
    );

    debugPrint('[LivePoll] 완료 — '
        'isReco:${state.isUsingRecoRoute} myStepIdx:$myStepIdx recoStepIdx:$recoStepIdx '
        'myCoords:${newMyCoords.length}개 recoCoords:${newRecoCoords.length}개 '
        'recoSection.idx=${recoSectionData?.idx} recoSection.type=${recoSectionData?.currentType}');
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

  /// RecoLiveRouteNotifier의 STOMP section 수신 시 호출.
  /// recoCurrentSectionData를 즉시 갱신하여 다음 _poll() 사이클에서
  /// recoStepIdx / recoRouteCoordinates가 올바르게 재계산되도록 한다.
  void updateRecoSection(CurrentSectionModel section) {
    if (state.status != HomeStatus.active) return;
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

  /// 루틴 생성/수정 후 경로 데이터 재조회 (추천 경로 0개 문제 해결)
  /// 루틴 생성/수정 후 데이터 재조회.
  /// silent 모드로 initialize를 호출하여 isLoading 스피너 없이 조용히 갱신.
  Future<void> refresh() async {
    await initialize(silent: true);
  }

  /// 추천 경로를 선택 (세 번째 화면 "이 경로로 변경" 버튼)
  /// saveRecoRoute POST → getRecommendedRoute + getRecoCurrentSection으로
  /// 추천 경로 데이터를 fresh하게 갱신한다.
  /// myRoute / myCurrentSectionData는 절대 건드리지 않아 나의 경로 탭이 독립 유지된다.
  Future<void> switchToRecommendedRoute(int recoId) async {
    state = state.copyWith(isLoading: true);

    try {
      // 1. 서버에 선택한 추천 경로 저장
      await _repository.saveRecoRoute(recoId);
    } catch (e) {
      debugPrint('[switchToRecommendedRoute] saveRecoRoute 실패: $e');
      state = state.copyWith(isLoading: false);
      return;
    }

    // 2. 저장 직후 추천 경로 LiveRouteModel을 fresh하게 조회
    LiveRouteModel? freshReco;
    try {
      freshReco = await _repository.getRecommendedRoute();
    } catch (e) {
      debugPrint('[switchToRecommendedRoute] getRecommendedRoute 실패: $e');
      // 실패해도 이전 recommendedRoute가 있으면 그대로 사용
      freshReco = state.recommendedRoute;
    }

    // 3. 추천 경로 현재 구간(section) 조회
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

    // isUsingRecoRoute + 경로 데이터를 먼저 세팅
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

    // preActive 상태면 startRoute()를 통해 active로 전환 — 나의 경로 초기화 없이 진입
    // active 상태면 이미 _ActiveView가 떠 있으므로 status는 건드리지 않고 폴링만 유지
    if (state.status != HomeStatus.active) {
      await startRoute();
    } else {
      _startPolling();
    }
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

  /// 오늘이 공휴일인지 확인합니다.
  /// 현재는 공공 공휴일 API 연동 없이 주말을 제외한 법정 공휴일 목록으로 체크합니다.
  /// 추후 공공데이터 포털 공휴일 API 연동 시 이 메서드만 교체하면 됩니다.
  Future<bool> _checkIsHoliday() async {
    try {
      // 서버에서 공휴일 여부 조회 시도 (백엔드가 준비되면 아래 주석 해제)
      // final res = await _repository.getTodayHolidayStatus();
      // return res;
    } catch (_) {}

    // 폴백: 클라이언트 사이드 한국 법정 공휴일 체크
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;
    // 고정 공휴일 목록
    const fixedHolidays = {
      (1, 1), (3, 1), (5, 5), (6, 6), (8, 15),
      (10, 3), (10, 9), (12, 25),
    };
    return fixedHolidays.contains((month, day));
  }
}