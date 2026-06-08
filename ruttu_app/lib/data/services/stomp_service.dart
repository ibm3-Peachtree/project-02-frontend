import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../../core/config/env_config.dart';
import 'token_storage.dart';

// ── STOMP 구독 대상 ───────────────────────────────────────────────────
//
//  [서버 → 앱]
//   /user/queue/status          : 이동 상태 (대기중/도보중/탑승중)
//   /user/queue/location/my     : 나의 경로 현재 구간 (CurrentSectionDto)
//   /user/queue/location/reco   : 추천 경로 현재 구간 (CurrentSectionDto)
//
//  [앱 → 서버]
//   /app/my   → LiveLocationController.myLocation()
//   /app/reco → LiveLocationController.recoLocation()
//
//  StompHandler(서버)가 CONNECT 프레임의 "Authorization" 헤더에서 JWT를 검증.
// ─────────────────────────────────────────────────────────────────────

typedef StompFrameCallback    = void Function(Map<String, dynamic> body);
typedef StompRawCallback      = void Function(String? rawBody);

class StompService {
  StompService._();
  static final StompService instance = StompService._();

  StompClient? _client;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // 재연결 지수 백오프
  int _retryDelay = 2;
  static const int _maxRetryDelay = 60;

  // destination → { subscriberKey → callback }
  // 같은 destination에 여러 subscriber가 등록될 수 있음 (예: reco 구간을 두 provider가 구독)
  final Map<String, Map<String, StompFrameCallback>> _subscriptions = {};
  final Map<String, Map<String, StompRawCallback>>   _rawSubscriptions = {};
  // destination당 실제 STOMP 구독 핸들 (서버와의 구독은 destination당 하나)
  final Map<String, StompUnsubscribe?> _activeSubs = {};

  // 연결 상태 스트림
  final _connectedController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectionChange => _connectedController.stream;

  // ── 연결 ─────────────────────────────────────────────────────────
  Future<void> connect() async {
    if (_isConnected || _client != null) return;

    final token = await TokenStorage().getAccessToken();
    if (token == null) {
      debugPrint('[STOMP] 토큰 없음 — 연결 건너뜀');
      return;
    }

    // http(s) → ws(s) 변환
    final baseUrl = EnvConfig.springBaseUrl;
    final wsUrl = baseUrl
        .replaceFirst(RegExp(r'^https://'), 'wss://')
        .replaceFirst(RegExp(r'^http://'), 'ws://');
    final endpoint = '$wsUrl/ws';

    debugPrint('[STOMP] 연결 시도: $endpoint');

    _client = StompClient(
      config: StompConfig(
        url: endpoint,
        // CONNECT 프레임 헤더에 JWT 추가 (StompHandler 검증)
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        heartbeatOutgoing: const Duration(seconds: 20),
        heartbeatIncoming: const Duration(seconds: 20),
        reconnectDelay: Duration(seconds: _retryDelay),
        onConnect: _onConnect,
        onDisconnect: _onDisconnect,
        onStompError: _onError,
        onWebSocketError: _onWebSocketError,
        onUnhandledFrame: (frame) =>
            debugPrint('[STOMP] 처리되지 않은 프레임: ${frame.command}'),
      ),
    );

    _client!.activate();
  }

  // ── 연결 성공 콜백 ────────────────────────────────────────────────
  void _onConnect(StompFrame frame) {
    _isConnected = true;
    _retryDelay = 2; // 성공 시 지연 초기화
    debugPrint('[STOMP] 연결 성공');
    _connectedController.add(true);

    // 기존 구독 재등록 (destination당 하나의 실제 STOMP 구독)
    for (final dest in _subscriptions.keys) {
      _doSubscribe(dest);
    }
    for (final dest in _rawSubscriptions.keys) {
      _doSubscribeRaw(dest);
    }
  }

  // ── 연결 해제 콜백 ────────────────────────────────────────────────
  void _onDisconnect(StompFrame frame) {
    _isConnected = false;
    _activeSubs.clear();
    debugPrint('[STOMP] 연결 해제');
    _connectedController.add(false);
  }

  // ── 에러 콜백 ─────────────────────────────────────────────────────
  void _onError(StompFrame frame) {
    debugPrint('[STOMP] 에러: ${frame.body}');
    _scheduleRetry();
  }

  void _onWebSocketError(dynamic error) {
    debugPrint('[STOMP] WebSocket 에러: $error');
    _isConnected = false;
    _connectedController.add(false);
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _retryDelay = (_retryDelay * 2).clamp(2, _maxRetryDelay);
    debugPrint('[STOMP] ${_retryDelay}초 후 재연결 시도');
  }

  // ── 구독 ─────────────────────────────────────────────────────────
  /// [destination] : 예) '/user/queue/location/reco'
  /// [subscriberKey] : 구독자 식별자 — 기본값은 destination과 동일.
  ///   같은 destination을 여러 곳에서 구독할 때 서로 다른 key를 지정하면
  ///   각각 독립적으로 콜백이 호출됨. key가 같으면 기존 콜백을 교체.
  void subscribe(
    String destination,
    StompFrameCallback onMessage, {
    String? subscriberKey,
  }) {
    final key = subscriberKey ?? destination;
    _subscriptions.putIfAbsent(destination, () => {})[key] = onMessage;
    if (_isConnected) {
      // destination에 대한 실제 STOMP 구독이 없으면 새로 등록
      if (!_activeSubs.containsKey(destination)) {
        _doSubscribe(destination);
      }
    }
    debugPrint('[STOMP] 구독 등록: $destination (key=$key, '
        '총 ${_subscriptions[destination]?.length ?? 0}개)');
  }

  /// plain-text / JSON-string body 를 raw String 그대로 수신할 때 사용.
  void subscribeRaw(
    String destination,
    StompRawCallback onRaw, {
    String? subscriberKey,
  }) {
    final key = subscriberKey ?? destination;
    _rawSubscriptions.putIfAbsent(destination, () => {})[key] = onRaw;
    if (_isConnected) {
      if (!_activeSubs.containsKey(destination)) {
        _doSubscribeRaw(destination);
      }
    }
    debugPrint('[STOMP] raw 구독 등록: $destination (key=$key)');
  }

  void _doSubscribeRaw(String destination) {
    _activeSubs[destination]?.call();
    _activeSubs[destination] = _client?.subscribe(
      destination: destination,
      callback: (frame) {
        final rawBody = frame.body;
        final callbacks = _rawSubscriptions[destination]?.values ?? [];
        for (final cb in callbacks) {
          cb(rawBody);
        }
      },
    );
    debugPrint('[STOMP] raw 구독 실행: $destination');
  }

  void _doSubscribe(String destination) {
    _activeSubs[destination]?.call();
    _activeSubs[destination] = _client?.subscribe(
      destination: destination,
      callback: (frame) {
        if (frame.body == null) return;
        Map<String, dynamic>? json;
        try {
          json = jsonDecode(frame.body!) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('[STOMP] 파싱 오류 ($destination): $e\nbody: ${frame.body}');
          return;
        }
        final callbacks = _subscriptions[destination]?.values ?? [];
        for (final cb in callbacks) {
          cb(json!);
        }
      },
    );
    debugPrint('[STOMP] 구독 실행: $destination');
  }

  // ── 구독 해제 ─────────────────────────────────────────────────────
  /// [subscriberKey]를 지정하면 해당 subscriber만 제거.
  /// 모든 subscriber가 제거되면 실제 STOMP 구독도 해제.
  /// [subscriberKey] 미지정 시 destination의 모든 subscriber + STOMP 구독 해제.
  void unsubscribe(String destination, {String? subscriberKey}) {
    if (subscriberKey != null) {
      _subscriptions[destination]?.remove(subscriberKey);
      _rawSubscriptions[destination]?.remove(subscriberKey);
      // 아직 다른 subscriber가 남아있으면 STOMP 구독 유지
      final remaining = (_subscriptions[destination]?.length ?? 0) +
          (_rawSubscriptions[destination]?.length ?? 0);
      if (remaining > 0) {
        debugPrint('[STOMP] 구독자 제거: $destination (key=$subscriberKey, 남은 구독자=$remaining)');
        return;
      }
    }
    // 전체 해제
    _subscriptions.remove(destination);
    _rawSubscriptions.remove(destination);
    _activeSubs[destination]?.call();
    _activeSubs.remove(destination);
    debugPrint('[STOMP] 구독 완전 해제: $destination');
  }

  // ── 메시지 전송 ───────────────────────────────────────────────────
  /// [destination] : 예) '/app/my'  또는  '/app/reco'
  void send({
    required String destination,
    required Map<String, dynamic> body,
  }) {
    if (!_isConnected || _client == null) {
      debugPrint('[STOMP] 전송 실패 — 미연결 상태 ($destination)');
      return;
    }
    _client!.send(
      destination: destination,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json'},
    );
  }

  // ── 연결 해제 ─────────────────────────────────────────────────────
  Future<void> disconnect() async {
    _subscriptions.clear();
    _rawSubscriptions.clear();
    _activeSubs.clear();
    _client?.deactivate();
    _client = null;
    _isConnected = false;
    debugPrint('[STOMP] 연결 종료');
    _connectedController.add(false);
  }

  void dispose() {
    disconnect();
    _connectedController.close();
  }
}
