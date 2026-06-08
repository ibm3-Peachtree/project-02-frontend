import '../config/env_config.dart';

class ApiConstants {
  ApiConstants._();

  static String get springBaseUrl => EnvConfig.springBaseUrl;

  // ── WebSocket (STOMP) ────────────────────────────────────────────
  // StompService가 EnvConfig.springBaseUrl을 직접 참조하므로 여기서는 참고용 문서
  // 실제 endpoint: ws(s)://<springBaseUrl>/ws
  // STOMP destinations:
  //   send  → /app/location/my    (나의 경로 위치 전송)
  //   send  → /app/location/reco  (추천 경로 위치 전송)
  //   sub   → /user/queue/location/my   (나의 경로 구간 수신)
  //   sub   → /user/queue/location/reco (추천 경로 구간 수신)
  //   sub   → /user/queue/status        (이동 상태 수신)
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
  static const notification = '/notifications';  // GET
  static const updateNotification = '/notifications';  // PUT

  // ── 5. Routine ───────────────────────────────────────────
  static const routines = '/me/routines';
  static String routineById(int id) => '/me/routines/$id';
  static const routeRecommend = '/me/routines/routes/recommend';
  static String routeRecommendDetail(int recoId) =>
      '/me/routines/routes/recommend/$recoId';

  // ── 6. Live Routine ──────────────────────────────────────
  static const liveStatus              = '/me/routines/active/status';
  // GET /me/routines/active/route/{routineId}
  static String liveMyRoute(int routineId) => '/me/routines/active/route/$routineId';
  // GET /me/routines/active/reco/{routineId}
  static String liveRecoRouteList(int routineId) => '/me/routines/active/reco/$routineId';
  // POST /me/routines/active/reco/detail/{recoId}
  static String liveRecoSave(int recoId) => '/me/routines/active/reco/detail/$recoId';
  // GET /me/routines/active/reco/detail/{recoId} — 추천 경로 상세
  static String liveRecoRouteDetail(int recoId) => '/me/routines/active/reco/detail/$recoId';
  // GET /me/routines/active/reco/detour/{pathId}
  static String liveRecoDetourDetail(int pathId) => '/me/routines/active/reco/detour/$pathId';
  // POST /me/routines/active/reco/detour/{pathId}
  static String liveDetourSave(int pathId) => '/me/routines/active/reco/detour/$pathId';
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
  static const briefingWeatherNew = '/me/briefing/weather';
  static const briefingCalendar   = '/me/briefing/calendar';
  static const briefingWeather = '/me/briefing/weather-air-quality';
  static String aiSummary(int userId) => '/$userId';
}