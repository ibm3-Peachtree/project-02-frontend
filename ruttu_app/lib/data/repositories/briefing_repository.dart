import '../models/weather_model.dart';
import '../models/route_model.dart';

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

abstract class BriefingRepository {
  Future<WeatherAirQualityModel> getWeatherAirQuality();
  Future<List<IssueModel>> getTodayIssues();
  Future<AiSummaryModel?> getAiSummary(int userId);
  Future<List<ScheduleItemModel>> getScheduleItems();
  Future<RouteModel?> getMeetingRoute();
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