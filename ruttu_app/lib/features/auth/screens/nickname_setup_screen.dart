import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class NicknameSetupScreen extends ConsumerStatefulWidget {
  const NicknameSetupScreen({super.key});

  @override
  ConsumerState<NicknameSetupScreen> createState() =>
      _NicknameSetupScreenState();
}

class _NicknameSetupScreenState extends ConsumerState<NicknameSetupScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isDuplicate = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    if (value == null || value.trim().isEmpty) return '닉네임을 입력해주세요.';
    if (value.trim().length < 2) return '닉네임은 2자 이상이어야 합니다.';
    if (value.trim().length > 10) return '닉네임은 10자 이하여야 합니다.';
    if (!RegExp(r'^[가-힣a-zA-Z0-9_]+$').hasMatch(value.trim())) {
      return '한글, 영문, 숫자, 밑줄(_)만 사용할 수 있습니다.';
    }
    if (_isDuplicate) return '이미 사용 중인 닉네임입니다.';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _isDuplicate = false);
    if (!_formKey.currentState!.validate()) return;

    final nickname = _controller.text.trim();
    final success =
        await ref.read(authProvider.notifier).setNickname(nickname);

    if (!success && mounted) {
      setState(() => _isDuplicate = true);
      _formKey.currentState!.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                const Text(
                  '닉네임을 설정해주세요',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '루뚜에서 사용할 닉네임을 입력해주세요.\n닉네임은 나중에 변경할 수 있습니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _controller,
                  validator: _validate,
                  maxLength: 10,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: '닉네임',
                    hintText: '2~10자, 한글/영문/숫자/_',
                    counterText: '',
                  ),
                  onChanged: (_) {
                    if (_isDuplicate) setState(() => _isDuplicate = false);
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('시작하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
