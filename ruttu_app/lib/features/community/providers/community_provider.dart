import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/post_model.dart';
import '../../../data/repositories/community_repository.dart';
import '../../../features/auth/providers/network_provider.dart';

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => ApiCommunityRepository(ref.read(apiClientProvider)),
);

// ── 피드 상태 ─────────────────────────────────────
class FeedState {
  final PostSummaryModel? hotPost;
  final List<PostSummaryModel> posts;      // 필터 적용된 목록
  final List<PostSummaryModel> allPosts;   // 필터 전 전체 목록 (칩 생성용)
  final List<PostSummaryModel> myPosts;
  final String sortType;   // 'latest' | 'view'
  final String? routeFilter;
  final bool isLoading;
  final bool isMyPostsLoading;
  final String? error;

  const FeedState({
    this.hotPost,
    this.posts = const [],
    this.allPosts = const [],
    this.myPosts = const [],
    this.sortType = 'latest',
    this.routeFilter,
    this.isLoading = false,
    this.isMyPostsLoading = false,
    this.error,
  });

  /// 전체 게시글에서 중복 없이 lineNumber 추출 (빈 값 제외)
  List<String> get allRoutes {
    final seen = <String>{};
    return allPosts
        .map((p) => p.lineNumber)
        .where((r) => r.isNotEmpty && seen.add(r))
        .toList();
  }

  FeedState copyWith({
    PostSummaryModel? hotPost,
    List<PostSummaryModel>? posts,
    List<PostSummaryModel>? allPosts,
    List<PostSummaryModel>? myPosts,
    String? sortType,
    String? routeFilter,
    bool clearRoute = false,
    bool? isLoading,
    bool? isMyPostsLoading,
    String? error,
    bool clearError = false,
  }) =>
      FeedState(
        hotPost:           hotPost           ?? this.hotPost,
        posts:             posts             ?? this.posts,
        allPosts:          allPosts          ?? this.allPosts,
        myPosts:           myPosts           ?? this.myPosts,
        sortType:          sortType          ?? this.sortType,
        routeFilter:       clearRoute ? null : (routeFilter ?? this.routeFilter),
        isLoading:         isLoading         ?? this.isLoading,
        isMyPostsLoading:  isMyPostsLoading  ?? this.isMyPostsLoading,
        error:             clearError ? null : (error ?? this.error),
      );
}

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>(
  (ref) => FeedNotifier(ref.read(communityRepositoryProvider)),
);

class FeedNotifier extends StateNotifier<FeedState> {
  final CommunityRepository _repository;

  FeedNotifier(this._repository) : super(const FeedState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final posts = await _repository.getPosts(sort: state.sortType);
      // 필터 적용 (클라이언트 사이드 — 백엔드에 필터 파라미터 없음)
      var filtered = posts;
      if (state.routeFilter != null && state.routeFilter!.isNotEmpty) {
        filtered = posts
            .where((p) => p.lineNumber.contains(state.routeFilter!))
            .toList();
      }
      // 조회수 1위 = hotPost
      final hot = posts.isEmpty
          ? null
          : (List<PostSummaryModel>.from(posts)
                ..sort((a, b) => b.viewCount.compareTo(a.viewCount)))
              .first;
      state = FeedState(
        hotPost:     hot,
        posts:       filtered,
        allPosts:    posts,
        myPosts:     state.myPosts,
        sortType:    state.sortType,
        routeFilter: state.routeFilter,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '게시글을 불러오지 못했어요.');
    }
  }

  Future<void> loadMyPosts() async {
    state = state.copyWith(isMyPostsLoading: true);
    try {
      final myPosts = await _repository.getMyPosts();
      state = state.copyWith(myPosts: myPosts, isMyPostsLoading: false);
    } catch (e) {
      state = state.copyWith(isMyPostsLoading: false, error: '내 게시글을 불러오지 못했어요.');
    }
  }

  Future<void> setSort(String sort) async {
    state = state.copyWith(sortType: sort);
    await load();
  }

  Future<void> setRouteFilter(String? route) async {
    state = state.copyWith(
      routeFilter: route,
      clearRoute: route == null,
    );
    await load();
  }

  Future<void> createPost(
    CreatePostRequest request, {
    dynamic imageFile,
  }) async {
    await _repository.createPost(request, imageFile: imageFile);
    await load();
  }

  Future<void> updatePost(
    int postId,
    CreatePostRequest request, {
    dynamic imageFile,
  }) async {
    await _repository.updatePost(postId, request, imageFile: imageFile);
  }

  Future<void> deletePost(int postId) async {
    await _repository.deletePost(postId);
    await load();
    await loadMyPosts();
  }
}

// ── 게시글 상세 상태 ──────────────────────────────
class PostDetailState {
  final PostDetailModel? post;
  final bool isLoading;
  const PostDetailState({
    this.post,
    this.isLoading = false,
  });

  PostDetailState copyWith({
    PostDetailModel? post,
    bool? isLoading,
  }) =>
      PostDetailState(
        post:      post      ?? this.post,
        isLoading: isLoading ?? this.isLoading,
      );
}

final postDetailProvider = StateNotifierProvider.family<PostDetailNotifier,
    PostDetailState, int>(
  (ref, postId) =>
      PostDetailNotifier(ref.read(communityRepositoryProvider), postId),
);

class PostDetailNotifier extends StateNotifier<PostDetailState> {
  final CommunityRepository _repository;
  final int _postId;

  PostDetailNotifier(this._repository, this._postId)
      : super(const PostDetailState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final post = await _repository.getPostDetail(_postId);
      state = PostDetailState(post: post);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> reportPost(String reason) =>
      _repository.reportPost(_postId, reason);

}
