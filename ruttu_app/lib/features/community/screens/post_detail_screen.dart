import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_constants.dart';
import '../../../data/models/post_model.dart';
import '../providers/community_provider.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final int postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(postDetailProvider(widget.postId).notifier).load();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showReportSheet({int? commentId}) {
    const reasons = ['욕설·비방', '스팸·광고', '허위정보', '기타'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('신고 사유 선택',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...reasons.map((r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r, style: const TextStyle(fontSize: 15)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _submitReport(r, commentId: commentId);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _submitReport(String reason, {int? commentId}) {
    final notifier = ref.read(postDetailProvider(widget.postId).notifier);
    if (commentId != null) {
      notifier.reportComment(commentId, reason);
    } else {
      notifier.reportPost(reason);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('신고가 접수되었어요.')),
    );
  }

  void _showPostMenu(PostDetailModel post) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('수정'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(
                  RouteConstants.postEdit
                      .replaceFirst(':id', '${post.postId}'),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('삭제',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('신고'),
              onTap: () {
                Navigator.pop(ctx);
                _showReportSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('이 게시글을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(feedProvider.notifier).deletePost(widget.postId);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('삭제',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    await ref.read(postDetailProvider(widget.postId).notifier).sendComment(text);
  }

  Color _routeColor(String route) {
    if (route.contains('2호선'))   return Colors.green;
    if (route.contains('신분당선')) return Colors.red;
    if (route.contains('3호선'))   return Colors.orange;
    if (route.contains('147'))     return Colors.blue;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postDetailProvider(widget.postId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('커뮤니티'),
        leading: const BackButton(),
        actions: [
          if (state.post != null)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showPostMenu(state.post!),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.post == null
              ? const Center(child: Text('게시글을 불러올 수 없어요.'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8 + MediaQuery.of(context).padding.bottom),
                        children: [
                          // 노선·정류장 칩
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _routeColor(state.post!.route)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  state.post!.route,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _routeColor(state.post!.route)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(state.post!.station,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 제목
                          Text(state.post!.title,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),

                          // 메타: 이슈타입 · 시간 · 조회수
                          Row(
                            children: [
                              _MetaChip(label: state.post!.issueType),
                              const SizedBox(width: 8),
                              Text(state.post!.timeAgo,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              const Icon(Icons.visibility_outlined,
                                  size: 13, color: AppColors.textSecondary),
                              const SizedBox(width: 2),
                              Text('${state.post!.viewCount}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          // 본문
                          Text(state.post!.content,
                              style: const TextStyle(
                                  fontSize: 15, height: 1.7)),
                          const SizedBox(height: 24),

                          // 댓글 헤더
                          Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline,
                                  size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                '댓글 ${state.comments.length}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 댓글 목록
                          if (state.comments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text('첫 댓글을 남겨보세요!',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary)),
                              ),
                            )
                          else
                            ...state.comments.map((c) => _CommentItem(
                                  comment: c,
                                  onReport: () =>
                                      _showReportSheet(commentId: c.commentId),
                                  onDelete: () async {
                                    await ref
                                        .read(postDetailProvider(widget.postId)
                                            .notifier)
                                        .deleteComment(c.commentId);
                                  },
                                )),
                        ],
                      ),
                    ),

                    // 하단 댓글 입력창
                    _CommentInputBar(
                      controller: _commentController,
                      isSending: state.isSending,
                      onSend: _sendComment,
                    ),
                  ],
                ),
    );
  }
}

// ── 이슈타입 칩 ─────────────────────────────────────
class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip({required this.label});

  Color get _color {
    return switch (label) {
      '지연' => Colors.orange,
      '결행' => AppColors.error,
      '혼잡' => Colors.purple,
      _     => AppColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: _color)),
      );
}

// ── 댓글 아이템 ──────────────────────────────────────
class _CommentItem extends StatelessWidget {
  final CommentModel comment;
  final VoidCallback onReport;
  final VoidCallback onDelete;

  const _CommentItem({
    required this.comment,
    required this.onReport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onReport,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: const Icon(Icons.person_outline,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('익명',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text(comment.timeAgo,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(comment.content,
                      style: const TextStyle(fontSize: 14, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 댓글 입력 바 ─────────────────────────────────────
class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _CommentInputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 8, 8,
          MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '댓글을 입력하세요...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              maxLines: null,
            ),
          ),
          isSending
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                  onPressed: onSend,
                ),
        ],
      ),
    );
  }
}
