// GET /me/briefing/weather-air-quality 응답

class WeatherModel {
  final String dateTime;
  final int tmp;        // 기온 (°C)
  final String wsd;    // 풍속
  final String sky;    // 하늘 상태
  final String? pty;   // 강수 형태 (백엔드 WeatherDto에 없을 수 있음)
  final int pop;       // 강수 확률 (%)
  final String pcp;    // 1시간 강수량
  final int reh;       // 습도 (%)
  final String sno;    // 1시간 적설량

  const WeatherModel({
    required this.dateTime,
    required this.tmp,
    required this.wsd,
    required this.sky,
    this.pty,
    required this.pop,
    required this.pcp,
    required this.reh,
    required this.sno,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) => WeatherModel(
        dateTime: (json['dateTime'] ?? '').toString(),
        tmp:  (json['tmp']  as num?)?.toInt() ?? 0,
        wsd:  (json['wsd']  ?? '').toString(),
        sky:  (json['sky']  ?? '1').toString(),
        pty:  json['pty']  as String?,
        pop:  (json['pop']  as num?)?.toInt() ?? 0,
        pcp:  (json['pcp']  ?? '없음').toString(),
        reh:  (json['reh']  as num?)?.toInt() ?? 0,
        sno:  (json['sno']  ?? '없음').toString(),
      );
}

class AirQualityRegionModel {
  final String seoul;
  final String gyeonggi;

  const AirQualityRegionModel({required this.seoul, required this.gyeonggi});

  factory AirQualityRegionModel.fromJson(Map<String, dynamic> json) =>
      AirQualityRegionModel(
        seoul:    (json['seoul']    ?? '').toString(),
        gyeonggi: (json['gyeonggi'] ?? '').toString(),
      );
}

class AirQualityModel {
  final AirQualityRegionModel pm10;
  final AirQualityRegionModel pm25;

  const AirQualityModel({required this.pm10, required this.pm25});

  factory AirQualityModel.fromJson(Map<String, dynamic> json) =>
      AirQualityModel(
        pm10: AirQualityRegionModel.fromJson(json['pm10'] as Map<String, dynamic>),
        pm25: AirQualityRegionModel.fromJson(json['pm25'] as Map<String, dynamic>),
      );
}

class WeatherAirQualityModel {
  final List<WeatherModel> weather;
  final AirQualityModel? airQuality;

  const WeatherAirQualityModel({
    required this.weather,
    this.airQuality,
  });

  // 백엔드는 airQuality를 List<AirQualityDto>로 내림 → 첫 번째 항목 사용
  factory WeatherAirQualityModel.fromJson(Map<String, dynamic> json) {
    final weatherList = (json['weather'] as List<dynamic>?)
            ?.map((e) => WeatherModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    AirQualityModel? airQuality;
    final aqRaw = json['airQuality'];
    if (aqRaw is List && aqRaw.isNotEmpty) {
      // 백엔드: List<AirQualityDto>
      airQuality = AirQualityModel.fromJson(aqRaw.first as Map<String, dynamic>);
    } else if (aqRaw is Map<String, dynamic>) {
      // 단일 객체인 경우도 허용 (이전 mock 호환)
      airQuality = AirQualityModel.fromJson(aqRaw);
    }

    return WeatherAirQualityModel(
      weather: weatherList,
      airQuality: airQuality,
    );
  }

  /// 현재 날씨 (첫 번째 항목)
  WeatherModel? get current => weather.isNotEmpty ? weather.first : null;

  /// 하늘 상태 아이콘
  String get skyEmoji {
    final w = current;
    if (w == null) return '🌤';
    if (w.pty == '1') return '🌧';   // 비
    if (w.pty == '3') return '🌨';   // 눈
    switch (w.sky) {
      case '1': return '☀️';
      case '3': return '⛅';
      case '4': return '☁️';
      default:  return '🌤';
    }
  }

  /// 미세먼지(PM10) 서울 등급 라벨
  String get pm10Label => airQuality?.pm10.seoul ?? '—';
}

// ── GET /me/briefing/weather 응답 (ResponseWeatherDto) ──────────────────────

class BriefingWeatherModel {
  final String locationName; // 주소 별칭 (예: 집, 회사)
  final double tmp;
  final double minTemp;
  final double maxTemp;
  final String sky;
  final String pcp;
  final String pm10;
  final String pm25;
  final String clothes;
  final String supplies;

  const BriefingWeatherModel({
    required this.locationName,
    required this.tmp,
    required this.minTemp,
    required this.maxTemp,
    required this.sky,
    required this.pcp,
    required this.pm10,
    required this.pm25,
    required this.clothes,
    required this.supplies,
  });

  factory BriefingWeatherModel.fromJson(Map<String, dynamic> json) =>
      BriefingWeatherModel(
        locationName: (json['locationName'] ?? '').toString(),
        tmp:      (json['tmp']      as num?)?.toDouble() ?? 0.0,
        minTemp:  (json['minTemp']  as num?)?.toDouble() ?? 0.0,
        maxTemp:  (json['maxTemp']  as num?)?.toDouble() ?? 0.0,
        sky:      (json['sky']      ?? '').toString(),
        pcp:      (json['pcp']      ?? '').toString(),
        pm10:     (json['pm10']     ?? '').toString(),
        pm25:     (json['pm25']     ?? '').toString(),
        clothes:  (json['clothes']  ?? '').toString(),
        supplies: (json['supplies'] ?? '').toString(),
      );
}

// ── GET /me/briefing/calendar 응답 (CalendarItemsDto) ───────────────────────

class BriefingCalendarItemDateTime {
  final int? value;
  final bool dateOnly;
  final int timeZoneShift;

  const BriefingCalendarItemDateTime({
    this.value,
    this.dateOnly = false,
    this.timeZoneShift = 540,
  });

  static BriefingCalendarItemDateTime? fromRaw(dynamic raw) {
    if (raw == null) return null;
    final outer = raw as Map<String, dynamic>;
    final inner = outer['dateTime'];
    if (inner == null) return null;
    final map = inner as Map<String, dynamic>;
    return BriefingCalendarItemDateTime(
      value:         (map['value']        as num?)?.toInt(),
      dateOnly:      (map['dateOnly']      as bool?) ?? false,
      timeZoneShift: (map['timeZoneShift'] as num?)?.toInt() ?? 540,
    );
  }

  DateTime? toDateTime() {
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value!, isUtc: true).toLocal();
  }
}

class BriefingCalendarEvent {
  final String summary;
  final String? description;
  final String? location;
  final BriefingCalendarItemDateTime? start;
  final BriefingCalendarItemDateTime? end;

  const BriefingCalendarEvent({
    required this.summary,
    this.description,
    this.location,
    this.start,
    this.end,
  });

  factory BriefingCalendarEvent.fromJson(Map<String, dynamic> json) {
    return BriefingCalendarEvent(
      summary:     (json['summary']    ?? '').toString(),
      description: json['description'] as String?,
      location:    json['location']    as String?,
      start:       BriefingCalendarItemDateTime.fromRaw(json['start']),
      end:         BriefingCalendarItemDateTime.fromRaw(json['end']),
    );
  }

  String get startTimeLabel {
    if (start?.dateOnly == true) return '종일';
    final dt = start?.toDateTime();
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int get sortKey => start?.value ?? 0;
}

class BriefingCalendarGroup {
  final String summary;   // 캘린더 이름
  final String? description;
  final List<BriefingCalendarEvent> items;

  const BriefingCalendarGroup({
    required this.summary,
    this.description,
    required this.items,
  });

  factory BriefingCalendarGroup.fromJson(Map<String, dynamic> json) =>
      BriefingCalendarGroup(
        summary:     (json['summary']     ?? '').toString(),
        description: json['description']  as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => BriefingCalendarEvent.fromJson(
                e as Map<String, dynamic>))
            .toList(),
      );
}