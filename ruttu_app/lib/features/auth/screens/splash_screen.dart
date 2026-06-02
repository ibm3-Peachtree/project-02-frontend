import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _dialogShown = false; // 다이얼로그 중복 표시 방지

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).checkAuthStatus();
    });
  }

  Future<void> _onGoogleSignIn() async {
    await ref.read(authProvider.notifier).signInWithGoogle();
  }

  String _friendlyError(String raw) {
    if (raw.contains('503') || raw.contains('Service Unavailable')) {
      return '서버 점검 중이에요.\n잠시 후 다시 시도해주세요.';
    }
    if (raw.contains('SocketException') || raw.contains('network')) {
      return '네트워크 연결을 확인해주세요.';
    }
    if (raw.contains('idToken') || raw.contains('Google 인증')) {
      return 'Google 인증에 실패했어요.\n다시 시도해주세요.';
    }
    if (raw.contains('취소')) {
      return '로그인이 취소됐어요.';
    }
    return '로그인에 실패했어요.\n잠시 후 다시 시도해주세요.';
  }

  Future<void> _showWithdrawnAccountDialog(BuildContext context) async {
    if (!mounted || _dialogShown) return;
    setState(() => _dialogShown = true);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '탈퇴된 계정입니다',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          '이 계정은 탈퇴 처리된 계정입니다.\n계정을 다시 활성화하시겠습니까?',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('활성화'),
          ),
        ],
      ),
    );

    // 다이얼로그가 닫힌 후 플래그 리셋 (재시도 가능하도록)
    if (mounted) setState(() => _dialogShown = false);

    if (!mounted) return;

    if (confirmed == true) {
      await ref.read(authProvider.notifier).restoreAndLogin();
    } else {
      // 취소 → 로그인 화면으로
      ref.read(authProvider.notifier).cancelWithdrawnRestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.isLoading;

    // withdrawnAccount 상태 감지 → 다이얼로그 표시
    // build 안에서 직접 감지하여 라우터 리다이렉트 타이밍 문제 해결
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.withdrawnAccount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showWithdrawnAccountDialog(context);
        });
      }
    });

    // 앱 시작 시 withdrawnAccount 상태로 복원된 경우도 처리
    if (auth.status == AuthStatus.withdrawnAccount && !_dialogShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWithdrawnAccountDialog(context);
      });
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, Color(0xFFFF8C55)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.directions_bus_rounded,
                  size: 80, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                AppConstants.appTagline,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              // withdrawnAccount 상태일 때: 로딩 인디케이터 (다이얼로그가 뜨는 동안)
              if (auth.status == AuthStatus.withdrawnAccount)
                const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: CircularProgressIndicator(color: Colors.white),
                )
              else if (auth.status == AuthStatus.unauthenticated ||
                  auth.status == AuthStatus.unknown) ...[
                if (auth.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _friendlyError(auth.errorMessage!),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 40),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _onGoogleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textPrimary,
                      disabledBackgroundColor: Colors.white54,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.g_mobiledata, size: 28),
                              SizedBox(width: 8),
                              Text(
                                'Google로 시작하기',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}