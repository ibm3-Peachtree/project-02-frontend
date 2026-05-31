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
  final int currentStepIndex;
  final int stepRemainingMinutes;
  /// getCurrentSection()에서 내려온 xy 좌표 목록 → 지도에 경로 폴리라인으로 그림
  final List<RouteXYModel> routeCoordinates;

  /// 경로 시작(출발) 시각 — completeRoutine 호출 시 departureTime으로 사용
  final DateTime? departureTime;

  /// 폴링에서 받은 raw section 데이터 — 정거장 위치 계산에 사용
  final CurrentSectionModel? currentSectionData;

  /// true: 추천 경로로 변경해서 진행 중 → complete/reco 호출
  /// false(기본): 나의 경로로 진행 중 → complete/my 호출
  final bool isUsingRecoRoute;

  /// 추천 경로의 좌표 목록 (나의 경로 routeCoordinates와 독립적으로 유지)
  /// isUsingRecoRoute=true일 때 지도에 표시
  final List<RouteXYModel> recoRouteCoordinates;

  const HomeState({
    this.status = HomeStatus.noRoutine,
    this.isLoading = false,
    this.activeRoutine,
    this.myRoute,
    this.recommendedRoute,
    this.weather,
    this.issues = const [],
    this.liveStatus,
    this.currentStepIndex = 0,
    this.stepRemainingMinutes = 0,
    this.routeCoordinates = const [],
    this.departureTime,
    this.currentSectionData,
    this.isUsingRecoRoute = false,
    this.recoRouteCoordinates = const [],
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

    // myRoute의 현재 path 구간(bus/subway)의 stationName 목록에서
    // 현재 정류장 이후 남은 정거장 수를 산출 (버스/지하철 공통)
    final route = myRoute;
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
    int? stepRemainingMinutes,
    List<RouteXYModel>? routeCoordinates,
    DateTime? departureTime,
    CurrentSectionModel? currentSectionData,
    bool? isUsingRecoRoute,
    List<RouteXYModel>? recoRouteCoordinates,
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
        stepRemainingMinutes: stepRemainingMinutes ?? this.stepRemainingMinutes,
        routeCoordinates: routeCoordinates ?? this.routeCoordinates,
        departureTime: departureTime ?? this.departureTime,
        currentSectionData: currentSectionData ?? this.currentSectionData,
        isUsingRecoRoute: isUsingRecoRoute ?? this.isUsingRecoRoute,
        recoRouteCoordinates: recoRouteCoordinates ?? this.recoRouteCoordinates,
      );
}