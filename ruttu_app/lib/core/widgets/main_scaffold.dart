import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/route_constants.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(RouteConstants.routine)) return 1;
    if (location.startsWith(RouteConstants.briefing)) return 2;
    if (location.startsWith(RouteConstants.community)) return 3;
    if (location.startsWith(RouteConstants.mypage)) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) {
          switch (i) {
            case 0: context.go(RouteConstants.home);
            case 1: context.go(RouteConstants.routine);
            case 2: context.go(RouteConstants.briefing);
            case 3: context.go(RouteConstants.community);
            case 4: context.go(RouteConstants.mypage);
          }
        },
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
