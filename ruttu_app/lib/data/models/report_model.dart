// ── Report 모델 ──────────────────────────────────────────────────────────────
// 백엔드 DTO 구조:
//   WeeklyReportDto   → WeeklyReportModel
//   MonthlyReportDto  → MonthlyReportModel
//   DailyDto / DailyStatusDto → DailyModel / DailyStatusModel
//   CommuteTimeMinDto → CommuteTimeMinModel
//   ComfortTimeDto    → ComfortTimeModel  (요일별 String 시간값, ex: "07:45")

// ── 공통: 요일별 정수값 컨테이너 (평균 소요시간 등) ──────────────────────────
class CommuteTimeMinModel {
  final int mon;
  final int tue;
  final int wed;
  final int thu;
  final int fri;
  final int sat;
  final int sun;

  const CommuteTimeMinModel({
    required this.mon,
    required this.tue,
    required this.wed,
    required this.thu,
    required this.fri,
    required this.sat,
    required this.sun,
  });

  factory CommuteTimeMinModel.fromJson(Map<String, dynamic> json) =>
      CommuteTimeMinModel(
        mon: (json['mon'] as num?)?.toInt() ?? 0,
        tue: (json['tue'] as num?)?.toInt() ?? 0,
        wed: (json['wed'] as num?)?.toInt() ?? 0,
        thu: (json['thu'] as num?)?.toInt() ?? 0,
        fri: (json['fri'] as num?)?.toInt() ?? 0,
        sat: (json['sat'] as num?)?.toInt() ?? 0,
        sun: (json['sun'] as num?)?.toInt() ?? 0,
      );

  /// 0이 아닌 요일의 평균
  int get average {
    final vals = [mon, tue, wed, thu, fri, sat, sun].where((v) => v > 0);
    if (vals.isEmpty) return 0;
    return (vals.reduce((a, b) => a + b) / vals.length).round();
  }

  /// 요일 이름 → 값 맵 (UI 렌더링용)
  Map<String, int> toWeekdayMap() => {
        '월': mon,
        '화': tue,
        '수': wed,
        '목': thu,
        '금': fri,
        '토': sat,
        '일': sun,
      };
}

// ── 주간: 하루의 출근 상태 ────────────────────────────────────────────────────

// ── 쾌적 출발 시간: ComfortTimeDto 대응 (요일별 String 시간값, ex: "07:45") ──
class ComfortTimeModel {
  final String? mon;
  final String? tue;
  final String? wed;
  final String? thu;
  final String? fri;
  final String? sat;
  final String? sun;

  const ComfortTimeModel({
    this.mon, this.tue, this.wed, this.thu, this.fri, this.sat, this.sun,
  });

  factory ComfortTimeModel.fromJson(Map<String, dynamic> json) =>
      ComfortTimeModel(
        mon: json['mon'] as String?,
        tue: json['tue'] as String?,
        wed: json['wed'] as String?,
        thu: json['thu'] as String?,
        fri: json['fri'] as String?,
        sat: json['sat'] as String?,
        sun: json['sun'] as String?,
      );

  /// null/empty가 아닌 요일 목록 (요일명, 시간문자열)
  List<MapEntry<String, String>> toEntries() {
    final pairs = <MapEntry<String, String?>>[
      MapEntry('월', mon), MapEntry('화', tue), MapEntry('수', wed),
      MapEntry('목', thu), MapEntry('금', fri), MapEntry('토', sat), MapEntry('일', sun),
    ];
    return pairs
        .where((e) => e.value != null && e.value!.isNotEmpty)
        .map((e) => MapEntry(e.key, e.value!))
        .toList();
  }

  /// HH:mm 문자열 기준 가장 이른 요일 반환
  MapEntry<String, String>? get earliest {
    final e = toEntries();
    if (e.isEmpty) return null;
    return e.reduce((a, b) => a.value.compareTo(b.value) <= 0 ? a : b);
  }
}

class DailyStatusModel {
  final int commuteTimeMin;
  final bool isComfort;

  const DailyStatusModel({
    required this.commuteTimeMin,
    required this.isComfort,
  });

  factory DailyStatusModel.fromJson(Map<String, dynamic> json) =>
      DailyStatusModel(
        commuteTimeMin: (json['commuteTimeMin'] as num?)?.toInt() ?? 0,
        isComfort: ((json['isComfort'] as num?)?.toInt() ?? 0) != 0,
      );
}

// ── 주간: 요일별 DailyStatusModel 컨테이너 ───────────────────────────────────
class DailyModel {
  final DailyStatusModel? mon;
  final DailyStatusModel? tue;
  final DailyStatusModel? wed;
  final DailyStatusModel? thu;
  final DailyStatusModel? fri;
  final DailyStatusModel? sat;
  final DailyStatusModel? sun;

  const DailyModel({
    this.mon,
    this.tue,
    this.wed,
    this.thu,
    this.fri,
    this.sat,
    this.sun,
  });

  factory DailyModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DailyModel();
    DailyStatusModel? _parse(String key) {
      final v = json[key];
      if (v == null) return null;
      return DailyStatusModel.fromJson(v as Map<String, dynamic>);
    }
    return DailyModel(
      mon: _parse('mon'),
      tue: _parse('tue'),
      wed: _parse('wed'),
      thu: _parse('thu'),
      fri: _parse('fri'),
      sat: _parse('sat'),
      sun: _parse('sun'),
    );
  }

  /// 요일 이름 → (소요시간, 쾌적여부) 순서 맵 (UI 렌더링용)
  List<MapEntry<String, DailyStatusModel>> toEntries() {
    final pairs = <MapEntry<String, DailyStatusModel?>>[ 
      MapEntry('월', mon),
      MapEntry('화', tue),
      MapEntry('수', wed),
      MapEntry('목', thu),
      MapEntry('금', fri),
      MapEntry('토', sat),
      MapEntry('일', sun),
    ];
    return pairs
        .where((e) => e.value != null)
        .map((e) => MapEntry(e.key, e.value!))
        .toList();
  }
}

// ── 주간 리포트 ───────────────────────────────────────────────────────────────
class WeeklyReportModel {
  final int id;
  final int userRoutineId;
  final int year;
  final int weekOfYear;
  final DateTime? weekStartDate;
  final int avgCommuteTimeMin;
  final int weeklyTransportCost;
  final int weeklyBurnedCalories;
  final int lateRiskCount;
  final int avgWaitTimeMin;
  final DailyModel? daily;

  const WeeklyReportModel({
    required this.id,
    required this.userRoutineId,
    required this.year,
    required this.weekOfYear,
    this.weekStartDate,
    required this.avgCommuteTimeMin,
    required this.weeklyTransportCost,
    required this.weeklyBurnedCalories,
    required this.lateRiskCount,
    required this.avgWaitTimeMin,
    this.daily,
  });

  factory WeeklyReportModel.fromJson(Map<String, dynamic> json) =>
      WeeklyReportModel(
        id:                    (json['id']                    as num?)?.toInt() ?? 0,
        userRoutineId:         (json['userRoutineId']         as num?)?.toInt() ?? 0,
        year:                  (json['year']                  as num?)?.toInt() ?? 0,
        weekOfYear:            (json['weekOfYear']            as num?)?.toInt() ?? 0,
        weekStartDate:         json['weekStartDate'] != null
            ? DateTime.tryParse(json['weekStartDate'] as String)
            : null,
        avgCommuteTimeMin:     (json['avgCommuteTimeMin']     as num?)?.toInt() ?? 0,
        weeklyTransportCost:   (json['weeklyTransportCost']   as num?)?.toInt() ?? 0,
        weeklyBurnedCalories:  (json['weeklyBurnedCalories']  as num?)?.toInt() ?? 0,
        lateRiskCount:         (json['lateRiskCount']         as num?)?.toInt() ?? 0,
        avgWaitTimeMin:        (json['avgWaitTimeMin']        as num?)?.toInt() ?? 0,
        daily: json['daily'] != null
            ? DailyModel.fromJson(json['daily'] as Map<String, dynamic>)
            : null,
      );

  /// "2026년 23주차" 형식의 레이블
  String get weekLabel => '$year년 $weekOfYear주차';
}

// ── 월간 리포트 ───────────────────────────────────────────────────────────────
class MonthlyReportModel {
  final int id;
  final int userRoutineId;
  final int year;
  final int month;
  final DateTime? monthStartDate;
  final CommuteTimeMinModel? avgCommuteTimeMin;
  final CommuteTimeMinModel? maxCommuteTimeMin;
  final CommuteTimeMinModel? minCommuteTimeMin;
  final int monthlyTransportCost;
  final int monthlyBurnedCalories;
  final int lateRiskCount;
  final ComfortTimeModel? recommendedComfortTime;

  const MonthlyReportModel({
    required this.id,
    required this.userRoutineId,
    required this.year,
    required this.month,
    this.monthStartDate,
    this.avgCommuteTimeMin,
    this.maxCommuteTimeMin,
    this.minCommuteTimeMin,
    required this.monthlyTransportCost,
    required this.monthlyBurnedCalories,
    required this.lateRiskCount,
    this.recommendedComfortTime,
  });

  factory MonthlyReportModel.fromJson(Map<String, dynamic> json) {
    CommuteTimeMinModel? _parseTime(String key) {
      final v = json[key];
      if (v == null) return null;
      return CommuteTimeMinModel.fromJson(v as Map<String, dynamic>);
    }

    // ComfortTimeDto는 String 필드 → 별도 파서 사용
    ComfortTimeModel? comfortTime;
    final comfortRaw = json['recommendedComfortTime'];
    if (comfortRaw != null) {
      comfortTime = ComfortTimeModel.fromJson(comfortRaw as Map<String, dynamic>);
    }

    return MonthlyReportModel(
      id:                    (json['id']                    as num?)?.toInt() ?? 0,
      userRoutineId:         (json['userRoutineId']         as num?)?.toInt() ?? 0,
      year:                  (json['year']                  as num?)?.toInt() ?? 0,
      month:                 (json['month']                 as num?)?.toInt() ?? 0,
      monthStartDate:        json['monthStartDate'] != null
          ? DateTime.tryParse(json['monthStartDate'] as String)
          : null,
      avgCommuteTimeMin:     _parseTime('avgCommuteTimeMin'),
      maxCommuteTimeMin:     _parseTime('maxCommuteTimeMin'),
      minCommuteTimeMin:     _parseTime('minCommuteTimeMin'),
      monthlyTransportCost:  (json['monthlyTransportCost']  as num?)?.toInt() ?? 0,
      monthlyBurnedCalories: (json['monthlyBurnedCalories'] as num?)?.toInt() ?? 0,
      lateRiskCount:         (json['lateRiskCount']         as num?)?.toInt() ?? 0,
      recommendedComfortTime: comfortTime,
    );
  }

  /// "2026년 5월" 형식의 레이블
  String get monthLabel => '$year년 ${month}월';
}