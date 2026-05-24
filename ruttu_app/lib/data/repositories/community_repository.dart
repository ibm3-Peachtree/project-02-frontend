import '../models/post_model.dart';

abstract class CommunityRepository {
  Future<PostSummaryModel?> getHotPost();
  Future<List<PostSummaryModel>> getFeeds({String? sort, String? route, String? station});
  Future<PostDetailModel> getPostDetail(int postId);
  Future<List<CommentModel>> getComments(int postId);
  Future<int> createPost(CreatePostRequest request);
  Future<void> deletePost(int postId);
  Future<void> createComment(int postId, String content);
  Future<void> deleteComment(int commentId);
  Future<void> reportPost(int postId, String reason);
  Future<void> reportComment(int commentId, String reason);
}

class MockCommunityRepository implements CommunityRepository {
  final List<PostDetailModel> _posts = [
    PostDetailModel(
      postId: 1,
      title: '2호선 강남역 오늘 심하게 지연되네요',
      content: '오전 9시 기준으로 강남~역삼 구간에서 신호 장애가 발생해 10분 이상 지연되고 있어요. 대체 경로 고려하세요.',
      route: '2호선',
      station: '강남역',
      issueType: '지연',
      viewCount: 234,
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)).toIso8601String(),
    ),
    PostDetailModel(
      postId: 2,
      title: '147번 버스 배차 간격 오늘 이상해요',
      content: '평소에 10분 간격인데 오늘은 30분 이상 오지 않고 있어요. 파업인지 확인 부탁드려요.',
      route: '147번',
      station: '강남역 버스정류장',
      issueType: '결행',
      viewCount: 89,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
    ),
    PostDetailModel(
      postId: 3,
      title: '선릉역 2호선 혼잡도 어때요?',
      content: '오늘 오후 6시 퇴근 시간대 선릉역 혼잡도 정보 아시는 분 계세요?',
      route: '2호선',
      station: '선릉역',
      issueType: '혼잡',
      viewCount: 45,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
    ),
  ];

  final Map<int, List<CommentModel>> _comments = {
    1: [
      CommentModel(
        commentId: 1,
        content: '저도 지금 막혀서 버스로 갈아탔어요.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 8)).toIso8601String(),
      ),
      CommentModel(
        commentId: 2,
        content: '신분당선으로 우회하는 게 빠를 것 같아요.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      ),
    ],
    2: [],
    3: [],
  };

  int _nextPostId   = 4;
  int _nextCommentId = 3;

  @override
  Future<PostSummaryModel?> getHotPost() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_posts.isEmpty) return null;
    final sorted = [..._posts]..sort((a, b) => b.viewCount.compareTo(a.viewCount));
    final p = sorted.first;
    return PostSummaryModel(
      postId: p.postId, title: p.title, route: p.route,
      station: p.station, viewCount: p.viewCount, createdAt: p.createdAt,
    );
  }

  @override
  Future<List<PostSummaryModel>> getFeeds({
    String? sort, String? route, String? station,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    var list = [..._posts];
    if (route != null && route.isNotEmpty) {
      list = list.where((p) => p.route == route).toList();
    }
    if (station != null && station.isNotEmpty) {
      list = list.where((p) => p.station.contains(station)).toList();
    }
    if (sort == 'view') {
      list.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    } else {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list.map((p) => PostSummaryModel(
      postId: p.postId, title: p.title, route: p.route,
      station: p.station, viewCount: p.viewCount, createdAt: p.createdAt,
    )).toList();
  }

  @override
  Future<PostDetailModel> getPostDetail(int postId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _posts.firstWhere((p) => p.postId == postId);
  }

  @override
  Future<List<CommentModel>> getComments(int postId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _comments[postId] ?? [];
  }

  @override
  Future<int> createPost(CreatePostRequest request) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final id = _nextPostId++;
    _posts.insert(0, PostDetailModel(
      postId: id,
      title: request.title,
      content: request.content,
      route: request.route,
      station: request.station,
      issueType: request.issueType,
      viewCount: 0,
      createdAt: DateTime.now().toIso8601String(),
    ));
    _comments[id] = [];
    return id;
  }

  @override
  Future<void> deletePost(int postId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _posts.removeWhere((p) => p.postId == postId);
    _comments.remove(postId);
  }

  @override
  Future<void> createComment(int postId, String content) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _comments.putIfAbsent(postId, () => []);
    _comments[postId]!.add(CommentModel(
      commentId: _nextCommentId++,
      content: content,
      createdAt: DateTime.now().toIso8601String(),
    ));
  }

  @override
  Future<void> deleteComment(int commentId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    for (final list in _comments.values) {
      list.removeWhere((c) => c.commentId == commentId);
    }
  }

  @override
  Future<void> reportPost(int postId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> reportComment(int commentId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}
