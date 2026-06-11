import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/route_color.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedProvider.notifier).loadMyPosts();
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
    final myPosts = feed.myPosts;
    final isLoading = feed.isMyPostsLoading;

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
          tabs: const [Tab(text: '내가 쓴 글')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
            onRefresh: () =>
                ref.read(feedProvider.notifier).loadMyPosts(),
            child: _PostsTab(posts: myPosts),
          ),
        ],
      ),
    );
  }
}

// ── 내가 쓴 글 탭 ───────────────────────────────────
class _PostsTab extends StatelessWidget {
  final List<PostSummaryModel> posts;
  const _PostsTab({required this.posts});


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
                            color: routeColor(p.route)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(p.route,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: routeColor(p.route))),
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