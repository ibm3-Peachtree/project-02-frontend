import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/route_constants.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/routine/screens/routine_list_screen.dart';
import '../../features/briefing/screens/briefing_screen.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/mypage/screens/mypage_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MainScaffold — IndexedStack 기반 탭 유지
//
// 문제: ShellRoute + context.go()로 탭 전환 시 HomeScreen이 재생성되어
//       실시간 경로 안내 상태(State)가 날아감.
//
// 해결: IndexedStack으로 5개 탭 화면을 항상 트리에 살려두고,
//       바텀 네비게이션 탭 전환은 _currentIndex만 바꿔서 표시만 전환.
//       ShellRoute의 child는 사용하지 않고, 현재 경로를 기반으로
//       인덱스만 동기화한다.
// ─────────────────────────────────────────────────────────────────────────────

class MainScaffold extends ConsumerStatefulWidget {
  /// ShellRoute가 넘겨주는 child — 서브 경로(/routine/:id 등)가 열릴 때만 사용.
  /// 탭 루트 경로에서는 IndexedStack으로 직접 화면을 렌더링한다.
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  // 각 탭의 루트 경로 prefix
  static const _tabRoots = [
    RouteConstants.home,      // 0: 실시간
    RouteConstants.routine,   // 1: 루틴
    RouteConstants.briefing,  // 2: 브리핑
    RouteConstants.community, // 3: 커뮤니티
    RouteConstants.mypage,    // 4: 마이
  ];

  // GoRouter 경로 → 탭 인덱스
  int _indexFromLocation(String location) {
    if (location.startsWith(RouteConstants.routine)) return 1;
    if (location.startsWith(RouteConstants.briefing)) return 2;
    if (location.startsWith(RouteConstants.community)) return 3;
    if (location.startsWith(RouteConstants.mypage)) return 4;
    return 0;
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return; // 같은 탭 재탭 — 무시
    setState(() => _currentIndex = index);
    // 라우터 위치도 동기화 (딥링크·뒤로가기 대응)
    context.go(_tabRoots[index]);
  }

  @override
  Widget build(BuildContext context) {
    // 라우터 위치 변화를 반영 (외부에서 go()로 탭이 바뀔 때)
    final location = GoRouterState.of(context).uri.toString();
    final routerIndex = _indexFromLocation(location);
    if (routerIndex != _currentIndex) {
      // build 중 setState 금지 → 다음 프레임에 반영
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && routerIndex != _currentIndex) {
          setState(() => _currentIndex = routerIndex);
        }
      });
    }

    return Scaffold(
      // IndexedStack: 5개 탭 화면을 모두 트리에 살려둔다.
      // Offstage처럼 비활성 탭은 렌더링되지 않지만 State는 유지된다.
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),        // 0
          RoutineListScreen(), // 1
          BriefingScreen(),    // 2
          CommunityScreen(),   // 3
          MypageScreen(),      // 4
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: '실시간'),
          BottomNavigationBarItem(icon: Icon(Icons.repeat), label: '루틴'),
          BottomNavigationBarItem(icon: Icon(Icons.wb_sunny_outlined), label: '브리핑'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: '커뮤니티'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이'),
        ],
      ),
    );
  }
}
