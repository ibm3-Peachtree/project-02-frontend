import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kakao_postcode_page.dart';
import '../../../data/models/address_model.dart';
import '../../../features/home/providers/address_provider.dart';

class AddressManageScreen extends ConsumerStatefulWidget {
  const AddressManageScreen({super.key});

  @override
  ConsumerState<AddressManageScreen> createState() =>
      _AddressManageScreenState();
}

class _AddressManageScreenState extends ConsumerState<AddressManageScreen> {
  // 서버에서 불러온 주소 목록
  List<AddressModel> _addresses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  /// 주소 목록 조회
  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(addressRepositoryProvider);
      final result = await repo.getAddresses();
      setState(() => _addresses = result);
    } catch (e) {
      setState(() => _errorMessage = '주소를 불러오지 못했어요. 다시 시도해주세요.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 주소 추가/수정 바텀시트 열기
  void _showAddSheet({AddressModel? editing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddressFormSheet(
        editing: editing,
        onSave: (name, roadAddress, jibunAddress) async {
          Navigator.pop(ctx);
          await _handleSave(
            editing: editing,
            name: name,
            roadAddress: roadAddress,
            jibunAddress: jibunAddress,
          );
        },
        onDelete: editing != null
            ? () {
          Navigator.pop(ctx);
          _confirmDelete(editing);
        }
            : null,
      ),
    );
  }

  /// 저장 처리 (추가만 구현; 수정은 API 준비 후 확장)
  Future<void> _handleSave({
    AddressModel? editing,
    required String name,
    required String roadAddress,
    String? jibunAddress,
  }) async {
    try {
      final repo = ref.read(addressRepositoryProvider);

      if (editing == null) {
        // ── 주소 생성 API 호출 ──
        final created = await repo.addAddress(
          name: name,
          roadAddress: roadAddress,
          jibunAddress: jibunAddress,
        );
        setState(() => _addresses.add(created));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('주소가 저장되었어요.')),
          );
        }
      } else {
        // TODO: 수정 API 연동 (PUT /address/{id}) 준비되면 여기에 추가
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('수정 기능은 준비 중이에요.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했어요. 다시 시도해주세요.')),
        );
      }
    }
  }

  /// 삭제 확인 다이얼로그
  void _confirmDelete(AddressModel item) {
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
              // TODO: 삭제 API 연동 (DELETE /address/{id}) 준비되면 여기에 추가
              setState(() =>
                  _addresses.removeWhere((a) => a.addressId == item.addressId));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('주소가 삭제되었어요.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('주소 관리',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        leading: const BackButton(),
        actions: [
          TextButton(
            onPressed: () => _showAddSheet(),
            child: const Text('추가',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_errorMessage!,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAddresses,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (_addresses.isEmpty) {
      return Center(
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
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _showAddSheet(),
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
    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
      children: [
        ..._addresses.map((a) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.location_on_outlined,
                color: AppColors.primary),
            title: Text(a.name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: Text(a.roadAddress,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 20, color: AppColors.textSecondary),
                  onPressed: () => _showAddSheet(editing: a),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppColors.textSecondary),
                  onPressed: () => _confirmDelete(a),
                ),
              ],
            ),
          ),
        )),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _showAddSheet(),
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('주소 추가하기'),
        ),
      ],
    );
  }
}

// ── 주소 추가/수정 시트 ────────────────────────────────
class _AddressFormSheet extends StatefulWidget {
  final AddressModel? editing;
  final void Function(String name, String roadAddress, String? jibunAddress)
  onSave;
  final VoidCallback? onDelete;

  const _AddressFormSheet({
    this.editing,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _nameCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  KakaoPostcodeResult? _kakaoResult;
  String? _prefilledAddress;

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
    final result = await Navigator.push<KakaoPostcodeResult>(
      context,
      MaterialPageRoute(builder: (_) => const KakaoPostcodePage()),
    );
    if (result != null) setState(() => _kakaoResult = result);
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('장소 이름을 입력해주세요.')));
      return;
    }
    if (!_hasAddress) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주소를 검색하여 선택해주세요.')));
      return;
    }

    final detail = _detailCtrl.text.trim();

    // 도로명 주소
    final String roadAddress;
    if (_kakaoResult != null) {
      roadAddress = detail.isEmpty
          ? _kakaoResult!.roadAddress
          : '${_kakaoResult!.roadAddress} $detail';
    } else {
      roadAddress = _prefilledAddress!;
    }

    // 지번 주소 (카카오 결과에서만 가져옴)
    final String? jibunAddress =
    _kakaoResult != null && _kakaoResult!.jibunAddress.isNotEmpty
        ? _kakaoResult!.jibunAddress
        : null;

    widget.onSave(_nameCtrl.text.trim(), roadAddress, jibunAddress);
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
            // 헤더
            Row(
              children: [
                Text(widget.editing == null ? '주소 추가' : '주소 수정',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (widget.onDelete != null)
                  TextButton(
                    onPressed: widget.onDelete,
                    child: const Text('삭제',
                        style: TextStyle(color: AppColors.error)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 장소 이름
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

            // 주소
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
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
                child: const Text('저장하기',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}