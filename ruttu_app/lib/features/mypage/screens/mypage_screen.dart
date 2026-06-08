import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_constants.dart';
import '../../auth/providers/auth_provider.dart';

class MypageScreen extends ConsumerWidget {
  const MypageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final nickname = user?.nickname ?? '사용자';
    final email = user?.email ?? '';
    final initials = nickname.isNotEmpty ? nickname[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        children: [
          // ── 프로필 헤더 ────────────────────────────────
          Container(
            color: AppColors.primary.withValues(alpha: 0.08),
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: Text(initials,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _showNicknameEditSheet(context, ref, nickname),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$nickname님',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit_outlined,
                                size: 18, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(email,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── 메인 메뉴 ──────────────────────────────────
          _MenuSection(
            children: [
              _MenuItem(
                icon: Icons.bar_chart_rounded,
                label: '리포트',
                onTap: () => context.push(RouteConstants.report),
              ),
              _MenuItem(
                icon: Icons.location_on_outlined,
                label: '주소 관리',
                onTap: () => context.push(RouteConstants.addressManage),
              ),
              _MenuItem(
                icon: Icons.notifications_outlined,
                label: '알림 설정',
                onTap: () =>
                    context.push(RouteConstants.notificationSettings),
              ),
              _MenuItem(
                icon: Icons.forum_outlined,
                label: '내 커뮤니티 활동',
                onTap: () =>
                    context.push(RouteConstants.myCommunityActivity),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── 앱 정보 ────────────────────────────────────
          _SectionLabel(label: '앱 정보'),
          _MenuSection(
            children: [
              _MenuItem(
                icon: Icons.info_outline,
                label: '앱 버전',
                trailing: const Text('1.0.0',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
                showArrow: false,
                onTap: null,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── 계정 관리 ──────────────────────────────────
          _SectionLabel(label: '계정 관리'),
          _MenuSection(
            children: [
              _MenuItem(
                icon: Icons.manage_accounts_outlined,
                label: '계정 관리',
                onTap: () => context.push(RouteConstants.accountManage),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── 섹션 라벨 ──────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );
}

// ── 메뉴 카드 컨테이너 ──────────────────────────────────
class _MenuSection extends StatelessWidget {
  final List<Widget> children;
  const _MenuSection({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        child: Column(children: children),
      );
}

// ── 닉네임 편집 바텀 시트 ───────────────────────────────
void _showNicknameEditSheet(
    BuildContext context, WidgetRef ref, String current) {
  final ctrl = TextEditingController(text: current);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _NicknameEditSheet(ctrl: ctrl, ref: ref),
  );
}

class _NicknameEditSheet extends StatefulWidget {
  final TextEditingController ctrl;
  final WidgetRef ref;
  const _NicknameEditSheet({required this.ctrl, required this.ref});

  @override
  State<_NicknameEditSheet> createState() => _NicknameEditSheetState();
}

class _NicknameEditSheetState extends State<_NicknameEditSheet> {
  String? _errorText;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 24, 20,
          MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).viewPadding.bottom +
              16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('닉네임 변경',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: widget.ctrl,
            autofocus: true,
            maxLength: 20,
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
            decoration: InputDecoration(
              hintText: '새 닉네임을 입력해주세요',
              counterText: '',
              errorText: _errorText,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              onPressed: _loading
                  ? null
                  : () async {
                      final name = widget.ctrl.text.trim();
                      if (name.isEmpty) return;
                      setState(() {
                        _loading = true;
                        _errorText = null;
                      });
                      final success =
                          await widget.ref.read(authProvider.notifier).setNickname(name, isFirstSetup: false);
                      if (!mounted) return;
                      if (success) {
                        Navigator.pop(context);
                      } else {
                        final errMsg = widget.ref.read(authProvider).errorMessage;
                        setState(() {
                          _loading = false;
                          _errorText = errMsg ?? '이미 존재하는 닉네임입니다.';
                        });
                      }
                    },
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('저장하기',
                      style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 메뉴 아이템 ──────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final bool showArrow;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.showArrow = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            leading: Icon(icon, color: AppColors.textSecondary, size: 22),
            title: Text(label,
                style: const TextStyle(fontSize: 15)),
            trailing: trailing ??
                (showArrow
                    ? const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary)
                    : null),
            onTap: onTap,
          ),
          const Divider(height: 1, indent: 56),
        ],
      );
}