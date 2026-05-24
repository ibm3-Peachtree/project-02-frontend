// GET /me/routines/active/route  &  /me/routes/active/reco 응답

// trafficType: 1=지하철, 2=버스, 3=도보
// pathType: 1=지하철, 2=버스, 3=버스+지하철
// wayCode: 1=상행, 2=하행

class PathModel {
  final int trafficType;     // 1=지하철, 2=버스, 3=도보
  final int distance;
  final int sectionTime;     // 분
  final int? stationCount;
  final int? subwayCode;
  final int? busNo;
  final String? startName;
  final String? endName;
  final String? way;
  final int? wayCode;        // 1=상행, 2=하행
  final String? door;
  final List<String> passStopList;

  const PathModel({
    required this.trafficType,
    required this.distance,
    required this.sectionTime,
    this.stationCount,
    this.subwayCode,
    this.busNo,
    this.startName,
    this.endName,
    this.way,
    this.wayCode,
    this.door,
    this.passStopList = const [],
  });

  bool get isWalking  => trafficType == 3;
  bool get isSubway   => trafficType == 1;
  bool get isBus      => trafficType == 2;

  String get typeLabel {
    if (isWalking) return '도보';
    if (isSubway)  return '지하철';
    return '버스';
  }

  factory PathModel.fromJson(Map<String, dynamic> json) => PathModel(
        trafficType:  json['trafficType']  as int,
        distance:     json['distance']     as int,
        sectionTime:  json['sectionTime']  as int,
        stationCount: json['stationCount'] as int?,
        subwayCode:   json['subwayCode']   as int?,
        busNo:        json['busNo']        as int?,
        startName:    json['startName']    as String?,
        endName:      json['endName']      as String?,
        way:          json['way']          as String?,
        wayCode:      json['wayCode']      as int?,
        door:         json['door']         as String?,
        passStopList: (json['passStopList'] as List<dynamic>?)
                ?.cast<String>() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'trafficType': trafficType,
        'distance': distance,
        'sectionTime': sectionTime,
        'stationCount': stationCount,
        'subwayCode': subwayCode,
        'busNo': busNo,
        'startName': startName,
        'endName': endName,
        'way': way,
        'wayCode': wayCode,
        'door': door,
        'passStopList': passStopList,
      };
}

class RouteModel {
  final int pathType;        // 1=지하철, 2=버스, 3=버스+지하철
  final int totalDistance;   // 미터
  final int trafficDistance;
  final int totalWalk;       // 미터
  final int totalTime;       // 분
  final int payment;         // 원
  final List<PathModel> path;

  const RouteModel({
    required this.pathType,
    required this.totalDistance,
    required this.trafficDistance,
    required this.totalWalk,
    required this.totalTime,
    required this.payment,
    required this.path,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) => RouteModel(
        pathType:        json['pathType']        as int,
        totalDistance:   json['totalDistance']   as int,
        trafficDistance: json['trafficDistance'] as int,
        totalWalk:       json['totalWalk']       as int,
        totalTime:       json['totalTime']       as int,
        payment:         json['payment']         as int,
        path: (json['path'] as List<dynamic>)
            .map((e) => PathModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'pathType': pathType,
        'totalDistance': totalDistance,
        'trafficDistance': trafficDistance,
        'totalWalk': totalWalk,
        'totalTime': totalTime,
        'payment': payment,
        'path': path.map((e) => e.toJson()).toList(),
      };
}

// GET /me/routines/active/status 응답
class LiveStatusModel {
  final String status;   // "도보 중" | "대기 중" | "탑승 중"
  final int updatedAt;   // Unix timestamp (Long)

  const LiveStatusModel({required this.status, required this.updatedAt});

  factory LiveStatusModel.fromJson(Map<String, dynamic> json) =>
      LiveStatusModel(
        status:    json['status']    as String,
        updatedAt: json['updatedAt'] as int,
      );
}

// GET /me/issues 응답 항목
class IssueModel {
  final String location;
  final String description;
  final String startDateTime;
  final String endDateTime;
  final bool isFullClosure;

  const IssueModel({
    required this.location,
    required this.description,
    required this.startDateTime,
    required this.endDateTime,
    required this.isFullClosure,
  });

  factory IssueModel.fromJson(Map<String, dynamic> json) => IssueModel(
        location:      json['location']      as String,
        description:   json['description']   as String,
        startDateTime: json['startDateTime'] as String,
        endDateTime:   json['endDateTime']   as String,
        isFullClosure: json['isFullClosure'] as bool,
      );
}
