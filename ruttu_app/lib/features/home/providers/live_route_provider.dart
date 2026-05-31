import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/route_model.dart';
import '../../../data/repositories/home_repository.dart';

// ── Repository Provider ────────────────────────────────────────────────────
// 외부에서 override하여 실제 ApiHomeRepository를 주입하세요.
final homeRepositoryProvider = Provider<HomeRepository>(
  (_) => throw UnimplementedError('homeRepositoryProvider must be overridden'),
);

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 1. 나의 경로 Provider
//    - "시작" 버튼을 누를 때 한 번만 fetch → 이후 리프레시 없음
//    - 실시간 위치(CurrentSection)는 30 초마다 폴링 (경로 자체는 변경 안 함)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class MyRouteState {
  /// 경로 데이터 — 한 번 로드되면 교체하지 않음
  final LiveRouteModel? route;

  /// 현재 위치 섹션 — 폴링으로 갱신
  final CurrentSectionModel? currentSection;

  /// 라이브 진행 중 여부 (시작 버튼 누른 후 true)
  final bool isActive;

  final bool isLoading;
  final String? error;

  const MyRouteState({
    this.route,
    this.currentSection,
    this.isActive = false,
    this.isLoading = false,
    this.error,
  });

  MyRouteState copyWith({
    LiveRouteModel? route,
    CurrentSectionModel? currentSection,
    bool? isActive,
    bool? isLoading,
    String? error,
  }) =>
      MyRouteState(
        route:          route          ?? this.route,
        currentSection: currentSection ?? this.currentSection,
        isActive:       isActive       ?? this.isActive,
        isLoading:      isLoading      ?? this.isLoading,
        error:          error,
      );
}

class MyRouteNotifier extends StateNotifier<MyRouteState> {
  MyRouteNotifier(this._repo) : super(const MyRouteState());

  final HomeRepository _repo;
  Timer? _timer;

  /// 나의 경로 탭에서 "시작" 버튼을 눌렀을 때 호출
  /// - route 를 한 번만 fetch (이미 있으면 재사용 → 리프레시해도 변경 없음)
  /// - 이후 30 초마다 currentSection만 갱신
  Future<void> startMyRoute() async {
    if (state.isActive) return; // 이미 활성화 중이면 무시

    state = state.copyWith(isLoading: true, error: null);

    try {
      // 경로가 아직 없을 때만 fetch — 핵심: 한 번 가져온 route는 교체하지 않음
      LiveRouteModel? route = state.route;
      if (route == null) {
        route = await _repo.getMyRoute();
      }

      // 첫 위치 섹션도 즉시 가져옴
      final section = await _repo.getCurrentSection();

      state = MyRouteState(
        route: route,
        currentSection: section,
        isActive: true,
        isLoading: false,
      );

      // 30 초 폴링 시작 (경로는 건드리지 않고 currentSection만 갱신)
      _startPolling();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '경로를 불러오지 못했어요. 다시 시도해 주세요.',
      );
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!state.isActive) return;
      try {
        final section = await _repo.getCurrentSection();
        // route 는 절대 교체하지 않음 — currentSection만 업데이트
        state = state.copyWith(currentSection: section);
      } catch (_) {
        // 폴링 실패는 무시 (마지막 섹션 유지)
      }
    });
  }

  /// 경로 종료 (완료 또는 취소)
  void stopMyRoute() {
    _timer?.cancel();
    _timer = null;
    state = const MyRouteState();
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
// 2. 추천 경로 Provider
//    - "이 경로로 변경" 버튼을 누를 때 한 번만 fetch → 이후 리프레시 없음
//    - 실시간 위치는 30 초마다 폴링 (경로 자체는 변경 안 함)
//    - 나의 경로와 완전히 독립적으로 동작
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class RecoRouteState {
  final LiveRouteModel? route;
  final CurrentSectionModel? currentSection;
  final bool isActive;
  final bool isLoading;
  final String? error;

  const RecoRouteState({
    this.route,
    this.currentSection,
    this.isActive = false,
    this.isLoading = false,
    this.error,
  });

  RecoRouteState copyWith({
    LiveRouteModel? route,
    CurrentSectionModel? currentSection,
    bool? isActive,
    bool? isLoading,
    String? error,
  }) =>
      RecoRouteState(
        route:          route          ?? this.route,
        currentSection: currentSection ?? this.currentSection,
        isActive:       isActive       ?? this.isActive,
        isLoading:      isLoading      ?? this.isLoading,
        error:          error,
      );
}

class RecoRouteNotifier extends StateNotifier<RecoRouteState> {
  RecoRouteNotifier(this._repo) : super(const RecoRouteState());

  final HomeRepository _repo;
  Timer? _timer;

  /// 추천 경로 탭에서 "이 경로로 변경" 버튼을 눌렀을 때 호출
  Future<void> startRecoRoute() async {
    if (state.isActive) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      LiveRouteModel? route = state.route;
      if (route == null) {
        route = await _repo.getRecommendedRoute();
      }

      final section = await _repo.getRecoCurrentSection();

      state = RecoRouteState(
        route: route,
        currentSection: section,
        isActive: true,
        isLoading: false,
      );

      _startPolling();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '추천 경로를 불러오지 못했어요. 다시 시도해 주세요.',
      );
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!state.isActive) return;
      try {
        final section = await _repo.getRecoCurrentSection();
        state = state.copyWith(currentSection: section);
      } catch (_) {
        // 폴링 실패는 무시
      }
    });
  }

  void stopRecoRoute() {
    _timer?.cancel();
    _timer = null;
    state = const RecoRouteState();
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 3. 현재 선택된 탭 (나의 경로 / 추천 경로) — UI 탭 상태만 관리
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum RouteTab { my, reco }

final selectedRouteTabProvider = StateProvider<RouteTab>((_) => RouteTab.my);
