// GET /routines 목록 응답
class RoutineModel {
  final int routineId;
  final String routineName;
  final String departureAddressName;
  final String arrivalAddressName;
  final String targetArrivalTime;       // "HH:mm"
  final String recommendedDepartureTime; // "HH:mm"
  final int estimatedDuration;           // 분 (명세 오타: estimateDuration/estimatedDuration 혼용)
  final List<String> days;               // ["MON","TUE",...]
  final bool isActive;

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
  });

  factory RoutineModel.fromJson(Map<String, dynamic> json) => RoutineModel(
        routineId: json['routineId'] as int,
        routineName: json['routineName'] as String,
        departureAddressName: json['departureAddressName'] as String,
        arrivalAddressName: json['arrivalAddressName'] as String,
        targetArrivalTime: json['targetArrivalTime'] as String,
        recommendedDepartureTime: json['recommendedDepartureTime'] as String,
        // 명세 오타 혼용 — 둘 다 허용
        estimatedDuration: (json['estimatedDuration'] ?? json['estimateDuration'] ?? 0) as int,
        days: (json['days'] as List<dynamic>).cast<String>(),
        isActive: json['isActive'] as bool? ?? true,
      );

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
