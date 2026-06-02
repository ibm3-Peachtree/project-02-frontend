import '../../../data/models/routine_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/weather_model.dart';

enum HomeStatus { noRoutine, noTodayRoutine, preActive, active }

class HomeState {
  final HomeStatus status;
  final bool isLoading;
  final RoutineModel? activeRoutine;
  final LiveRouteModel? myRoute;
  final LiveRouteModel? recommendedRoute;
  final WeatherAirQualityModel? weather;
  final List<IssueModel> issues;
  final LiveStatusModel? liveStatus;

  /// 추천 경로 탭 — 카드 목록
  final List<RouteModel> recoRouteList;
  final List<RouteModel> detourRouteList;
  final bool hasIncident;
  final String? incidentMessage;
  final int currentStepIndex;
  final int stepRemainingMinutes;
  /// getCurrentSection()에서 내려온 xy 좌표 목록 → 지도에 경로 폴리라인으로 그림
  final List<RouteXYModel> routeCoordinates;

  /// 경로 시작(출발) 시각 — completeRoutine 호출 시 departureTime으로 사용
  final DateTime? departureTime;

  /// 나의 경로 전용 section 데이터 — 나의 경로 탭 패널에 전달
  final CurrentSectionModel? myCurrentSectionData;

  /// 추천 경로 전용 section 데이터 — 추천 경로 탭 패널에 전달
  final CurrentSectionModel? recoCurrentSectionData;

  /// @deprecated — 하위 호환용. 실제로는 myCurrentSectionData / recoCurrentSectionData를 사용.
  /// isUsingRecoRoute에 따라 둘 중 하나를 반환한다.
  CurrentSectionModel? get currentSectionData =>
      isUsingRecoRoute ? recoCurrentSectionData : myCurrentSectionData;

  /// true: 추천 경로로 변경해서 진행 중 → complete/reco 호출
  /// false(기본): 나의 경로로 진행 중 → complete/my 호출
  final bool isUsingRecoRoute;

  /// 추천 경로의 좌표 목록 (나의 경로 routeCoordinates와 독립적으로 유지)
  /// isUsingRecoRoute=true일 때 지도에 표시
  final List<RouteXYModel> recoRouteCoordinates;

  /// 나의 경로 탭 전용 stepIndex — myCurrentSectionData 기준으로 독립 관리
  /// isUsingRecoRoute=true로 전환 후에도 나의 경로 탭은 이 값을 사용
  final int myStepIndex;

  /// 추천 경로 탭 전용 stepIndex — recoCurrentSectionData 기준으로 독립 관리
  final int recoStepIndex;

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
    this.currentStepIndex = 0,
    this.stepRemainingMinutes = 0,
    this.routeCoordinates = const [],
    this.departureTime,
    this.myCurrentSectionData,
    this.recoCurrentSectionData,
    this.isUsingRecoRoute = false,
    this.recoRouteCoordinates = const [],
    this.myStepIndex = 0,
    this.recoStepIndex = 0,
  });

  bool get isDepartureImminent {
    if (activeRoutine == null) return false;
    final depTime = activeRoutine!.recommendedDepartureTime; // "HH:mm"
    final parts = depTime.split(':');
    if (parts.length != 2) return false;
    final now = DateTime.now();
    final dep = DateTime(now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]));
    final diff = dep.difference(now).inMinutes;
    return diff >= 0 && diff <= 10;
  }

  /// true: 권장 출발 시간이 이미 지났음 (diff < 0)
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

  /// 권장 출발 시간이 몇 분 지났는지 (양수 반환, 지나지 않았으면 0)
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

  /// 도보/대기 중 여부
  /// liveStatus.status를 우선 사용 (speed 기반으로 정확).
  /// "탑승중" → false (버스/지하철 탑승), 나머지 → true (도보/대기)
  bool get isWalking {
    final statusStr = liveStatus?.status;
    if (statusStr != null) {
      if (statusStr == '탑승중') return false;
      if (statusStr == '도보중') return true;
      if (statusStr == '대기중') return false; // 정류장 대기 중 → 탑승 준비 상태
    }
    // liveStatus 없으면 section 데이터로 폴백
    final sec = currentSectionData;
    if (sec == null) return true;
    // idx = 도착 예정 구간이므로, 현재 있는 구간은 idx - 1
    final currentIdx = sec.idx - 1; // 현재 구간 (idx는 도착 예정)
    final raw = sec.section;
    if (currentIdx < 0 || currentIdx >= raw.length) return true;
    return raw[currentIdx] == 'walk';
  }

  /// 현재 구간(버스/지하철) 내 남은 정거장 수.
  /// 도보/대기 중이면 null 반환.
  int? get stopsRemaining {
    if (isWalking) return null;

    // 활성 경로(나의 경로 or 추천 경로)의 현재 path 구간 stationName 목록에서
    // 현재 정류장 이후 남은 정거장 수를 산출 (버스/지하철 공통)
    final route = isUsingRecoRoute ? recommendedRoute : myRoute;
    if (route == null) return null;

    final paths = route.path;
    if (currentStepIndex < 0 || currentStepIndex >= paths.length) return null;

    final currentPath = paths[currentStepIndex];
    if (currentPath.isWalking) return null;

    final stations = currentPath.stationName;
    if (stations.isEmpty) return currentPath.displayStationCount;

    final currentStation = currentStationName;

    // 현재 정류장을 모르면 전체 정거장 수 반환
    if (currentStation == null) return currentPath.displayStationCount;

    final currentPos = stations.indexOf(currentStation);
    // 인덱스를 찾지 못하면 전체 수 반환
    if (currentPos < 0) return currentPath.displayStationCount;

    // stationName[0]=승차, stationName[last]=하차
    // 현재 정류장 이후 하차지까지 남은 정거장 수
    return (stations.length - 1 - currentPos).clamp(0, 9999);
  }

  /// 현재 위치 정거장 이름
  /// - 도보/대기 중: 다음 탑승 위치(정거장) 이름
  /// - 탑승 중: 현재 정거장 이름
  String? get currentStationName {
    final sec = currentSectionData;
    if (sec == null) return null;
    final idx = sec.idx;
    if (sec.xy.isEmpty) return null;
    final raw = sec.section;

    if (isWalking) {
      // 도보/대기 중: idx(도착 예정 구간)의 탑승 정거장 이름 반환
      if (idx >= 0 && idx < raw.length && idx < sec.xy.length && raw[idx] != 'walk') {
        final name = sec.xy[idx].stationName;
        if (name != null && name.isNotEmpty) return name;
      }
      // idx 이후에서 탑승 정거장 탐색
      for (var i = idx + 1; i < raw.length && i < sec.xy.length; i++) {
        if (raw[i] != 'walk') {
          final name = sec.xy[i].stationName;
          if (name != null && name.isNotEmpty) return name;
        }
      }
      return null;
    }

    // 탑승 중: 현재 구간(idx - 1)의 정거장 이름
    final currentIdx = idx - 1;
    if (currentIdx < 0 || currentIdx >= sec.xy.length) return null;
    return sec.xy[currentIdx].stationName;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 탭별 독립 computed 값 — 나의 경로 탭 전용
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  bool _isWalkingForSection(CurrentSectionModel? sec) {
    // liveStatus는 현재 활성 경로 기준 — 나의 경로 탭 전용 (isUsingRecoRoute=false 시)
    final statusStr = liveStatus?.status;
    if (statusStr != null && !isUsingRecoRoute) {
      if (statusStr == '탑승중') return false;
      if (statusStr == '도보중') return true;
      if (statusStr == '대기중') return false;
    }
    if (sec == null) return true;
    final currentIdx = sec.idx - 1;
    final raw = sec.section;
    if (currentIdx < 0 || currentIdx >= raw.length) return true;
    return raw[currentIdx] == 'walk';
  }

  /// 나의 경로 탭 전용 isWalking (myCurrentSectionData 기준)
  bool get myIsWalking {
    // 나의 경로 탭은 항상 section 데이터 기준으로 판단 (liveStatus는 활성 경로 기준)
    final sec = myCurrentSectionData;
    if (sec == null) return true;
    final currentIdx = sec.idx - 1;
    final raw = sec.section;
    if (currentIdx < 0 || currentIdx >= raw.length) return true;
    return raw[currentIdx] == 'walk';
  }

  /// 나의 경로 탭 전용 currentStationName
  String? get myCurrentStationName =>
      _stationNameForSection(myCurrentSectionData, myIsWalking);

  /// 나의 경로 탭 전용 stopsRemaining
  int? get myStopsRemaining =>
      _stopsRemainingForRoute(myRoute, myCurrentSectionData, myIsWalking, myStepIndex);

  /// 나의 경로 탭 전용 stepRemainingMinutes
  int get myStepRemainingMinutes =>
      _remainingMinutesForRoute(myRoute, myStepIndex);

  /// 추천 경로 탭 전용 isWalking (recoCurrentSectionData 기준)
  bool get recoIsWalking {
    // 추천 경로가 활성일 때는 liveStatus도 참조
    final statusStr = liveStatus?.status;
    if (statusStr != null && isUsingRecoRoute) {
      if (statusStr == '탑승중') return false;
      if (statusStr == '도보중') return true;
      if (statusStr == '대기중') return false;
    }
    final sec = recoCurrentSectionData;
    if (sec == null) return true;
    final currentIdx = sec.idx - 1;
    final raw = sec.section;
    if (currentIdx < 0 || currentIdx >= raw.length) return true;
    return raw[currentIdx] == 'walk';
  }

  /// 추천 경로 탭 전용 currentStationName
  String? get recoCurrentStationName =>
      _stationNameForSection(recoCurrentSectionData, recoIsWalking);

  /// 추천 경로 탭 전용 stopsRemaining
  int? get recoStopsRemaining =>
      _stopsRemainingForRoute(recommendedRoute, recoCurrentSectionData, recoIsWalking, recoStepIndex);

  /// 추천 경로 탭 전용 stepRemainingMinutes
  int get recoStepRemainingMinutes =>
      _remainingMinutesForRoute(recommendedRoute, recoStepIndex);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 공통 내부 헬퍼
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  String? _stationNameForSection(CurrentSectionModel? sec, bool walking) {
    if (sec == null) return null;
    final idx = sec.idx;
    if (sec.xy.isEmpty) return null;
    final raw = sec.section;
    if (walking) {
      if (idx >= 0 && idx < raw.length && idx < sec.xy.length && raw[idx] != 'walk') {
        final name = sec.xy[idx].stationName;
        if (name != null && name.isNotEmpty) return name;
      }
      for (var i = idx + 1; i < raw.length && i < sec.xy.length; i++) {
        if (raw[i] != 'walk') {
          final name = sec.xy[i].stationName;
          if (name != null && name.isNotEmpty) return name;
        }
      }
      return null;
    }
    final currentIdx = idx - 1;
    if (currentIdx < 0 || currentIdx >= sec.xy.length) return null;
    return sec.xy[currentIdx].stationName;
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
    int? currentStepIndex,
    int? myStepIndex,
    int? recoStepIndex,
    int? stepRemainingMinutes,
    List<RouteXYModel>? routeCoordinates,
    DateTime? departureTime,
    CurrentSectionModel? myCurrentSectionData,
    CurrentSectionModel? recoCurrentSectionData,
    bool? isUsingRecoRoute,
    List<RouteXYModel>? recoRouteCoordinates,
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
        currentStepIndex: currentStepIndex ?? this.currentStepIndex,
        myStepIndex: myStepIndex ?? this.myStepIndex,
        recoStepIndex: recoStepIndex ?? this.recoStepIndex,
        stepRemainingMinutes: stepRemainingMinutes ?? this.stepRemainingMinutes,
        routeCoordinates: routeCoordinates ?? this.routeCoordinates,
        departureTime: departureTime ?? this.departureTime,
        myCurrentSectionData: myCurrentSectionData ?? this.myCurrentSectionData,
        recoCurrentSectionData: recoCurrentSectionData ?? this.recoCurrentSectionData,
        isUsingRecoRoute: isUsingRecoRoute ?? this.isUsingRecoRoute,
        recoRouteCoordinates: recoRouteCoordinates ?? this.recoRouteCoordinates,
        recoRouteList: recoRouteList ?? this.recoRouteList,
        detourRouteList: detourRouteList ?? this.detourRouteList,
        hasIncident: hasIncident ?? this.hasIncident,
        incidentMessage: incidentMessage ?? this.incidentMessage,
      );
}