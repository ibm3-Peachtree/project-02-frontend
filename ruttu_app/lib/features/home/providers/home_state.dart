import '../../../data/models/routine_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/weather_model.dart';

enum HomeStatus { noRoutine, preActive, active }

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
      );
}