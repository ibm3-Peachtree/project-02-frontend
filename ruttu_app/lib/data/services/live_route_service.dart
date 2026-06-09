import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

// ─────────────────────────────────────────────
//  모델 (프로젝트에 이미 있는 모델로 교체하세요)
// ─────────────────────────────────────────────

class SectionInfo {
  final int sectionIndex;
  final String status;
  // 필요한 필드 추가
  SectionInfo({required this.sectionIndex, required this.status});
  factory SectionInfo.fromJson(Map<String, dynamic> json) =>
      SectionInfo(sectionIndex: json['sectionIndex'], status: json['status']);
}

class LiveLocationDto {
  final double lat;
  final double lng;
  LiveLocationDto({required this.lat, required this.lng});
  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

// ─────────────────────────────────────────────
//  LiveRouteService
//  변경 요약:
//   • startRoute()        : isReco 분기에서 REST 제거 → STOMP 구독만 남김
//   • _poll()             : isUsingRecoRoute 분기의 REST 폴링 완전 제거
//   • switchToRecommendedRoute() : REST 호출 제거
// ─────────────────────────────────────────────

class LiveRouteService {
  // ── STOMP ──────────────────────────────────
  late StompClient _stompClient;
  StompUnsubscribe? _recoSectionSub; // 추천 경로 section push 구독 핸들

  // ── 상태 ────────────────────────────────────
  bool isReco = false;
  bool isUsingRecoRoute = false;
  Timer? _pollTimer;

  // ── 콜백 (UI 레이어에 주입) ──────────────────
  final void Function(SectionInfo) onMySection;
  final void Function(SectionInfo) onRecoSection; // STOMP push 수신 시 호출
  final void Function(Map<String, dynamic>) onIncidentDetour;
  final void Function(Map<String, dynamic>) onRouteProgress;

  LiveRouteService({
    required this.onMySection,
    required this.onRecoSection,
    required this.onIncidentDetour,
    required this.onRouteProgress,
  });

  // ────────────────────────────────────────────
  //  startRoute()
  //  [변경] isReco 분기: getRecoCurrentSection() REST 제거
  //         → 서버가 /location/reco STOMP 메시지 수신 후 push해주므로
  //           클라이언트는 구독만 설정하고 대기
  // ────────────────────────────────────────────
  Future<void> startRoute({
    required bool isRecommended,
    required String wsUrl,
    required String accessToken,
  }) async {
    isReco = isRecommended;
    isUsingRecoRoute = isRecommended;

    // STOMP 연결
    _stompClient = StompClient(
      config: StompConfig.sockJS(
        url: wsUrl,
        onConnect: (frame) => _onStompConnected(frame, accessToken),
        webSocketConnectHeaders: {'Authorization': 'Bearer $accessToken'},
        onStompError: (frame) => print('[STOMP] error: ${frame.body}'),
        onDisconnect: (_) => print('[STOMP] disconnected'),
      ),
    );
    _stompClient.activate();

    // 폴링 시작 (isReco 경로는 폴링 내부에서 REST를 호출하지 않음 — 아래 _poll 참조)
    _startPolling();
  }

  void _onStompConnected(StompFrame frame, String accessToken) {
    print('[STOMP] connected');

    // ── 공통 구독 ──────────────────────────────
    _stompClient.subscribe(
      destination: '/user/queue/route-progress',
      callback: (f) {
        if (f.body == null) return;
        onRouteProgress(jsonDecode(f.body!));
      },
    );

    _stompClient.subscribe(
      destination: '/user/queue/incident-detour',
      callback: (f) {
        if (f.body == null) return;
        onIncidentDetour(jsonDecode(f.body!));
      },
    );

    // ── 나의 경로 section (isReco=false 시에도 공통으로 구독) ──
    _stompClient.subscribe(
      destination: '/user/queue/my-section',
      callback: (f) {
        if (f.body == null) return;
        onMySection(SectionInfo.fromJson(jsonDecode(f.body!)));
      },
    );

    // ── [변경] 추천 경로 section: REST 제거 → STOMP 구독으로 교체 ──
    if (isReco) {
      _subscribeRecoSection();
    }
  }

  /// 추천 경로 section push 구독
  /// 서버는 /location/reco STOMP 수신 후 getRecoCurrentSection() 결과를
  /// /user/queue/reco-section 으로 push함
  void _subscribeRecoSection() {
    _recoSectionSub = _stompClient.subscribe(
      destination: '/user/queue/reco-section',
      callback: (f) {
        if (f.body == null) return;
        onRecoSection(SectionInfo.fromJson(jsonDecode(f.body!)));
      },
    );
  }

  // ────────────────────────────────────────────
  //  _poll()
  //  [변경] isUsingRecoRoute 분기에서 getRecoCurrentSection() REST 완전 제거
  //         recoSectionRest 변수도 제거
  //         → 위치 전송만 담당; section 응답은 STOMP push로 수신
  // ────────────────────────────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    // 현재 위치 획득 (실제 구현으로 교체)
    final location = await _getCurrentLocation();

    if (isUsingRecoRoute) {
      // ── 추천 경로 ──────────────────────────────
      // [변경] REST getRecoCurrentSection() 호출 제거
      //        recoSectionRest 변수 제거
      // 위치만 STOMP로 전송 → 서버가 section 계산 후 /user/queue/reco-section push
      _sendLocation(destination: '/app/location/reco', location: location);
    } else {
      // ── 나의 경로 ──────────────────────────────
      // 위치 전송 → 서버가 /user/queue/my-section push
      _sendLocation(destination: '/app/location/my', location: location);
    }
  }

  void _sendLocation({
    required String destination,
    required LiveLocationDto location,
  }) {
    if (!_stompClient.connected) return;
    _stompClient.send(
      destination: destination,
      body: jsonEncode(location.toJson()),
    );
  }

  // ────────────────────────────────────────────
  //  switchToRecommendedRoute()
  //  [변경] getRecoCurrentSection() REST 호출 제거
  //         → 추천 경로 section은 다음 _poll() 위치 전송 후 서버 push로 수신
  // ────────────────────────────────────────────
  Future<void> switchToRecommendedRoute() async {
    isUsingRecoRoute = true;

    // [변경] REST getRecoCurrentSection() 제거
    // 추천 경로 section push 구독이 아직 없으면 설정
    if (_recoSectionSub == null) {
      _subscribeRecoSection();
    }

    // 즉시 위치 전송하여 서버가 빠르게 section을 push하도록 트리거
    final location = await _getCurrentLocation();
    _sendLocation(destination: '/app/location/reco', location: location);

    print('[Route] 추천 경로로 전환 완료 — section은 STOMP push로 수신 대기');
  }

  // ────────────────────────────────────────────
  //  정리
  // ────────────────────────────────────────────
  void dispose() {
    _pollTimer?.cancel();
    _recoSectionSub?.call(); // 구독 해제
    _stompClient.deactivate();
  }

  // ── 더미 위치 (실제 GPS 로직으로 교체) ──────────
  Future<LiveLocationDto> _getCurrentLocation() async {
    return LiveLocationDto(lat: 37.5665, lng: 126.9780);
  }
}
