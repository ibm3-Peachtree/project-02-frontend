import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';

/// 휴먼 계정 복구 화면
/// - 트리거: 로그인 응답 status == "DORMANT"
/// - AuthStatus.dormant → router가 이 화면으로 redirect
class DormantRestoreScreen extends ConsumerWidget {
  const DormantRestoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final notifier = ref.read(authProvider.notifier);
    final isLoading = auth.isLoading;

    // 복구 완료(unauthenticated) 후 errorMessage가 있으면 스낵바로 표시
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.unauthenticated &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 아이콘
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_off_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 28),

              // 제목
              const Text(
                '휴먼 계정 안내',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              // 설명
              const Text(
                '30일 이내에 탈퇴한 계정입니다.\n계정을 복구하면 이전 정보를 그대로 이용할 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),

              // 복구 버튼
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => notifier.restoreAndLogin(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '계정 복구하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // 취소 버튼 (로그인 화면으로 돌아가기)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: TextButton(
                  onPressed: isLoading
                      ? null
                      : () => notifier.signOut(), // 토큰 + Google 세션 전체 초기화 → splash
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '취소',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),

              // 에러 메시지
              if (auth.errorMessage != null &&
                  auth.status == AuthStatus.dormant) ...[
                const SizedBox(height: 16),
                Text(
                  auth.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}