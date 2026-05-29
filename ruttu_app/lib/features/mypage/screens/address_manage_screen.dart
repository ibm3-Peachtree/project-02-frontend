import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kakao_postcode_page.dart';

class _AddressItem {
  final int id;
  final String name;
  final String address;

  const _AddressItem(
      {required this.id, required this.name, required this.address});
}

class AddressManageScreen extends StatefulWidget {
  const AddressManageScreen({super.key});

  @override
  State<AddressManageScreen> createState() => _AddressManageScreenState();
}

class _AddressManageScreenState extends State<AddressManageScreen> {
  final List<_AddressItem> _addresses = [
    const _AddressItem(
        id: 1, name: '집', address: '서울특별시 강남구 역삼동 123'),
    const _AddressItem(
        id: 2, name: '회사', address: '서울특별시 중구 을지로 100'),
  ];

  void _showAddSheet({_AddressItem? editing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddressFormSheet(
        editing: editing,
        onSave: (name, address) {
          setState(() {
            if (editing != null) {
              final idx = _addresses.indexWhere((a) => a.id == editing.id);
              if (idx != -1) {
                _addresses[idx] =
                    _AddressItem(id: editing.id, name: name, address: address);
              }
            } else {
              _addresses.add(_AddressItem(
                id: DateTime.now().millisecondsSinceEpoch,
                name: name,
                address: address,
              ));
            }
          });
          Navigator.pop(ctx);
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

  void _confirmDelete(_AddressItem item) {
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
            onPressed: () {
              setState(() =>
                  _addresses.removeWhere((a) => a.id == item.id));
              Navigator.pop(ctx);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('삭제',
                style: TextStyle(color: Colors.white)),
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
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _addresses.isEmpty
          ? Center(
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
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
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
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
              children: [
                ..._addresses.map((a) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.location_on_outlined,
                            color: AppColors.primary),
                        title: Text(a.name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(a.address,
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
                              onPressed: () => _showAddSheet(editing: a),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20,
                                  color: AppColors.textSecondary),
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
                      side:
                          const BorderSide(color: AppColors.primary),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('주소 추가하기'),
                ),
              ],
            ),
    );
  }
}

// ── 주소 추가/수정 시트 ────────────────────────────────
class _AddressFormSheet extends StatefulWidget {
  final _AddressItem? editing;
  final void Function(String name, String address) onSave;
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
  // 수정 모드에서 기존 주소를 표시하기 위해 유지
  String? _prefilledAddress;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      _nameCtrl.text = widget.editing!.name;
      _prefilledAddress = widget.editing!.address;
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
    print("🔥 _save 함수 진입");
    if (_nameCtrl.text.trim().isEmpty) {
      print("🔥 이름 없음 - return");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('장소 이름을 입력해주세요.')));
      return;
    }
    if (!_hasAddress) {
      print("🔥 주소 없음 - return");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주소를 검색하여 선택해주세요.')));
      return;
    }
    final detail = _detailCtrl.text.trim();
    final String fullAddress;
    if (_kakaoResult != null) {
      fullAddress = detail.isEmpty
          ? _kakaoResult!.roadAddress
          : '${_kakaoResult!.roadAddress} $detail';
    } else {
      fullAddress = _prefilledAddress!;
    }
    print("🔥 onSave 호출 직전");
    print("🔥 name = ${_nameCtrl.text.trim()}");
    print("🔥 address = $fullAddress");
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
