import '../config/env_config.dart';

class ApiConstants {
  ApiConstants._();

  static String get springBaseUrl => EnvConfig.springBaseUrl;
  static String get fastapiBaseUrl => EnvConfig.fastapiBaseUrl;

  // ── 1. Auth ──────────────────────────────────────────────
  static const googleLogin = '/auth/google';
  static const logout = '/auth/logout';
  static const refreshToken = '/auth/refresh';

  // ── 2. User ──────────────────────────────────────────────
  static const getMyInfo     = '/users/me';          // GET
  static const deleteAccount = '/users/me';          // DELETE
  static const updateNickname = '/users/nickname';   // PATCH

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
  static const liveStatus              = '/me/routines/active/status';
  static const liveMyRoute             = '/me/routines/active/route';
  static const liveRecoRoute           = '/me/routines/active/reco';
  static const liveRecoRouteList       = '/me/routines/active/reco';           // GET  — 추천 경로 목록
  static String liveRecoSave(int recoId) => '/me/routines/active/reco/$recoId'; // POST — 추천 경로 저장
  static const liveCurrentSection      = '/me/routines/active/location/my';
  static const liveCurrentSectionReco  = '/me/routines/active/location/reco';
  // PATCH /me/routines/active — LiveLocationController 실제 endpoint
  static const liveLocation            = '/me/routines/active';
  static const routineCompleteMyRoute  = '/me/routines/active/complete/my';
  static const routineCompleteRecoRoute = '/me/routines/active/complete/reco';
  /// 하위 호환 — 기존 코드가 참조하는 경우 my 엔드포인트로 연결
  static const routineComplete         = routineCompleteMyRoute;
  static const todayIssues        = '/me/issues';

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