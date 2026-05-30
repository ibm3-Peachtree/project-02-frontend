import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  void _next() {
    if (_currentPage < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    ref.read(authProvider.notifier).completeOnboarding();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == 2;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('건너뛰기',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: const [
                  _Page1(),
                  _Page2(),
                  _Page3(),
                ],
              ),
            ),
            // 페이지 인디케이터
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(isLast ? '시작하기' : '다음',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── 공통 레이아웃 ────────────────────────────────────────
class _PageLayout extends StatelessWidget {
  final String tag;
  final String title;
  final String highlight;
  final String description;
  final Widget mockup;

  const _PageLayout({
    required this.tag,
    required this.title,
    required this.highlight,
    required this.description,
    required this.mockup,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(tag,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          const SizedBox(height: 12),
          _HighlightText(full: title, highlight: highlight, fontSize: 24),
          const SizedBox(height: 8),
          Text(description,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
          const SizedBox(height: 20),
          Expanded(child: mockup),
        ],
      ),
    );
  }
}

// ── Page 1: 출발 시간 알림 ────────────────────────────────
class _Page1 extends StatelessWidget {
  const _Page1();

  @override
  Widget build(BuildContext context) {
    return _PageLayout(
      tag: '01 · 출발 알림',
      title: '딱 맞는 출발 시간을\n알려드려요',
      highlight: '출발 시간',
      description: '루틴을 등록하면 목적지 도착 시간에 맞춰\n최적의 출발 시각을 자동으로 계산해드려요.',
      mockup: const _DepartureAlarmMockup(),
    );
  }
}

class _DepartureAlarmMockup extends StatelessWidget {
  const _DepartureAlarmMockup();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE9ECEF)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 루틴 카드
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_bus_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('집 → 헬스장', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text('매일 오전 · 도착 10:00', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('활성', style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 알림 카드
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('지금 출발하세요! 🚀', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        SizedBox(height: 2),
                        Text('09:27 출발 → 10:00 도착 (약 33분)', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 시간표
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _TimeChip(label: '출발', time: '09:27', active: true),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textSecondary),
                _TimeChip(label: '도착', time: '10:00', active: false),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label, time;
  final bool active;
  const _TimeChip({required this.label, required this.time, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.primary.withOpacity(0.10) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? AppColors.primary.withOpacity(0.3) : const Color(0xFFE9ECEF)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: active ? AppColors.primary : AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(time, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: active ? AppColors.primary : AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ── Page 2: 실시간 경로 안내 ─────────────────────────────
class _Page2 extends StatelessWidget {
  const _Page2();

  @override
  Widget build(BuildContext context) {
    return _PageLayout(
      tag: '02 · 실시간 안내',
      title: '이동 중 경로를\n실시간으로 안내해요',
      highlight: '실시간으로',
      description: '대기·탑승·환승 상황을 단계별로 추적하고\n돌발 상황엔 대체 경로를 바로 알려드려요.',
      mockup: const _RouteGuideMockup(),
    );
  }
}

class _RouteGuideMockup extends StatelessWidget {
  const _RouteGuideMockup();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE9ECEF)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 상태바
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                    child: const Text('진행 중', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  const Text('2호선 탑승 중 · 2정거장 남음', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // 스텝 리스트
            _StepItem(icon: Icons.directions_walk_rounded, label: '도보 5분', color: AppColors.textSecondary, done: true),
            _StepDivider(),
            _StepItem(icon: Icons.subway_rounded, label: '2호선 · 교대방면', color: const Color(0xFF009241), done: false, isCurrent: true, sub: '강남 → 교대 (2정거장)'),
            _StepDivider(),
            _StepItem(icon: Icons.directions_walk_rounded, label: '도보 2분', color: AppColors.textSecondary, done: false),
            _StepDivider(),
            _StepItem(icon: Icons.subway_rounded, label: '3호선 · 양재방면', color: const Color(0xFFEF7C1C), done: false, sub: '교대 → 양재 (3정거장)'),
            _StepDivider(),
            _StepItem(icon: Icons.flag_rounded, label: '도착', color: AppColors.primary, done: false),
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool done;
  final bool isCurrent;
  final String? sub;

  const _StepItem({required this.icon, required this.label, required this.color, required this.done, this.isCurrent = false, this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: isCurrent ? BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ) : null,
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? const Color(0xFFE0E0E0) : color.withOpacity(0.15),
            ),
            child: Icon(icon, size: 16, color: done ? Colors.grey : color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(
                  fontSize: 13, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: done ? AppColors.textSecondary : (isCurrent ? color : AppColors.textPrimary),
                  decoration: done ? TextDecoration.lineThrough : null,
                )),
                if (sub != null)
                  Text(sub!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (isCurrent) const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _StepDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 23),
      child: Container(width: 1.5, height: 10, color: const Color(0xFFE0E0E0)),
    );
  }
}

// ── Page 3: AI 브리핑 ────────────────────────────────────
class _Page3 extends StatelessWidget {
  const _Page3();

  @override
  Widget build(BuildContext context) {
    return _PageLayout(
      tag: '03 · AI 브리핑',
      title: '날씨·교통 이슈를\n한눈에 확인하세요',
      highlight: '한눈에 확인',
      description: 'AI가 오늘의 날씨, 교통 지연, 맞춤 경로 요약을\n아침마다 자동으로 정리해드려요.',
      mockup: const _BriefingMockup(),
    );
  }
}

class _BriefingMockup extends StatelessWidget {
  const _BriefingMockup();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE9ECEF)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI 브리핑 카드
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      const Text('AI 브리핑', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      const Spacer(),
                      Text('오늘 오전 7:00', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '오늘은 맑은 날씨가 예상됩니다. 2호선 강남 구간에 지연이 있으니 10분 일찍 출발하세요.',
                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // 날씨/교통 요약 칩
            Row(
              children: [
                _InfoChip(icon: Icons.wb_sunny_rounded, label: '맑음 · 23°C', color: const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _InfoChip(icon: Icons.warning_amber_rounded, label: '2호선 지연', color: const Color(0xFFEF4444)),
              ],
            ),
            const SizedBox(height: 10),
            // 추천 출발
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('추천 출발 시각', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  const Text('09:17', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// 특정 단어만 primary 색상으로 강조
class _HighlightText extends StatelessWidget {
  final String full;
  final String highlight;
  final double fontSize;

  const _HighlightText({required this.full, required this.highlight, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final parts = full.split(highlight);
    for (var i = 0; i < parts.length; i++) {
      spans.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        spans.add(TextSpan(
          text: highlight,
          style: const TextStyle(color: AppColors.primary),
        ));
      }
    }
    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
    );
  }
}
