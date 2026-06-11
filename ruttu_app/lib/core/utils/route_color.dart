import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 노선명 또는 버스 번호를 받아 대표 색상을 반환합니다.
///
/// - 지하철: 공식 노선 색상표 기준
/// - 버스: 색상 통일
/// - 매칭 없으면 [AppColors.primary] 반환
Color routeColor(String route) {
  // ── 지하철 ──────────────────────────────────────
  const subwayColors = <String, Color>{
    '1호선':           Color(0xFF0052A4),
    '2호선':           Color(0xFF009246),
    '3호선':           Color(0xFFEF7C1C),
    '4호선':           Color(0xFF00A2D1),
    '5호선':           Color(0xFF996CAC),
    '6호선':           Color(0xFFCD7C2F),
    '7호선':           Color(0xFF747F00),
    '8호선':           Color(0xFFE6186C),
    '9호선':           Color(0xFFBDB092),
    '신분당선':         Color(0xFFD4003B),
    '경의중앙선':       Color(0xFF77C4A3),
    '수인분당선':       Color(0xFFFFD600),
    '경춘선':          Color(0xFF158D6B),
    '공항철도':         Color(0xFF2768B2),
    'GTX-A':          Color(0xFF8B5CF6),
    '인천1호선':        Color(0xFF7CA8D5),
    '인천2호선':        Color(0xFFF5A200),
    '경강선':          Color(0xFF003DA5),
    '서해선':          Color(0xFF8BC34A),
    '수도권경전철의정부': Color(0xFFE4AA00),
    '수도권경전철용인':  Color(0xFF7E5BB5),
    '김포골드라인':     Color(0xFFB4983E),
    '우이신설선':       Color(0xFFB0C700),
    '신림선':          Color(0xFF6789CA),
  };

  for (final entry in subwayColors.entries) {
    if (route.contains(entry.key)) return entry.value;
  }

  // ── 버스: 단일 색상 ──────────────────────────────
  // 번호 체계가 불규칙해 패턴 매칭 대신 통일된 색상 사용
  if (!route.contains('호선') &&
      !subwayColors.keys.any(route.contains)) {
    return AppColors.primary;
  }

  return AppColors.primary;
}
