import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_constants.dart';
import '../../auth/providers/auth_provider.dart';

class AccountManageScreen extends ConsumerWidget {
  const AccountManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('계정 관리',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),

          // ── 로그인 정보 ────────────────────────────────
          _SectionLabel(label: '로그인 정보'),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const _GoogleIcon(),
                  title: const Text('Google 계정으로 로그인 중',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('연동됨',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary)),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.email_outlined,
                      color: AppColors.textSecondary),
                  title: Text(email,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── 계정 ──────────────────────────────────────
          _SectionLabel(label: '계정'),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout,
                      color: AppColors.textSecondary, size: 22),
                  title: const Text('로그아웃',
                      style: TextStyle(fontSize: 15)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                  onTap: () => _showSignOutDialog(context, ref),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: AppColors.error, size: 22),
                  title: const Text('회원 탈퇴',
                      style: TextStyle(
                          fontSize: 15, color: AppColors.error)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.error),
                  onTap: () => _showDeleteAccountDialog(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('로그아웃 하시겠어요?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text(
          '다시 로그인하면 언제든지 돌아올 수 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(authProvider.notifier).signOut();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: const Text('로그아웃',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Column(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 40),
            SizedBox(height: 12),
            Text('정말 탈퇴하시겠어요?',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            // 30일 복구 안내 배너
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '탈퇴 후 30일 이내에 같은 계정으로 로그인하면 계정을 복구할 수 있어요.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(authProvider.notifier).deleteAccount();
                  if (context.mounted) {
                    context.go(RouteConstants.accountDeleted);
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error),
                child: const Text('탈퇴하기',
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text('G',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue)),
        ),
      );
}