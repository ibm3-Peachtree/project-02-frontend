import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── 앱 대표색 ─────────────────────────────────────────
  static const primary    = Color(0xFFF4622D); // 코랄-오렌지
  static const secondary  = Color(0xFF0D7A6B); // 틸 (도착 시각, 소요시간 칩)
  static const background = Color(0xFFF5F5F4); // 웜 스톤 배경
  static const surface    = Color(0xFFFFFFFF);
  static const textPrimary    = Color(0xFF1C1917); // 웜 차콜
  static const textSecondary  = Color(0xFF78716C); // 웜 스톤
  static const border     = Color(0xFFE7E5E4);
  static const success    = Color(0xFF33C756);
  static const warning    = Color(0xFFFFC107);
  static const error      = Color(0xFFF04444);
  static const amber      = Color(0xFFFFF8E1);

  // ── 교통수단 아이콘 배경 ──────────────────────────────
  // 지하철: 웜 차콜 (#44403C)
  static const subway   = Color(0xFF44403C);
  static const subwayBg = Color(0xFFEEEDE9);

  // 버스: 스톤 그레이 (#78716C)
  static const bus   = Color(0xFF78716C);
  static const busBg = Color(0xFFF5F5F4);

  // 도보
  static const walk   = Color(0xFF9CA3AF);
  static const walkBg = Color(0xFFF0F0F0);

  // ── 칩 3종 ────────────────────────────────────────────
  // 노선명·버스번호·방향: 연살구 + 번트 오렌지 (원래 색)
  static const chipRoute   = Color(0xFFC44B17);
  static const chipRouteBg = Color(0xFFFFF0E8);

  // 경로 상세(루틴 생성) 전용 버스 번호 칩: subway 다크 색상
  static const chipRouteDetail    = Color(0xFFFFFFFF); // 흰 글씨
  static const chipRouteDetailBg  = Color(0xFF44403C); // 다크 배경

  // 소요시간: 틸 solid (흰 글씨)
  static const chipTime   = Color(0xFFFFFFFF); // 글씨색
  static const chipTimeBg = Color(0xFF0D7A6B); // 배경색

  // 정거장 수: 연민트 + 틸
  static const chipStops   = Color(0xFF0D7A6B);
  static const chipStopsBg = Color(0xFFD4F0EA);
}
