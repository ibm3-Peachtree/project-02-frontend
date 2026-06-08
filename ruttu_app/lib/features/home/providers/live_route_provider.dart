import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/home_repository_provider.dart';
import '../../../data/models/route_model.dart';
import '../../../data/repositories/home_repository.dart';
import '../../../data/services/stomp_service.dart';
import '../../auth/providers/network_provider.dart';


// ── 탭 상태 ─────────────────────────────────────────────────────────
enum RouteTab { my, reco }

final selectedRouteTabProvider = StateProvider<RouteTab>((_) => RouteTab.my);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 1. 나의 경로 Provider
//
//  [변경] _startPolling() 제거 → STOMP /user/queue/location/my 구독으로 대체
//
//  서버가 /app/my 수신 후 위치 계산 결과를
//  /user/queue/location/my 로 push → 앱에서 구독하여 currentSection 갱신
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// STOMP 구독 destination
const _queueLocationMy   = '/user/queue/location/my';
const _queueLocationReco = '/user/queue/location/reco';
const _queueStatus       = '/user/queue/status';
const _queueIncident     = '/user/queue/incident';
const _queueDetour       = '/user/queue/detour';

class MyRouteState {
  final LiveRouteModel? route;
  final CurrentSectionModel? currentSection;
  final bool isActive;
  final bool isRouteLoading;
  final bool isSectionLoading;
  final String? error;

  const MyRouteState({
    this.route,
    this.currentSection,
    this.isActive = false,
    this.isRouteLoading = false,
    this.isSectionLoading = false,
    this.error,
  });

  MyRouteState copyWith({
    LiveRouteModel? route,
    CurrentSectionModel? currentSection,
    bool? isActive,
    bool? isRouteLoading,
    bool? isSectionLoading,
    String? error,
    bool clearError = false,
  }) =>
      MyRouteState(
        route:            route            ?? this.route,
        currentSection:   currentSection   ?? this.currentSection,
        isActive:         isActive         ?? this.isActive,
        isRouteLoading:   isRouteLoading   ?? this.isRouteLoading,
        isSectionLoading: isSectionLoading ?? this.isSectionLoading,
        error:            clearError ? null : (error ?? this.error),
      );
}

class MyRouteNotifier extends StateNotifier<MyRouteState> {
  MyRouteNotifier(this._repo) : super(const MyRouteState());

  final HomeRepository _repo;
  final StompService _stomp = StompService.instance;

  Future<void> loadMyRoute() async {
    if (state.route != null || state.isRouteLoading) return;
    state = state.copyWith(isRouteLoading: true, clearError: true);
    try {
      final route = await _repo.getMyRoute();
      state = state.copyWith(route: route, isRouteLoading: false);
    } catch (e) {
      state = state.copyWith(
        isRouteLoading: false,
        error: '경로를 불러오지 못했어요. 다시 시도해 주세요.',
      );
    }
  }

  Future<void> startMyRoute() async {
    if (state.isActive) return;
    // 백엔드에 /location/my REST 엔드포인트가 없으므로 STOMP push만 사용.
    // 구독 등록 후 서버가 push하면 currentSection이 채워진다.
    state = state.copyWith(isActive: true, clearError: true);
    _subscribeLocationMy();
  }

  // ── STOMP /user/queue/location/my 구독 ─────────────────────────
  void _subscribeLocationMy() {
    _stomp.subscribe(_queueLocationMy, (json) {
      if (!mounted) return;
      try {
        final section = _parseCurrentSection(json);
        state = state.copyWith(currentSection: section);
        debugPrint('[MyRoute] STOMP section 수신 idx=${section.idx}');
      } catch (e) {
        debugPrint('[MyRoute] section 파싱 오류: $e');
      }
    });
  }

  void stopMyRoute() {
    _stomp.unsubscribe(_queueLocationMy);
    // route 보존, 나머지 초기화
    state = MyRouteState(route: state.route);
  }

  @override
  void dispose() {
    _stomp.unsubscribe(_queueLocationMy);
    super.dispose();
  }
}

final myRouteProvider =
    StateNotifierProvider<MyRouteNotifier, MyRouteState>(
  (ref) => MyRouteNotifier(ref.read(homeRepositoryProvider)),
);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 2. 추천 경로 Provider
//
//  [변경] _startPolling() 제거 → STOMP /user/queue/location/reco 구독으로 대체
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class RecoRouteState {
  final List<RouteModel> recoList;
  final List<RouteModel> detourList;       // REST 응답의 우회 경로 (RouteModel)
  final List<DetourModel> detourModelList; // STOMP push 우회 경로 (DetourModel)
  final bool hasIncident;
  final String? incidentMessage;
  final RouteModel? detailRoute;
  final bool isDetailLoading;
  final int? selectedRecoId;
  final int? selectedDetourPathId;   // 선택된 우회 경로 pathId
  final bool isSaving;
  final LiveRouteModel? route;
  final CurrentSectionModel? currentSection;
  final bool isActive;
  final bool isRouteLoading;
  final bool isSectionLoading;
  final String? error;

  const RecoRouteState({
    this.recoList = const [],
    this.detourList = const [],
    this.detourModelList = const [],
    this.hasIncident = false,
    this.incidentMessage,
    this.detailRoute,
    this.isDetailLoading = false,
    this.selectedRecoId,
    this.selectedDetourPathId,
    this.isSaving = false,
    this.route,
    this.currentSection,
    this.isActive = false,
    this.isRouteLoading = false,
    this.isSectionLoading = false,
    this.error,
  });

  RecoRouteState copyWith({
    List<RouteModel>? recoList,
    List<RouteModel>? detourList,
    List<DetourModel>? detourModelList,
    bool? hasIncident,
    String? incidentMessage,
    RouteModel? detailRoute,
    bool? isDetailLoading,
    int? selectedRecoId,
    int? selectedDetourPathId,
    bool? isSaving,
    LiveRouteModel? route,
    CurrentSectionModel? currentSection,
    bool? isActive,
    bool? isRouteLoading,
    bool? isSectionLoading,
    String? error,
    bool clearError = false,
    bool clearDetail = false,
    bool clearSelectedRecoId = false,
    bool clearSelectedDetourPathId = false,
  }) =>
      RecoRouteState(
        recoList:               recoList              ?? this.recoList,
        detourList:             detourList            ?? this.detourList,
        detourModelList:        detourModelList       ?? this.detourModelList,
        hasIncident:            hasIncident           ?? this.hasIncident,
        incidentMessage:        incidentMessage       ?? this.incidentMessage,
        detailRoute:            clearDetail ? null : (detailRoute ?? this.detailRoute),
        isDetailLoading:        isDetailLoading       ?? this.isDetailLoading,
        selectedRecoId:         clearSelectedRecoId ? null : (selectedRecoId ?? this.selectedRecoId),
        selectedDetourPathId:   clearSelectedDetourPathId ? null : (selectedDetourPathId ?? this.selectedDetourPathId),
        isSaving:               isSaving              ?? this.isSaving,
        route:            route             ?? this.route,
        currentSection:   currentSection    ?? this.currentSection,
        isActive:         isActive          ?? this.isActive,
        isRouteLoading:   isRouteLoading    ?? this.isRouteLoading,
        isSectionLoading: isSectionLoading  ?? this.isSectionLoading,
        error:            clearError ? null : (error ?? this.error),
      );
}

class RecoRouteNotifier extends StateNotifier<RecoRouteState> {
  RecoRouteNotifier(this._repo) : super(const RecoRouteState());

  final HomeRepository _repo;
  final StompService _stomp = StompService.instance;

  // ── 목록 ─────────────────────────────────────────────────

  /// homeProvider.initialize()에서 이미 받아온 데이터를 직접 주입.
  /// API 중복 호출 없이 즉시 state를 채운다.
  void preloadList(RecoRouteListResponse resp) {
    // recoList 또는 detourList(REST)가 이미 있으면 무시.
    // detourModelList(STOMP)만 있는 경우에는 recoList를 주입 허용.
    if (state.recoList.isNotEmpty || state.detourList.isNotEmpty) return;
    state = state.copyWith(
      recoList:        resp.recoList,
      detourList:      resp.detourList,
      hasIncident:     resp.hasIncident,
      incidentMessage: resp.incidentMessage,
    );
  }

  Future<void> loadRecoRouteList({bool force = false}) async {
    if (state.isRouteLoading) return;
    if (state.isActive) return;
    // recoList 또는 detourList(REST)가 이미 있으면 스킵.
    // detourModelList(STOMP)만 있는 경우에는 recoList가 비어있을 수 있으므로
    // recoList가 없으면 로드를 허용한다.
    if (!force && (state.recoList.isNotEmpty || state.detourList.isNotEmpty)) return;

    state = state.copyWith(isRouteLoading: true, clearError: true);
    try {
      final resp = await _repo.getRecoRouteListResponse();
      state = state.copyWith(
        recoList:        resp.recoList,
        detourList:      resp.detourList,
        hasIncident:     resp.hasIncident,
        incidentMessage: resp.incidentMessage,
        isRouteLoading:  false,
      );
    } catch (e) {
      state = state.copyWith(
        isRouteLoading: false,
        error: '추천 경로를 불러오지 못했어요. 다시 시도해 주세요.',
      );
    }
  }

  /// homeProvider.initialize()에서 getRecoRouteListResponse() 실패 시 호출.
  /// 탭 진입 시 _tryLoad()가 다시 loadRecoRouteList()를 시도할 수 있도록
  /// error 상태만 세팅하고 isRouteLoading은 false로 유지.
  void markLoadError() {
    if (state.isActive || state.recoList.isNotEmpty || state.detourModelList.isNotEmpty) return;
    state = state.copyWith(
      error: '추천 경로를 불러오지 못했어요. 다시 시도해 주세요.',
      clearError: false,
    );
  }

  void selectReco(int recoId) {
    state = state.copyWith(selectedRecoId: recoId, clearSelectedDetourPathId: true);
  }

  void selectDetour(int pathId) {
    state = state.copyWith(selectedDetourPathId: pathId, clearSelectedRecoId: true);
  }

  // ── 우회 경로 상세 보기 ────────────────────────────────────────
  Future<void> loadDetourDetail(int pathId) async {
    state = state.copyWith(isDetailLoading: true, clearDetail: true);

    // 우회 경로 상세는 STOMP detourModelList에 이미 전체 데이터가 있다.
    // 서버 GET /reco/detour/{pathId} 응답이 List<DetourDto> 배열이므로
    // 별도 API 호출 없이 메모리의 detourModelList에서 찾아 변환한다.
    final found = state.detourModelList
        .where((d) => d.pathId == pathId)
        .cast<DetourModel?>()
        .firstWhere((_) => true, orElse: () => null);

    if (found != null) {
      final detail = _detourModelToRouteModel(found);
      state = state.copyWith(detailRoute: detail, isDetailLoading: false);
      return;
    }

    // fallback: 메모리에 없으면 API 호출 (배열 응답 대응)
    try {
      final detail = await _repo.getDetourDetail(pathId);
      state = state.copyWith(detailRoute: detail, isDetailLoading: false);
    } catch (e) {
      state = state.copyWith(
        isDetailLoading: false,
        error: '우회 경로 상세를 불러오지 못했어요.',
      );
    }
  }

  /// DetourModel → RouteModel 변환 (상세 오버레이용)
  /// TRANSIT/TRANSFER → walk/subway/bus 타입 매핑
  RouteModel _detourModelToRouteModel(DetourModel detour) {
    final paths = detour.pathSegments.map((seg) {
      String mappedType;
      if (seg.isWalk) {
        mappedType = 'walk';
      } else if (seg.isSubway) {
        mappedType = 'subway';
      } else {
        mappedType = 'bus';
      }
      return PathModel(
        type: mappedType,
        sectionTime: seg.segmentDurationMin.round(),
        no: seg.displayName,
        stationCount: seg.stopCount,
        stationName: seg.stations.map((s) => s.name).toList(),
      );
    }).toList();
    return RouteModel(
      recoId: detour.pathId,
      totalDistance: detour.pathSegments.fold(0, (s, e) => s + e.totalDistanceM),
      totalTime: detour.totalDurationMin.round(),
      payment: 0,
      path: paths,
      isDetour: true,
    );
  }

  // ── 우회 경로로 변경 ──────────────────────────────────────────
  // detourModelList(STOMP)에 이미 전체 경로 데이터가 있으므로 별도 API 호출 없이
  // 메모리에서 변환해 사용한다. (GET /reco/detour/{pathId} 응답이 배열이어서 파싱 불가)
  Future<void> saveAndStartDetourRoute(int pathId) async {
    if (state.isActive || state.isSaving) return;

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repo.saveDetourRoute(pathId);

      // detourModelList에서 pathId로 찾아 LiveRouteModel로 변환
      final found = state.detourModelList
          .where((d) => d.pathId == pathId)
          .cast<DetourModel?>()
          .firstWhere((_) => true, orElse: () => null);

      RouteModel detailRoute;
      if (found != null) {
        detailRoute = _detourModelToRouteModel(found);
      } else {
        // fallback: 메모리에 없으면 API 호출
        detailRoute = await _repo.getDetourDetail(pathId);
      }

      final route = LiveRouteModel(
        totalDistance: detailRoute.totalDistance,
        totalTime:     detailRoute.totalTime,
        payment:       detailRoute.payment,
        startName:     detailRoute.startName,
        endName:       detailRoute.endName,
        path:          detailRoute.path,
      );

      state = state.copyWith(
        route:    route,
        isSaving: false,
        isActive: true,
      );

      // STOMP 구독 — 이후 서버 push로 currentSection 수신
      _subscribeLocationReco();
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: '우회 경로 변경에 실패했어요. 다시 시도해 주세요.',
      );
    }
  }

  // ── 상세 보기 ─────────────────────────────────────────────
  Future<void> loadRecoDetail(int recoId) async {
    state = state.copyWith(isDetailLoading: true, clearDetail: true);
    try {
      final detail = await _repo.getRecoRouteDetail(recoId);
      state = state.copyWith(detailRoute: detail, isDetailLoading: false);
    } catch (e) {
      state = state.copyWith(
        isDetailLoading: false,
        error: '경로 상세를 불러오지 못했어요.',
      );
    }
  }

  void closeDetail() {
    state = state.copyWith(clearDetail: true);
  }

  Future<void> saveRecoRoute(int recoId) async {
    await _repo.saveRecoRoute(recoId);
  }

  // ── 이 경로로 변경 ────────────────────────────────────────
  // 백엔드 GET /reco는 List<RouteListDto>를 반환하므로 LiveRouteModel 파싱 불가.
  // 저장 후엔 GET /reco/{recoId}로 상세를 가져와 변환해 사용한다.
  // /location/reco REST 엔드포인트는 백엔드에 없으므로 STOMP push만 사용.
  Future<void> saveAndStartRecoRoute(int recoId) async {
    if (state.isActive || state.isSaving) return;

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repo.saveRecoRoute(recoId);

      // GET /me/routines/active/reco/{recoId} → RouteModel → LiveRouteModel 변환
      final detailRoute = await _repo.getRecoRouteDetail(recoId);
      final route = LiveRouteModel(
        totalDistance: detailRoute.totalDistance,
        totalTime:     detailRoute.totalTime,
        payment:       detailRoute.payment,
        startName:     detailRoute.startName,
        endName:       detailRoute.endName,
        path:          detailRoute.path,
      );

      state = state.copyWith(
        route:    route,
        isSaving: false,
        isActive: true,
      );

      // STOMP 구독 시작 — 이후 서버 push로 currentSection 수신
      _subscribeLocationReco();
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: '경로 변경에 실패했어요. 다시 시도해 주세요.',
      );
    }
  }

  // ── STOMP /user/queue/location/reco 구독 ────────────────
  void _subscribeLocationReco() {
    _stomp.subscribe(
      _queueLocationReco,
      (json) {
        if (!mounted) return;
        try {
          final section = _parseCurrentSection(json);
          state = state.copyWith(currentSection: section);
          debugPrint('[RecoRoute] STOMP section 수신 idx=${section.idx}');
        } catch (e) {
          debugPrint('[RecoRoute] section 파싱 오류: $e');
        }
      },
      subscriberKey: 'recoRoute',
    );
  }

  // ── 종료 ─────────────────────────────────────────────────
  void stopRecoRoute() {
    _stomp.unsubscribe(_queueLocationReco, subscriberKey: 'recoRoute');
    state = RecoRouteState(
      recoList:   state.recoList,
      detourList: state.detourList,
    );
  }

  @override
  void dispose() {
    _stomp.unsubscribe(_queueLocationReco, subscriberKey: 'recoRoute');
    super.dispose();
  }

  /// incidentDetourProvider → recoRouteProvider 상태 동기화
  void applyIncidentDetour({
    required String? incidentMessage,
    required bool hasIncident,
    required List<DetourModel> detourModelList,
  }) {
    state = state.copyWith(
      hasIncident: hasIncident,
      incidentMessage: incidentMessage,
      detourModelList: detourModelList,
    );
  }
}

final recoRouteProvider =
    StateNotifierProvider<RecoRouteNotifier, RecoRouteState>(
  (ref) {
    final notifier = RecoRouteNotifier(ref.read(homeRepositoryProvider));
    // incidentDetourProvider 변화 → recoRouteProvider 상태 머지
    ref.listen<IncidentDetourState>(incidentDetourProvider, (prev, next) {
      // incident / detour 중 하나라도 변경되면 즉시 머지
      // (incident·detour는 서버가 독립적으로 push하므로 조건 분기 없이 항상 최신값 반영)
      final changed = next.incidentMessage != prev?.incidentMessage ||
          next.hasIncident != (prev?.hasIncident ?? false) ||
          next.detourList.length != (prev?.detourList.length ?? 0);
      if (changed) {
        notifier.applyIncidentDetour(
          incidentMessage: next.incidentMessage,
          hasIncident: next.hasIncident,
          detourModelList: next.detourList,
        );
      }
    });
    return notifier;
  },
);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 3. 이동 상태 Provider  (대기중 / 도보중 / 탑승중)
//
//  서버 push: /user/queue/status → LiveStatusModel { status, updatedAt }
//  liveLocationProvider가 STOMP 연결 후 자동으로 구독 시작
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

final liveStatusProvider =
    StateNotifierProvider<LiveStatusNotifier, LiveStatusModel?>(
  (ref) => LiveStatusNotifier(),
);

class LiveStatusNotifier extends StateNotifier<LiveStatusModel?> {
  LiveStatusNotifier() : super(null) {
    StompService.instance.subscribe(_queueStatus, (json) {
      state = LiveStatusModel.fromJson(json);
      debugPrint('[LiveStatus] ${state?.status}');
    });
  }

  @override
  void dispose() {
    StompService.instance.unsubscribe(_queueStatus);
    super.dispose();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 공통 파싱 헬퍼
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 서버 CurrentSectionDto → Flutter CurrentSectionModel
/// {
///   "idx": 3,
///   "section": ["walk", "bus:5535", ...],
///   "xy": [{"stationName": ..., "x": ..., "y": ..., "arsID": ...,
///           "type": ..., "no": ...}, ...]
/// }
CurrentSectionModel _parseCurrentSection(Map<String, dynamic> json) {
  final idx = (json['idx'] as num).toInt();

  final section = (json['section'] as List<dynamic>)
      .map((e) => e as String)
      .toList();

  final xyRaw = json['xy'] as List<dynamic>;
  final xy = xyRaw.map((e) {
    final m = e as Map<String, dynamic>;
    return RouteXYModel(
      stationName: m['stationName'] as String?,
      x:           (m['x'] as num?)?.toDouble(),
      y:           (m['y'] as num?)?.toDouble(),
      arsID:       m['arsID'] as String?,
      type:        m['type'] as String?,
      no:          m['no'] as String?,
    );
  }).toList();

  return CurrentSectionModel(idx: idx, section: section, xy: xy);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 4. 이벤트/우회 경로 Provider
//
//  서버 sendIncidentsDetour():
//    incident 문자열이 비어있지 않을 때
//      → /user/queue/incident  : String (이벤트 메시지)
//      → /user/queue/detour    : List<DetourDto> (우회 경로 목록)
//
//  앱은 두 구독을 함께 유지하고, 수신 시 incidentDetourProvider 상태 갱신.
//  active 종료 시 구독 해제.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class IncidentDetourState {
  /// /user/queue/incident 로 수신된 이벤트 메시지 (null = 이상 없음)
  final String? incidentMessage;
  /// 돌발 사고 발생 여부 — clearIncident() 후에도 유지됨
  final bool hasIncident;
  /// /user/queue/detour 로 수신된 우회 경로 목록 — clearIncident() 후에도 유지됨
  final List<DetourModel> detourList;

  const IncidentDetourState({
    this.incidentMessage,
    this.hasIncident = false,
    this.detourList = const [],
  });

  IncidentDetourState copyWith({
    String? incidentMessage,
    bool? hasIncident,
    List<DetourModel>? detourList,
    bool clearIncident = false,
  }) =>
      IncidentDetourState(
        // clearIncident: 팝업 dismiss용 — 메시지만 null, hasIncident·detourList는 유지
        incidentMessage: clearIncident ? null : (incidentMessage ?? this.incidentMessage),
        hasIncident:     hasIncident ?? this.hasIncident,
        detourList:      detourList ?? this.detourList,
      );
}

class IncidentDetourNotifier extends StateNotifier<IncidentDetourState> {
  IncidentDetourNotifier() : super(const IncidentDetourState()) {
    _subscribeAll();
  }

  final StompService _stomp = StompService.instance;

  void _subscribeAll() {
    // ── /user/queue/incident — 서버가 plain String으로 push ──────────────
    // subscribe()는 JSON Map 파싱을 시도하므로 String body에 사용 불가.
    // subscribeRaw()만 등록 — 재연결 시 _rawSubscriptions 맵에서 자동 복구됨.
    _stomp.subscribeRaw(_queueIncident, (rawBody) {
      if (!mounted || rawBody == null) return;
      // JSON string 형태 ("\"...\"") 또는 plain string 모두 처리
      String msg = rawBody.trim();
      if (msg.startsWith('"') && msg.endsWith('"')) {
        msg = msg.substring(1, msg.length - 1);
      }
      if (msg.isNotEmpty) {
        state = state.copyWith(incidentMessage: msg, hasIncident: true);
        debugPrint('[Incident] 수신: $msg');
      }
    });

    // ── /user/queue/detour — List<DetourDto> push ─────────────────
    _stomp.subscribeRaw(_queueDetour, (rawBody) {
      if (!mounted || rawBody == null) return;
      try {
        final list = (jsonDecode(rawBody) as List<dynamic>)
            .map((e) => DetourModel.fromJson(e as Map<String, dynamic>))
            .toList();
        // detour push가 오면 incident도 발생한 것으로 간주
        // (서버가 sendIncidentsDetour()로 incident·detour를 함께 push하므로
        //  detour가 도착했다는 것 자체가 돌발 상황이 발생했다는 신호)
        state = state.copyWith(detourList: list, hasIncident: true);
        debugPrint('[Detour] ${list.length}개 우회 경로 수신');
      } catch (e) {
        debugPrint('[Detour] 파싱 오류: $e');
      }
    });
  }

  /// 이벤트 확인 후 dismiss
  void clearIncident() {
    state = state.copyWith(clearIncident: true);
  }

  void stopSubscriptions() {
    _stomp.unsubscribe(_queueIncident);
    _stomp.unsubscribe(_queueDetour);
    state = const IncidentDetourState();
  }

  @override
  void dispose() {
    stopSubscriptions();
    super.dispose();
  }
}

final incidentDetourProvider =
    StateNotifierProvider<IncidentDetourNotifier, IncidentDetourState>(
  (ref) => IncidentDetourNotifier(),
);
