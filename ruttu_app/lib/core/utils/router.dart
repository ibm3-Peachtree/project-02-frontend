import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/splash_screen.dart' show SplashScreen;
import '../../features/auth/screens/nickname_setup_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/dormant_restore_screen.dart';
import '../../features/routine/screens/routine_detail_screen.dart';
import '../../features/routine/screens/routine_create_screen.dart';
import '../../data/models/routine_model.dart';
import '../../features/community/screens/post_detail_screen.dart';
import '../../features/community/screens/post_create_screen.dart';
import '../../features/mypage/screens/mypage_screen.dart';
import '../../features/mypage/screens/account_manage_screen.dart';
import '../../features/mypage/screens/report_screen.dart';
import '../../features/mypage/screens/notification_settings_screen.dart';
import '../../features/mypage/screens/address_manage_screen.dart';
import '../../features/mypage/screens/my_community_activity_screen.dart';
import '../../features/mypage/screens/account_deleted_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/auth_state.dart';
import '../../features/auth/providers/network_provider.dart';
import '../constants/route_constants.dart';
import '../widgets/main_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = ValueNotifier<int>(0);

  ref.listen(authProvider, (_, _) {
    authListenable.value++;
  });

  // 세션 만료 시 토큰 삭제 후 로그인 화면으로 강제 이동
  // ⚠️ signOut()은 API 호출을 다시 하므로 forceSignOut()으로 로컬만 정리
  ref.listen(sessionExpiredProvider, (_, expired) async {
    if (expired) {
      await ref.read(authProvider.notifier).forceSignOut();
      ref.read(sessionExpiredProvider.notifier).state = false;
    }
  });

  return GoRouter(
    initialLocation: RouteConstants.splash,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isOnSplash      = state.matchedLocation == RouteConstants.splash;
      final isOnNickname    = state.matchedLocation == RouteConstants.nicknameSetup;
      final isOnOnboarding  = state.matchedLocation == RouteConstants.onboarding;
      final isOnHome        = state.matchedLocation == RouteConstants.home;
      final isOnDeleted     = state.matchedLocation == RouteConstants.accountDeleted;
      final isOnDormant     = state.matchedLocation == RouteConstants.dormantRestore;

      // 탈퇴 완료 화면은 인증 상태 무관하게 항상 허용
      if (isOnDeleted) return null;

      switch (auth.status) {
        case AuthStatus.unknown:
          return isOnSplash ? null : RouteConstants.splash;
        case AuthStatus.unauthenticated:
          return isOnSplash ? null : RouteConstants.splash;
        case AuthStatus.needsNickname:
          return isOnNickname ? null : RouteConstants.nicknameSetup;
        case AuthStatus.needsOnboarding:
          // 온보딩은 홈 화면 안에서 처리
          return isOnHome ? null : RouteConstants.home;
        case AuthStatus.dormant:
          return isOnDormant ? null : RouteConstants.dormantRestore;
        case AuthStatus.withdrawnAccount:
          // 탈퇴된 계정은 스플래시에서 다이얼로그로 처리
          return isOnSplash ? null : RouteConstants.splash;
        case AuthStatus.authenticated:
          if (isOnSplash || isOnNickname || isOnOnboarding || isOnHome) return RouteConstants.home;
          // 참고: isOnHome은 온보딩 완료 직후 홈에서 authenticated로 전환될 때 머무르게 함
          return null;
      }
    },
    routes: [
      GoRoute(
        path: RouteConstants.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteConstants.nicknameSetup,
        builder: (context, state) => const NicknameSetupScreen(),
      ),
      GoRoute(
        path: RouteConstants.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RouteConstants.dormantRestore,
        builder: (context, state) => const DormantRestoreScreen(),
      ),
      // 루틴/커뮤니티 생성·상세는 ShellRoute 바깥 — 바텀 네비 없이 전체 화면으로 열림
      GoRoute(
        path: RouteConstants.routineCreate,
        builder: (context, state) {
          final routine = state.extra is RoutineModel
              ? state.extra as RoutineModel
              : null;
          return RoutineCreateScreen(editRoutine: routine);
        },
      ),
      GoRoute(
        path: RouteConstants.routineDetail,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          // extra로 RoutineModel을 넘기면 API 재호출 없이 즉시 표시
          final routine = state.extra is RoutineModel
              ? state.extra as RoutineModel
              : null;
          return RoutineDetailScreen(routineId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.postCreate,
        builder: (context, state) => const PostCreateScreen(),
      ),
      GoRoute(
        path: RouteConstants.postEdit,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return PostCreateScreen(editPostId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.postDetail,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return PostDetailScreen(postId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.accountManage,
        builder: (context, state) => const AccountManageScreen(),
      ),
      GoRoute(
        path: RouteConstants.report,
        builder: (context, state) => const ReportScreen(),
      ),
      GoRoute(
        path: RouteConstants.notificationSettings,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: RouteConstants.addressManage,
        builder: (context, state) => const AddressManageScreen(),
      ),
      GoRoute(
        path: RouteConstants.myCommunityActivity,
        builder: (context, state) => const MyCommunityActivityScreen(),
      ),
      GoRoute(
        path: RouteConstants.accountDeleted,
        builder: (context, state) => const AccountDeletedScreen(),
      ),

      // ─────────────────────────────────────────────────────────────────────
      // ShellRoute: 바텀 네비게이션이 있는 5개 탭 루트 경로
      //
      // MainScaffold가 IndexedStack으로 탭 화면을 직접 렌더링하므로,
      // 각 GoRoute의 builder는 SizedBox.shrink()를 반환해도 무방하다.
      // (child는 MainScaffold 내부에서 사용되지 않음)
      //
      // 이 경로들은 redirect, 딥링크, context.go() 대상으로만 기능한다.
      // ─────────────────────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: RouteConstants.home,
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: RouteConstants.routine,
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: RouteConstants.briefing,
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: RouteConstants.community,
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: RouteConstants.mypage,
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      ),
    ],
  );
});
