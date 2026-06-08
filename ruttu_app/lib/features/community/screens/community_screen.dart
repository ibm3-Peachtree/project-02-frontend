import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_constants.dart';
import '../../../data/models/post_model.dart';
import '../providers/community_provider.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('커뮤니티',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () => context.push(RouteConstants.postCreate),
          ),
        ],
      ),
      body: feed.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(feedProvider.notifier).load(),
              child: CustomScrollView(
                slivers: [
                  // HOT 게시글 배너
                  if (feed.hotPost != null)
                    SliverToBoxAdapter(
                      child: _HotPostBanner(
                        post: feed.hotPost!,
                        onTap: () => context.push(
                          RouteConstants.postDetail.replaceFirst(
                              ':id', '${feed.hotPost!.postId}'),
                        ).then((_) => ref.read(feedProvider.notifier).load()),
                      ),
                    ),

                  // 필터 행
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _FilterHeaderDelegate(
                      sortType: feed.sortType,
                      routeFilter: feed.routeFilter,
                      // 전체 posts(필터 전)에서 lineNumber 추출 → 동적 칩
                      routes: feed.allRoutes,
                      onSortChanged: (s) =>
                          ref.read(feedProvider.notifier).setSort(s),
                      onRouteChanged: (r) =>
                          ref.read(feedProvider.notifier).setRouteFilter(r),
                    ),
                  ),

                  // 게시글 목록
                  if (feed.posts.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text('게시글이 없어요.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.of(context).padding.bottom),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _PostCard(
                            post: feed.posts[i],
                            onTap: () => context.push(
                              RouteConstants.postDetail.replaceFirst(
                                  ':id', '${feed.posts[i].postId}'),
                            ).then((_) => ref.read(feedProvider.notifier).load()),
                          ),
                          childCount: feed.posts.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ── HOT 게시글 배너 ──────────────────────────────
class _HotPostBanner extends StatelessWidget {
  final PostSummaryModel post;
  final VoidCallback? onTap;
  const _HotPostBanner({required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => context.push(
        RouteConstants.postDetail.replaceFirst(':id', '${post.postId}'),
      ),
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
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                post.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                const Icon(Icons.visibility_outlined,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 2),
                Text('${post.viewCount}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 고정 필터 헤더 ────────────────────────────────
class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String sortType;
  final String? routeFilter;
  final List<String> routes;
  final void Function(String) onSortChanged;
  final void Function(String?) onRouteChanged;

  const _FilterHeaderDelegate({
    required this.sortType,
    required this.routeFilter,
    required this.routes,
    required this.onSortChanged,
    required this.onRouteChanged,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // 정렬
            _SmallChip(
              label: '최신순',
              selected: sortType == 'latest',
              onTap: () => onSortChanged('latest'),
            ),
            const SizedBox(width: 6),
            _SmallChip(
              label: '조회순',
              selected: sortType == 'view',
              onTap: () => onSortChanged('view'),
            ),
            const SizedBox(width: 12),
            const VerticalDivider(width: 1, thickness: 1),
            const SizedBox(width: 12),
            // 노선 필터
            _SmallChip(
              label: '전체',
              selected: routeFilter == null,
              onTap: () => onRouteChanged(null),
            ),
            ...routes.map((r) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _SmallChip(
                    label: r,
                    selected: routeFilter == r,
                    onTap: () =>
                        onRouteChanged(routeFilter == r ? null : r),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => 52;
  @override
  double get minExtent => 52;
  @override
  bool shouldRebuild(_FilterHeaderDelegate old) =>
      old.sortType != sortType || old.routeFilter != routeFilter ||
      old.routes.length != routes.length;
}

class _SmallChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SmallChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  color:
                      selected ? Colors.white : AppColors.textSecondary)),
        ),
      );
}

// ── 게시글 카드 ───────────────────────────────────
class _PostCard extends StatelessWidget {
  final PostSummaryModel post;
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
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
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
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
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  Text(post.timeAgo,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
