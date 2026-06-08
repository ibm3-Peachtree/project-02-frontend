import 'package:dio/dio.dart';
import '../models/post_model.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';

// ── 인터페이스 ─────────────────────────────────────────────────────
abstract class CommunityRepository {
  /// 게시글 목록 (GET /posts?sort=latest|view)
  Future<List<PostSummaryModel>> getPosts({String sort});

  /// 내가 쓴 글 (GET /posts/me)
  Future<List<PostSummaryModel>> getMyPosts();

  /// 게시글 상세 (GET /posts/{postId})
  Future<PostDetailModel> getPostDetail(int postId);

  /// 게시글 작성 (POST /posts, multipart)
  Future<void> createPost(CreatePostRequest request, {dynamic imageFile});

  /// 게시글 수정 (PUT /posts/{id}, multipart)
  Future<void> updatePost(int postId, CreatePostRequest request, {dynamic imageFile});

  /// 게시글 삭제 (DELETE /posts/{id})
  Future<void> deletePost(int postId);

  // ── Comment / Report — 백엔드 미구현이므로 인터페이스만 유지 ──
  Future<List<CommentModel>> getComments(int postId);
  Future<void> createComment(int postId, String content);
  Future<void> deleteComment(int commentId);
  Future<void> reportPost(int postId, String reason);
  Future<void> reportComment(int commentId, String reason);

  // 하위 호환: CommunityScreen 이 hotPost를 요청할 수 있으므로 유지
  Future<PostSummaryModel?> getHotPost();
}

// ── 실제 API 구현 ──────────────────────────────────────────────────
class ApiCommunityRepository implements CommunityRepository {
  const ApiCommunityRepository(this._client);
  final ApiClient _client;

  // ── 게시글 목록 ─────────────────────────────────────────────
  @override
  Future<List<PostSummaryModel>> getPosts({String sort = 'latest'}) async {
    final res = await _client.dio.get(
      ApiConstants.posts,
      queryParameters: {'sort': sort},
    );
    final list = res.data as List<dynamic>;
    return list
        .map((e) => PostSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── 내가 쓴 글 ──────────────────────────────────────────────
  @override
  Future<List<PostSummaryModel>> getMyPosts() async {
    final res = await _client.dio.get(ApiConstants.myPosts);
    final list = res.data as List<dynamic>;
    return list
        .map((e) => PostSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── 게시글 상세 ─────────────────────────────────────────────
  @override
  Future<PostDetailModel> getPostDetail(int postId) async {
    final res = await _client.dio.get(ApiConstants.postById(postId));
    return PostDetailModel.fromJson(res.data as Map<String, dynamic>);
  }

  // ── 가장 많이 조회된 글 (목록 중 최다 조회) ─────────────────
  @override
  Future<PostSummaryModel?> getHotPost() async {
    final posts = await getPosts(sort: 'view');
    return posts.isEmpty ? null : posts.first;
  }

  // ── 게시글 작성 ─────────────────────────────────────────────
  @override
  Future<void> createPost(
    CreatePostRequest request, {
    dynamic imageFile, // XFile or File
  }) async {
    final formData = FormData.fromMap({
      ...request.toFormFields(),
      if (imageFile != null)
        'file': await _toMultipart(imageFile),
    });
    await _client.dio.post(
      ApiConstants.posts,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // ── 게시글 수정 ─────────────────────────────────────────────
  @override
  Future<void> updatePost(
    int postId,
    CreatePostRequest request, {
    dynamic imageFile,
  }) async {
    final formData = FormData.fromMap({
      ...request.toFormFields(),
      if (imageFile != null)
        'image': await _toMultipart(imageFile),
    });
    await _client.dio.put(
      ApiConstants.postById(postId),
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // ── 게시글 삭제 ─────────────────────────────────────────────
  @override
  Future<void> deletePost(int postId) async {
    await _client.dio.delete(ApiConstants.postById(postId));
  }

  // ── Comment — 백엔드 미구현: 빈 응답 반환 ───────────────────
  @override
  Future<List<CommentModel>> getComments(int postId) async => [];

  @override
  Future<void> createComment(int postId, String content) async {}

  @override
  Future<void> deleteComment(int commentId) async {}

  // ── Report — 백엔드 미구현 ───────────────────────────────────
  @override
  Future<void> reportPost(int postId, String reason) async {}

  @override
  Future<void> reportComment(int commentId, String reason) async {}

  // ── 헬퍼: XFile/File → MultipartFile ────────────────────────
  Future<MultipartFile> _toMultipart(dynamic file) async {
    // image_picker XFile
    try {
      final bytes = await (file as dynamic).readAsBytes() as List<int>;
      final name  = (file.name as String?) ?? 'image.jpg';
      return MultipartFile.fromBytes(bytes, filename: name);
    } catch (_) {
      // dart:io File fallback
      return MultipartFile.fromFileSync(
        (file as dynamic).path as String,
        filename: 'image.jpg',
      );
    }
  }
}
