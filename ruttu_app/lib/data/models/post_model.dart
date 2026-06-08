// ── 게시글 목록 항목 (GET /posts?sort=) ─────────────────────────────
// 백엔드 PostAllDto: postId, author, title, lineNumber, stationName, viewCount, createdAt
class PostSummaryModel {
  final int postId;
  final String author;
  final String title;
  final String lineNumber;   // 1호선, 147번
  final String stationName;
  final int viewCount;
  final String createdAt;   // Instant → ISO-8601 문자열

  const PostSummaryModel({
    required this.postId,
    required this.author,
    required this.title,
    required this.lineNumber,
    required this.stationName,
    required this.viewCount,
    required this.createdAt,
  });

  // 하위 호환: 기존 코드가 .route 를 참조하는 경우를 위한 getter
  String get route => lineNumber;
  String get station => stationName;

  factory PostSummaryModel.fromJson(Map<String, dynamic> json) =>
      PostSummaryModel(
        postId:      json['postId']      as int,
        author:      (json['author']     as String?) ?? '익명',
        title:       json['title']       as String,
        lineNumber:  (json['lineNumber'] as String?) ?? '',
        stationName: (json['stationName'] as String?) ?? '',
        viewCount:   (json['viewCount']  as int?) ?? 0,
        createdAt:   (json['createdAt']  as String?) ?? '',
      );

  String get timeAgo {
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1)  return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24)   return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

// ── 게시글 상세 (GET /posts/{postId}) ───────────────────────────────
// 백엔드 PostDetailDto: postId, title, content, image, transportType,
//                        lineNumber, stationName, issueType, viewCount, createdAt
class PostDetailModel {
  final int postId;
  final String title;
  final String content;
  final String? image;          // S3 URL or null
  final String transportType;   // "BUS" | "SUBWAY"
  final String lineNumber;
  final String stationName;
  final String issueType;       // "DELAY" | "CANCELLATION" | "CROWD" | "ETC"
  final int viewCount;
  final String createdAt;

  const PostDetailModel({
    required this.postId,
    required this.title,
    required this.content,
    this.image,
    required this.transportType,
    required this.lineNumber,
    required this.stationName,
    required this.issueType,
    required this.viewCount,
    required this.createdAt,
  });

  // 하위 호환 getter
  String get route => lineNumber;
  String get station => stationName;
  String? get imageUrl => image;

  /// UI 표시용 이슈 타입 한국어 변환
  String get issueTypeLabel => switch (issueType) {
        'DELAY'        => '지연',
        'CANCELLATION' => '결행',
        'CROWD'        => '혼잡',
        _              => '기타',
      };

  /// UI 표시용 교통수단 한국어 변환
  String get transportTypeLabel =>
      transportType == 'BUS' ? '버스' : '지하철';

  factory PostDetailModel.fromJson(Map<String, dynamic> json) =>
      PostDetailModel(
        postId:        json['postId']        as int,
        title:         json['title']         as String,
        content:       (json['content']      as String?) ?? '',
        image:         json['image']         as String?,
        transportType: (json['transportType'] as String?) ?? 'SUBWAY',
        lineNumber:    (json['lineNumber']   as String?) ?? '',
        stationName:   (json['stationName'] as String?) ?? '',
        issueType:     (json['issueType']    as String?) ?? 'ETC',
        viewCount:     (json['viewCount']    as int?) ?? 0,
        createdAt:     (json['createdAt']    as String?) ?? '',
      );

  String get timeAgo {
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1)  return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24)   return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

// ── 댓글 (GET /posts/{postId}/comments) ────────────────────────────
// 백엔드 CommentAllDto: commentId, content, createdAt (LocalDateTime)
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
        createdAt: (json['createdAt'] as String?) ?? '',
      );

  String get timeAgo {
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1)  return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24)   return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

// ── 게시글 작성/수정 요청 (POST /posts, PUT /posts/{id}) ─────────────
// 백엔드 PostDto: title, content, transportType(enum), lineNumber, stationName, issueType(enum)
// 전송: multipart/form-data (file 첨부 선택)
class CreatePostRequest {
  final String title;
  final String content;
  final String transportType;   // "BUS" | "SUBWAY"
  final String lineNumber;
  final String? stationName;
  final String issueType;       // "DELAY" | "CANCELLATION" | "CROWD" | "ETC"

  const CreatePostRequest({
    required this.title,
    required this.content,
    required this.transportType,
    required this.lineNumber,
    this.stationName,
    required this.issueType,
  });

  Map<String, String> toFormFields() => {
        'title':         title,
        'content':       content,
        'transportType': transportType,
        'lineNumber':    lineNumber,
        if (stationName != null && stationName!.isNotEmpty)
          'stationName': stationName!,
        'issueType':     issueType,
      };

  // 하위 호환 getter
  String get route   => lineNumber;
  String get station => stationName ?? '';
}
