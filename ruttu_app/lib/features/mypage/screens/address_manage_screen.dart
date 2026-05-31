import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kakao_postcode_page.dart';
import '../../../data/models/address_model.dart';
import '../../auth/providers/network_provider.dart';

// ── 주소 목록 FutureProvider ───────────────────────────
final _addressListProvider = FutureProvider.autoDispose<List<AddressModel>>((ref) async {
  final res = await ref.read(apiClientProvider).dio.get('/address');
  final list = res.data as List<dynamic>;
  return list.map((e) => AddressModel.fromJson(e as Map<String, dynamic>)).toList();
});

class AddressManageScreen extends ConsumerWidget {
  const AddressManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAddresses = ref.watch(_addressListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('주소 관리',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        leading: const BackButton(),
        actions: [
          TextButton(
            onPressed: () async {
              await _showAddSheet(context, ref, null);
            },
            child: const Text('추가',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: asyncAddresses.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('주소를 불러올 수 없어요: $e')),
        data: (addresses) => addresses.isEmpty
            ? _EmptyView(onAdd: () => _showAddSheet(context, ref, null))
            : ListView(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
                children: [
                  ...addresses.map((a) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const Icon(Icons.location_on_outlined,
                              color: AppColors.primary),
                          title: Text(a.name,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          subtitle: Text(a.roadAddress,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 20,
                                    color: AppColors.textSecondary),
                                onPressed: () =>
                                    _showAddSheet(context, ref, a),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20,
                                    color: AppColors.textSecondary),
                                onPressed: () =>
                                    _confirmDelete(context, ref, a),
                              ),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _showAddSheet(context, ref, null),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('주소 추가하기'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _showAddSheet(
      BuildContext context, WidgetRef ref, AddressModel? editing) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final currentAddresses = ref.read(_addressListProvider).valueOrNull ?? [];
        return _AddressFormSheet(
        editing: editing,
        existingAddresses: currentAddresses,
        onSave: (name, roadAddress, jibunAddress) async {
          final apiClient = ref.read(apiClientProvider);
          try {
            if (editing != null) {
              await apiClient.dio.put('/address/${editing.addressId}', data: {
                'name': name,
                'roadAddress': roadAddress,
                'jibunAddress': jibunAddress,
              });
            } else {
              await apiClient.dio.post('/address', data: {
                'name': name,
                'roadAddress': roadAddress,
                'jibunAddress': jibunAddress,
              });
            }
            ref.invalidate(_addressListProvider);
            if (ctx.mounted) Navigator.pop(ctx);
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('저장에 실패했어요: $e')));
            }
          }
        },
        );
      },
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, AddressModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('주소를 삭제할까요?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text("'${item.name}' 주소가 삭제됩니다.",
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(apiClientProvider).dio.delete('/address/${item.addressId}');
                ref.invalidate(_addressListProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('삭제에 실패했어요: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child:
                const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── 주소 없을 때 빈 화면 ───────────────────────────────
class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined,
                size: 64, color: AppColors.border),
            const SizedBox(height: 16),
            const Text('저장된 주소가 없어요',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            const Text(
              '자주 가는 장소를 등록하면\n루틴 설정이 편리해요',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14)),
              child: const Text('주소 추가하기',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
}

// ── 주소 추가/수정 시트 ───────────────────────────────
class _AddressFormSheet extends StatefulWidget {
  final AddressModel? editing;
  final List<AddressModel> existingAddresses;
  final Future<void> Function(String name, String roadAddress,
      String jibunAddress) onSave;

  const _AddressFormSheet({
    this.editing,
    required this.existingAddresses,
    required this.onSave,
  });

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _nameCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  KakaoPostcodeResult? _kakaoResult;
  String? _prefilledAddress;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      _nameCtrl.text = widget.editing!.name;
      _prefilledAddress = widget.editing!.roadAddress;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  bool get _hasAddress => _kakaoResult != null || _prefilledAddress != null;

  Future<void> _searchAddress() async {
    final result = await Navigator.of(context, rootNavigator: true).push<KakaoPostcodeResult>(
      MaterialPageRoute(builder: (_) => const KakaoPostcodePage()),
    );
    if (result != null) setState(() => _kakaoResult = result);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('장소 이름을 입력해주세요.')));
      return;
    }
    if (!_hasAddress) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('주소를 검색하여 선택해주세요.')));
      return;
    }

    final detail = _detailCtrl.text.trim();
    final String roadAddress;
    final String jibunAddress;

    if (_kakaoResult != null) {
      roadAddress = detail.isEmpty
          ? _kakaoResult!.roadAddress
          : '${_kakaoResult!.roadAddress} $detail';
      jibunAddress = _kakaoResult!.jibunAddress;
    } else {
      roadAddress = _prefilledAddress!;
      jibunAddress = widget.editing?.jibunAddress ?? '';
    }

    // 중복 이름 체크 (수정 시 자기 자신 제외)
    final inputName = _nameCtrl.text.trim();
    final isDuplicate = widget.existingAddresses.any((a) =>
        a.name == inputName &&
        (widget.editing == null || a.addressId != widget.editing!.addressId));
    if (isDuplicate) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('이름 중복',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: const Text('이미 사용 중인 장소 이름이에요.\n다른 이름을 입력해주세요.',
              style: TextStyle(fontSize: 14)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: const Text('확인',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
      return;
    }

    setState(() => _saving = true);
    await widget.onSave(inputName, roadAddress, jibunAddress);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final navBar = MediaQuery.of(context).viewPadding.bottom;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, inset + navBar + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.editing == null ? '주소 추가' : '주소 수정',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            const Text('장소 이름',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              maxLength: 10,
              decoration: const InputDecoration(
                  hintText: '예) 집, 회사, 헬스장', counterText: ''),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: ['집', '회사', '학교', '기타'].map((t) {
                return ActionChip(
                  label: Text(t, style: const TextStyle(fontSize: 13)),
                  onPressed: () => setState(() => _nameCtrl.text = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            const Text('주소',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),

            if (!_hasAddress) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _searchAddress,
                  icon: const Icon(Icons.search),
                  label: const Text('주소 검색'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_kakaoResult != null &&
                              _kakaoResult!.zonecode.isNotEmpty)
                            Text('[${_kakaoResult!.zonecode}]',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          Text(
                            _kakaoResult?.roadAddress ?? _prefilledAddress!,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (_kakaoResult != null &&
                              _kakaoResult!.jibunAddress.isNotEmpty)
                            Text(_kakaoResult!.jibunAddress,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _searchAddress,
                      child: const Text('다시 검색',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
              if (_kakaoResult != null) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _detailCtrl,
                  decoration: const InputDecoration(
                      hintText: '상세 주소 입력 (예: 101호, 3층) — 선택'),
                ),
              ],
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
                child: _saving
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
      ),
    );
  }
}