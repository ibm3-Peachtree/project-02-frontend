import 'route_model.dart';

// GET /me/routines 목록 및 GET /me/routines/{id} 상세 응답
class RoutineModel {
  final int routineId;
  final String routineName;
  final String departureAddressName;
  final String arrivalAddressName;
  final String targetArrivalTime;        // "HH:mm"
  final String recommendedDepartureTime; // "HH:mm"
  final int estimatedDuration;           // 분
  final int spareTime;                   // 여유 시간 (분)
  final bool skipHoliday;                // 공휴일 제외 여부
  final List<String> days;               // ["MON","TUE",...]
  final bool isActive;
  final RouteModel? route;               // 상세 조회 시에만 포함 (RoutineDetailDto.route)
  /// preActive 지도 경로 폴리라인용 XY 좌표 (RoutineDetailDto.routeXy)
  final List<RouteXYModel> routeXy;

  const RoutineModel({
    required this.routineId,
    required this.routineName,
    required this.departureAddressName,
    required this.arrivalAddressName,
    required this.targetArrivalTime,
    required this.recommendedDepartureTime,
    required this.estimatedDuration,
    this.spareTime = 15,
    this.skipHoliday = false,
    required this.days,
    this.isActive = true,
    this.route,
    this.routeXy = const [],
  });

  factory RoutineModel.fromJson(Map<String, dynamic> json) {
    // ── 디버그: 공휴일·여유시간 필드 확인 ──────────────────────────────
    assert(() {
      final hasExclude = json.containsKey('excludeHoliday');
      final hasSkip = json.containsKey('skipHoliday');
      final hasSpare = json.containsKey('spareTime');
      if (!hasExclude && !hasSkip) {
        // ignore: avoid_print
        print('[RoutineModel] ⚠️ 응답에 excludeHoliday/skipHoliday 필드 없음 — 서버 DTO 확인 필요. json keys: ${json.keys.toList()}');
      }
      if (!hasSpare) {
        // ignore: avoid_print
        print('[RoutineModel] ⚠️ 응답에 spareTime 필드 없음 — 서버 DTO 확인 필요.');
      }
      return true;
    }());
    return RoutineModel(
        routineId: (json['routineId'] as num).toInt(),
        routineName: json['routineName'] as String,
        departureAddressName: json['originAlias'] as String? ??
            json['departureAddressName'] as String? ?? '',
        arrivalAddressName: json['destinationAlias'] as String? ??
            json['arrivalAddressName'] as String? ?? '',
        targetArrivalTime: _formatTime(json['targetArrivalTime']),
        recommendedDepartureTime: json['recommendedDepartureTime'] != null
            ? _formatTime(json['recommendedDepartureTime'])
            : '--:--',
        estimatedDuration:
            (json['estimatedDuration'] ?? json['estimateDuration'] ?? 0) is int
                ? (json['estimatedDuration'] ?? json['estimateDuration'] ?? 0) as int
                : ((json['estimatedDuration'] ?? json['estimateDuration'] ?? 0) as num).toInt(),
        spareTime: (json['spareTime'] as num?)?.toInt() ?? 15,
        skipHoliday: _parseBool(json['excludeHoliday'] ?? json['skipHoliday']),
        days: json['dow'] != null
            ? _dowToDays((json['dow'] as List<dynamic>))
            : ((json['days'] as List<dynamic>?)?.cast<String>() ?? const []),
        isActive: json['isActive'] as bool? ?? true,
        route: json['route'] != null
            ? RouteModel.fromJson(json['route'] as Map<String, dynamic>)
            : null,
        // 백엔드 RoutineDetailDto.routeXy 파싱
        routeXy: (json['routeXy'] as List<dynamic>?)
                ?.map((e) => RouteXYModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
  }

  static String _formatTime(dynamic value) {
    final raw = value.toString();
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  /// bit(1) → int(1/0), bool(true/false), String("1"/"true") 모두 처리
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  static List<String> _dowToDays(List<dynamic> dow) {
    const keys = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final days = <String>[];
    for (var i = 0; i < dow.length && i < keys.length; i++) {
      if (_parseBool(dow[i])) days.add(keys[i]);
    }
    return days;
  }

  Map<String, dynamic> toJson() => {
        'routineId': routineId,
        'routineName': routineName,
        'departureAddressName': departureAddressName,
        'arrivalAddressName': arrivalAddressName,
        'targetArrivalTime': targetArrivalTime,
        'recommendedDepartureTime': recommendedDepartureTime,
        'estimatedDuration': estimatedDuration,
        'spareTime': spareTime,
        'excludeHoliday': skipHoliday,
        'days': days,
        'isActive': isActive,
      };

  static const dayLabels = {
    'MON': '월', 'TUE': '화', 'WED': '수',
    'THU': '목', 'FRI': '금', 'SAT': '토', 'SUN': '일',
  };

  List<String> get dayLabelsKo =>
      days.map((d) => dayLabels[d] ?? d).toList();
}