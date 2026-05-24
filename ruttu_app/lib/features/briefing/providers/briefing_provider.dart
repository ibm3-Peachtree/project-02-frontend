import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/weather_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/repositories/briefing_repository.dart';
import '../../auth/providers/auth_provider.dart';

final briefingRepositoryProvider = Provider<BriefingRepository>(
  (_) => MockBriefingRepository(),
);

class BriefingState {
  final WeatherAirQualityModel? weather;
  final List<IssueModel> issues;
  final AiSummaryModel? aiSummary;
  final List<ScheduleItemModel> scheduleItems;
  final RouteModel? meetingRoute;
  final bool isLoading;

  const BriefingState({
    this.weather,
    this.issues = const [],
    this.aiSummary,
    this.scheduleItems = const [],
    this.meetingRoute,
    this.isLoading = false,
  });

  BriefingState copyWith({
    WeatherAirQualityModel? weather,
    List<IssueModel>? issues,
    AiSummaryModel? aiSummary,
    List<ScheduleItemModel>? scheduleItems,
    RouteModel? meetingRoute,
    bool? isLoading,
  }) =>
      BriefingState(
        weather:       weather       ?? this.weather,
        issues:        issues        ?? this.issues,
        aiSummary:     aiSummary     ?? this.aiSummary,
        scheduleItems: scheduleItems ?? this.scheduleItems,
        meetingRoute:  meetingRoute  ?? this.meetingRoute,
        isLoading:     isLoading     ?? this.isLoading,
      );
}

final briefingProvider =
    StateNotifierProvider<BriefingNotifier, BriefingState>(
  (ref) => BriefingNotifier(
    ref.read(briefingRepositoryProvider),
    ref.read(authProvider).user?.userId,
  ),
);

class BriefingNotifier extends StateNotifier<BriefingState> {
  final BriefingRepository _repository;
  final int? _userId;

  BriefingNotifier(this._repository, this._userId)
      : super(const BriefingState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final results = await Future.wait([
      _repository.getWeatherAirQuality(),
      _repository.getTodayIssues(),
      _repository.getScheduleItems(),
      _repository.getMeetingRoute(),
      if (_userId != null) _repository.getAiSummary(_userId),
    ]);

    state = BriefingState(
      weather:       results[0] as WeatherAirQualityModel,
      issues:        results[1] as List<IssueModel>,
      scheduleItems: results[2] as List<ScheduleItemModel>,
      meetingRoute:  results[3] as RouteModel?,
      aiSummary:     results.length > 4 ? results[4] as AiSummaryModel? : null,
    );
  }
}
