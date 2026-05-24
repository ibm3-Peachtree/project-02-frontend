import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_constants.dart';
import '../../../data/models/post_model.dart';
import '../../community/providers/community_provider.dart';

class MyCommunityActivityScreen extends ConsumerStatefulWidget {
  const MyCommunityActivityScreen({super.key});

  @override
  ConsumerState<MyCommunityActivityScreen> createState() =>
      _MyCommunityActivityScreenState();
}

class _MyCommunityActivityScreenState
    extends ConsumerState<MyCommunityActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock: my posts (postIds 1, 2)
  static const _myPostIds = [1, 2];
  // Mock: my comments
  static const _myComments = [
    _MyComment(
      commentId: 1,
      content: '저도 지금 막혀서 버스로 갈아탔어요.',
      postTitle: '2호선 강남역 오늘 심하게 지연되네요',
      postId: 1,
      createdAt: '2026-05-19T08:52:00',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
    final myPosts = feed.posts
        .where((p) => _myPostIds.contains(p.postId))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('내 커뮤니티 활동',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        leading: const BackButton(),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          tabs: const [Tab(text: '내가 쓴 글'), Tab(text: '내가 쓴 댓글')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PostsTab(posts: myPosts),
          const _CommentsTab(comments: _myComments),
        ],
      ),
    );
  }
}

// ── 내가 쓴 글 탭 ───────────────────────────────────
class _PostsTab extends StatelessWidget {
  final List<PostSummaryModel> posts;
  const _PostsTab({required this.posts});

  Color _routeColor(String route) {
    if (route.contains('2호선'))   return Colors.green;
    if (route.contains('신분당선')) return Colors.red;
    if (route.contains('3호선'))   return Colors.orange;
    if (route.contains('147'))     return Colors.blue;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_off_outlined, size: 56, color: AppColors.border),
            SizedBox(height: 16),
            Text('아직 작성한 글이 없어요',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            SizedBox(height: 6),
            Text('커뮤니티에서 정보를 공유해보세요',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + MediaQuery.of(context).padding.bottom),
        children: [
          Text('총 ${posts.length}개',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ...posts.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => context.push(
                    RouteConstants.postDetail
                        .replaceFirst(':id', '${p.postId}'),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _routeColor(p.route)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(p.route,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _routeColor(p.route))),
                            ),
                            const SizedBox(width: 6),
                            Text(p.station,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(p.title,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.visibility_outlined,
                                size: 13,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text('${p.viewCount}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            const Spacer(),
                            Text(p.timeAgo,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ── 내가 쓴 댓글 탭 ─────────────────────────────────
class _CommentsTab extends StatelessWidget {
  final List<_MyComment> comments;
  const _CommentsTab({required this.comments});

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 56, color: AppColors.border),
            SizedBox(height: 16),
            Text('아직 작성한 댓글이 없어요',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + MediaQuery.of(context).padding.bottom),
      children: [
        Text('총 ${comments.length}개',
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        ...comments.map((c) {
          final dt = DateTime.tryParse(c.createdAt);
          final dateLabel = dt != null
              ? '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}'
              : '';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => context.push(
                      RouteConstants.postDetail
                          .replaceFirst(':id', '${c.postId}'),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Text('↳ ',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic)),
                          Expanded(
                            child: Text(c.postTitle,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 16,
                              color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(c.content,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(dateLabel,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            minimumSize: Size.zero,
                            padding: EdgeInsets.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap),
                        child: const Text('삭제',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _MyComment {
  final int commentId;
  final String content;
  final String postTitle;
  final int postId;
  final String createdAt;

  const _MyComment({
    required this.commentId,
    required this.content,
    required this.postTitle,
    required this.postId,
    required this.createdAt,
  });
}
