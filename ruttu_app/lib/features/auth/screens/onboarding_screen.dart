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
    if (_currentPage < 3) {
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
    final isLast = _currentPage == 3;

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
                children: [
                  OnbPage1(),
                  OnbPage2(),
                  OnbPage3(),
                  OnbPage4(),
                ],
              ),
            ),
            // 페이지 인디케이터
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => AnimatedContainer(
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
class OnbPageLayout extends StatelessWidget {
  final String tag;
  final String title;
  final String highlight;
  final String description;
  final Widget mockup;

  const OnbPageLayout({
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
          OnbHighlightText(full: title, highlight: highlight, fontSize: 24),
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
class OnbPage1 extends StatelessWidget {
  const OnbPage1();

  @override
  Widget build(BuildContext context) {
    return OnbPageLayout(
      tag: '01 · 출발 알림',
      title: '딱 맞는 출발 시간을\n알려드려요',
      highlight: '출발 시간',
      description: '목적지 도착 시간, 경로 소요 시간, 여유 시간(기본 15분)을 더해 최적의 출발 시각을 자동으로 계산해드려요. 여유 시간은 루틴 생성 시 직접 설정할 수 있어요.',
      mockup: const OnbDepartureAlarmMockup(),
    );
  }
}

class OnbDepartureAlarmMockup extends StatelessWidget {
  const OnbDepartureAlarmMockup();

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
                OnbTimeChip(label: '출발', time: '09:27', active: true),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textSecondary),
                OnbTimeChip(label: '도착', time: '10:00', active: false),
              ],
            ),
            const SizedBox(height: 12),
            // 여유 시간 설명 배너
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      const Text('권장 출발 시간이란?',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('소요시간 + 여유 시간을 역산해\n가장 안전한 출발 시각을 알려드려요',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      OnbTimeCol(label: '출발', time: '08:30', sub: '+15분 여유', color: AppColors.primary),
                      const Text('→', style: TextStyle(color: AppColors.textSecondary)),
                      OnbTimeCol(label: '이동', time: '35분', color: AppColors.textSecondary),
                      const Text('→', style: TextStyle(color: AppColors.textSecondary)),
                      OnbTimeCol(label: '도착 목표', time: '09:20', color: const Color(0xFF0D7A6B)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('루틴 생성 시 여유 시간을 직접 설정할 수 있어요 (기본 15분)',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnbTimeChip extends StatelessWidget {
  final String label, time;
  final bool active;
  const OnbTimeChip({required this.label, required this.time, required this.active});

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
class OnbPage2 extends StatelessWidget {
  const OnbPage2();

  @override
  Widget build(BuildContext context) {
    return OnbPageLayout(
      tag: '02 · 실시간 안내',
      title: '이동 중 경로를\n실시간으로 안내해요',
      highlight: '실시간으로',
      description: '대기·탑승·환승 상황을 단계별로 추적하고\n돌발 상황엔 대체 경로를 바로 알려드려요.',
      mockup: const OnbRouteGuideMockup(),
    );
  }
}

class OnbRouteGuideMockup extends StatelessWidget {
  const OnbRouteGuideMockup();

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
            OnbStepItem(icon: Icons.directions_walk_rounded, label: '도보 5분', color: AppColors.textSecondary, done: true),
            OnbStepDivider(),
            OnbStepItem(icon: Icons.subway_rounded, label: '2호선 · 교대방면', color: const Color(0xFF009241), done: false, isCurrent: true, sub: '강남 → 교대 (2정거장)'),
            OnbStepDivider(),
            OnbStepItem(icon: Icons.directions_walk_rounded, label: '도보 2분', color: AppColors.textSecondary, done: false),
            OnbStepDivider(),
            OnbStepItem(icon: Icons.subway_rounded, label: '3호선 · 양재방면', color: const Color(0xFFEF7C1C), done: false, sub: '교대 → 양재 (3정거장)'),
            OnbStepDivider(),
            OnbStepItem(icon: Icons.flag_rounded, label: '도착', color: AppColors.primary, done: false),
          ],
        ),
      ),
    );
  }
}

class OnbStepItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool done;
  final bool isCurrent;
  final String? sub;

  const OnbStepItem({required this.icon, required this.label, required this.color, required this.done, this.isCurrent = false, this.sub});

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

class OnbStepDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 23),
      child: Container(width: 1.5, height: 10, color: const Color(0xFFE0E0E0)),
    );
  }
}

// ── Page 3: AI 브리핑 ────────────────────────────────────
class OnbPage3 extends StatelessWidget {
  const OnbPage3();

  @override
  Widget build(BuildContext context) {
    return OnbPageLayout(
      tag: '03 · AI 브리핑',
      title: '날씨·교통 이슈를\n한눈에 확인하세요',
      highlight: '한눈에 확인',
      description: 'AI가 오늘의 날씨, 교통 지연, 맞춤 경로 요약을\n아침마다 자동으로 정리해드려요.',
      mockup: const OnbBriefingMockup(),
    );
  }
}

class OnbBriefingMockup extends StatelessWidget {
  const OnbBriefingMockup();

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
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ① AI 요약 카드
              _OnbCard(
                headerColor: const LinearGradient(
                  colors: [AppColors.secondary, Color(0xFF00D4C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                headerContent: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text('AI 요약', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                body: const Text(
                  '오늘은 맑은 날씨가 예상됩니다. 2호선 강남 구간에 지연이 있으니 10분 일찍 출발하세요.',
                  style: TextStyle(fontSize: 11, color: AppColors.textPrimary, height: 1.5),
                ),
              ),
              const SizedBox(height: 8),

              // ② 날씨 카드
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wb_sunny_outlined, color: AppColors.primary, size: 14),
                        SizedBox(width: 6),
                        Text('오늘의 날씨',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('☀️', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 8),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('23°', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            Text('맑음', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(children: [
                              const Icon(Icons.arrow_upward, size: 11, color: Colors.red),
                              Text('27°', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red)),
                            ]),
                            const SizedBox(height: 3),
                            Row(children: [
                              const Icon(Icons.arrow_downward, size: 11, color: Colors.blue),
                              Text('16°', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue)),
                            ]),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _OnbWeatherTile(icon: Icons.water_drop_outlined, iconColor: const Color(0xFF1565C0), label: '강수량', value: '없음', valueColor: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        _OnbWeatherTile(icon: Icons.air, iconColor: Colors.green, label: '미세먼지', value: '보통', valueColor: Colors.green),
                        const SizedBox(width: 6),
                        _OnbWeatherTile(icon: Icons.blur_on, iconColor: Colors.blue, label: '초미세먼지', value: '좋음', valueColor: Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ③ 준비물 카드
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.backpack_outlined, color: AppColors.primary, size: 14),
                        SizedBox(width: 6),
                        Text('오늘의 준비물',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.dry_cleaning_outlined, size: 13, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      const Text('옷차림 추천',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ]),
                    const SizedBox(height: 4),
                    const Text('낮에는 반팔, 얇은 긴팔이 적당하며 일교차가 있으니 가디건을 챙기세요.',
                        style: TextStyle(fontSize: 11, height: 1.5)),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.checklist_outlined, size: 13, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      const Text('챙겨야 할 것',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ]),
                    const SizedBox(height: 4),
                    const Text('자외선 차단을 위한 선크림과 선글라스를 챙기면 좋습니다.',
                        style: TextStyle(fontSize: 11, height: 1.5)),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ④ 일정 카드
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 14),
                        const SizedBox(width: 6),
                        const Text('오늘의 일정',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, size: 10, color: Colors.green),
                              SizedBox(width: 3),
                              Text('Google Calendar 연동됨',
                                  style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withOpacity(0.30)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary)),
                          const SizedBox(width: 5),
                          const Text('내 캘린더', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(width: 3,
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.35), borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 8),
                          const Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                SizedBox(width: 36, child: Text('09:00', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
                                SizedBox(width: 5),
                                Text('팀 스탠드업 미팅', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ]),
                              SizedBox(height: 6),
                              Row(children: [
                                SizedBox(width: 36, child: Text('14:00', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
                                SizedBox(width: 5),
                                Text('기획 리뷰', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ]),
                            ],
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 온보딩 브리핑 목업용 헤더 있는 카드
class _OnbCard extends StatelessWidget {
  final Gradient headerColor;
  final Widget headerContent;
  final Widget body;
  const _OnbCard({required this.headerColor, required this.headerContent, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(gradient: headerColor),
            child: headerContent,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: body,
          ),
        ],
      ),
    );
  }
}

// 온보딩 브리핑 목업용 날씨 타일
class _OnbWeatherTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  const _OnbWeatherTile({required this.icon, required this.iconColor, required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 11, color: iconColor),
              const SizedBox(width: 3),
              Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: valueColor)),
          ],
        ),
      ),
    );
  }
}

class OnbInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const OnbInfoChip({required this.icon, required this.label, required this.color});

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
class OnbHighlightText extends StatelessWidget {
  final String full;
  final String highlight;
  final double fontSize;

  const OnbHighlightText({required this.full, required this.highlight, required this.fontSize});

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

class OnbTimeCol extends StatelessWidget {
  final String label;
  final String time;
  final String? sub;
  final Color color;
  const OnbTimeCol({required this.label, required this.time, required this.color, this.sub});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(time, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        if (sub != null)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Text(sub!, style: const TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}
// ── Page 4: 메뉴 설명 ────────────────────────────────────
class OnbPage4 extends StatelessWidget {
  const OnbPage4({super.key});

  @override
  Widget build(BuildContext context) {
    return OnbPageLayout(
      tag: '04 · 메뉴 설명',
      title: '각 메뉴가 하는\n일을 소개해요',
      highlight: '메뉴가 하는',
      description: '루틴 추가부터 AI 브리핑, 커뮤니티, 리포트까지\n탭해서 각 기능을 미리 살펴보세요.',
      mockup: const OnbMenuExplainerMockup(),
    );
  }
}

// ── mock 루틴 데이터 ─────────────────────────────────────
class _MockRoutine {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String from;
  final String to;
  final String days;
  final String arrivalTime;
  final String departureTime;
  final bool isActive;

  const _MockRoutine({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.from,
    required this.to,
    required this.days,
    required this.arrivalTime,
    required this.departureTime,
    required this.isActive,
  });
}

const _mockRoutines = [
  _MockRoutine(
    icon: Icons.subway_rounded,
    iconColor: AppColors.primary,
    iconBg: Color(0x1FF4622D),
    from: '집',
    to: '회사',
    days: '평일',
    arrivalTime: '09:00',
    departureTime: '08:17',
    isActive: true,
  ),
  _MockRoutine(
    icon: Icons.directions_run_rounded,
    iconColor: AppColors.secondary,
    iconBg: Color(0x1F0D7A6B),
    from: '집',
    to: '헬스장',
    days: '매일 오전',
    arrivalTime: '10:00',
    departureTime: '09:27',
    isActive: false,
  ),
  _MockRoutine(
    icon: Icons.school_rounded,
    iconColor: Color(0xFF3B82F6),
    iconBg: Color(0x1F3B82F6),
    from: '회사',
    to: '강남역',
    days: '금요일',
    arrivalTime: '19:30',
    departureTime: '19:08',
    isActive: true,
  ),
];

// ── 메뉴 설명 mockup ─────────────────────────────────────
class OnbMenuExplainerMockup extends StatefulWidget {
  const OnbMenuExplainerMockup({super.key});

  @override
  State<OnbMenuExplainerMockup> createState() => _OnbMenuExplainerMockupState();
}

class _OnbMenuExplainerMockupState extends State<OnbMenuExplainerMockup> {
  String? _openMenu; // null | 'routine' | 'briefing' | 'community' | 'report'

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: _openMenu == null
          ? _MenuGrid(key: const ValueKey('grid'), onTap: (m) => setState(() => _openMenu = m))
          : _MenuDetail(
              key: ValueKey(_openMenu),
              menuKey: _openMenu!,
              onBack: () => setState(() => _openMenu = null),
            ),
    );
  }
}

// ── 메뉴 그리드 ──────────────────────────────────────────
class _MenuGrid extends StatelessWidget {
  final void Function(String) onTap;
  const _MenuGrid({super.key, required this.onTap});

  static const _menus = [
    _MenuMeta(
      key: 'routine',
      icon: Icons.add_circle_outline_rounded,
      iconBg: Color(0x1FF4622D),
      iconColor: AppColors.primary,
      name: '루틴 추가',
      desc: '출발·도착 경로를\n등록하고 관리해요',
    ),
    _MenuMeta(
      key: 'briefing',
      icon: Icons.auto_awesome_rounded,
      iconBg: Color(0x1F3B82F6),
      iconColor: Color(0xFF3B82F6),
      name: 'AI 브리핑',
      desc: '날씨·교통 이슈를\n매일 아침 요약해요',
    ),
    _MenuMeta(
      key: 'community',
      icon: Icons.people_outline_rounded,
      iconBg: Color(0x1F7C3AED),
      iconColor: Color(0xFF7C3AED),
      name: '커뮤니티',
      desc: '이웃과 실시간 교통\n정보를 공유해요',
    ),
    _MenuMeta(
      key: 'report',
      icon: Icons.bar_chart_rounded,
      iconBg: Color(0x1F059669),
      iconColor: Color(0xFF059669),
      name: '리포트',
      desc: '이동 패턴과 통계를\n주·월간으로 분석해요',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
        children: _menus
            .map((m) => _MenuCard(meta: m, onTap: () => onTap(m.key)))
            .toList(),
      ),
    );
  }
}

class _MenuMeta {
  final String key;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String name;
  final String desc;

  const _MenuMeta({
    required this.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.name,
    required this.desc,
  });
}

class _MenuCard extends StatelessWidget {
  final _MenuMeta meta;
  final VoidCallback onTap;
  const _MenuCard({required this.meta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: meta.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(meta.icon, color: meta.iconColor, size: 22),
            ),
            const Spacer(),
            Text(
              meta.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta.desc,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '자세히 보기',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: meta.iconColor,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 14, color: meta.iconColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 메뉴 상세 패널 ───────────────────────────────────────
class _MenuDetail extends StatelessWidget {
  final String menuKey;
  final VoidCallback onBack;
  const _MenuDetail({super.key, required this.menuKey, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onBack,
            child: Row(
              children: const [
                Icon(Icons.arrow_back_ios_rounded, size: 13, color: AppColors.textSecondary),
                SizedBox(width: 2),
                Text('메뉴 목록', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (menuKey) {
      case 'routine':
        return const _RoutineDetailContent();
      case 'briefing':
        return const _BriefingDetailContent();
      case 'community':
        return const _CommunityDetailContent();
      case 'report':
        return const _ReportDetailContent();
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── 루틴 추가 상세 ────────────────────────────────────────
class _RoutineDetailContent extends StatelessWidget {
  const _RoutineDetailContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailHeader(
            icon: Icons.add_circle_outline_rounded,
            iconColor: AppColors.primary,
            iconBg: const Color(0x1FF4622D),
            title: '루틴 추가',
            subtitle: '자주 이용하는 경로를 등록해 매일 최적 출발 시각을 자동으로 알림 받으세요.',
          ),
          const SizedBox(height: 10),
          const Text('등록된 루틴',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ..._mockRoutines.map((r) => _RoutineRow(routine: r)),
          const SizedBox(height: 8),
          // 루틴 추가 버튼 (mock)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                SizedBox(width: 4),
                Text('새 루틴 추가하기',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              '설정 항목: 출발지 · 목적지 · 도착 희망 시각 · 요일 · 여유 시간(기본 15분) · 공휴일 제외 여부',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineRow extends StatelessWidget {
  final _MockRoutine routine;
  const _RoutineRow({required this.routine});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: routine.iconBg, shape: BoxShape.circle),
            child: Icon(routine.icon, color: routine.iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${routine.from} → ${routine.to}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('${routine.days} · 도착 ${routine.arrivalTime}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: routine.isActive ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  routine.isActive ? '활성' : '일시정지',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: routine.isActive ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                routine.departureTime,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: routine.isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── AI 브리핑 상세 ────────────────────────────────────────
class _BriefingDetailContent extends StatelessWidget {
  const _BriefingDetailContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailHeader(
            icon: Icons.auto_awesome_rounded,
            iconColor: const Color(0xFF3B82F6),
            iconBg: const Color(0x1F3B82F6),
            title: 'AI 브리핑',
            subtitle: '매일 아침 날씨, 교통 이슈, 맞춤 경로 요약을 자동으로 정리해드려요.',
          ),
          const SizedBox(height: 10),
          // AI 요약 카드
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 5),
                    const Text('AI 브리핑',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
                    const Spacer(),
                    Text('오늘 오전 7:00',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '오늘 출근 시간대 2호선 강남~신도림 구간이 혼잡해요. 평소보다 10분 일찍 출발하세요. 오후 소나기 예보 있으니 우산 챙기세요! ☂️',
                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _InfoChip(icon: Icons.wb_sunny_rounded, label: '맑음 23°C', color: const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _InfoChip(icon: Icons.warning_amber_rounded, label: '2호선 지연', color: AppColors.error),
            ],
          ),
          const SizedBox(height: 8),
          // 추천 출발 시각
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: const [
                Icon(Icons.schedule_rounded, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text('추천 출발 시각', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Spacer(),
                Text('08:17',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('브리핑 포함 항목',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          ...[
            (Icons.cloud_rounded, const Color(0xFF3B82F6), '날씨 요약', '기온·강수·체감 온도'),
            (Icons.schedule_rounded, AppColors.primary, '추천 출발 시각', '루틴별 최적 시간 계산'),
            (Icons.calendar_today_rounded, const Color(0xFF7C3AED), '오늘 일정', '캘린더 연동 일정 요약'),
            (Icons.backpack_rounded, const Color(0xFF059669), '준비물 안내', '우산·겉옷 등 날씨 맞춤'),
          ].map((e) => _FeatureRow(icon: e.$1, color: e.$2, title: e.$3, desc: e.$4)),
        ],
      ),
    );
  }
}

// ── 커뮤니티 상세 ─────────────────────────────────────────
class _CommunityDetailContent extends StatelessWidget {
  const _CommunityDetailContent();

  static const _posts = [
    (route: '2호선', station: '강남역', title: '오늘 아침 왜 이렇게 막혀요? 😭', time: '12분 전', views: 312),
    (route: '신분당선', station: '강남역', title: '강남역 1번 출구 공사 언제 끝나나요?', time: '34분 전', views: 87),
    (route: '147번', station: '역삼역', title: '147번 배차 간격이 너무 길어요', time: '1시간 전', views: 54),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailHeader(
            icon: Icons.people_outline_rounded,
            iconColor: const Color(0xFF7C3AED),
            iconBg: const Color(0x1F7C3AED),
            title: '커뮤니티',
            subtitle: '같은 노선 이용자들과 실시간 교통 정보를 주고받을 수 있어요.',
          ),
          const SizedBox(height: 10),
          const Text('실시간 인기 글',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ..._posts.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0E8),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(p.route,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFC44B17))),
                        ),
                        const SizedBox(width: 6),
                        Text(p.station,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(p.title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(p.time, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(width: 10),
                        const Icon(Icons.remove_red_eye_outlined, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Text('${p.views}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          ...[
            (Icons.trending_up_rounded, AppColors.error, '실시간 혼잡도 공유', '직접 경험한 정보 공유'),
            (Icons.sort_rounded, const Color(0xFF059669), '최신순·조회순 정렬', '필요한 정보 빠르게 탐색'),
          ].map((e) => _FeatureRow(icon: e.$1, color: e.$2, title: e.$3, desc: e.$4)),
        ],
      ),
    );
  }
}

// ── 리포트 상세 ───────────────────────────────────────────
class _ReportDetailContent extends StatelessWidget {
  const _ReportDetailContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailHeader(
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFF059669),
            iconBg: const Color(0x1F059669),
            title: '리포트',
            subtitle: '주간·월간 이동 데이터를 분석해 나의 이동 패턴을 한눈에 확인하세요.',
          ),
          const SizedBox(height: 10),
          // 탭 헤더 mock
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEDE9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
                    ),
                    child: const Center(
                      child: Text('주간', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('월간', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 통계 그리드
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.payments_outlined, label: '주간 교통비', value: '12,400원', sub: '일 평균 2,480원', iconColor: const Color(0xFF059669))),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(icon: Icons.local_fire_department_outlined, label: '소모 칼로리', value: '3,250 kcal', sub: '꾸준히 증가 중', iconColor: const Color(0xFFF59E0B))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.warning_amber_rounded, label: '지각 위기', value: '1회', sub: '비자의적 기준', iconColor: AppColors.error)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(icon: Icons.hourglass_top_rounded, label: '평균 대기시간', value: '4.2분', sub: '이번 주 기준', iconColor: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          // 요일별 바차트
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('요일별 소요 시간',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    OnbReportMiniBar(day: '월', minutes: 38, maxMinutes: 55),
                    OnbReportMiniBar(day: '화', minutes: 42, maxMinutes: 55),
                    OnbReportMiniBar(day: '수', minutes: 55, maxMinutes: 55, isMax: true),
                    OnbReportMiniBar(day: '목', minutes: 35, maxMinutes: 55),
                    OnbReportMiniBar(day: '금', minutes: 40, maxMinutes: 55),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 공통 위젯 ─────────────────────────────────────────────
class _DetailHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;

  const _DetailHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4)),
            ],
          ),
        ),
      ],
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
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _FeatureRow({required this.icon, required this.color, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color iconColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// OnbReportMiniBar는 기존 코드에서 재사용
class OnbReportMiniBar extends StatelessWidget {
  final String day;
  final int minutes;
  final int maxMinutes;
  final bool isMax;

  const OnbReportMiniBar({
    super.key,
    required this.day,
    required this.minutes,
    required this.maxMinutes,
    this.isMax = false,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = minutes / maxMinutes;
    const barMaxHeight = 44.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('${minutes}분',
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isMax ? AppColors.warning : AppColors.textSecondary)),
        const SizedBox(height: 3),
        Container(
          width: 20,
          height: barMaxHeight * ratio,
          decoration: BoxDecoration(
            color: isMax ? AppColors.warning : AppColors.primary.withOpacity(0.65),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(day,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }
}