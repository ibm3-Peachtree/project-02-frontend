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
  // 새 API 결과 — origin(출발지) / destination(도착지) 분리
  final BriefingWeatherModel? originWeather;
  final BriefingWeatherModel? destinationWeather;
  final String? weatherError;
  final List<BriefingCalendarGroup> calendarGroups;
  final String? calendarError;

  const BriefingState({
    this.weather,
    this.issues = const [],
    this.aiSummary,
    this.scheduleItems = const [],
    this.meetingRoute,
    this.isLoading = false,
    this.originWeather,
    this.destinationWeather,
    this.weatherError,
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
    BriefingWeatherModel? originWeather,
    BriefingWeatherModel? destinationWeather,
    String? weatherError,
    List<BriefingCalendarGroup>? calendarGroups,
    String? calendarError,
  }) =>
      BriefingState(
        weather:             weather             ?? this.weather,
        issues:              issues              ?? this.issues,
        aiSummary:           aiSummary           ?? this.aiSummary,
        scheduleItems:       scheduleItems       ?? this.scheduleItems,
        meetingRoute:        meetingRoute        ?? this.meetingRoute,
        isLoading:           isLoading           ?? this.isLoading,
        originWeather:       originWeather       ?? this.originWeather,
        destinationWeather:  destinationWeather  ?? this.destinationWeather,
        weatherError:        weatherError        ?? this.weatherError,
        calendarGroups:      calendarGroups      ?? this.calendarGroups,
        calendarError:       calendarError       ?? this.calendarError,
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

    BriefingWeatherModel? originWeather;
    BriefingWeatherModel? destinationWeather;
    String? weatherError;
    List<BriefingCalendarGroup> calendarGroups = const [];
    String? calendarError;

    // 모든 API를 한 번에 병렬 호출 — 순차 대기 제거로 로딩 시간 단축
    await Future.wait([
      () async { try { weather = await _repository.getWeatherAirQuality(); } catch (_) {} }(),
      () async { try { issues = await _repository.getTodayIssues(); } catch (_) {} }(),
      () async { try { meetingRoute = await _repository.getMeetingRoute(); } catch (_) {} }(),
      if (_userId != null)
        () async { try { aiSummary = await _repository.getAiSummary(_userId!); } catch (_) {} }(),
      () async {
        try {
          originWeather = await _repository.getOriginWeather();
        } catch (e, st) {
          weatherError = '날씨 정보를 불러오지 못했어요.';
          debugPrint('[OriginWeather] ERROR: $e');
          debugPrint('[OriginWeather] STACK: $st');
        }
      }(),
      () async {
        try {
          destinationWeather = await _repository.getDestinationWeather();
        } catch (e, st) {
          weatherError ??= '날씨 정보를 불러오지 못했어요.';
          debugPrint('[DestinationWeather] ERROR: $e');
          debugPrint('[DestinationWeather] STACK: $st');
        }
      }(),
      () async {
        try {
          final v = await _repository.getBriefingCalendar();
          calendarGroups = v;
          debugPrint('[BriefingCalendar] success: ${v.length} groups, '
              '${v.expand((g) => g.items).length} events');
        } catch (e, st) {
          calendarError = '일정을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
          debugPrint('[BriefingCalendar] ERROR: $e');
          debugPrint('[BriefingCalendar] STACK: $st');
        }
      }(),
    ]);

    state = BriefingState(
      weather:            weather,
      issues:             issues,
      scheduleItems:      scheduleItems,
      meetingRoute:       meetingRoute,
      aiSummary:          aiSummary,
      originWeather:      originWeather,
      destinationWeather: destinationWeather,
      weatherError:       weatherError,
      calendarGroups:     calendarGroups,
      calendarError:      calendarError,
    );
  }
}