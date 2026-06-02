import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/route_model.dart';
import '../../../data/repositories/home_repository.dart';
import '../../auth/providers/network_provider.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Repository Provider (나의 경로와 독립된 별도 provider)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

final recoLiveRepositoryProvider = Provider<HomeRepository>((ref) {
  return ApiHomeRepository(ref.read(apiClientProvider).dio);
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 추천 경로 실시간 안내 State
// (나의 경로와 완전 독립 — live_route_provider.dart 와 공유 없음)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class RecoLiveRouteState {
  /// GET /me/routines/active/reco/{recoId} 응답 (경로 상세)
  final RouteModel? routeDetail;
  /// GET /me/routines/active/location/reco 응답 (현재 위치/구간)
  final CurrentSectionModel? currentSection;
  final bool isRouteLoading;
  final bool isSectionLoading;
  final String? error;
  /// 진입 시각 (complete API 호출에 사용)
  final DateTime? departureTime;
  /// complete 진행 중
  final bool isCompleting;

  const RecoLiveRouteState({
    this.routeDetail,
    this.currentSection,
    this.isRouteLoading = false,
    this.isSectionLoading = false,
    this.error,
    this.departureTime,
    this.isCompleting = false,
  });

  RecoLiveRouteState copyWith({
    RouteModel? routeDetail,
    CurrentSectionModel? currentSection,
    bool? isRouteLoading,
    bool? isSectionLoading,
    String? error,
    bool clearError = false,
    DateTime? departureTime,
    bool? isCompleting,
  }) =>
      RecoLiveRouteState(
        routeDetail:      routeDetail      ?? this.routeDetail,
        currentSection:   currentSection   ?? this.currentSection,
        isRouteLoading:   isRouteLoading   ?? this.isRouteLoading,
        isSectionLoading: isSectionLoading ?? this.isSectionLoading,
        error: clearError ? null : (error ?? this.error),
        departureTime:    departureTime    ?? this.departureTime,
        isCompleting:     isCompleting     ?? this.isCompleting,
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Notifier
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class RecoLiveRouteNotifier extends StateNotifier<RecoLiveRouteState> {
  RecoLiveRouteNotifier(this._repo) : super(const RecoLiveRouteState());

  final HomeRepository _repo;
  Timer? _timer;

  /// 진입 시 호출 — GET /reco/{recoId} + GET /location/reco 동시 fetch
  Future<void> init(int recoId) async {
    state = state.copyWith(
      isRouteLoading: true,
      isSectionLoading: true,
      clearError: true,
      departureTime: DateTime.now(), // 출발 시각 기록
    );

    // 경로 상세와 현재 구간 병렬 fetch
    await Future.wait([
      _fetchRouteDetail(recoId),
      _fetchCurrentSection(),
    ]);

    // 폴링 시작 (30초 주기)
    _startPolling();
  }

  Future<void> _fetchRouteDetail(int recoId) async {
    try {
      final detail = await _repo.getRecoRouteDetail(recoId);
      if (mounted) state = state.copyWith(routeDetail: detail, isRouteLoading: false);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isRouteLoading: false,
          error: '경로 정보를 불러오지 못했어요.',
        );
      }
    }
  }

  Future<void> _fetchCurrentSection() async {
    try {
      final section = await _repo.getRecoCurrentSection();
      if (mounted) state = state.copyWith(currentSection: section, isSectionLoading: false);
    } catch (e) {
      if (mounted) state = state.copyWith(isSectionLoading: false);
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final section = await _repo.getRecoCurrentSection();
        if (mounted) state = state.copyWith(currentSection: section);
      } catch (_) {}
    });
  }

  /// 종료 + POST /complete/reco — 피드백 점수와 함께 호출
  Future<void> completeAndStop({
    int? satWaitTimeScore,
    int? satEtaScore,
    int? satRouteScore,
  }) async {
    _timer?.cancel();
    _timer = null;

    state = state.copyWith(isCompleting: true);

    final departure = state.departureTime ?? DateTime.now();
    final arrival = DateTime.now();

    try {
      await _repo.completeRecoRoute(
        departureTime: departure,
        arrivalTime: arrival,
        satWaitTimeScore: satWaitTimeScore,
        satEtaScore: satEtaScore,
        satRouteScore: satRouteScore,
      );
    } catch (_) {
      // 실패해도 화면은 닫음
    }

    if (mounted) state = const RecoLiveRouteState();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = const RecoLiveRouteState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Provider
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

final recoLiveRouteProvider =
    StateNotifierProvider<RecoLiveRouteNotifier, RecoLiveRouteState>(
  (ref) => RecoLiveRouteNotifier(ref.read(recoLiveRepositoryProvider)),
);