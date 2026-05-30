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

    // 각 항목이 실패해도 나머지는 정상 표시되도록 개별 처리
    // API 개발 완료 전까지 mock이 사용되며, 실제 API 전환 후에도 안전하게 동작합니다.
    WeatherAirQualityModel? weather;
    List<IssueModel> issues = const [];
    List<ScheduleItemModel> scheduleItems = const [];
    RouteModel? meetingRoute;
    AiSummaryModel? aiSummary;

    await Future.wait([
      _repository.getWeatherAirQuality()
          .then((v) => weather = v)
          .catchError((_) {}),
      _repository.getTodayIssues()
          .then((v) => issues = v)
          .catchError((_) {}),
      _repository.getScheduleItems()
          .then((v) => scheduleItems = v)
          .catchError((_) {}),
      _repository.getMeetingRoute()
          .then((v) => meetingRoute = v)
          .catchError((_) {}),
      if (_userId != null)
        _repository.getAiSummary(_userId!)
            .then((v) => aiSummary = v)
            .catchError((_) {}),
    ]);

    state = BriefingState(
      weather:       weather,
      issues:        issues,
      scheduleItems: scheduleItems,
      meetingRoute:  meetingRoute,
      aiSummary:     aiSummary,
    );
  }
}