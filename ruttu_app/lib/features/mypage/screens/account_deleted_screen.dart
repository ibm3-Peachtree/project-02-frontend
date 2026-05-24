import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_constants.dart';

class AccountDeletedScreen extends StatelessWidget {
  const AccountDeletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
          child: Column(
            children: [
              // 앱 로고
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_bus_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 8),
                  const Text('RUTTU',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ],
              ),

              const Spacer(),

              // 일러스트 영역
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.door_back_door_outlined,
                    size: 64, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),

              // 타이틀
              const Text(
                '탈퇴가 완료되었어요',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // 내용
              const Text(
                '그동안 RUTTU를 이용해주셔서 감사해요.\n언제든 다시 돌아오세요 🙂',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.6),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go(RouteConstants.splash),
                  child: const Text('처음 화면으로'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
