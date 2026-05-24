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

  String? _selectedTransportType; // '버스' | '지하철' | '도로현황'
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

  void _prefillForEdit() {
    final postId = widget.editPostId!;
    final detail = ref.read(postDetailProvider(postId));
    final post = detail.post;
    if (post == null) {
      return;
    }
    _titleController.text   = post.title;
    _contentController.text = post.content;
    setState(() {
      _selectedRoute   = post.route;
      _selectedStation = post.station;
      _selectedTransportType = _inferTransportType(post.route);
    });
  }

  String _inferTransportType(String route) {
    if (route.contains('호선') || route.contains('신분당선') ||
        route.contains('경의중앙')) {
      return '지하철';
    }
    if (RegExp(r'^\d').hasMatch(route) || route.startsWith('M')) {
      return '버스';
    }
    return '도로현황';
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoute == null) {
      _showError('노선을 선택해주세요.');
      return;
    }
    if (_selectedStation == null) {
      _showError('정류장/역을 선택해주세요.');
      return;
    }
    if (_selectedIssueType == null) {
      _showError('이슈 유형을 선택해주세요.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      await repo.createPost(CreatePostRequest(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        route: _selectedRoute!,
        station: _selectedStation!,
        issueType: _selectedIssueType!,
      ));
      await ref.read(feedProvider.notifier).load();
      if (mounted) Navigator.pop(context);
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
            _SectionLabel(label: '교통수단 / 노선 / 정류장'),
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
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
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
                                          color:
                                              AppColors.textSecondary)),
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
      '버스'     => (Icons.directions_bus_outlined, Colors.blue),
      '지하철'   => (Icons.subway_outlined, Colors.green),
      '도로현황' => (Icons.traffic_outlined, Colors.orange),
      _          => (Icons.directions_transit_outlined, AppColors.primary),
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
  final void Function(String transport, String route, String? station)
      onConfirm;

  const _TransportPickerSheet({
    this.initialTransport,
    this.initialRoute,
    this.initialStation,
    required this.onConfirm,
  });

  @override
  State<_TransportPickerSheet> createState() =>
      _TransportPickerSheetState();
}

class _TransportPickerSheetState extends State<_TransportPickerSheet> {
  int _step = 0; // 0=교통수단, 1=노선/호선/도로, 2=정류장/역
  String? _transport;
  String? _route;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Mock 데이터
  static const _busRoutes = [
    '7770', '147', 'M5107', '9', '472', '3030', '1001', 'M6450',
  ];
  static const _busStops = <String, List<String>>{
    '7770':  ['수원역 버스정류장', '교대역 정류장', '사당역 정류장', '방배역 정류장'],
    '147':   ['강남역 버스정류장', '양재역 정류장', '매봉역 정류장'],
    'M5107': ['수원역 환승센터', '판교역 정류장', '강남역 정류장'],
    '9':     ['김포공항 정류장', '당산역 정류장', '여의도역 정류장', '노량진역 정류장'],
    '472':   ['을지로2가 정류장', '시청역 정류장', '충정로역 정류장'],
    '3030':  ['잠실역 정류장', '강변역 정류장', '구리시 정류장'],
    '1001':  ['강남역 정류장', '서초역 정류장', '남부터미널 정류장'],
    'M6450': ['수지구청역 정류장', '판교역 정류장', '강남역 정류장'],
  };

  static const _subwayLines = [
    '1호선', '2호선', '3호선', '4호선', '5호선',
    '6호선', '7호선', '8호선', '9호선', '신분당선', '경의중앙선',
  ];
  static const _subwayColors = <String, Color>{
    '1호선':    Color(0xFF0052A4),
    '2호선':    Color(0xFF009246),
    '3호선':    Color(0xFFEF7C1C),
    '4호선':    Color(0xFF00A2D1),
    '5호선':    Color(0xFF996CAC),
    '6호선':    Color(0xFFCD7C2F),
    '7호선':    Color(0xFF747F00),
    '8호선':    Color(0xFFE6186C),
    '9호선':    Color(0xFFBDB092),
    '신분당선':  Color(0xFFD4003B),
    '경의중앙선': Color(0xFF77C4A3),
  };
  static const _subwayStations = <String, List<String>>{
    '1호선':    ['수원역', '서울역', '종각역', '동대문역', '청량리역', '의정부역'],
    '2호선':    ['강남역', '역삼역', '선릉역', '삼성역', '당산역', '홍대입구역', '사당역', '잠실역'],
    '3호선':    ['양재역', '매봉역', '도곡역', '대치역', '학여울역', '수서역'],
    '4호선':    ['사당역', '이수역', '동작역', '총신대입구역', '서울역', '미아역'],
    '5호선':    ['여의도역', '마포역', '공덕역', '서대문역', '광화문역'],
    '6호선':    ['이태원역', '한강진역', '녹사평역', '삼각지역'],
    '7호선':    ['건대입구역', '뚝섬유원지역', '청담역', '강남구청역'],
    '8호선':    ['잠실역', '석촌역', '복정역', '모란역'],
    '9호선':    ['당산역', '여의도역', '노량진역', '동작역', '고속터미널역', '신논현역'],
    '신분당선':  ['강남역', '양재역', '판교역', '정자역', '광교역'],
    '경의중앙선': ['서울역', '신촌역', '수색역', '능곡역', '행신역'],
  };

  static const _roads = [
    '경부고속도로', '서해안고속도로', '중부고속도로', '영동고속도로',
    '강남대로', '올림픽대로', '내부순환로', '경부간선도로',
    '한남대교', '반포대교', '동작대교', '성수대교',
  ];

  @override
  void initState() {
    super.initState();
    _transport = widget.initialTransport;
    _route     = widget.initialRoute;
    if (_transport != null) _step = 1;
    if (_route != null) _step = 2;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _list {
    if (_step == 1) {
      final src = _transport == '버스'
          ? _busRoutes.toList()
          : _transport == '지하철'
              ? _subwayLines.toList()
              : _roads.toList();
      if (_query.isEmpty) return src;
      return src.where((s) => s.contains(_query)).toList();
    }
    if (_step == 2) {
      final src = _transport == '버스'
          ? (_busStops[_route] ?? <String>[])
          : (_subwayStations[_route] ?? <String>[]);
      if (_query.isEmpty) return src;
      return src.where((s) => s.contains(_query)).toList();
    }
    return [];
  }

  String get _title => switch (_step) {
        0 => '교통수단 선택',
        1 => _transport == '버스'
            ? '노선 번호 선택'
            : _transport == '지하철'
                ? '호선 선택'
                : '도로 / 구간 선택',
        _ => _transport == '버스' ? '정류장 선택' : '역 선택',
      };

  void _pickTransport(String t) => setState(() {
        _transport = t;
        _route = null;
        _query = '';
        _searchCtrl.clear();
        _step = 1;
      });

  void _pickRoute(String r) {
    if (_transport == '도로현황') {
      widget.onConfirm(_transport!, r, null);
      Navigator.pop(context);
      return;
    }
    setState(() {
      _route = r;
      _query = '';
      _searchCtrl.clear();
      _step = 2;
    });
  }

  void _pickStation(String s) {
    widget.onConfirm(_transport!, _route!, s);
    Navigator.pop(context);
  }

  void _directInput() {
    final text = _searchCtrl.text.trim();
    if (text.isEmpty) return;
    if (_step == 1) {
      _pickRoute(text);
    } else {
      _pickStation(text);
    }
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
                      _query = '';
                      _searchCtrl.clear();
                      if (_step == 0) _transport = null;
                      if (_step < 2) _route = null;
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

          // Step 0: 교통수단 선택
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
                      desc: '버스 노선 번호로 검색',
                      onTap: () => _pickTransport('버스'),
                    ),
                    const SizedBox(height: 10),
                    _TransportOption(
                      icon: Icons.subway_outlined,
                      label: '지하철',
                      color: Colors.green,
                      desc: '호선 선택 후 역 검색',
                      onTap: () => _pickTransport('지하철'),
                    ),
                    const SizedBox(height: 10),
                    _TransportOption(
                      icon: Icons.traffic_outlined,
                      label: '도로현황',
                      color: Colors.orange,
                      desc: '도로/구간 선택',
                      onTap: () => _pickTransport('도로현황'),
                    ),
                  ],
                ),
              ),
            ),

          // Step 1 & 2: 검색 + 목록
          if (_step > 0) ...[
            // 검색창
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: _step == 1
                            ? (_transport == '지하철'
                                ? '호선 검색'
                                : '검색 또는 직접 입력')
                            : '검색 또는 직접 입력',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  // 지하철 호선 선택은 직접 입력 불필요
                  if (!(_step == 1 && _transport == '지하철')) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _directInput,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side:
                            const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('직접 입력',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
            // 목록
            Expanded(
              child: _step == 1 && _transport == '지하철'
                  ? _SubwayLineGrid(
                      lines: _subwayLines,
                      colors: _subwayColors,
                      onSelect: _pickRoute,
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                          16, 0, 16, bottomPad + 16),
                      itemCount: _list.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        title: Text(_list[i],
                            style: const TextStyle(fontSize: 14)),
                        trailing: const Icon(Icons.chevron_right,
                            size: 18,
                            color: AppColors.textSecondary),
                        onTap: () => _step == 1
                            ? _pickRoute(_list[i])
                            : _pickStation(_list[i]),
                      ),
                    ),
            ),
          ],
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
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 18),
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
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
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
            child: Text(line,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
        );
      }).toList(),
    );
  }
}
