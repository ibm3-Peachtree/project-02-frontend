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
  final List<String> days;               // ["MON","TUE",...]
  final bool isActive;
  final RouteModel? route;               // 상세 조회 시에만 포함 (RoutineDetailDto.route)

  const RoutineModel({
    required this.routineId,
    required this.routineName,
    required this.departureAddressName,
    required this.arrivalAddressName,
    required this.targetArrivalTime,
    required this.recommendedDepartureTime,
    required this.estimatedDuration,
    required this.days,
    this.isActive = true,
    this.route,
  });

  factory RoutineModel.fromJson(Map<String, dynamic> json) => RoutineModel(
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
        days: json['dow'] != null
            ? _dowToDays((json['dow'] as List<dynamic>))
            : ((json['days'] as List<dynamic>?)?.cast<String>() ?? const []),
        isActive: json['isActive'] as bool? ?? true,
        route: json['route'] != null
            ? RouteModel.fromJson(json['route'] as Map<String, dynamic>)
            : null,
      );

  static String _formatTime(dynamic value) {
    final raw = value.toString();
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  static List<String> _dowToDays(List<dynamic> dow) {
    const keys = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final days = <String>[];
    for (var i = 0; i < dow.length && i < keys.length; i++) {
      if (dow[i] == true) days.add(keys[i]);
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