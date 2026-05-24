import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/post_model.dart';
import '../../../data/repositories/community_repository.dart';

final communityRepositoryProvider = Provider<CommunityRepository>(
  (_) => MockCommunityRepository(),
);

// ── 피드 상태 ─────────────────────────────────────
class FeedState {
  final PostSummaryModel? hotPost;
  final List<PostSummaryModel> posts;
  final String sortType;   // 'latest' | 'view'
  final String? routeFilter;
  final bool isLoading;

  const FeedState({
    this.hotPost,
    this.posts = const [],
    this.sortType = 'latest',
    this.routeFilter,
    this.isLoading = false,
  });

  FeedState copyWith({
    PostSummaryModel? hotPost,
    List<PostSummaryModel>? posts,
    String? sortType,
    String? routeFilter,
    bool clearRoute = false,
    bool? isLoading,
  }) =>
      FeedState(
        hotPost:     hotPost     ?? this.hotPost,
        posts:       posts       ?? this.posts,
        sortType:    sortType    ?? this.sortType,
        routeFilter: clearRoute ? null : (routeFilter ?? this.routeFilter),
        isLoading:   isLoading   ?? this.isLoading,
      );
}

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>(
  (ref) => FeedNotifier(ref.read(communityRepositoryProvider)),
);

class FeedNotifier extends StateNotifier<FeedState> {
  final CommunityRepository _repository;

  FeedNotifier(this._repository) : super(const FeedState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final results = await Future.wait([
      _repository.getHotPost(),
      _repository.getFeeds(
        sort: state.sortType,
        route: state.routeFilter,
      ),
    ]);
    state = FeedState(
      hotPost:     results[0] as PostSummaryModel?,
      posts:       results[1] as List<PostSummaryModel>,
      sortType:    state.sortType,
      routeFilter: state.routeFilter,
    );
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

  Future<void> deletePost(int postId) async {
    await _repository.deletePost(postId);
    await load();
  }
}

// ── 게시글 상세 상태 ──────────────────────────────
class PostDetailState {
  final PostDetailModel? post;
  final List<CommentModel> comments;
  final bool isLoading;
  final bool isSending;

  const PostDetailState({
    this.post,
    this.comments = const [],
    this.isLoading = false,
    this.isSending = false,
  });

  PostDetailState copyWith({
    PostDetailModel? post,
    List<CommentModel>? comments,
    bool? isLoading,
    bool? isSending,
  }) =>
      PostDetailState(
        post:      post      ?? this.post,
        comments:  comments  ?? this.comments,
        isLoading: isLoading ?? this.isLoading,
        isSending: isSending ?? this.isSending,
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
    final results = await Future.wait([
      _repository.getPostDetail(_postId),
      _repository.getComments(_postId),
    ]);
    state = PostDetailState(
      post:     results[0] as PostDetailModel,
      comments: results[1] as List<CommentModel>,
    );
  }

  Future<void> sendComment(String content) async {
    if (content.trim().isEmpty) return;
    state = state.copyWith(isSending: true);
    await _repository.createComment(_postId, content.trim());
    final comments = await _repository.getComments(_postId);
    state = state.copyWith(comments: comments, isSending: false);
  }

  Future<void> deleteComment(int commentId) async {
    await _repository.deleteComment(commentId);
    final comments = await _repository.getComments(_postId);
    state = state.copyWith(comments: comments);
  }

  Future<void> reportPost(String reason) =>
      _repository.reportPost(_postId, reason);

  Future<void> reportComment(int commentId, String reason) =>
      _repository.reportComment(commentId, reason);
}
