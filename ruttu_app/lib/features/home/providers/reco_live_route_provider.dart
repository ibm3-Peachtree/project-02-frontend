import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/home_repository_provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/models/route_model.dart';
import '../../../data/repositories/home_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/stomp_service.dart';
import '../../auth/providers/network_provider.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Repository Provider
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// recoLiveRepositoryProvider → home_repository_provider.dart의 homeRepositoryProvider 사용

// ── STOMP destination ────────────────────────────────────────────────
const _queueLocationReco = '/user/queue/location/reco';
const _appLocationReco   = '/app/location/reco';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 추천 경로 실시간 안내 State
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class RecoLiveRouteState {
  final RouteModel? routeDetail;
  final CurrentSectionModel? currentSection;
  final bool isRouteLoading;
  final String? error;
  final DateTime? departureTime;
  final bool isCompleting;

  const RecoLiveRouteState({
    this.routeDetail,
    this.currentSection,
    this.isRouteLoading = false,
    this.error,
    this.departureTime,
    this.isCompleting = false,
  });

  RecoLiveRouteState copyWith({
    RouteModel? routeDetail,
    CurrentSectionModel? currentSection,
    bool? isRouteLoading,
    String? error,
    bool clearError = false,
    DateTime? departureTime,
    bool? isCompleting,
  }) =>
      RecoLiveRouteState(
        routeDetail:    routeDetail    ?? this.routeDetail,
        currentSection: currentSection ?? this.currentSection,
        isRouteLoading: isRouteLoading ?? this.isRouteLoading,
        error: clearError ? null : (error ?? this.error),
        departureTime:  departureTime  ?? this.departureTime,
        isCompleting:   isCompleting   ?? this.isCompleting,
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Notifier
//
//  GPS 전송을 homeProvider.status에 의존하지 않고 자체적으로 관리.
//  이유: RecoLiveRouteScreen은 homeProvider의 active 상태와 독립적으로 진입 가능.
//  GPS 스트림 시작/종료를 init()/stop()/completeAndStop()에서 직접 제어.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class RecoLiveRouteNotifier extends StateNotifier<RecoLiveRouteState> {
  RecoLiveRouteNotifier(this._repo) : super(const RecoLiveRouteState());

  final HomeRepository _repo;
  final StompService _stomp = StompService.instance;
  final LocationService _locationService = LocationService();

  StreamSubscription<Position>? _gpsSub;

  /// STOMP section 수신 시 외부(home_provider)에 알리는 콜백.
  void Function(CurrentSectionModel)? onSectionUpdate;

  // ── GPS 전송 ─────────────────────────────────────────────────────
  //
  // 문제: connect()는 activate()만 호출하고 실제 연결 완료(onConnect)를 기다리지 않는다.
  // 따라서 GPS 스트림이 먼저 시작되면 첫 위치 수신 시점에 isConnected==false 여서
  // send()가 "전송 실패 — 미연결 상태"로 조용히 드롭된다.
  // 해결: STOMP 연결이 완료된 뒤에 GPS 스트림을 열도록 onConnectionChange 스트림 활용.
  Future<void> _startGps() async {
    if (_gpsSub != null) return;

    // 이미 연결된 상태면 바로 진행.
    // 미연결이면 connect() 후 최대 10초 대기.
    // (onConnectionChange는 상태 변화만 emit하므로, 이미 connected면 신호가 없음)
    if (!_stomp.isConnected) {
      _stomp.connect();
      try {
        await _stomp.onConnectionChange
            .firstWhere((connected) => connected)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        debugPrint('[RecoLiveRoute] STOMP 연결 대기 타임아웃');
        // 타임아웃이어도 GPS는 시작 — send()에서 재시도 없이 드롭되지만
        // 다음 위치 수신 시 연결이 완료되어 있으면 정상 전송됨
      }
    }

    await _locationService.ensurePermission();
    if (!mounted) return;

    _gpsSub = _locationService.getLocationStream().listen(
      (pos) {
        if (!mounted) return;
        final speed = pos.speed < 0 ? 0.0 : pos.speed;
        debugPrint('[RecoLiveRoute] GPS 수신 — isConnected=${_stomp.isConnected}  lat=${pos.latitude}');
        _stomp.send(
          destination: _appLocationReco,
          body: {
            'latitude':  pos.latitude,
            'longitude': pos.longitude,
            'speed':     speed,
            'accuracy':  pos.accuracy,
          },
        );
        debugPrint('[RecoLiveRoute] GPS → $_appLocationReco'
            '  lat=${pos.latitude}  lng=${pos.longitude}');
      },
      onError: (e) => debugPrint('[RecoLiveRoute] GPS 스트림 에러: $e'),
    );
    debugPrint('[RecoLiveRoute] GPS 스트림 시작');
  }

  void _stopGps() {
    _gpsSub?.cancel();
    _gpsSub = null;
    debugPrint('[RecoLiveRoute] GPS 종료');
  }

  // ── init (우회 경로) ─────────────────────────────────────────────
  /// 우회 경로 선택 후 진입 시 호출.
  ///
  /// 1. STOMP /user/queue/location/reco 구독
  /// 2. POST /me/routines/active/reco/detour/{pathId} → 서버 저장
  /// 3. detourModelList 메모리 또는 GET /reco/detour/{pathId} → 경로 상세 fetch
  /// 4. GPS 스트림 시작 → /app/location/reco 전송
  Future<void> initDetour(int pathId) async {
    state = state.copyWith(
      isRouteLoading: true,
      clearError:     true,
      departureTime:  DateTime.now(),
    );

    // 1. STOMP 구독
    _stomp.subscribe(
      _queueLocationReco,
      (json) {
        if (!mounted) return;
        try {
          final section = _parseCurrentSection(json);
          state = state.copyWith(currentSection: section);
          onSectionUpdate?.call(section);
          debugPrint('[RecoLiveRoute] STOMP section 수신(detour) idx=${section.idx}');
        } catch (e) {
          debugPrint('[RecoLiveRoute] section 파싱 오류: $e');
        }
      },
      subscriberKey: 'recoLiveRoute',
    );

    // 2. 서버 저장 (POST /me/routines/active/reco/detour/{pathId})
    try {
      await _repo.saveDetourRoute(pathId);
      debugPrint('[RecoLiveRoute] saveDetourRoute 완료 pathId=$pathId');
    } catch (e) {
      debugPrint('[RecoLiveRoute] saveDetourRoute 실패 (무시): $e');
    }

    // 3. 경로 상세 fetch
    await _fetchDetourDetail(pathId);

    // 4. GPS 시작
    await _startGps();
  }

  Future<void> _fetchDetourDetail(int pathId) async {
    try {
      final detail = await _repo.getDetourDetail(pathId);
      if (mounted) state = state.copyWith(routeDetail: detail, isRouteLoading: false);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isRouteLoading: false,
          error: '우회 경로 정보를 불러오지 못했어요.',
        );
      }
    }
  }

  // ── init (추천 경로) ─────────────────────────────────────────────
  /// 진입 시 호출.
  ///
  /// 1. STOMP /user/queue/location/reco 구독 (section push 수신)
  /// 2. POST /reco/{recoId} → Redis 키 보장 (서버가 section push 가능 상태)
  /// 3. GET  /reco/{recoId} → 경로 상세 fetch
  /// 4. GPS 스트림 시작 → /app/location/reco 전송 → 서버 section push 트리거
  ///
  /// GPS 전송을 homeProvider.status에 의존하지 않고 자체 관리.
  Future<void> init(int recoId) async {
    state = state.copyWith(
      isRouteLoading: true,
      clearError:     true,
      departureTime:  DateTime.now(),
    );

    // 1. STOMP 구독을 먼저 등록
    _stomp.subscribe(
      _queueLocationReco,
      (json) {
        if (!mounted) return;
        try {
          final section = _parseCurrentSection(json);
          state = state.copyWith(currentSection: section);
          onSectionUpdate?.call(section);
          debugPrint('[RecoLiveRoute] STOMP section 수신 idx=${section.idx} '
              'type=${section.currentType} station=${section.currentXY?.stationName}');
        } catch (e) {
          debugPrint('[RecoLiveRoute] section 파싱 오류: $e');
        }
      },
      subscriberKey: 'recoLiveRoute',
    );

    // 2. Redis 키 보장
    try {
      await _repo.saveRecoRoute(recoId);
      debugPrint('[RecoLiveRoute] saveRecoRoute 완료 → Redis 키 보장');
    } catch (e) {
      debugPrint('[RecoLiveRoute] saveRecoRoute 실패 (무시): $e');
    }

    // 3. 경로 상세 fetch
    await _fetchRouteDetail(recoId);

    // 4. GPS 시작 → STOMP 연결 완료 후 위치 전송 → 서버 section push 트리거
    await _startGps();
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

  // ── 종료 ─────────────────────────────────────────────────────────
  Future<void> completeAndStop({
    int? satWaitTimeScore,
    int? satEtaScore,
    int? satRouteScore,
  }) async {
    _stomp.unsubscribe(_queueLocationReco, subscriberKey: 'recoLiveRoute');
    _stopGps();

    state = state.copyWith(isCompleting: true);

    final departure = state.departureTime ?? DateTime.now();
    final arrival   = DateTime.now();

    try {
      await _repo.completeRecoRoute(
        departureTime:    departure,
        arrivalTime:      arrival,
        satWaitTimeScore: satWaitTimeScore,
        satEtaScore:      satEtaScore,
        satRouteScore:    satRouteScore,
      );
    } catch (_) {}

    if (mounted) state = const RecoLiveRouteState();
  }

  void stop() {
    _stomp.unsubscribe(_queueLocationReco, subscriberKey: 'recoLiveRoute');
    _stopGps();
    state = const RecoLiveRouteState();
  }

  @override
  void dispose() {
    _stomp.unsubscribe(_queueLocationReco, subscriberKey: 'recoLiveRoute');
    _stopGps();
    super.dispose();
  }
}

final recoLiveRouteProvider =
    StateNotifierProvider<RecoLiveRouteNotifier, RecoLiveRouteState>(
  (ref) => RecoLiveRouteNotifier(ref.read(homeRepositoryProvider)),
);

// ── 파싱 헬퍼 ──────────────────────────────────────────────────────
CurrentSectionModel _parseCurrentSection(Map<String, dynamic> json) {
  final idx = (json['idx'] as num).toInt();
  final section = (json['section'] as List<dynamic>).map((e) => e as String).toList();
  final xy = (json['xy'] as List<dynamic>).map((e) {
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
