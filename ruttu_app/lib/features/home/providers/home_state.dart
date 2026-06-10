import '../../../data/models/routine_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/weather_model.dart';

enum HomeStatus { noRoutine, noTodayRoutine, preActive, active }

/// 현재 안내 중인 경로 종류.
/// [isUsingRecoRoute: bool] 플래그를 대체하여 my/reco/detour를 명시적으로 구분한다.
enum RouteType { my, reco, detour }

class HomeState {
  // ── 고정 데이터 ──────────────────────────────────────────────────────────
  final HomeStatus status;
  final bool isLoading;
  final RoutineModel? activeRoutine;
  final LiveRouteModel? myRoute;
  final LiveRouteModel? recommendedRoute;
  final WeatherAirQualityModel? weather;
  final List<IssueModel> issues;
  final LiveStatusModel? liveStatus;
  final List<RouteModel> recoRouteList;
  final List<RouteModel> detourRouteList;
  final bool hasIncident;
  final String? incidentMessage;
  final DateTime? departureTime;

  // ── 경로 종류 (단일 진실의 원천) ────────────────────────────────────────
  /// 현재 안내 중인 경로 타입.
  /// 지도/UI는 [activeCoords], [activeRoute], [activeStepIndex] 등 computed를 사용.
  final RouteType selectedRouteType;

  // ── 경로별 독립 좌표 슬롯 ────────────────────────────────────────────────
  // STOMP /queue/location/my  → myRouteCoords 전담 갱신
  // STOMP /queue/location/reco → recoRouteCoords 전담 갱신
  // _poll()은 좌표를 절대 건드리지 않음 (race condition 원천 차단)
  final List<RouteXYModel> myRouteCoords;
  final List<RouteXYModel> recoRouteCoords;
  final List<RouteXYModel> detourRouteCoords;

  // ── 실시간 구간 데이터 ───────────────────────────────────────────────────
  final CurrentSectionModel? myCurrentSectionData;
  final CurrentSectionModel? recoCurrentSectionData;

  // ── 경로별 독립 stepIndex ─────────────────────────────────────────────────
  final int myStepIndex;
  final int recoStepIndex;
  final int stepRemainingMinutes;

  // ── @deprecated — 하위 호환용 ────────────────────────────────────────────
  // 신규 코드는 selectedRouteType을 사용할 것.
  @Deprecated('Use selectedRouteType == RouteType.reco || RouteType.detour')
  bool get isUsingRecoRoute =>
      selectedRouteType == RouteType.reco || selectedRouteType == RouteType.detour;

  @Deprecated('Use activeCoords')
  List<RouteXYModel> get routeCoordinates => myRouteCoords;

  @Deprecated('Use recoRouteCoords')
  List<RouteXYModel> get recoRouteCoordinates => recoRouteCoords;

  @Deprecated('Use activeStepIndex')
  int get currentStepIndex => activeStepIndex;

  @Deprecated('Use myCurrentSectionData or recoCurrentSectionData')
  CurrentSectionModel? get currentSectionData => switch (selectedRouteType) {
        RouteType.my => myCurrentSectionData,
        RouteType.reco || RouteType.detour => recoCurrentSectionData,
      };

  // ── Computed: 활성 경로 기반 ─────────────────────────────────────────────

  /// 현재 안내 중인 경로의 좌표 목록. 지도 폴리라인은 이것만 바라본다.
  List<RouteXYModel> get activeCoords => switch (selectedRouteType) {
        RouteType.my => myRouteCoords,
        RouteType.reco || RouteType.detour => recoRouteCoords,
      };

  /// 현재 안내 중인 경로 모델.
  LiveRouteModel? get activeRoute => switch (selectedRouteType) {
        RouteType.my => myRoute,
        RouteType.reco || RouteType.detour => recommendedRoute,
      };

  /// 현재 안내 중인 경로의 stepIndex.
  int get activeStepIndex => switch (selectedRouteType) {
        RouteType.my => myStepIndex,
        RouteType.reco || RouteType.detour => recoStepIndex,
      };

  const HomeState({
    this.status = HomeStatus.noRoutine,
    this.isLoading = false,
    this.activeRoutine,
    this.myRoute,
    this.recommendedRoute,
    this.weather,
    this.issues = const [],
    this.liveStatus,
    this.recoRouteList = const [],
    this.detourRouteList = const [],
    this.hasIncident = false,
    this.incidentMessage,
    this.departureTime,
    this.selectedRouteType = RouteType.my,
    this.myRouteCoords = const [],
    this.recoRouteCoords = const [],
    this.detourRouteCoords = const [],
    this.myCurrentSectionData,
    this.recoCurrentSectionData,
    this.myStepIndex = 0,
    this.recoStepIndex = 0,
    this.stepRemainingMinutes = 0,
  });

  // ── 출발 시간 관련 computed ──────────────────────────────────────────────

  bool get isDepartureImminent {
    if (activeRoutine == null) return false;
    final depTime = activeRoutine!.recommendedDepartureTime;
    final parts = depTime.split(':');
    if (parts.length != 2) return false;
    final now = DateTime.now();
    final dep = DateTime(now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]));
    final diff = dep.difference(now).inMinutes;
    return diff >= 0 && diff <= 10;
  }

  bool get isDepartureOverdue {
    if (activeRoutine == null) return false;
    final depTime = activeRoutine!.recommendedDepartureTime;
    final parts = depTime.split(':');
    if (parts.length != 2) return false;
    final now = DateTime.now();
    final dep = DateTime(now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]));
    return dep.difference(now).inMinutes < 0;
  }

  int get minutesOverdue {
    if (activeRoutine == null) return 0;
    final depTime = activeRoutine!.recommendedDepartureTime;
    final parts = depTime.split(':');
    if (parts.length != 2) return 0;
    final now = DateTime.now();
    final dep = DateTime(now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]));
    final diff = now.difference(dep).inMinutes;
    return diff > 0 ? diff : 0;
  }

  // ── isWalking / stopsRemaining / stationName ─────────────────────────────

  bool get isWalking {
    final statusStr = liveStatus?.status;
    if (statusStr != null) {
      if (statusStr == '탑승중') return false;
      if (statusStr == '도보중') return true;
      if (statusStr == '대기중') return false;
    }
    return _isWalkingForSection(currentSectionData);
  }

  bool _isWalkingForSection(CurrentSectionModel? sec) {
    if (sec == null) return true;
    final raw = sec.section;
    if (sec.idx < 0 || sec.idx >= raw.length) return true;
    return raw[sec.idx] == 'walk';
  }

  int? get stopsRemaining => _stopsRemainingForRoute(
      activeRoute, currentSectionData, isWalking, activeStepIndex);

  String? get currentStationName =>
      _stationNameForSection(currentSectionData, isWalking);

  // ── 나의 경로 탭 전용 ────────────────────────────────────────────────────

  bool get myIsWalking {
    final statusStr = liveStatus?.status;
    if (statusStr != null) {
      if (statusStr == '탑승중') return false;
      if (statusStr == '도보중') return true;
      if (statusStr == '대기중') return false;
    }
    return _isWalkingForSection(myCurrentSectionData);
  }

  String? get myCurrentStationName =>
      _stationNameForSection(myCurrentSectionData, myIsWalking);

  int? get myStopsRemaining =>
      _stopsRemainingForRoute(myRoute, myCurrentSectionData, myIsWalking, myStepIndex);

  int get myStepRemainingMinutes => _remainingMinutesForRoute(myRoute, myStepIndex);

  // ── 추천 경로 탭 전용 ────────────────────────────────────────────────────

  bool get recoIsWalking {
    final statusStr = liveStatus?.status;
    if (statusStr != null &&
        (selectedRouteType == RouteType.reco ||
            selectedRouteType == RouteType.detour)) {
      if (statusStr == '탑승중') return false;
      if (statusStr == '도보중') return true;
      if (statusStr == '대기중') return false;
    }
    return _isWalkingForSection(recoCurrentSectionData);
  }

  String? get recoCurrentStationName =>
      _stationNameForSection(recoCurrentSectionData, recoIsWalking);

  int? get recoStopsRemaining =>
      _stopsRemainingForRoute(recommendedRoute, recoCurrentSectionData, recoIsWalking, recoStepIndex);

  int get recoStepRemainingMinutes =>
      _remainingMinutesForRoute(recommendedRoute, recoStepIndex);

  // ── 공통 헬퍼 ────────────────────────────────────────────────────────────

  String? _stationNameForSection(CurrentSectionModel? sec, bool walking) {
    if (sec == null) return null;
    final idx = sec.idx;
    if (sec.xy.isEmpty) return null;
    final raw = sec.section;
    if (walking) {
      for (var i = idx + 1; i < raw.length && i < sec.xy.length; i++) {
        if (raw[i] != 'walk') {
          final name = sec.xy[i].stationName;
          if (name != null && name.isNotEmpty) return name;
        }
      }
      return null;
    }
    if (idx < 0 || idx >= sec.xy.length) return null;
    return sec.xy[idx].stationName;
  }

  int? _stopsRemainingForRoute(
      LiveRouteModel? route, CurrentSectionModel? sec, bool walking, int stepIdx) {
    if (walking || route == null) return null;
    final paths = route.path;
    if (stepIdx < 0 || stepIdx >= paths.length) return null;
    final currentPath = paths[stepIdx];
    if (currentPath.isWalking) return null;
    final stations = currentPath.stationName;
    if (stations.isEmpty) return currentPath.displayStationCount;
    final currentStation = _stationNameForSection(sec, walking);
    if (currentStation == null) return currentPath.displayStationCount;
    final pos = stations.indexOf(currentStation);
    if (pos < 0) return currentPath.displayStationCount;
    return (stations.length - 1 - pos).clamp(0, 9999);
  }

  int _remainingMinutesForRoute(LiveRouteModel? route, int stepIdx) {
    if (route == null || route.path.isEmpty || stepIdx >= route.path.length) return 0;
    return route.path.skip(stepIdx).fold(0, (sum, p) => sum + p.sectionTime);
  }

  HomeState copyWith({
    HomeStatus? status,
    bool? isLoading,
    RoutineModel? activeRoutine,
    LiveRouteModel? myRoute,
    LiveRouteModel? recommendedRoute,
    WeatherAirQualityModel? weather,
    List<IssueModel>? issues,
    LiveStatusModel? liveStatus,
    int? myStepIndex,
    int? recoStepIndex,
    int? stepRemainingMinutes,
    DateTime? departureTime,
    CurrentSectionModel? myCurrentSectionData,
    CurrentSectionModel? recoCurrentSectionData,
    RouteType? selectedRouteType,
    List<RouteXYModel>? myRouteCoords,
    List<RouteXYModel>? recoRouteCoords,
    List<RouteXYModel>? detourRouteCoords,
    List<RouteModel>? recoRouteList,
    List<RouteModel>? detourRouteList,
    bool? hasIncident,
    String? incidentMessage,
  }) =>
      HomeState(
        status: status ?? this.status,
        isLoading: isLoading ?? this.isLoading,
        activeRoutine: activeRoutine ?? this.activeRoutine,
        myRoute: myRoute ?? this.myRoute,
        recommendedRoute: recommendedRoute ?? this.recommendedRoute,
        weather: weather ?? this.weather,
        issues: issues ?? this.issues,
        liveStatus: liveStatus ?? this.liveStatus,
        myStepIndex: myStepIndex ?? this.myStepIndex,
        recoStepIndex: recoStepIndex ?? this.recoStepIndex,
        stepRemainingMinutes: stepRemainingMinutes ?? this.stepRemainingMinutes,
        departureTime: departureTime ?? this.departureTime,
        myCurrentSectionData: myCurrentSectionData ?? this.myCurrentSectionData,
        recoCurrentSectionData: recoCurrentSectionData ?? this.recoCurrentSectionData,
        selectedRouteType: selectedRouteType ?? this.selectedRouteType,
        myRouteCoords: myRouteCoords ?? this.myRouteCoords,
        recoRouteCoords: recoRouteCoords ?? this.recoRouteCoords,
        detourRouteCoords: detourRouteCoords ?? this.detourRouteCoords,
        recoRouteList: recoRouteList ?? this.recoRouteList,
        detourRouteList: detourRouteList ?? this.detourRouteList,
        hasIncident: hasIncident ?? this.hasIncident,
        incidentMessage: incidentMessage ?? this.incidentMessage,
      );
}
