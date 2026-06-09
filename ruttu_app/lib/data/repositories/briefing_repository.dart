import 'package:flutter/foundation.dart';
import '../models/weather_model.dart';
import '../models/route_model.dart';
import 'package:dio/dio.dart';
import 'package:ruttu_app/core/constants/api_constants.dart';

// GET /{user_id} AI 요약
class AiSummaryModel {
  final String date;
  final String summary;

  const AiSummaryModel({required this.date, required this.summary});

  factory AiSummaryModel.fromJson(Map<String, dynamic> json) => AiSummaryModel(
        date:    json['date']    as String,
        summary: json['summary'] as String,
      );
}

// Google Calendar 일정 항목
class ScheduleItemModel {
  final String time;     // "10:00"
  final String title;
  final String? location;
  final bool hasMeetingRoute; // 미팅 경로 카드 표시 여부

  const ScheduleItemModel({
    required this.time,
    required this.title,
    this.location,
    this.hasMeetingRoute = false,
  });
}

// GET /me/briefing/supplies → GeminiSuppliesResultDto
class GeminiSuppliesModel {
  final String clothes;
  final String supplies;

  const GeminiSuppliesModel({required this.clothes, required this.supplies});

  factory GeminiSuppliesModel.fromJson(Map<String, dynamic> json) =>
      GeminiSuppliesModel(
        clothes:  (json['clothes']  ?? '').toString(),
        supplies: (json['supplies'] ?? '').toString(),
      );
}

abstract class BriefingRepository {
  Future<WeatherAirQualityModel> getWeatherAirQuality();
  Future<List<IssueModel>> getTodayIssues();
  Future<AiSummaryModel?> getAiSummary(int userId);
  Future<List<ScheduleItemModel>> getScheduleItems();
  Future<RouteModel?> getMeetingRoute();
  /// @deprecated — use getOriginWeather / getDestinationWeather
  Future<BriefingWeatherModel?> getBriefingWeather();
  Future<BriefingWeatherModel?> getOriginWeather();
  Future<BriefingWeatherModel?> getDestinationWeather();
  Future<List<BriefingCalendarGroup>> getBriefingCalendar();
  Future<GeminiSuppliesModel?> getSupplies();
  /// 날씨·준비물·일정을 String으로 조합해 POST → AI 요약 텍스트 반환
  Future<String?> getTodayBriefing(String contents);
}
// ── 실제 API 구현체 ──────────────────────────────────────────────────────────

class ApiBriefingRepository implements BriefingRepository {
  final Dio _dio;
  ApiBriefingRepository(this._dio);

  @override
  Future<WeatherAirQualityModel> getWeatherAirQuality() =>
      MockBriefingRepository().getWeatherAirQuality();

  @override
  Future<List<IssueModel>> getTodayIssues() =>
      MockBriefingRepository().getTodayIssues();

  @override
  Future<AiSummaryModel?> getAiSummary(int userId) =>
      MockBriefingRepository().getAiSummary(userId);

  @override
  Future<RouteModel?> getMeetingRoute() =>
      MockBriefingRepository().getMeetingRoute();

  // ── 새 API ──────────────────────────────────────────────

  /// @deprecated
  @override
  Future<BriefingWeatherModel?> getBriefingWeather() => getOriginWeather();

  @override
  Future<BriefingWeatherModel?> getOriginWeather() =>
      _fetchWeather(ApiConstants.briefingWeatherOrigin);

  @override
  Future<BriefingWeatherModel?> getDestinationWeather() =>
      _fetchWeather(ApiConstants.briefingWeatherDestination);

  Future<BriefingWeatherModel?> _fetchWeather(String path) async {
    try {
      final res = await _dio.get(path);
      if (res.statusCode == 204) return null;
      if (res.data == null || res.data is! Map<String, dynamic>) return null;
      return BriefingWeatherModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) return null;
      rethrow;
    }
  }

  @override
  Future<List<BriefingCalendarGroup>> getBriefingCalendar() async {
    debugPrint('[BriefingRepo] GET ${ApiConstants.briefingCalendar}');
    final res = await _dio.get(ApiConstants.briefingCalendar);
    debugPrint('[BriefingRepo] calendar raw: ${res.data}');
    final list = res.data as List<dynamic>;
    final groups = list
        .map((e) => BriefingCalendarGroup.fromJson(e as Map<String, dynamic>))
        .toList();
    debugPrint('[BriefingRepo] parsed ${groups.length} groups, '
        '${groups.expand((g) => g.items).length} events');
    return groups;
  }

  @override
  Future<GeminiSuppliesModel?> getSupplies() async {
    try {
      final res = await _dio.get(ApiConstants.briefingSupplies);
      if (res.statusCode == 204 || res.data == null) return null;
      return GeminiSuppliesModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('[BriefingRepo] getSupplies error: $e');
      if (e.response?.statusCode == 409) return null;
      rethrow;
    }
  }

  @override
  Future<String?> getTodayBriefing(String contents) async {
    try {
      final res = await _dio.post(
        ApiConstants.briefingSummary,
        data: contents,
        options: Options(headers: {'Content-Type': 'text/plain; charset=utf-8'}),
      );
      if (res.statusCode == 204 || res.data == null) return null;
      return res.data.toString();
    } on DioException catch (e) {
      debugPrint('[BriefingRepo] getTodayBriefing error: $e');
      return null;
    }
  }

  /// 스케줄 카드용: 모든 캘린더 그룹의 이벤트를 시간순으로 병합
  @override
  Future<List<ScheduleItemModel>> getScheduleItems() async {
    final groups = await getBriefingCalendar();
    final events = groups.expand((g) => g.items).toList()
      ..sort((a, b) {
        final av = a.start?.value ?? 0;
        final bv = b.start?.value ?? 0;
        return av.compareTo(bv);
      });
    return events
        .map((e) => ScheduleItemModel(
              time:     e.startTimeLabel,
              title:    e.summary,
              location: e.location,
            ))
        .toList();
  }
}
class MockBriefingRepository implements BriefingRepository {
  @override
  Future<WeatherAirQualityModel> getWeatherAirQuality() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return WeatherAirQualityModel(
      weather: [
        WeatherModel(
          dateTime: DateTime.now().toIso8601String(),
          tmp: 23, wsd: '2.5', sky: '1',
          pty: '0', pop: 10, pcp: '없음', reh: 45, sno: '없음',
        ),
        WeatherModel(
          dateTime: DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
          tmp: 27, wsd: '3.0', sky: '3',
          pty: '0', pop: 20, pcp: '없음', reh: 50, sno: '없음',
        ),
        WeatherModel(
          dateTime: DateTime.now().add(const Duration(hours: 6)).toIso8601String(),
          tmp: 18, wsd: '1.5', sky: '1',
          pty: '0', pop: 5, pcp: '없음', reh: 40, sno: '없음',
        ),
      ],
      airQuality: AirQualityModel(
        pm10: const AirQualityRegionModel(seoul: '좋음', gyeonggi: '좋음'),
        pm25: const AirQualityRegionModel(seoul: '보통', gyeonggi: '좋음'),
      ),
    );
  }

  @override
  Future<List<IssueModel>> getTodayIssues() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      IssueModel(
        location: '2호선 강남~역삼 구간',
        description: '신호 장애로 인한 지연 운행',
        startDateTime: DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        endDateTime: DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
        isFullClosure: false,
      ),
    ];
  }

  @override
  Future<AiSummaryModel?> getAiSummary(int userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return AiSummaryModel(
      date: DateTime.now().toIso8601String(),
      summary: '오늘은 맑은 날씨가 예상됩니다. 2호선 강남 구간에 지연이 있으니 10분 일찍 출발하시는 것을 권장해요. 미세먼지는 서울 기준 좋음이며, 저녁에는 기온이 낮아질 예정이니 겉옷을 챙기세요.',
    );
  }

  @override
  Future<List<ScheduleItemModel>> getScheduleItems() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const [
      ScheduleItemModel(
        time: '10:00',
        title: '팀 스프린트 미팅',
        location: '을지로 본사 6층 회의실',
        hasMeetingRoute: true,
      ),
      ScheduleItemModel(
        time: '13:00',
        title: '점심 약속',
        location: '강남 파스타 레스토랑',
      ),
      ScheduleItemModel(
        time: '17:00',
        title: '코드 리뷰',
        location: '화상 미팅 (Zoom)',
      ),
    ];
  }

  @override
  Future<BriefingWeatherModel?> getBriefingWeather() async {
    throw UnimplementedError('Use ApiBriefingRepository for real data');
  }

  @override
  Future<BriefingWeatherModel?> getOriginWeather() async {
    throw UnimplementedError('Use ApiBriefingRepository for real data');
  }

  @override
  Future<BriefingWeatherModel?> getDestinationWeather() async {
    throw UnimplementedError('Use ApiBriefingRepository for real data');
  }

  @override
  Future<List<BriefingCalendarGroup>> getBriefingCalendar() async {
    throw UnimplementedError('Use ApiBriefingRepository for real data');
  }

  @override
  Future<GeminiSuppliesModel?> getSupplies() async {
    throw UnimplementedError('Use ApiBriefingRepository for real data');
  }

  @override
  Future<String?> getTodayBriefing(String contents) async {
    throw UnimplementedError('Use ApiBriefingRepository for real data');
  }

  @override
  Future<RouteModel?> getMeetingRoute() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return RouteModel(
      recoId: 99,
      totalDistance: 12260,
      totalTime: 39,
      payment: 1650,
      startName: '회사',
      endName: '을지로 본사',
      path: const [
        PathModel(
          type: 'walk',
          sectionTime: 4,
          start: '회사',
          end: '강남역',
        ),
        PathModel(
          type: 'subway',
          sectionTime: 28,
          no: ['2'],
          stationCount: 9,
          start: '강남',
          end: '을지로입구',
          way: '성수방향',
          stationName: ['강남', '역삼', '선릉', '삼성', '종합운동장', '잠실새내', '잠실', '신천', '강변'],
        ),
        PathModel(
          type: 'walk',
          sectionTime: 5,
          start: '을지로입구역',
          end: '을지로 본사',
        ),
      ],
    );
  }
}