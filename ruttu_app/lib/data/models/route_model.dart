// GET /me/routines/active/route  &  /me/routes/active/reco 응답

// type: "walk" | "bus" | "subway"  (백엔드 RouteSectionDto.type)

/// 단일 구간 — walk / bus / subway 공통
class PathModel {
  final String type;         // "walk" | "bus" | "subway"
  final int sectionTime;     // 분
  final List<String> no;     // 버스 번호 or 지하철 노선 번호 목록
  final String? start;       // 승차 정류장/역
  final String? end;         // 하차 정류장/역
  final int? stationCount;
  final List<String> stationName; // 경유 정류장/역 목록
  final String? way;         // 지하철 방향 (SubwaySectionDto.way)

  const PathModel({
    required this.type,
    required this.sectionTime,
    this.no = const [],
    this.start,
    this.end,
    this.stationCount,
    this.stationName = const [],
    this.way,
  });

  bool get isWalking => type == 'walk';
  bool get isSubway  => type == 'subway';
  bool get isBus     => type == 'bus';

  String get typeLabel {
    if (isWalking) return '도보';
    if (isSubway)  return '지하철';
    return '버스';
  }

  factory PathModel.fromJson(Map<String, dynamic> json) => PathModel(
        type:         json['type']         as String,
        sectionTime:  json['sectionTime']  as int,
        no:           (json['no'] as List<dynamic>?)?.cast<String>() ?? const [],
        start:        json['start']        as String?,
        end:          json['end']          as String?,
        stationCount: json['stationCount'] as int?,
        stationName:  (json['stationName'] as List<dynamic>?)?.cast<String>() ?? const [],
        way:          json['way']          as String?,
      );

  Map<String, dynamic> toJson() => {
        'type':         type,
        'sectionTime':  sectionTime,
        'no':           no,
        'start':        start,
        'end':          end,
        'stationCount': stationCount,
        'stationName':  stationName,
        'way':          way,
      };
}

/// GET /me/routines/active/route  &  /me/routes/active/reco 응답 (RouteDto)
class RouteModel {
  final int recoId;
  final int totalDistance; // 미터
  final int totalTime;     // 분
  final int payment;       // 원
  final String? startName;
  final String? endName;
  final List<PathModel> path;

  const RouteModel({
    required this.recoId,
    required this.totalDistance,
    required this.totalTime,
    required this.payment,
    this.startName,
    this.endName,
    required this.path,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    // searchRoutes 응답(RouteListDto): path 대신 trafficType 배열로 내려옴
    // e.g. { "recoId": 1, "totalTime": 45, "payment": 1650,
    //        "trafficType": ["walk", "bus:360", "subway:2", "walk"] }
    if (json['trafficType'] is List) {
      return RouteModel._fromListDto(json);
    }

    return RouteModel(
      recoId:        (json['recoId'] as num).toInt(),
      totalDistance: json['totalDistance'] as int? ?? 0,
      totalTime:     json['totalTime']     as int,
      payment:       json['payment']       as int,
      startName:     json['startName']     as String?,
      endName:       json['endName']       as String?,
      path: (json['path'] as List<dynamic>?)
              ?.map((e) => PathModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// searchRoutes 응답 — trafficType 배열로 경로 구성
  factory RouteModel._fromListDto(Map<String, dynamic> json) {
    final types = (json['trafficType'] as List<dynamic>).cast<String>();
    return RouteModel(
      recoId:        (json['recoId'] as num).toInt(),
      totalDistance: 0,
      totalTime:     json['totalTime'] as int,
      payment:       json['payment']   as int,
      path:          types.map(_pathFromType).toList(),
    );
  }

  static PathModel _pathFromType(String type) {
    if (type == 'walk') {
      return const PathModel(type: 'walk', sectionTime: 0);
    }
    if (type.startsWith('bus:')) {
      return PathModel(
        type: 'bus',
        sectionTime: 0,
        no: [type.substring(4)],
      );
    }
    if (type.startsWith('subway:')) {
      return PathModel(
        type: 'subway',
        sectionTime: 0,
        no: [type.substring(7)],
      );
    }
    return const PathModel(type: 'walk', sectionTime: 0);
  }

  Map<String, dynamic> toJson() => {
        'recoId':        recoId,
        'totalDistance': totalDistance,
        'totalTime':     totalTime,
        'payment':       payment,
        'startName':     startName,
        'endName':       endName,
        'path':          path.map((e) => e.toJson()).toList(),
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