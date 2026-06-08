import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/route_model.dart';
import '../providers/reco_live_route_provider.dart';
import '../providers/home_provider.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 추천 경로 실시간 안내 화면
// - "이 경로로 변경" 후 진입
// - GET /me/routines/active/reco/{recoId}  → 경로 상세
// - GET /me/routines/active/location/reco → 현재 구간 (30초 폴링)
// - 나의 경로와 완전히 독립 (별도 provider 사용)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class RecoLiveRouteScreen extends ConsumerStatefulWidget {
  final int recoId;
  /// 우회 경로 선택 시 true. pathId == recoId로 전달됨.
  /// true이면 initDetour(recoId), false이면 init(recoId) 호출.
  final bool isDetour;
  /// true이면 탭 내부 인라인 표시 — Scaffold/SafeArea를 사용하지 않음.
  /// false(기본)이면 Navigator.push로 전체 화면 표시.
  final bool isInline;
  /// 인라인 모드에서 종료 시 호출할 콜백.
  final VoidCallback? onStop;

  const RecoLiveRouteScreen({
    super.key,
    required this.recoId,
    this.isDetour = false,
    this.isInline = false,
    this.onStop,
  });

  @override
  ConsumerState<RecoLiveRouteScreen> createState() =>
      _RecoLiveRouteScreenState();
}

class _RecoLiveRouteScreenState extends ConsumerState<RecoLiveRouteScreen> {
  // 정거장 목록 펼침 상태 (pathIndex → expanded)
  final Map<int, bool> _expandedStops = {};
  NaverMapController? _mapController;
  // _onMapReady 시점에 routeDetail이 아직 없으면 true로 설정,
  // 이후 routeDetail이 도착했을 때 지도를 그린다.
  bool _pendingDraw = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // STOMP section 수신 시 homeProvider도 즉시 동기화
      // → _poll()의 recoStepIdx 재계산에 최신 recoCurrentSectionData가 반영됨
      ref.read(recoLiveRouteProvider.notifier).onSectionUpdate = (section) {
        try {
          ref.read(homeProvider.notifier).updateRecoSection(section);
        } catch (_) {}
      };
      if (widget.isDetour) {
        ref.read(recoLiveRouteProvider.notifier).initDetour(widget.recoId);
      } else {
        ref.read(recoLiveRouteProvider.notifier).init(widget.recoId);
      }
    });
  }

  @override
  void dispose() {
    ref.read(recoLiveRouteProvider.notifier).stop();
    super.dispose();
  }

  // 경로 데이터가 바뀌면 지도에 다시 그림
  void _onMapReady(NaverMapController controller) {
    _mapController = controller;
    final state = ref.read(recoLiveRouteProvider);
    if (state.routeDetail != null) {
      _drawRoute(controller, state);
    } else {
      // routeDetail 아직 미도착 — fetch 완료 시 ref.listen이 그려줌
      _pendingDraw = true;
      _moveToCurrentLocation(controller);
    }
  }

  Future<void> _drawRoute(NaverMapController controller, RecoLiveRouteState state) async {
    await controller.clearOverlays();

    // path 에서 좌표 추출 (stationName 기반 — 실제 좌표는 currentSection.xy 사용)
    final section = state.currentSection;
    if (section != null && section.xy.isNotEmpty) {
      final validPoints = section.xy
          .where((c) => c.x != null && c.y != null)
          .map((c) => (pt: NLatLng(c.y!, c.x!), type: c.type ?? 'walk'))
          .toList();

      if (validPoints.length >= 2) {
        await _drawPolylines(controller, validPoints);

        // 현재 위치 마커
        final curIdx = section.idx.clamp(0, validPoints.length - 1);
        final curPt = validPoints[curIdx].pt;
        await controller.addOverlay(
          NMarker(id: 'reco_current', position: curPt)
            ..setCaption(NOverlayCaption(text: '현재', textSize: 12)),
        );

        // 카메라 이동
        await _fitBounds(controller, validPoints.map((e) => e.pt).toList());
        return;
      }
    }

    _moveToCurrentLocation(controller);
  }

  Future<void> _drawPolylines(
    NaverMapController controller,
    List<({NLatLng pt, String type})> points,
  ) async {
    Color typeColor(String type) {
      switch (type) {
        case 'subway': return AppColors.subway;
        case 'bus': return const Color(0xFF22C55E);
        default: return const Color(0xFF9CA3AF);
      }
    }

    // 타입별 세그먼트 그룹핑
    String curType = points.first.type;
    List<NLatLng> curPts = [points.first.pt];
    int segIdx = 0;

    for (var i = 1; i < points.length; i++) {
      final item = points[i];
      if (item.type != curType) {
        if (curPts.length >= 2) {
          await controller.addOverlay(NPolylineOverlay(
            id: 'reco_seg_$segIdx',
            coords: curPts,
            color: typeColor(curType),
            width: curType == 'walk' ? 3.0 : 6.0,
          ));
          segIdx++;
        }
        curType = item.type;
        curPts = [curPts.last, item.pt];
      } else {
        curPts.add(item.pt);
      }
    }
    if (curPts.length >= 2) {
      await controller.addOverlay(NPolylineOverlay(
        id: 'reco_seg_$segIdx',
        coords: curPts,
        color: typeColor(curType),
        width: curType == 'walk' ? 3.0 : 6.0,
      ));
    }

    // 출발·도착 마커
    await controller.addOverlay(
      NMarker(id: 'reco_start', position: points.first.pt)
        ..setCaption(NOverlayCaption(text: '출발', textSize: 12)),
    );
    await controller.addOverlay(
      NMarker(id: 'reco_end', position: points.last.pt)
        ..setCaption(NOverlayCaption(text: '도착', textSize: 12)),
    );
  }

  Future<void> _fitBounds(NaverMapController controller, List<NLatLng> pts) async {
    final lats = pts.map((e) => e.latitude).toList();
    final lngs = pts.map((e) => e.longitude).toList();
    await controller.updateCamera(NCameraUpdate.fitBounds(
      NLatLngBounds(
        southWest: NLatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
        northEast: NLatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
      ),
      padding: const EdgeInsets.all(60),
    ));
  }

  Future<void> _moveToCurrentLocation(NaverMapController controller) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await controller.updateCamera(NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(pos.latitude, pos.longitude),
        zoom: 15,
      ));
    } catch (_) {}
  }

  // currentSection이 업데이트되면 현재 위치 마커만 갱신
  Future<void> _updateCurrentMarker(CurrentSectionModel section) async {
    final ctrl = _mapController;
    if (ctrl == null) return;
    final cur = section.currentXY;
    if (cur == null || cur.x == null || cur.y == null) return;
    await ctrl.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: 'reco_current'));
    await ctrl.addOverlay(
      NMarker(id: 'reco_current', position: NLatLng(cur.y!, cur.x!))
        ..setCaption(NOverlayCaption(text: '현재', textSize: 12)),
    );
    await ctrl.updateCamera(NCameraUpdate.scrollAndZoomTo(
      target: NLatLng(cur.y!, cur.x!),
      zoom: 15,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recoLiveRouteProvider);

    // currentSection 변경 시 마커 갱신
    ref.listen<RecoLiveRouteState>(recoLiveRouteProvider, (prev, next) {
      if (next.currentSection != null &&
          next.currentSection != prev?.currentSection) {
        _updateCurrentMarker(next.currentSection!);
      }
      // routeDetail이 처음 도착했을 때 지도 그리기 + 정거장 모두 펼치기
      // (_pendingDraw: 지도가 먼저 준비됐지만 데이터가 없었던 경우)
      if (prev?.routeDetail == null && next.routeDetail != null) {
        final ctrl = _mapController;
        if (ctrl != null) {
          _pendingDraw = false;
          _drawRoute(ctrl, next);
        } else {
          // 지도 자체가 아직 준비 안 됨 — _onMapReady에서 처리됨
          _pendingDraw = true;
        }
        // 정거장이 있는 경로를 모두 펼친 상태로 초기화
        setState(() {
          for (int i = 0; i < next.routeDetail!.path.length; i++) {
            final path = next.routeDetail!.path[i];
            if (path.stationName.isNotEmpty && !path.isWalking) {
              _expandedStops[i] = true;
            }
          }
        });
      }
    });

    final body = Column(
      children: [
        // ── 상단 알림 배너 (현재 구간 정보) ─────────────────────────
        if (state.currentSection != null)
          _AlertBanner(currentSection: state.currentSection!),

        // ── 네이버 지도 ───────────────────────────────────────────────
        SizedBox(
          height: 220,
          child: Stack(
            children: [
              NaverMap(
                key: const ValueKey('reco_live_map'),
                options: const NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: NLatLng(37.5665, 126.9780),
                    zoom: 14,
                  ),
                  mapType: NMapType.basic,
                  activeLayerGroups: [NLayerGroup.transit],
                ),
                onMapReady: _onMapReady,
              ),
                  // 줌 / 현위치 버튼
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MapButton(
                          icon: Icons.add,
                          onTap: () async {
                            if (_mapController != null) {
                              await _mapController!.updateCamera(NCameraUpdate.zoomIn());
                            }
                          },
                        ),
                        const SizedBox(height: 6),
                        _MapButton(
                          icon: Icons.remove,
                          onTap: () async {
                            if (_mapController != null) {
                              await _mapController!.updateCamera(NCameraUpdate.zoomOut());
                            }
                          },
                        ),
                        const SizedBox(height: 6),
                        _MapButton(
                          icon: Icons.my_location,
                          onTap: () {
                            if (_mapController != null) {
                              _moveToCurrentLocation(_mapController!);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 본문 ─────────────────────────────────────────────────────
            Expanded(
              child: _buildBody(state),
            ),

            // ── 종료 버튼 ─────────────────────────────────────────────────
            _TerminateButton(
              isCompleting: state.isCompleting,
              onTap: () => _showFeedbackDialog(context),
            ),
          ],
    );

    // 인라인 모드: Scaffold/SafeArea 없이 그대로 반환
    if (widget.isInline) {
      return body;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: body),
    );
  }

  Widget _buildBody(RecoLiveRouteState state) {
    if (state.isRouteLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.routeDetail == null) {
      return _ErrorView(
        message: state.error!,
        onRetry: () =>
            ref.read(recoLiveRouteProvider.notifier).init(widget.recoId),
      );
    }

    if (state.routeDetail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    _ensureExpandedStops(state);
    return _RouteBody(
      routeDetail: state.routeDetail!,
      currentSection: state.currentSection,
      expandedStops: _expandedStops,
      onToggleStops: (i) => setState(() {
        _expandedStops[i] = !(_expandedStops[i] ?? false);
      }),
    );
  }

  /// routeDetail이 처음 렌더될 때 _expandedStops가 비어있으면 모두 펼침
  void _ensureExpandedStops(RecoLiveRouteState state) {
    if (_expandedStops.isNotEmpty) return;
    final detail = state.routeDetail;
    if (detail == null) return;
    bool changed = false;
    for (int i = 0; i < detail.path.length; i++) {
      final path = detail.path[i];
      if (path.stationName.isNotEmpty && !path.isWalking) {
        _expandedStops[i] = true;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 피드백 다이얼로그 (종료 버튼 클릭 시)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _showFeedbackDialog(BuildContext context) async {
    int? waitScore;
    int? etaScore;
    int? routeScore;

    final result = await showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              '경로 안내를 종료합니다',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '이번 경로는 어땠나요?\n(선택)',
                    style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 16),
                  _FeedbackRow(
                    label: '대기 시간',
                    value: waitScore,
                    onChanged: (v) => setDialogState(() => waitScore = v),
                  ),
                  const SizedBox(height: 12),
                  _FeedbackRow(
                    label: '도착 예정 정확도',
                    value: etaScore,
                    onChanged: (v) => setDialogState(() => etaScore = v),
                  ),
                  const SizedBox(height: 12),
                  _FeedbackRow(
                    label: '경로 만족도',
                    value: routeScore,
                    onChanged: (v) => setDialogState(() => routeScore = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('취소', style: TextStyle(color: Color(0xFF666666))),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('건너뛰기', style: TextStyle(color: Color(0xFF999999))),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('종료'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || !mounted) return; // 취소

    // 건너뛰기(false): 별점 없이 종료 / 제출(true): 별점 포함 종료
    await ref.read(recoLiveRouteProvider.notifier).completeAndStop(
      satWaitTimeScore: result == true ? waitScore : null,
      satEtaScore: result == true ? etaScore : null,
      satRouteScore: result == true ? routeScore : null,
    );
    if (!mounted) return;
    // 인라인 모드: onStop 콜백으로 상위(recoRouteProvider)에 종료 신호
    // 전체 화면 모드: Navigator.pop으로 화면 닫기
    if (widget.isInline) {
      widget.onStop?.call();
    } else {
      Navigator.of(context).pop();
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 피드백 별점 행 위젯
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final void Function(int?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: List.generate(5, (i) {
            final star = i + 1;
            final selected = value != null && star <= value!;
            return GestureDetector(
              onTap: () => onChanged(value == star ? null : star),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  selected ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 28,
                  color: selected ? const Color(0xFFFFA726) : const Color(0xFFCCCCCC),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 지도 버튼
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 상단 알림 배너 (이미지3 스타일)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.currentSection});
  final CurrentSectionModel currentSection;

  /// 현재 idx 기준으로 같은 구간(버스/지하철) 내 남은 정거장 수를 계산.
  /// 도보 구간이면 null 반환 (하차 알림 불필요).
  int? _remainingStops() {
    final groups = currentSection.groupedSections;
    if (groups.isEmpty) return null;

    final curGroupIdx = groups.indexWhere(
      (g) => currentSection.idx >= g.startIdx && currentSection.idx <= g.endIdx,
    );
    if (curGroupIdx < 0) return null;

    final curGroup = groups[curGroupIdx];
    if (curGroup.isWalk) return null;

    return curGroup.endIdx - currentSection.idx;
  }

  String _buildNextLabel() {
    final groups = currentSection.groupedSections;
    if (groups.isEmpty) return '';
    final curIdx = groups.indexWhere(
      (g) => currentSection.idx >= g.startIdx && currentSection.idx <= g.endIdx,
    );
    if (curIdx >= 0 && curIdx + 1 < groups.length) {
      return groups[curIdx + 1].displayLabel;
    }
    return '';
  }

  String _buildCurrentName() {
    return currentSection.currentXY?.stationName ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final currentName = _buildCurrentName();
    final nextLabel = _buildNextLabel();
    final remaining = _remainingStops();
    // 1정거장 이하로 남았을 때만 하차 알림 표시
    final showAlertBanner = remaining != null && remaining <= 1;

    return Column(
      children: [
        if (showAlertBanner)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF3CD),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Color(0xFF856404)),
                const SizedBox(width: 8),
                Text(
                  remaining == 0
                      ? '다음 정거장에서 하차하세요!'
                      : '1정거장 후 하차 — 준비하세요',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF856404),
                  ),
                ),
              ],
            ),
          ),
        if (currentName.isNotEmpty || nextLabel.isNotEmpty)
          Container(
            width: double.infinity,
            color: const Color(0xFFF8F8F8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.notifications_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  '현재 위치: $currentName',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (nextLabel.isNotEmpty) ...[
                  const Text(' → ',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  Text(
                    '다음: $nextLabel',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 본문 — 진행 표시 + 경로 단계 목록
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _RouteBody extends StatelessWidget {
  const _RouteBody({
    required this.routeDetail,
    required this.currentSection,
    required this.expandedStops,
    required this.onToggleStops,
  });

  final RouteModel routeDetail;
  final CurrentSectionModel? currentSection;
  final Map<int, bool> expandedStops;
  final void Function(int) onToggleStops;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 고정 영역: 상태 칩 + 진행 단계 + ETA ─────────────────────────
        _StatusChip(currentSection: currentSection),
        _ProgressStepBar(
          path: routeDetail.path,
          currentSection: currentSection,
        ),
        _EtaRow(totalTime: routeDetail.totalTime),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),

        // ── 스크롤 영역: 경로 단계 목록 ──────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: routeDetail.path.asMap().entries.map((e) {
                final isLast = e.key == routeDetail.path.length - 1;
                final isCurrent = _isCurrentPath(e.key, e.value);
                return _LivePathItem(
                  pathIndex: e.key,
                  path: e.value,
                  isLast: isLast,
                  isCurrent: isCurrent,
                  expanded: expandedStops[e.key] ?? false,
                  onToggle: () => onToggleStops(e.key),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  bool _isCurrentPath(int index, PathModel path) {
    final section = currentSection;
    if (section == null) return false;
    final groups = section.groupedSections;

    // path 배열과 groupedSections 배열을 순서 기반으로 매핑.
    // 두 배열의 크기가 다를 수 있으므로 index가 범위 내인지 확인.
    if (index >= groups.length) return false;

    // 현재 idx가 속한 groupedSection을 찾고, 그게 path[index]와 일치하는지 확인.
    final curGroupIdx = groups.indexWhere(
      (g) => section.idx >= g.startIdx && section.idx <= g.endIdx,
    );
    // 현재 group이 path[index]에 해당하는지 순서로 판단
    if (curGroupIdx != index) return false;

    final curGroup = groups[curGroupIdx];
    if (path.isWalking && curGroup.isWalk) return true;
    if (path.isBus && curGroup.isBus) {
      // 버스 번호 비교 (busNumbers는 no 배열, busNo는 typeKey 파싱)
      final busNo = curGroup.busNo ?? '';
      return path.busNumbers.contains(busNo) ||
          path.busNumbers.any((n) => n.replaceAll(RegExp(r'[^0-9]'), '') ==
              busNo.replaceAll(RegExp(r'[^0-9]'), ''));
    }
    if (path.isSubway && curGroup.isSubway) return true;
    return false;
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 대기중 상태 칩
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.currentSection});
  final CurrentSectionModel? currentSection;

  @override
  Widget build(BuildContext context) {
    final label = currentSection == null ? '대기중' : _statusLabel();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_walk,
                size: 14, color: Color(0xFF2E7D32)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel() {
    if (currentSection == null) return '대기중';
    switch (currentSection!.currentType) {
      case 'bus':
        return '버스 탑승중';
      case 'subway':
        return '지하철 탑승중';
      default:
        return '도보중';
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 진행 단계 Step Bar (이미지3 상단)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ProgressStepBar extends StatelessWidget {
  const _ProgressStepBar({required this.path, required this.currentSection});
  final List<PathModel> path;
  final CurrentSectionModel? currentSection;

  int _currentStepIndex() {
    if (currentSection == null) return -1;
    final groups = currentSection!.groupedSections;
    if (groups.isEmpty) return -1;
    final curGroupIdx = groups.indexWhere(
      (g) => currentSection!.idx >= g.startIdx && currentSection!.idx <= g.endIdx,
    );
    if (curGroupIdx < 0) return -1;
    return curGroupIdx.clamp(0, path.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _currentStepIndex();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: path.asMap().entries.expand((e) {
          final i = e.key;
          final p = e.value;
          final isDone = i < currentStep;
          final isCurrent = i == currentStep;
          final isLast = i == path.length - 1;

          final bgColor = isDone
              ? AppColors.primary
              : isCurrent
                  ? AppColors.primary
                  : const Color(0xFFEEEEEE);
          final iconColor = (isDone || isCurrent) ? Colors.white : const Color(0xFFAAAAAA);

          return [
            _StepDot(
              icon: p.isWalking
                  ? Icons.directions_walk
                  : p.isSubway
                      ? Icons.subway_outlined
                      : Icons.directions_bus_outlined,
              bg: bgColor,
              iconColor: iconColor,
              label: p.isWalking
                  ? '도보'
                  : p.isSubway
                      ? p.subwayLineName
                      : (p.busNumbers.isNotEmpty ? '${p.busNumbers.first}번' : '버스'),
              isCurrent: isCurrent,
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  height: 2,
                  color: isDone ? AppColors.primary : const Color(0xFFDDDDDD),
                ),
              ),
          ];
        }).toList(),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.icon,
    required this.bg,
    required this.iconColor,
    required this.label,
    required this.isCurrent,
  });

  final IconData icon;
  final Color bg;
  final Color iconColor;
  final String label;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isCurrent ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 예상 도착 행
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _EtaRow extends StatelessWidget {
  const _EtaRow({required this.totalTime});
  final int totalTime;

  String _arrivalTime() {
    final now = DateTime.now();
    final arrival = now.add(Duration(minutes: totalTime));
    return '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          Text(
            '예상 도착 ${_arrivalTime()}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '약 ${totalTime}분 소요',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 경로 단계 아이템 (이미지3 하단 리스트)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _LivePathItem extends StatelessWidget {
  const _LivePathItem({
    required this.pathIndex,
    required this.path,
    required this.isLast,
    required this.isCurrent,
    required this.expanded,
    required this.onToggle,
  });

  final int pathIndex;
  final PathModel path;
  final bool isLast;
  final bool isCurrent;
  final bool expanded;
  final VoidCallback onToggle;

  Color get _color => path.isWalking
      ? AppColors.textSecondary
      : path.isSubway
          ? AppColors.subway
          : AppColors.bus;

  Color get _chipBg => path.isWalking
      ? AppColors.walkBg
      : path.isSubway
          ? AppColors.subwayBg
          : AppColors.busBg;

  IconData get _icon => path.isWalking
      ? Icons.directions_walk
      : path.isSubway
          ? Icons.subway_outlined
          : Icons.directions_bus_outlined;

  String get _title {
    if (path.isWalking) return '도보';
    if (path.start != null && path.start!.isNotEmpty) return '${path.start} 승차';
    return path.isSubway ? '지하철 승차' : '버스 승차';
  }

  @override
  Widget build(BuildContext context) {
    // 도보 구간은 정거장 목록 표시 안 함
    final hasStations = path.stationName.isNotEmpty && !path.isWalking;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 타임라인
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrent
                    ? _color.withValues(alpha: 0.2)
                    : _color.withValues(alpha: 0.1),
                border: isCurrent
                    ? Border.all(color: _color, width: 2)
                    : null,
              ),
              child: Icon(_icon, size: 18, color: _color),
            ),
            if (!isLast)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 2,
                height: hasStations && expanded
                    ? 44.0 + path.stationName.length * 28.0
                    : 40,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 14),
        // 내용
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 현재 구간 레이블
                if (isCurrent) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '현재 구간',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                // 타이틀 (탭 가능 → 정류장 펼치기)
                GestureDetector(
                  onTap: hasStations ? onToggle : null,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (hasStations)
                        Icon(
                          expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // 지하철 노선 + 방향 칩
                if (path.isSubway && path.subwayLineName.isNotEmpty) ...[
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _Chip(
                        label: path.subwayLineName,
                        bg: AppColors.subwayBg,
                        fg: AppColors.subway,
                      ),
                      if (path.way != null && path.way!.isNotEmpty)
                        _Chip(
                          label: '${path.way} 방향',
                          bg: _chipBg,
                          fg: _color,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                // 버스 번호 칩
                if (path.isBus && path.busNumbers.isNotEmpty) ...[
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: path.busNumbers
                        .map((n) => _Chip(
                              label: '${n}번',
                              bg: AppColors.busBg,
                              fg: AppColors.bus,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                ],
                // 시간 + 정거장 수 칩
                Wrap(
                  spacing: 6,
                  children: [
                    _Chip(
                      label: '${path.sectionTime}분',
                      bg: path.isWalking ? AppColors.walkBg : AppColors.subwayBg,
                      fg: path.isWalking ? AppColors.walk : AppColors.subway,
                    ),
                    if (hasStations)
                      _Chip(
                        label: path.stationCountLabel,
                        bg: AppColors.busBg,
                        fg: AppColors.bus,
                      ),
                  ],
                ),
                // 정류장 목록 (펼침)
                if (hasStations && expanded) ...[
                  const SizedBox(height: 8),
                  ...path.stationName.asMap().entries.map((e) {
                    final isFirst = e.key == 0;
                    final isLastStation = e.key == path.stationName.length - 1;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 16,
                          child: Column(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (isFirst || isLastStation)
                                      ? _color
                                      : _color.withValues(alpha: 0.3),
                                  border: Border.all(color: _color, width: 1.5),
                                ),
                              ),
                              if (!isLastStation)
                                Container(
                                  width: 2,
                                  height: 20,
                                  color: _color.withValues(alpha: 0.25),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 12,
                              color: (isFirst || isLastStation)
                                  ? _color
                                  : AppColors.textSecondary,
                              fontWeight: (isFirst || isLastStation)
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 공용 칩
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 종료 버튼
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _TerminateButton extends StatelessWidget {
  const _TerminateButton({required this.onTap, this.isCompleting = false});
  final VoidCallback onTap;
  final bool isCompleting;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isCompleting ? null : onTap,
          icon: isCompleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.stop_circle_outlined, size: 18),
          label: Text(
            isCompleting ? '처리 중...' : '종료',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 에러 뷰
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('다시 시도',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}