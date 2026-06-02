import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/route_model.dart';
import '../../../data/repositories/home_repository.dart';
import '../../auth/providers/network_provider.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Repository Provider
// ── home_provider.dart 와 동일한 실제 구현체를 사용.
//    UnimplementedError 로 두면 live_route_tabs.dart 에서 호출 즉시 crash.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return ApiHomeRepository(ref.read(apiClientProvider).dio);
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 탭 상태
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum RouteTab { my, reco }

final selectedRouteTabProvider = StateProvider<RouteTab>((_) => RouteTab.my);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 1. 나의 경로 Provider  (추천 경로와 완전 독립)
//
// [진입]  loadMyRoute()  → getMyRoute() 1회 fetch
// [시작]  startMyRoute() → getCurrentSection() 폴링 시작
// [종료]  stopMyRoute()  → 폴링 취소, route 보존
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
  Timer? _timer;

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
    state = state.copyWith(isSectionLoading: true, clearError: true);
    try {
      final section = await _repo.getCurrentSection();
      state = state.copyWith(
        currentSection:   section,
        isActive:         true,
        isSectionLoading: false,
      );
      _startPolling();
    } catch (e) {
      state = state.copyWith(
        isSectionLoading: false,
        error: '위치 정보를 불러오지 못했어요. 다시 시도해 주세요.',
      );
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!state.isActive) return;
      try {
        final section = await _repo.getCurrentSection();
        if (mounted) state = state.copyWith(currentSection: section);
      } catch (_) {}
    });
  }

  void stopMyRoute() {
    _timer?.cancel();
    _timer = null;
    // route 보존, 나머지 초기화
    state = MyRouteState(route: state.route);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final myRouteProvider =
    StateNotifierProvider<MyRouteNotifier, MyRouteState>(
  (ref) => MyRouteNotifier(ref.read(homeRepositoryProvider)),
);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 2. 추천 경로 Provider  (나의 경로와 완전 독립)
//
// [진입]         loadRecoRouteList()           → 카드 목록 fetch
// [카드 선택]    selectReco(recoId)             → selectedRecoId 세팅
// [상세보기]     loadRecoDetail(recoId)         → 상세 오버레이 표시
// [이 경로로 변경] saveAndStartRecoRoute(recoId) → POST 저장 후
//                                               LiveRouteModel + section fetch
//                                               → isActive=true + 폴링 시작
//                                               → _RouteDetail 위젯 표시
// [종료]         stopRecoRoute()               → 폴링 취소
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class RecoRouteState {
  final List<RouteModel> recoList;
  final List<RouteModel> detourList;
  final bool hasIncident;
  final String? incidentMessage;
  final RouteModel? detailRoute;
  final bool isDetailLoading;
  final int? selectedRecoId;
  final bool isSaving;
  // ── 실시간 안내 ───────────────────────────────────────────
  // ✅ 핵심: saveAndStartRecoRoute 에서 반드시 route 를 채워야
  //    live_route_tabs.dart 의 `state.isActive && state.route != null` 분기가 동작한다.
  final LiveRouteModel? route;
  final CurrentSectionModel? currentSection;
  final bool isActive;
  // ── 로딩 ─────────────────────────────────────────────────
  final bool isRouteLoading;    // 목록 로딩
  final bool isSectionLoading;  // 변경 후 route/section 로딩
  final String? error;

  const RecoRouteState({
    this.recoList = const [],
    this.detourList = const [],
    this.hasIncident = false,
    this.incidentMessage,
    this.detailRoute,
    this.isDetailLoading = false,
    this.selectedRecoId,
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
    bool? hasIncident,
    String? incidentMessage,
    RouteModel? detailRoute,
    bool? isDetailLoading,
    int? selectedRecoId,
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
  }) =>
      RecoRouteState(
        recoList:         recoList          ?? this.recoList,
        detourList:       detourList        ?? this.detourList,
        hasIncident:      hasIncident       ?? this.hasIncident,
        incidentMessage:  incidentMessage   ?? this.incidentMessage,
        detailRoute:      clearDetail ? null : (detailRoute ?? this.detailRoute),
        isDetailLoading:  isDetailLoading   ?? this.isDetailLoading,
        selectedRecoId:   clearSelectedRecoId ? null : (selectedRecoId ?? this.selectedRecoId),
        isSaving:         isSaving          ?? this.isSaving,
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
  Timer? _timer;

  // ── 목록 ─────────────────────────────────────────────────
  Future<void> loadRecoRouteList() async {
    if (state.recoList.isNotEmpty || state.detourList.isNotEmpty ||
        state.isRouteLoading) return;

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

  // ── 카드 선택 ─────────────────────────────────────────────
  void selectReco(int recoId) {
    state = state.copyWith(selectedRecoId: recoId);
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

  // ── 경로 저장만 (POST) — 화면 전환은 호출 측에서 처리
  Future<void> saveRecoRoute(int recoId) async {
    await _repo.saveRecoRoute(recoId);
  }

  // ── 이 경로로 변경 ────────────────────────────────────────
  // ✅ 버그 수정: 기존 코드는 saveRecoRoute(POST) 만 하고 route(LiveRouteModel)를
  //    fetch하지 않아 state.route 가 null 인 채로 isActive=true 가 됐음.
  //    live_route_tabs.dart 의 _RecoRouteTab.build() 은
  //      `state.isActive && state.route != null` 일 때만 _RouteDetail 를 표시하므로
  //    route fetch 가 반드시 필요함.
  Future<void> saveAndStartRecoRoute(int recoId) async {
    if (state.isActive || state.isSaving) return;

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      // 1) 서버에 선택한 추천 경로 저장
      await _repo.saveRecoRoute(recoId);

      state = state.copyWith(isSaving: false, isSectionLoading: true);

      // 2) LiveRouteModel fetch  ← 이게 없으면 _RouteDetail 이 절대 안 나옴
      final route = await _repo.getRecommendedRoute();

      // 3) 현재 구간(section) fetch
      CurrentSectionModel? section;
      try {
        section = await _repo.getRecoCurrentSection();
      } catch (_) {
        // 서버가 아직 reco 세션 미준비 상태(403)일 수 있으므로 무시
      }

      state = state.copyWith(
        route:            route,
        currentSection:   section,
        isActive:         true,
        isSectionLoading: false,
      );

      // 4) 폴링 시작 (30초 주기)
      _startPolling();
    } catch (e) {
      state = state.copyWith(
        isSaving:         false,
        isSectionLoading: false,
        error: '경로 변경에 실패했어요. 다시 시도해 주세요.',
      );
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!state.isActive) return;
      try {
        final section = await _repo.getRecoCurrentSection();
        if (mounted) state = state.copyWith(currentSection: section);
      } catch (_) {}
    });
  }

  // ── 종료 ─────────────────────────────────────────────────
  void stopRecoRoute() {
    _timer?.cancel();
    _timer = null;
    // 카드 목록만 보존, 실시간 안내 관련은 초기화
    state = RecoRouteState(
      recoList:   state.recoList,
      detourList: state.detourList,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final recoRouteProvider =
    StateNotifierProvider<RecoRouteNotifier, RecoRouteState>(
  (ref) => RecoRouteNotifier(ref.read(homeRepositoryProvider)),
);