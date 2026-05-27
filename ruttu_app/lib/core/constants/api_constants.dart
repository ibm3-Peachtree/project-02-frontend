import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
class ApiConstants {
  ApiConstants._();

static String get springBaseUrl {
  return 'http://10.0.2.2:8080';
}
  static String get fastapiBaseUrl => springBaseUrl;

  // ── 1. Auth ──────────────────────────────────────────────
  static const googleLogin = '/auth/google';
  static const logout = '/auth/logout';
  static const refreshToken = '/auth/refresh';

  // ── 2. User ──────────────────────────────────────────────
  static const deleteAccount = '/users/me';
  static const updateNickname = '/users/mypage/nickname';

  // ── 3. Address ───────────────────────────────────────────
  static const addresses = '/address';
  static String addressById(int id) => '/address/$id';

  // ── 4. Notification / Settings ───────────────────────────
  static const notificationSettings = '/users/me/settings';
  static const updateSettings = '/settings';

  // ── 5. Routine ───────────────────────────────────────────
  static const routines = '/me/routines';
  static String routineById(int id) => '/me/routines/$id';
  static const routeRecommend = '/me/routines/routes/recommend';
  static String routeRecommendDetail(int recoId) =>
      '/me/routines/routes/recommend/$recoId';

  // ── 6. Live Routine ──────────────────────────────────────
  static const liveStatus = '/me/routines/active/status';
  static const liveMyRoute = '/me/routines/active/route';
  static const liveRecoRoute = '/me/routes/active/reco';
  static const liveLocation = '/me/routines/active';
  static const todayIssues = '/me/issues';

  // ── 7. Report ────────────────────────────────────────────
  static const weeklyReport = '/me/reports/weekly';
  static const monthlyReport = '/me/reports/monthly';

  // ── 8. Feed ──────────────────────────────────────────────
  static const feeds = '/feeds';
  static const hotFeed = '/feeds/hot';

  // ── 9. Post ──────────────────────────────────────────────
  static const posts = '/posts';
  static const myPosts = '/posts/me';
  static String postById(int id) => '/posts/$id';

  // ── 10. Comment ──────────────────────────────────────────
  static const myComments = '/comments/me';
  static String postComments(int postId) => '/posts/$postId/comments';
  static String commentById(int id) => '/comments/$id';

  // ── 11. Post Report ──────────────────────────────────────
  static String reportPost(int postId) => '/posts/$postId/report';
  static String reportComment(int commentId) =>
      '/comments/$commentId/report';

  // ── 12. Feedback ─────────────────────────────────────────
  static const feedback = '/me/feedback';

  // ── 13. Briefing (FastAPI) ───────────────────────────────
  static const briefingRoute = '/me/briefing/route';
  static const briefingWeather = '/me/briefing/weather-air-quality';
  static String aiSummary(int userId) => '/$userId';
}
