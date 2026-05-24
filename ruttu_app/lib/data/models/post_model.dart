// GET /feeds, GET /posts 목록 응답 항목
class PostSummaryModel {
  final int postId;
  final String title;
  final String route;
  final String station;
  final int viewCount;
  final String createdAt; // LocalDateTime 문자열

  const PostSummaryModel({
    required this.postId,
    required this.title,
    required this.route,
    required this.station,
    required this.viewCount,
    required this.createdAt,
  });

  factory PostSummaryModel.fromJson(Map<String, dynamic> json) =>
      PostSummaryModel(
        postId:    json['postId']    as int,
        title:     json['title']     as String,
        route:     json['route']     as String,
        station:   json['station']   as String,
        viewCount: json['viewCount'] as int,
        createdAt: json['createdAt'] as String,
      );

  String get timeAgo {
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24)   return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

// GET /posts/{postId} 상세 응답
class PostDetailModel {
  final int postId;
  final String title;
  final String content;
  final String? imageUrl;
  final String route;
  final String station;
  final String issueType;
  final int viewCount;
  final String createdAt;

  const PostDetailModel({
    required this.postId,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.route,
    required this.station,
    required this.issueType,
    required this.viewCount,
    required this.createdAt,
  });

  factory PostDetailModel.fromJson(Map<String, dynamic> json) =>
      PostDetailModel(
        postId:    json['postId']    as int,
        title:     json['title']     as String,
        content:   json['content']   as String,
        imageUrl:  json['imageUrl']  as String?,
        route:     json['route']     as String,
        station:   json['station']   as String,
        issueType: json['issueType'] as String,
        viewCount: json['viewCount'] as int,
        createdAt: json['createdAt'] as String,
      );

  String get timeAgo {
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24)   return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

// GET /posts/{postId}/comments 응답 항목
class CommentModel {
  final int commentId;
  final String content;
  final String createdAt;

  const CommentModel({
    required this.commentId,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) => CommentModel(
        commentId: json['commentId'] as int,
        content:   json['content']   as String,
        createdAt: json['createdAt'] as String,
      );

  String get timeAgo {
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24)   return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

// POST /posts Request (multipart/form-data)
class CreatePostRequest {
  final String title;
  final String content;
  final String route;
  final String station;
  final String issueType;

  const CreatePostRequest({
    required this.title,
    required this.content,
    required this.route,
    required this.station,
    required this.issueType,
  });
}
