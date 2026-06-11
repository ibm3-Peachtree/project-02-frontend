import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/post_model.dart';
import '../providers/community_provider.dart';

class PostCreateScreen extends ConsumerStatefulWidget {
  final int? editPostId;
  const PostCreateScreen({super.key, this.editPostId});

  @override
  ConsumerState<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends ConsumerState<PostCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String? _selectedTransportType; // '버스' | '지하철'
  String? _selectedRoute;
  String? _selectedStation;
  String? _selectedIssueType;
  bool _isSubmitting = false;

  static const _issueTypes = ['지연', '결행', '혼잡', '기타'];

  bool get _isEditMode => widget.editPostId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefillForEdit());
    }
  }

  static const _enumToIssueType = {
    'DELAY':        '지연',
    'CANCELLATION': '결행',
    'CROWD':        '혼잡',
    'ETC':          '기타',
  };

  void _prefillForEdit() {
    final postId = widget.editPostId!;
    final detail = ref.read(postDetailProvider(postId));
    final post = detail.post;
    if (post == null) return;
    _titleController.text   = post.title;
    _contentController.text = post.content;
    setState(() {
      _selectedRoute         = post.lineNumber;
      _selectedStation       = post.stationName.isEmpty ? null : post.stationName;
      _selectedTransportType = post.transportType == 'BUS' ? '버스' : '지하철';
      _selectedIssueType     = _enumToIssueType[post.issueType];
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _showTransportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransportPickerSheet(
        initialTransport: _selectedTransportType,
        initialRoute: _selectedRoute,
        initialStation: _selectedStation,
        onConfirm: (transport, route, station) {
          setState(() {
            _selectedTransportType = transport;
            _selectedRoute = route;
            _selectedStation = station;
          });
        },
      ),
    );
  }

  static const _issueTypeToEnum = {
    '지연': 'DELAY',
    '결행': 'CANCELLATION',
    '혼잡': 'CROWD',
    '기타': 'ETC',
  };
  static const _transportTypeToEnum = {
    '버스':   'BUS',
    '지하철': 'SUBWAY',
  };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTransportType == null || _selectedRoute == null) {
      _showError('교통수단과 노선을 선택해주세요.');
      return;
    }
    if (_selectedIssueType == null) {
      _showError('이슈 유형을 선택해주세요.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final request = CreatePostRequest(
        title:         _titleController.text.trim(),
        content:       _contentController.text.trim(),
        transportType: _transportTypeToEnum[_selectedTransportType] ?? 'BUS',
        lineNumber:    _selectedRoute!,
        stationName:   _selectedStation,
        issueType:     _issueTypeToEnum[_selectedIssueType] ?? 'ETC',
      );

      if (_isEditMode) {
        await ref.read(feedProvider.notifier).updatePost(widget.editPostId!, request);
      } else {
        await ref.read(feedProvider.notifier).createPost(request);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('저장에 실패했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditMode ? '게시글 수정' : '게시글 작성'),
        leading: const CloseButton(),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('등록',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
          children: [
            // 교통수단 / 노선 / 정류장 선택
            _SectionLabel(label: '교통수단 / 노선 · 역(정류장)'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showTransportSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedRoute != null
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: _selectedRoute == null
                    ? Row(
                  children: const [
                    Icon(Icons.directions_transit_outlined,
                        size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('교통수단 / 노선을 선택하세요',
                        style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary)),
                    Spacer(),
                    Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                  ],
                )
                    : Row(
                  children: [
                    _TransportTypeChip(
                        type: _selectedTransportType ?? ''),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedRoute!,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          if (_selectedStation != null) ...[
                            const SizedBox(height: 2),
                            Text(_selectedStation!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _showTransportSheet,
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap),
                      child: const Text('변경',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 이슈 유형
            _SectionLabel(label: '이슈 유형'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _issueTypes.map((t) {
                final selected = _selectedIssueType == t;
                return ChoiceChip(
                  label: Text(t),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedIssueType = t),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 제목
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '제목을 입력하세요',
                border: InputBorder.none,
              ),
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700),
              maxLength: 100,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '제목을 입력해주세요.';
                if (v.trim().length < 5) return '제목은 5자 이상 입력해주세요.';
                return null;
              },
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 본문
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: '내용을 입력하세요. 실제 경험한 교통 상황을 공유해주세요.',
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 15, height: 1.6),
              maxLines: null,
              minLines: 8,
              maxLength: 2000,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '내용을 입력해주세요.';
                if (v.trim().length < 10) return '내용은 10자 이상 입력해주세요.';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary));
}

class _TransportTypeChip extends StatelessWidget {
  final String type;
  const _TransportTypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      '버스'   => (Icons.directions_bus_outlined, Colors.blue),
      '지하철' => (Icons.subway_outlined, Colors.green),
      _        => (Icons.directions_transit_outlined, AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(type,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

// ── 교통수단 선택 바텀 시트 ────────────────────────
class _TransportPickerSheet extends StatefulWidget {
  final String? initialTransport;
  final String? initialRoute;
  final String? initialStation;
  final void Function(String transport, String route, String? station) onConfirm;

  const _TransportPickerSheet({
    this.initialTransport,
    this.initialRoute,
    this.initialStation,
    required this.onConfirm,
  });

  @override
  State<_TransportPickerSheet> createState() => _TransportPickerSheetState();
}

class _TransportPickerSheetState extends State<_TransportPickerSheet> {
  // step: 0=교통수단, 1=노선 입력(버스)/호선 선택(지하철), 2=역/정류장 입력
  int _step = 0;
  String? _transport;
  String? _route;

  // 버스: 직접 입력
  final _busRouteCtrl = TextEditingController();

  // 지하철: 호선 목록
  static const _subwayLines = [
    // 서울 지하철
    '1호선', '2호선', '3호선', '4호선', '5호선',
    '6호선', '7호선', '8호선', '9호선','우이신설선', '신림선'
    // 광역·특수 노선
    '신분당선', '경의중앙선', '수인분당선', '경춘선', '공항철도',
    'GTX-A',
    // 인천·경기
    '인천1호선', '인천2호선', '경강선', '서해선', '수도권경전철의정부',
    '수도권경전철용인', '김포골드라인',
  ];
  static const _subwayColors = <String, Color>{
    // 서울 지하철
    '1호선':           Color(0xFF0052A4),
    '2호선':           Color(0xFF009246),
    '3호선':           Color(0xFFEF7C1C),
    '4호선':           Color(0xFF00A2D1),
    '5호선':           Color(0xFF996CAC),
    '6호선':           Color(0xFFCD7C2F),
    '7호선':           Color(0xFF747F00),
    '8호선':           Color(0xFFE6186C),
    '9호선':           Color(0xFFBDB092),
    '우이신설선':       Color(0xFFB0C700),
    '신림선':          Color(0xFF6789CA),
    // 광역·특수 노선
    '신분당선':         Color(0xFFD4003B),
    '경의중앙선':       Color(0xFF77C4A3),
    '수인분당선':       Color(0xFFFFD600),
    '경춘선':          Color(0xFF158D6B),
    '공항철도':         Color(0xFF2768B2),
    'GTX-A':          Color(0xFF8B5CF6),
    // 인천·경기
    '인천1호선':        Color(0xFF7CA8D5),
    '인천2호선':        Color(0xFFF5A200),
    '경강선':          Color(0xFF003DA5),
    '서해선':          Color(0xFF8BC34A),
    '수도권경전철의정부': Color(0xFFE4AA00),
    '수도권경전철용인':  Color(0xFF7E5BB5),
    '김포골드라인':     Color(0xFFB4983E),
  };

  // 역/정류장: 직접 입력 (선택)
  final _stationCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _transport = widget.initialTransport;
    _route     = widget.initialRoute;
    if (_transport != null) _step = 1;
    if (_route != null) {
      _step = 2;
      if (_transport == '버스') _busRouteCtrl.text = _route!;
    }
    if (widget.initialStation != null) {
      _stationCtrl.text = widget.initialStation!;
    }
  }

  @override
  void dispose() {
    _busRouteCtrl.dispose();
    _stationCtrl.dispose();
    super.dispose();
  }

  String get _title => switch (_step) {
    0 => '교통수단 선택',
    1 => _transport == '버스' ? '버스 노선 번호 입력' : '호선 선택',
    _ => _transport == '버스' ? '정류장 입력 (선택)' : '역 입력 (선택)',
  };

  void _pickTransport(String t) => setState(() {
    _transport = t;
    _route = null;
    _busRouteCtrl.clear();
    _stationCtrl.clear();
    _step = 1;
  });

  void _pickSubwayLine(String line) => setState(() {
    _route = line;
    _stationCtrl.clear();
    _step = 2;
  });

  void _confirmBusRoute() {
    final text = _busRouteCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _route = text;
      _stationCtrl.clear();
      _step = 2;
    });
  }

  void _confirmFinal() {
    final station = _stationCtrl.text.trim();
    widget.onConfirm(_transport!, _route!, station.isEmpty ? null : station);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              children: [
                if (_step > 0)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() {
                      _step--;
                      if (_step == 0) {
                        _transport = null;
                        _route = null;
                        _busRouteCtrl.clear();
                        _stationCtrl.clear();
                      }
                      if (_step == 1) {
                        _route = null;
                        _stationCtrl.clear();
                      }
                    }),
                  ),
                if (_step > 0) const SizedBox(width: 8),
                Text(_title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // 브레드크럼
          if (_step > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  if (_transport != null) ...[
                    _TransportTypeChip(type: _transport!),
                    const SizedBox(width: 4),
                  ],
                  if (_route != null) ...[
                    const Icon(Icons.chevron_right,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 2),
                    Text(_route!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),

          // ── Step 0: 교통수단 선택 (버스 / 지하철만) ──
          if (_step == 0)
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 16),
                child: Column(
                  children: [
                    _TransportOption(
                      icon: Icons.directions_bus_outlined,
                      label: '버스',
                      color: Colors.blue,
                      desc: '노선 번호를 직접 입력',
                      onTap: () => _pickTransport('버스'),
                    ),
                    const SizedBox(height: 10),
                    _TransportOption(
                      icon: Icons.subway_outlined,
                      label: '지하철',
                      color: Colors.green,
                      desc: '호선 선택 후 역 입력',
                      onTap: () => _pickTransport('지하철'),
                    ),
                  ],
                ),
              ),
            ),

          // ── Step 1 (버스): 노선 번호 직접 입력 ──
          if (_step == 1 && _transport == '버스')
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad + 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _busRouteCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: '예) 147, M5107, 9401',
                        prefixIcon: Icon(Icons.edit_outlined, size: 20),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _confirmBusRoute(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '버스 노선 번호를 입력해주세요.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _confirmBusRoute,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('다음',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),

          // ── Step 1 (지하철): 호선 그리드 선택 ──
          if (_step == 1 && _transport == '지하철')
            Expanded(
              child: _SubwayLineGrid(
                lines: _subwayLines,
                colors: _subwayColors,
                onSelect: _pickSubwayLine,
              ),
            ),

          // ── Step 2: 역/정류장 입력 (선택 사항) ──
          if (_step == 2)
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad + 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _stationCtrl,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: _transport == '버스'
                            ? '예) 강남역 버스정류장'
                            : '예) 강남역',
                        prefixIcon:
                        const Icon(Icons.place_outlined, size: 20),
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _confirmFinal(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '입력하지 않아도 됩니다 (선택)',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        // 건너뛰기
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _stationCtrl.clear();
                              _confirmFinal();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(
                                  color: AppColors.border),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(10)),
                            ),
                            child: const Text('건너뛰기',
                                style: TextStyle(fontSize: 15)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // 확인
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _confirmFinal,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(10)),
                            ),
                            child: const Text('확인',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String desc;
  final VoidCallback onTap;

  const _TransportOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary)),
            ],
          ),
          const Spacer(),
          Icon(Icons.chevron_right, color: color),
        ],
      ),
    ),
  );
}

class _SubwayLineGrid extends StatelessWidget {
  final List<String> lines;
  final Map<String, Color> colors;
  final void Function(String) onSelect;

  const _SubwayLineGrid({
    required this.lines,
    required this.colors,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: lines.map((line) {
        final color = colors[line] ?? AppColors.primary;
        return InkWell(
          onTap: () => onSelect(line),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(line,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}