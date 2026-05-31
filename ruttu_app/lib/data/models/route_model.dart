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

  /// 화면에 표시할 정거장 수.
  /// stationCount(백엔드 값)가 있으면 우선 사용하고,
  /// 없으면 stationName 목록 길이에서 1을 뺀 값 사용
  /// (stationName에 start/end가 포함되어 있어 -1 처리).
  int get displayStationCount {
    if (stationCount != null && stationCount! > 0) return stationCount!;
    return (stationName.length - 1).clamp(0, 9999);
  }

  String get stationCountLabel => '${displayStationCount}정거장';

  String get typeLabel {
    if (isWalking) return '도보';
    if (isSubway)  return '지하철';
    return '버스';
  }

  /// 지하철 노선 번호(no)를 사람이 읽을 수 있는 이름으로 변환
  /// 백엔드가 내부 코드번호로 내려보낼 때 보정
  static const _subwayLineNames = <String, String>{
    '1': '1호선',
    '2': '2호선',
    '3': '3호선',
    '4': '4호선',
    '5': '5호선',
    '6': '6호선',
    '7': '7호선',
    '8': '8호선',
    '9': '9호선',
    '21': '인천1호선',
    '22': '인천2호선',
    '100': '경의중앙선',
    '101': '공항철도',
    '102': '자기부상',
    '103': '경춘선',
    '104': '수인분당선',
    '105': '신분당선',
    '106': '의정부경전철',
    '107': '에버라인',
    '108': '경강선',
    '109': '신분당선',   // 일부 API가 신분당선을 109로 반환
    '110': '우이신설선',
    '111': '서해선',
    '112': '김포골드라인',
    '113': '수도권9호선',
    '114': '신림선',
  };

  /// 노선명 정규화: 이미 "호선"/"선" 포함 시 그대로, 숫자 코드는 매핑 사용, 그 외 "N호선"
  static String _normalizeSubwayLine(String raw) {
    if (raw.contains('호선') || raw.contains('선')) return raw;
    if (_subwayLineNames.containsKey(raw)) return _subwayLineNames[raw]!;
    return '${raw}호선';
  }

  /// 지하철일 때 표시할 노선명 (예: "2호선", "수도권 1호선")
  /// ※ 백엔드가 이미 "수도권 1호선"처럼 전체 이름을 내려보내도 "호선" 중복 없음
  String get subwayLineName {
    if (!isSubway || no.isEmpty) return '지하철';
    return _normalizeSubwayLine(no.first);
  }

  /// 지하철일 때 모든 노선명 목록 (복수 노선 대비)
  List<String> get subwayLineNames =>
      isSubway ? no.map(_normalizeSubwayLine).toList() : const [];

  /// 버스 번호 전체 목록 (비어있는 항목 제외)
  List<String> get busNumbers =>
      isBus ? no.where((n) => n.isNotEmpty).toList() : const [];

  /// 버스 번호를 '·' 구분 문자열 — no 배열의 모든 항목 포함
  /// (예: "5535번 · 8551(출근맞춤버스)번 · 500번")
  String get busNumbersLabel =>
      busNumbers.map((n) => '${n}번').join(' · ');

  factory PathModel.fromJson(Map<String, dynamic> json) => PathModel(
        type:         (json['type']        as String?) ?? 'walk',
        sectionTime:  (json['sectionTime'] as num?)?.toInt() ?? 0,
        no:           (json['no'] as List<dynamic>?)?.cast<String>() ?? const [],
        start:        json['start']        as String?,
        end:          json['end']          as String?,
        stationCount: (json['stationCount'] as num?)?.toInt(),
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
      recoId:        (json['recoId'] as num?)?.toInt() ?? 0,
      totalDistance: (json['totalDistance'] as num?)?.toInt() ?? 0,
      totalTime:     (json['totalTime']     as num).toInt(),
      payment:       (json['payment']       as num).toInt(),
      startName:     json['startName']      as String?,
      endName:       json['endName']        as String?,
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
      recoId:        (json['recoId'] as num?)?.toInt() ?? 0,
      totalDistance: 0,
      totalTime:     (json['totalTime'] as num).toInt(),
      payment:       (json['payment']   as num).toInt(),
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

// GET /me/routines/active/status 응답 (CurrentLocationDto)
class LiveStatusModel {
  final String status;   // "대기중" | "도보중" | "탑승중"
  final int updatedAt;   // Unix timestamp millis (Long)

  const LiveStatusModel({required this.status, required this.updatedAt});

  factory LiveStatusModel.fromJson(Map<String, dynamic> json) =>
      LiveStatusModel(
        status:    json['status']    as String,
        updatedAt: (json['updatedAt'] as num).toInt(),
      );
}

// GET /me/routines/active/route  &  /me/routines/active/reco 응답 (LiveRouteDto)
class LiveRouteModel {
  final int totalDistance;
  final int totalTime;
  final int payment;
  final String? startName;
  final String? endName;
  final List<PathModel> path;

  const LiveRouteModel({
    required this.totalDistance,
    required this.totalTime,
    required this.payment,
    this.startName,
    this.endName,
    required this.path,
  });

  factory LiveRouteModel.fromJson(Map<String, dynamic> json) => LiveRouteModel(
        totalDistance: (json['totalDistance'] as num?)?.toInt() ?? 0,
        totalTime:     (json['totalTime']     as num).toInt(),
        payment:       (json['payment']       as num).toInt(),
        startName:     json['startName']      as String?,
        endName:       json['endName']        as String?,
        path: (json['path'] as List<dynamic>?)
                ?.map((e) => PathModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'totalDistance': totalDistance,
        'totalTime':     totalTime,
        'payment':       payment,
        'startName':     startName,
        'endName':       endName,
        'path':          path.map((e) => e.toJson()).toList(),
      };
}

// GET /me/routines/active/location 응답 — RouteXYDto 단일 좌표 포인트
class RouteXYModel {
  final String? stationName; // 정류장/역 이름 (null이면 도보 구간)
  final double? x;           // 경도 (longitude)
  final double? y;           // 위도 (latitude)
  final String? arsID;       // 버스 정류장 ID
  final String? type;        // "walk" | "bus" | "subway"
  /// 섹션 식별자 (xy[i].no) — 예: "walk", "bus:5535", "subway:수도권 1호선"
  final String? no;

  const RouteXYModel({this.stationName, this.x, this.y, this.arsID, this.type, this.no});

  bool get hasCoord => x != null && y != null;

  /// 이 정류장이 속한 버스 번호 ("bus:5535" → "5535"). 버스가 아니면 null.
  String? get busNo {
    final n = no;
    if (n == null || !n.startsWith('bus:')) return null;
    return n.substring(4);
  }

  /// 이 정류장이 속한 지하철 노선명 ("subway:수도권 1호선" → "수도권 1호선"). 지하철가 아니면 null.
  String? get subwayLine {
    final n = no;
    if (n == null || !n.startsWith('subway:')) return null;
    final raw = n.substring(7); // e.g. '수도권 1호선'
    if (raw.contains('호선') || raw.contains('선')) return raw;
    return '${raw}호선';
  }

  factory RouteXYModel.fromJson(Map<String, dynamic> json) => RouteXYModel(
        stationName: json['stationName'] as String?,
        x:           (json['x'] as num?)?.toDouble(),
        y:           (json['y'] as num?)?.toDouble(),
        arsID:       json['arsID'] as String?,
        type:        json['type'] as String?,
        no:          json['no'] as String?,
      );
}

// GET /me/routines/active/location 응답 (CurrentSectionDto)
class CurrentSectionModel {
  final int idx;              // 현재 위치 정류장 인덱스 (0-based, xy 배열 기준)
  /// 차례대로 정류장/최소단위 섹션을 나타냄 ("walk", "bus:5535", "subway:수도권 1호선" 등)
  final List<String> section;
  final List<RouteXYModel> xy; // 전체 경로 좌표 포인트 목록

  const CurrentSectionModel({
    required this.idx,
    required this.section,
    this.xy = const [],
  });

  /// 현재 위치한 xy ���리트 (idx �b��위 벗어나면 null)
  RouteXYModel? get currentXY =>
      (idx >= 0 && idx < xy.length) ? xy[idx] : null;

  /// 현재 위치한 섹션 식별자 ("walk", "bus:5535", "subway:수도권 1호선" 등)
  String? get currentSection =>
      (idx >= 0 && idx < section.length) ? section[idx] : null;

  /// 진행 상태: 'walk' | 'bus' | 'subway'
  String get currentType {
    final s = currentSection ?? 'walk';
    if (s.startsWith('bus:')) return 'bus';
    if (s.startsWith('subway:')) return 'subway';
    return 'walk';
  }

  /// 현재 탑스 중인 버스 번호 (bus가 아니면 null) — 예: "5535"
  String? get currentBusNo {
    final s = currentSection;
    if (s == null || !s.startsWith('bus:')) return null;
    return s.substring(4);
  }

  /// 현재 탑스 중인 지하철 노선명 (subway가 아니면 null)
  String? get currentSubwayLine {
    final s = currentSection;
    if (s == null || !s.startsWith('subway:')) return null;
    final raw = s.substring(7);
    if (raw.contains('호선') || raw.contains('선')) return raw;
    return '${raw}호선';
  }

  /// 프로그렘스 표시용: section 배열을 주소프 탠위 GroupedSection 목록으로 최소화
  /// [변화 기준] 섹션 식별자가 바뀔 시점대로 그룹화 ("bus:5535" → "bus:5517" 처림 버스 환스도 별도 구간)
  List<GroupedSection> get groupedSections {
    if (section.isEmpty) return const [];
    final result = <GroupedSection>[];
    String current = section[0];
    int startIdx = 0;
    for (int i = 1; i < section.length; i++) {
      if (section[i] != current) {
        result.add(GroupedSection(typeKey: current, startIdx: startIdx, endIdx: i - 1));
        current = section[i];
        startIdx = i;
      }
    }
    result.add(GroupedSection(typeKey: current, startIdx: startIdx, endIdx: section.length - 1));
    return result;
  }

  /// section 배열을 "도보 → 버스:5535 → 도보 → 지하철:수도권 1호선" 형태로 요약
  /// 연속 중복 항목은 하나로 합쳐서 표시
  String get sectionSummaryLabel {
    return groupedSections.map((g) {
      if (g.isWalk) return '도보';
      if (g.isBus) return '버스:${g.busNo}';
      if (g.isSubway) return '지하철:${g.subwayLine ?? '지하철'}';
      return g.typeKey;
    }).join(' → ');
  }

  factory CurrentSectionModel.fromJson(Map<String, dynamic> json) =>
      CurrentSectionModel(
        idx:     (json['idx'] as num).toInt(),
        section: (json['section'] as List<dynamic>).cast<String>(),
        xy: (json['xy'] as List<dynamic>?)
                ?.map((e) => RouteXYModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// section 배열의 연속된 동일 섹션을 하나의 객체로 표현
/// typeKey: "walk" | "bus:5535" | "subway:수도권 1호선" 등
class GroupedSection {
  final String typeKey;  // 섹션 식별자
  final int startIdx;    // section/xy 배열에서의 시작 인덱스
  final int endIdx;      // 종료 인덱스 (최하위 포함)

  const GroupedSection({required this.typeKey, required this.startIdx, required this.endIdx});

  int get length => endIdx - startIdx + 1;

  bool get isWalk    => typeKey == 'walk';
  bool get isBus     => typeKey.startsWith('bus:');
  bool get isSubway  => typeKey.startsWith('subway:');

  /// 버스 번호 ("bus:5535" → "5535")
  String? get busNo => isBus ? typeKey.substring(4) : null;

  /// 지하철 노선명 ("subway:수도권 1호선" → "수도권 1호선")
  String? get subwayLine {
    if (!isSubway) return null;
    final raw = typeKey.substring(7);
    if (raw.contains('호선') || raw.contains('선')) return raw;
    return '${raw}호선';
  }

  /// 프로그렘스 바에 보여준 레이블 ("5535번", "수도권 1호선", "도보")
  String get displayLabel {
    if (isBus) return '${busNo}번';
    if (isSubway) return subwayLine ?? '지하철';
    return '도보';
  }
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