import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/weather_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/repositories/briefing_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/network_provider.dart';

final briefingRepositoryProvider = Provider<BriefingRepository>((ref) =>
    ApiBriefingRepository(ref.read(apiClientProvider).dio));

class BriefingState {
  final WeatherAirQualityModel? weather;
  final List<IssueModel> issues;
  final AiSummaryModel? aiSummary;
  final List<ScheduleItemModel> scheduleItems;
  final RouteModel? meetingRoute;
  final bool isLoading;
  // 새 API 결과
  final BriefingWeatherModel? briefingWeather;
  final List<BriefingCalendarGroup> calendarGroups;
  final String? calendarError;

  const BriefingState({
    this.weather,
    this.issues = const [],
    this.aiSummary,
    this.scheduleItems = const [],
    this.meetingRoute,
    this.isLoading = false,
    this.briefingWeather,
    this.calendarGroups = const [],
    this.calendarError,
  });

  BriefingState copyWith({
    WeatherAirQualityModel? weather,
    List<IssueModel>? issues,
    AiSummaryModel? aiSummary,
    List<ScheduleItemModel>? scheduleItems,
    RouteModel? meetingRoute,
    bool? isLoading,
    BriefingWeatherModel? briefingWeather,
    List<BriefingCalendarGroup>? calendarGroups,
    String? calendarError,
  }) =>
      BriefingState(
        weather:         weather         ?? this.weather,
        issues:          issues          ?? this.issues,
        aiSummary:       aiSummary       ?? this.aiSummary,
        scheduleItems:   scheduleItems   ?? this.scheduleItems,
        meetingRoute:    meetingRoute    ?? this.meetingRoute,
        isLoading:       isLoading       ?? this.isLoading,
        briefingWeather: briefingWeather ?? this.briefingWeather,
        calendarGroups:  calendarGroups  ?? this.calendarGroups,
        calendarError:   calendarError   ?? this.calendarError,
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

    BriefingWeatherModel? briefingWeather;
    List<BriefingCalendarGroup> calendarGroups = const [];
    String? calendarError;

    // 모든 API를 한 번에 병렬 호출 — 순차 대기 제거로 로딩 시간 단축
    await Future.wait([
      _repository.getWeatherAirQuality()
          .then((v) => weather = v)
          .catchError((_) {}),
      _repository.getTodayIssues()
          .then((v) => issues = v)
          .catchError((_) {}),
      _repository.getMeetingRoute()
          .then((v) => meetingRoute = v)
          .catchError((_) {}),
      if (_userId != null)
        _repository.getAiSummary(_userId!)
            .then((v) => aiSummary = v)
            .catchError((_) {}),
      _repository.getBriefingWeather()
          .then((v) => briefingWeather = v)
          .catchError((_) {}),
      _repository.getBriefingCalendar()
          .then((v) {
            calendarGroups = v;
            debugPrint('[BriefingCalendar] success: ${v.length} groups, '
                '${v.expand((g) => g.items).length} events');
          })
          .catchError((e, st) {
            calendarError = e.toString();
            debugPrint('[BriefingCalendar] ERROR: $e');
            debugPrint('[BriefingCalendar] STACK: $st');
          }),
    ]);

    state = BriefingState(
      weather:         weather,
      issues:          issues,
      scheduleItems:   scheduleItems,
      meetingRoute:    meetingRoute,
      aiSummary:       aiSummary,
      briefingWeather: briefingWeather,
      calendarGroups:  calendarGroups,
      calendarError:   calendarError,
    );
  }
}