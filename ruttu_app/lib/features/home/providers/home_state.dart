import '../../../data/models/routine_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/models/weather_model.dart';

enum HomeStatus { noRoutine, preActive, active }

class HomeState {
  final HomeStatus status;
  final bool isLoading;
  final RoutineModel? activeRoutine;
  final RouteModel? myRoute;
  final RouteModel? recommendedRoute;
  final WeatherAirQualityModel? weather;
  final List<IssueModel> issues;
  final LiveStatusModel? liveStatus;
  final int currentStepIndex;
  final int stepRemainingMinutes;

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
    RouteModel? myRoute,
    RouteModel? recommendedRoute,
    WeatherAirQualityModel? weather,
    List<IssueModel>? issues,
    LiveStatusModel? liveStatus,
    int? currentStepIndex,
    int? stepRemainingMinutes,
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
      );
}
