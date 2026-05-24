// GET /me/briefing/weather-air-quality 응답

class WeatherModel {
  final String dateTime;
  final int tmp;        // 기온 (°C)
  final String wsd;    // 풍속
  final String sky;    // 하늘 상태
  final String pty;    // 강수 형태
  final int pop;       // 강수 확률 (%)
  final String pcp;    // 1시간 강수량
  final int reh;       // 습도 (%)
  final String sno;    // 1시간 적설량

  const WeatherModel({
    required this.dateTime,
    required this.tmp,
    required this.wsd,
    required this.sky,
    required this.pty,
    required this.pop,
    required this.pcp,
    required this.reh,
    required this.sno,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) => WeatherModel(
        dateTime: json['dateTime'] as String,
        tmp:  json['tmp']  as int,
        wsd:  json['wsd']  as String,
        sky:  json['sky']  as String,
        pty:  json['pty']  as String,
        pop:  json['pop']  as int,
        pcp:  json['pcp']  as String,
        reh:  json['reh']  as int,
        sno:  json['sno']  as String,
      );
}

class AirQualityRegionModel {
  final String seoul;
  final String gyeonggi;

  const AirQualityRegionModel({required this.seoul, required this.gyeonggi});

  factory AirQualityRegionModel.fromJson(Map<String, dynamic> json) =>
      AirQualityRegionModel(
        seoul:    json['seoul']    as String,
        gyeonggi: json['gyeonggi'] as String,
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
  final AirQualityModel airQuality;

  const WeatherAirQualityModel({
    required this.weather,
    required this.airQuality,
  });

  factory WeatherAirQualityModel.fromJson(Map<String, dynamic> json) =>
      WeatherAirQualityModel(
        weather: (json['weather'] as List<dynamic>)
            .map((e) => WeatherModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        airQuality: AirQualityModel.fromJson(
            json['airQuality'] as Map<String, dynamic>),
      );

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
  String get pm10Label => airQuality.pm10.seoul;
}
