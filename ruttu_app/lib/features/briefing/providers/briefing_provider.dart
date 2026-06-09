import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/weather_model.dart';
import '../../../data/models/route_model.dart';
import '../../../data/repositories/briefing_repository.dart' show BriefingRepository, ApiBriefingRepository, GeminiSuppliesModel, AiSummaryModel, ScheduleItemModel;
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
  // 준비물 API 결과 (GET /me/briefing/supplies)
  final GeminiSuppliesModel? suppliesResult;
  final String? suppliesError;
  // 오늘의 브리핑 요약 (POST /me/briefing/summary)
  final String? todayBriefing;

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
    this.suppliesResult,
    this.suppliesError,
    this.todayBriefing,
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
    GeminiSuppliesModel? suppliesResult,
    String? suppliesError,
    String? todayBriefing,
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
        suppliesResult:      suppliesResult      ?? this.suppliesResult,
        suppliesError:       suppliesError       ?? this.suppliesError,
        todayBriefing:       todayBriefing       ?? this.todayBriefing,
      );
}

final briefingProvider =
    StateNotifierProvider<BriefingNotifier, BriefingState>(
  (ref) => BriefingNotifier(ref.read(briefingRepositoryProvider)),
);

class BriefingNotifier extends StateNotifier<BriefingState> {
  final BriefingRepository _repository;

  BriefingNotifier(this._repository) : super(const BriefingState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);

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
    GeminiSuppliesModel? suppliesResult;
    String? suppliesError;

    // 날씨·준비물·일정을 병렬로 먼저 가져옴
    await Future.wait([
      () async { try { weather = await _repository.getWeatherAirQuality(); } catch (_) {} }(),
      () async { try { issues = await _repository.getTodayIssues(); } catch (_) {} }(),
      () async { try { meetingRoute = await _repository.getMeetingRoute(); } catch (_) {} }(),
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
      () async {
        try {
          suppliesResult = await _repository.getSupplies();
        } catch (e, st) {
          suppliesError = '준비물 정보를 불러오지 못했어요.';
          debugPrint('[Supplies] ERROR: $e');
          debugPrint('[Supplies] STACK: $st');
        }
      }(),
    ]);

    // 날씨·준비물·일정 데이터를 String으로 조합해 POST → AI 요약 수신
    String? todayBriefing;
    try {
      final contents = _buildSummaryContents(
        originWeather:      originWeather,
        destinationWeather: destinationWeather,
        supplies:           suppliesResult,
        calendarGroups:     calendarGroups,
      );
      if (contents.isNotEmpty) {
        todayBriefing = await _repository.getTodayBriefing(contents);
        debugPrint('[TodayBriefing] result length: ${todayBriefing?.length}');
      }
    } catch (e, st) {
      debugPrint('[TodayBriefing] ERROR: $e');
      debugPrint('[TodayBriefing] STACK: $st');
    }

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
      suppliesResult:     suppliesResult,
      suppliesError:      suppliesError,
      todayBriefing:      todayBriefing,
    );
  }

  /// 날씨·준비물·일정을 백엔드가 요약할 수 있는 자연어 String으로 조합
  String _buildSummaryContents({
    required BriefingWeatherModel? originWeather,
    required BriefingWeatherModel? destinationWeather,
    required GeminiSuppliesModel? supplies,
    required List<BriefingCalendarGroup> calendarGroups,
  }) {
    final buf = StringBuffer();

    if (originWeather != null) {
      buf.writeln('[출발지 날씨]');
      buf.writeln('위치: ${originWeather.locationName}');
      buf.writeln('현재 기온: ${originWeather.tmp.toStringAsFixed(0)}°C '
          '(최저 ${originWeather.minTemp.toStringAsFixed(0)}°C / '
          '최고 ${originWeather.maxTemp.toStringAsFixed(0)}°C)');
      buf.writeln('날씨: ${originWeather.sky}');
      if (originWeather.pm10.isNotEmpty)
        buf.writeln('미세먼지: ${originWeather.pm10}');
      if (originWeather.pm25.isNotEmpty)
        buf.writeln('초미세먼지: ${originWeather.pm25}');
    }

    if (destinationWeather != null) {
      buf.writeln('[도착지 날씨]');
      buf.writeln('위치: ${destinationWeather.locationName}');
      buf.writeln('현재 기온: ${destinationWeather.tmp.toStringAsFixed(0)}°C');
      buf.writeln('날씨: ${destinationWeather.sky}');
    }

    if (supplies != null) {
      buf.writeln('[오늘의 준비물]');
      if (supplies.clothes.isNotEmpty) buf.writeln('옷차림: ${supplies.clothes}');
      if (supplies.supplies.isNotEmpty) buf.writeln('챙길 것: ${supplies.supplies}');
    }

    final allEvents = calendarGroups.expand((g) => g.items).toList()
      ..sort((a, b) => (a.start?.value ?? 0).compareTo(b.start?.value ?? 0));

    if (allEvents.isNotEmpty) {
      buf.writeln('[오늘의 일정]');
      for (final e in allEvents) {
        final time = e.startTimeLabel;
        buf.write('$time ${e.summary}');
        if (e.location != null && e.location!.isNotEmpty) {
          buf.write(' (${e.location})');
        }
        buf.writeln();
      }
    }

    return buf.toString().trim();
  }
}