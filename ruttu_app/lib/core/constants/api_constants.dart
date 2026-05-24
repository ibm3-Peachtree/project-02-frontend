class ApiConstants {
  ApiConstants._();

  // 서버 주소 (환경변수로 교체 예정)
  static const springBaseUrl = 'https://api.ruttu.app/api/v1';
  static const fastapiBaseUrl = 'https://ai.ruttu.app/api/v1';

  // ── 1. Auth ──────────────────────────────────────────────
  static const googleLogin = '/auth/google';        // POST — idToken → accessToken+refreshToken+userId
  static const logout     = '/auth/logout';          // POST — refreshToken

  // ── 2. User ──────────────────────────────────────────────
  static const deleteAccount   = '/users/me';              // DELETE
  static const updateNickname  = '/users/mypage/nickname'; // PUT — { nickname }

  // ── 3. Address ───────────────────────────────────────────
  static const addresses       = '/address';               // GET(목록), POST(생성)
  static String addressById(int id) => '/address/$id';     // DELETE, PUT

  // ── 4. Notification / Settings ───────────────────────────
  static const notificationSettings = '/users/me/settings'; // GET
  static const updateSettings        = '/settings';          // PUT

  // ── 5. Routine ───────────────────────────────────────────
  static const routines          = '/routines';             // GET(목록), POST(생성)
  static String routineById(int id) => '/routines/$id';    // GET(상세), PUT, DELETE

  // ── 6. Live Routine ──────────────────────────────────────
  static const liveStatus       = '/me/routines/active/status'; // GET — 현재 단계
  static const liveMyRoute      = '/me/routines/active/route';  // GET — 나의 경로
  static const liveRecoRoute    = '/me/routes/active/reco';     // GET — 추천 경로
  static const liveLocation     = '/me/routines/active';        // POST — 위치 저장
  static const todayIssues      = '/me/issues';                  // GET — 오늘의 이슈

  // ── 7. Report ────────────────────────────────────────────
  static const weeklyReport  = '/me/reports/weekly';   // GET
  static const monthlyReport = '/me/reports/monthly';  // GET

  // ── 8. Feed ──────────────────────────────────────────────
  static const feeds    = '/feeds';     // GET
  static const hotFeed  = '/feeds/hot'; // GET

  // ── 9. Post ──────────────────────────────────────────────
  static const posts      = '/posts';           // GET(목록), POST(작성)
  static const myPosts    = '/posts/me';        // GET
  static String postById(int id) => '/posts/$id'; // GET(상세), PUT, DELETE

  // ── 10. Comment ──────────────────────────────────────────
  static const myComments = '/comments/me';                             // GET
  static String postComments(int postId) => '/posts/$postId/comments'; // GET, POST
  static String commentById(int id) => '/comments/$id';                // DELETE

  // ── 11. Post Report ──────────────────────────────────────
  static String reportPost(int postId)       => '/posts/$postId/report';    // POST
  static String reportComment(int commentId) => '/comments/$commentId/report'; // POST

  // ── 12. Feedback ─────────────────────────────────────────
  static const feedback = '/me/feedback'; // POST

  // ── 13. Briefing (FastAPI) ───────────────────────────────
  static const briefingRoute       = '/me/briefing/route';               // GET
  static const briefingWeather     = '/me/briefing/weather-air-quality'; // GET
  // AI 요약: GET /{user_id}  — 경로 동적이므로 메서드로 제공
  static String aiSummary(int userId) => '/$userId';
}
