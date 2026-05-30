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
  @override
  void initState() {
    super.initState();
    // Check auth status after first frame so router can react
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).checkAuthStatus();
    });
  }

  Future<void> _onGoogleSignIn() async {
    await ref.read(authProvider.notifier).signInWithGoogle();
    // GPS 권한 요청은 auth_provider.signInWithGoogle() 내부에서 처리합니다.
    // deniedForever인 경우 location_service.ensurePermission()이
    // 경로 시작 시 설정 안내를 띄웁니다.
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.isLoading;

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
              if (auth.status == AuthStatus.unauthenticated ||
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