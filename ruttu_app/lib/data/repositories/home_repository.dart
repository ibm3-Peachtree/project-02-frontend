import '../models/routine_model.dart';
import '../models/route_model.dart';
import '../models/weather_model.dart';

abstract class HomeRepository {
  Future<List<RoutineModel>> getRoutines();
  Future<LiveStatusModel> getLiveStatus();
  Future<RouteModel> getMyRoute();
  Future<RouteModel> getRecommendedRoute();
  Future<List<IssueModel>> getTodayIssues();
  Future<WeatherAirQualityModel> getWeatherAirQuality();
}

class MockHomeRepository implements HomeRepository {
  @override
  Future<List<RoutineModel>> getRoutines() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      RoutineModel(
        routineId: 1,
        routineName: '수원 → 여의도 출근',
        departureAddressName: '집',
        arrivalAddressName: '회사',
        targetArrivalTime: '09:00',
        recommendedDepartureTime: '07:37',
        estimatedDuration: 83,
        days: ['MON', 'TUE', 'WED', 'THU', 'FRI'],
        isActive: true,
      ),
    ];
  }

  @override
  Future<LiveStatusModel> getLiveStatus() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const LiveStatusModel(status: '도보 중', updatedAt: 0);
  }

  @override
  Future<RouteModel> getMyRoute() async {
    await Future.delayed(const Duration(milliseconds: 500));
    // 수원 → 여의도 (버스 + 2호선 + 9호선, 환승 2회, 총 83분)
    return RouteModel(
      pathType: 3,
      totalDistance: 41200,
      trafficDistance: 38870,
      totalWalk: 1330,
      totalTime: 83,
      payment: 2500,
      path: [
        // 구간 1: 도보 — 자택 → 버스 정류장
        const PathModel(
          trafficType: 3,
          distance: 350,
          sectionTime: 5,
          startName: '수원시 팔달구 자택',
          endName: '수원역 버스 정류장',
        ),
        // 구간 2: 버스 7770 — 수원역 → 사당역 (환승 전)
        PathModel(
          trafficType: 2,
          distance: 24800,
          sectionTime: 35,
          busNo: 7770,
          stationCount: 12,
          startName: '수원역 버스터미널',
          endName: '사당역 버스 정류장',
          passStopList: const [
            '수원역', '매탄동', '화서역', '안양역', '명학역',
            '금정역', '산본역', '수리산역', '안양1번가', '이수역',
            '총신대입구역', '사당역',
          ],
        ),
        // 구간 3: 도보 — 사당역 버스 → 사당역 지하철 (환승 1)
        const PathModel(
          trafficType: 3,
          distance: 280,
          sectionTime: 4,
          startName: '사당역 버스 정류장',
          endName: '사당역 2호선 승강장',
        ),
        // 구간 4: 지하철 2호선 — 사당역 → 당산역
        PathModel(
          trafficType: 1,
          distance: 13200,
          sectionTime: 18,
          subwayCode: 2,
          stationCount: 6,
          startName: '사당역',
          endName: '당산역',
          way: '성수 방향',
          wayCode: 1,
          door: '왼쪽',
          passStopList: const [
            '사당역', '방배역', '서초역', '교대역',
            '강남역', '역삼역', '선릉역', '당산역',
          ],
        ),
        // 구간 5: 도보 — 당산역 2호선 → 당산역 9호선 (환승 2)
        const PathModel(
          trafficType: 3,
          distance: 200,
          sectionTime: 3,
          startName: '당산역 2호선 승강장',
          endName: '당산역 9호선 승강장',
        ),
        // 구간 6: 지하철 9호선 — 당산역 → 여의도역
        PathModel(
          trafficType: 1,
          distance: 4200,
          sectionTime: 8,
          subwayCode: 9,
          stationCount: 2,
          startName: '당산역',
          endName: '여의도역',
          way: '김포공항 방향',
          wayCode: 2,
          door: '오른쪽',
          passStopList: const ['당산역', '국회의사당역', '여의도역'],
        ),
        // 구간 7: 도보 — 여의도역 → 회사
        const PathModel(
          trafficType: 3,
          distance: 700,
          sectionTime: 10,
          startName: '여의도역',
          endName: '여의도 회사',
        ),
      ],
    );
  }

  @override
  Future<RouteModel> getRecommendedRoute() async {
    await Future.delayed(const Duration(milliseconds: 500));
    // 대안 경로: 수원역 → 1호선(급행) → 서울역 → 9호선 → 여의도 (환승 1회, 70분)
    return RouteModel(
      pathType: 3,
      totalDistance: 38500,
      trafficDistance: 37050,
      totalWalk: 1450,
      totalTime: 70,
      payment: 2800,
      path: [
        const PathModel(
          trafficType: 3,
          distance: 350,
          sectionTime: 5,
          startName: '수원시 팔달구 자택',
          endName: '수원역 지하철 1호선',
        ),
        PathModel(
          trafficType: 1,
          distance: 29500,
          sectionTime: 42,
          subwayCode: 1,
          stationCount: 11,
          startName: '수원역',
          endName: '노량진역',
          way: '서울역 방향',
          wayCode: 1,
          door: '오른쪽',
          passStopList: const [
            '수원역', '세류역', '병점역', '서동탄역', '오산역',
            '오산대역', '진위역', '송탄역', '서정리역', '평택역',
            '지제역', '천안역',
          ],
        ),
        const PathModel(
          trafficType: 3,
          distance: 400,
          sectionTime: 6,
          startName: '노량진역 1호선',
          endName: '노량진역 9호선 승강장',
        ),
        PathModel(
          trafficType: 1,
          distance: 3900,
          sectionTime: 10,
          subwayCode: 9,
          stationCount: 3,
          startName: '노량진역',
          endName: '여의도역',
          way: '김포공항 방향',
          wayCode: 2,
          door: '오른쪽',
          passStopList: const ['노량진역', '샛강역', '여의도역'],
        ),
        const PathModel(
          trafficType: 3,
          distance: 700,
          sectionTime: 7,
          startName: '여의도역',
          endName: '여의도 회사',
        ),
      ],
    );
  }

  @override
  Future<List<IssueModel>> getTodayIssues() async {
    return [];
  }

  @override
  Future<WeatherAirQualityModel> getWeatherAirQuality() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return WeatherAirQualityModel(
      weather: [
        WeatherModel(
          dateTime: DateTime.now().toIso8601String(),
          tmp: 23, wsd: '2.5', sky: '1',
          pty: '0', pop: 10, pcp: '없음', reh: 45, sno: '없음',
        ),
      ],
      airQuality: AirQualityModel(
        pm10: const AirQualityRegionModel(seoul: '좋음', gyeonggi: '좋음'),
        pm25: const AirQualityRegionModel(seoul: '좋음', gyeonggi: '좋음'),
      ),
    );
  }
}
