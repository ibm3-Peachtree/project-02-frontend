import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// ── Mock 데이터 ───────────────────────────────────
class _MockPost {
  final int postId;
  final String title;
  final String route;
  final String station;
  final int viewCount;
  final String timeAgo;

  const _MockPost({
    required this.postId,
    required this.title,
    required this.route,
    required this.station,
    required this.viewCount,
    required this.timeAgo,
  });
}

// ── Mock 커뮤니티 화면 (실제 CommunityScreen 레이아웃 그대로) ────────────────
class MockCommunityScreen extends StatefulWidget {
  const MockCommunityScreen({super.key});

  @override
  State<MockCommunityScreen> createState() => _MockCommunityScreenState();
}

class _MockCommunityScreenState extends State<MockCommunityScreen> {
  String _sortType = 'latest';
  String? _routeFilter;

  static final _hotPost = _MockPost(
    postId: 0,
    title: '2호선 오늘 아침 왜 이렇게 막혀요? 평소보다 15분은 더 걸렸어요 😭',
    route: '2호선',
    station: '강남역',
    viewCount: 312,
    timeAgo: '12분 전',
  );

  static final _allPosts = [
    _MockPost(postId: 1, title: '2호선 강남~홍대입구 오늘 아침 혼잡 심했어요', route: '2호선', station: '강남역', viewCount: 312, timeAgo: '12분 전'),
    _MockPost(postId: 2, title: '신분당선 강남역 1번 출구 공사 언제 끝나나요?', route: '신분당선', station: '강남역', viewCount: 87, timeAgo: '34분 전'),
    _MockPost(postId: 3, title: '147번 버스 배차 간격이 요즘 너무 길어요', route: '147번', station: '강남역', viewCount: 54, timeAgo: '1시간 전'),
    _MockPost(postId: 4, title: '출퇴근 짐 줄이는 꿀팁 공유해요 🎒', route: '2호선', station: '역삼역', viewCount: 201, timeAgo: '2시간 전'),
    _MockPost(postId: 5, title: '강남역 환승 최단 경로 아시는 분?', route: '신분당선', station: '강남역', viewCount: 145, timeAgo: '3시간 전'),
  ];

  List<_MockPost> get _filteredPosts {
    var posts = [..._allPosts];
    if (_routeFilter != null) {
      posts = posts.where((p) => p.route == _routeFilter).toList();
    }
    if (_sortType == 'view') {
      posts.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    }
    return posts;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPosts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('커뮤니티',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () => _showRoutinePrompt(context),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // HOT 게시글 배너
          SliverToBoxAdapter(child: _HotPostBanner(post: _hotPost, onTap: () {})),

          // 필터 헤더 (고정)
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterHeaderDelegate(
              sortType: _sortType,
              routeFilter: _routeFilter,
              onSortChanged: (s) => setState(() => _sortType = s),
              onRouteChanged: (r) => setState(() => _routeFilter = r),
            ),
          ),

          // 게시글 목록
          if (filtered.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('게시글이 없어요.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 32 + MediaQuery.of(context).padding.bottom),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _PostCard(
                    post: filtered[i],
                    onTap: () {},
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showRoutinePrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.edit_outlined, size: 40, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text('루틴 등록 후 글 작성이 가능해요',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('루틴을 등록하면 커뮤니티에 글을 쓰고\n같은 노선 이웃과 소통할 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text('확인', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── HOT 배너 (실제 _HotPostBanner 레이아웃 그대로) ───────────────────────────
class _HotPostBanner extends StatelessWidget {
  final _MockPost post;
  final VoidCallback onTap;
  const _HotPostBanner({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFFFF8C55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('🔥 HOT',
                  style: TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                post.title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                const Icon(Icons.visibility_outlined, size: 14, color: Colors.white70),
                const SizedBox(width: 2),
                Text('${post.viewCount}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 고정 필터 헤더 (실제 _FilterHeaderDelegate 그대로) ───────────────────────
class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String sortType;
  final String? routeFilter;
  final void Function(String) onSortChanged;
  final void Function(String?) onRouteChanged;

  const _FilterHeaderDelegate({
    required this.sortType,
    required this.routeFilter,
    required this.onSortChanged,
    required this.onRouteChanged,
  });

  static const _routes = ['2호선', '신분당선', '147번', '강남역'];

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _SmallChip(label: '최신순', selected: sortType == 'latest',
                onTap: () => onSortChanged('latest')),
            const SizedBox(width: 6),
            _SmallChip(label: '조회순', selected: sortType == 'view',
                onTap: () => onSortChanged('view')),
            const SizedBox(width: 12),
            const VerticalDivider(width: 1, thickness: 1),
            const SizedBox(width: 12),
            _SmallChip(label: '전체', selected: routeFilter == null,
                onTap: () => onRouteChanged(null)),
            ..._routes.map((r) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _SmallChip(
                label: r,
                selected: routeFilter == r,
                onTap: () => onRouteChanged(routeFilter == r ? null : r),
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override double get maxExtent => 52;
  @override double get minExtent => 52;
  @override bool shouldRebuild(_FilterHeaderDelegate old) =>
      old.sortType != sortType || old.routeFilter != routeFilter;
}

class _SmallChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SmallChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppColors.primary : AppColors.border),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? Colors.white : AppColors.textSecondary)),
    ),
  );
}

// ── 게시글 카드 (실제 _PostCard 레이아웃 그대로) ─────────────────────────────
class _PostCard extends StatelessWidget {
  final _MockPost post;
  final VoidCallback onTap;
  const _PostCard({required this.post, required this.onTap});

  Color _routeColor(String route) {
    if (route.contains('2호선'))   return Colors.green;
    if (route.contains('신분당선')) return Colors.red;
    if (route.contains('3호선'))   return Colors.orange;
    if (route.contains('147'))     return Colors.blue;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 노선·정류장 칩
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _routeColor(post.route).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(post.route,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _routeColor(post.route))),
                  ),
                  const SizedBox(width: 6),
                  Text(post.station,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),
              // 제목
              Text(post.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              // 하단 메타
              Row(
                children: [
                  const Icon(Icons.visibility_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Text('${post.viewCount}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  Text(post.timeAgo,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}