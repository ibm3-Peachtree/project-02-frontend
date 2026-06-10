import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/models/address_model.dart';
import '../../../data/repositories/address_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/stomp_service.dart';
import '../../auth/providers/network_provider.dart';
import 'home_provider.dart';
import 'home_state.dart';
import 'live_route_provider.dart' show recoRouteProvider, myRouteProvider, RecoRouteState, MyRouteState;

// ── 상수 ─────────────────────────────────────────────────────────────
const double _arrivalRadiusMeters   = 80.0;
const double _departureRadiusMeters = 100.0;

// ── STOMP 전송 목적지 ─────────────────────────────────────────────────
//   LiveLocationController:
//     @MessageMapping("/location/my")   → 실제 destination: /app/location/my
//     @MessageMapping("/location/reco") → 실제 destination: /app/location/reco
const _stompDestMy   = '/app/location/my';
const _stompDestReco = '/app/location/reco';

// ── GPS 켜짐 여부 (외부 노출) ─────────────────────────────────────────
final gpsActiveProvider = StateProvider<bool>((ref) => false);

// ── liveLocationProvider ──────────────────────────────────────────────
//
//  [변경] HTTP PATCH /me/routines/active → STOMP /app/my | /app/reco
//
//  서버 처리 흐름:
//    앱 → STOMP /app/my|reco
//      → LiveLocationController.myLocation|recoLocation()
//        ① sendRouteProgress()      → push /user/queue/status
//        ② getMyCurrentSection()    → push /user/queue/location/my
//           또는 getRecoCurrentSection() → push /user/queue/location/reco
//        ③ updateLocation()         → Redis 저장
//
//  ② push 수신은 live_route_provider / reco_live_route_provider 에서 처리.
// ─────────────────────────────────────────────────────────────────────
final liveLocationProvider = Provider<void>((ref) {
  ref.keepAlive();
  final locationService = LocationService();
  final stomp = StompService.instance;

  StreamSubscription<Position>? sub;
  // alias → AddressModel 캐시 (getAddressByName 결과를 재사용)
  final Map<String, AddressModel?> addrCache = {};
  Timer? scheduleTimer;

  final addressRepo = ApiAddressRepository(ref.read(apiClientProvider));

  Future<AddressModel?> getAddressByAlias(String alias) async {
    if (addrCache.containsKey(alias)) return addrCache[alias];
    try {
      final addr = await addressRepo.getAddressByName(alias);
      addrCache[alias] = addr;
      return addr;
    } catch (_) {
      addrCache[alias] = null; // 조회 실패 시 null 캐시 (무한 재시도 방지)
      return null;
    }
  }

  void ensureStompConnected() {
    if (!stomp.isConnected) stomp.connect();
  }

  // ── STOMP 위치 전송 ─────────────────────────────────────────────
  void sendLocation({
    required double latitude,
    required double longitude,
    required double speed,
    required double accuracy,
    required bool isReco,
  }) {
    stomp.send(
      destination: isReco ? _stompDestReco : _stompDestMy,
      body: {
        'latitude':  latitude,
        'longitude': longitude,
        'speed':     speed,
        'accuracy':  accuracy,
      },
    );
    debugPrint('[LiveLocation] STOMP → ${isReco ? _stompDestReco : _stompDestMy}'
        '  lat=$latitude  lng=$longitude');
  }

  bool _starting = false;

  void stopGps() {
    if (sub == null) return;
    sub?.cancel();
    sub = null;
    _starting = false;
    try { ref.read(gpsActiveProvider.notifier).state = false; } catch (_) {}
    debugPrint('[LiveLocation] GPS 종료됨');
  }


  void startGps() {
    if (sub != null || _starting) return;
    _starting = true;

    ensureStompConnected();

    locationService.ensurePermission().then((_) {
      // 즉시 현재 위치를 한 번 전송 (에뮬레이터·GPS 이동 없는 경우 대비)
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
          .then((pos) {
        final isRecoActive = ref.read(recoRouteProvider).isActive;
        if (ref.read(homeProvider).activeRoutine == null) return;
        sendLocation(
          latitude:  pos.latitude,
          longitude: pos.longitude,
          speed:     pos.speed < 0 ? 0.0 : pos.speed,
          accuracy:  pos.accuracy,
          isReco:    isRecoActive,
        );
        debugPrint('[LiveLocation] 즉시 위치 전송 (startGps) isReco=$isRecoActive');
      }).catchError((e) {
        debugPrint('[LiveLocation] 즉시 위치 전송 실패 (무시): $e');
      });
      sub = locationService.getLocationStream().listen(
        (position) async {
          try {
            if (!ref.read(gpsActiveProvider)) {
              ref.read(gpsActiveProvider.notifier).state = true;
            }
          } catch (_) {}

          final homeState = ref.read(homeProvider);
          final routine   = homeState.activeRoutine;
          if (routine == null) return;

          final safeSpeed = position.speed < 0 ? 0.0 : position.speed;

          // ✅ 추천 경로 활성 중이면 /app/location/reco, 아니면 /app/location/my 전송
          final isRecoActive = ref.read(recoRouteProvider).isActive;
          sendLocation(
            latitude:  position.latitude,
            longitude: position.longitude,
            speed:     safeSpeed,
            accuracy:  position.accuracy,
            isReco:    isRecoActive,
          );

          // 출발지 이탈 감지 → active 전환
          if (homeState.status == HomeStatus.preActive) {
            final dep = await getAddressByAlias(routine.departureAddressName);
            if (dep?.latitude != null && dep?.longitude != null) {
              final dist = Geolocator.distanceBetween(
                position.latitude, position.longitude,
                dep!.latitude!, dep.longitude!,
              );
              if (dist > _departureRadiusMeters) {
                debugPrint('[LiveLocation] 출발지 이탈 ${dist.toStringAsFixed(0)}m → 자동 시작');
                await ref.read(homeProvider.notifier).startRoute();
                return;
              }
            }
          }

          // 목적지 도달 체크
          if (homeState.status == HomeStatus.active) {
            final arr = await getAddressByAlias(routine.arrivalAddressName);
            if (arr?.latitude != null && arr?.longitude != null) {
              final dist = Geolocator.distanceBetween(
                position.latitude, position.longitude,
                arr!.latitude!, arr.longitude!,
              );
              if (dist <= _arrivalRadiusMeters) {
                debugPrint('[LiveLocation] 목적지 도달 ${dist.toStringAsFixed(0)}m → 자동 종료');
                // ✅ recoRoute / myRoute isActive 초기화 (안내중 상태 해제)
                if (ref.read(recoRouteProvider).isActive) {
                  ref.read(recoRouteProvider.notifier).stopRecoRoute();
                }
                if (ref.read(myRouteProvider).isActive) {
                  ref.read(myRouteProvider.notifier).stopMyRoute();
                }
                ref.read(homeProvider.notifier).arriveByGps();
                stopGps();
              }
            }
          }
        },
        onError: (e) {
          debugPrint('[LiveLocation] 스트림 에러: $e');
          try { ref.read(gpsActiveProvider.notifier).state = false; } catch (_) {}
        },
      );
      debugPrint('[LiveLocation] GPS 스트림 구독 시작');
      _starting = false;
    }).catchError((e) {
      _starting = false;
      debugPrint('[LiveLocation] 권한 오류: $e');
    });
  }

  // ── homeProvider 상태 변화 감지 ─────────────────────────────────
  // ── homeProvider: 출발/도착/임박 감지 ──────────────────────────────
  ref.listen<HomeState>(homeProvider, (prev, next) {
    // 나의 경로 시작 (myRouteProvider.isActive로 별도 감지하므로 여기선 preActive→active 전환만 처리)
    if (prev?.status != HomeStatus.active && next.status == HomeStatus.active) {
      // recoRoute가 이미 active면 GPS는 reco 전송 중이므로 스킵하지 않고 그냥 시작
      // (sendLocation 내부에서 isRecoActive를 실시간 판단함)
      debugPrint('[LiveLocation] 경로 active 전환 → GPS 시작');
      ensureStompConnected();
      startGps();
    }

    if (prev?.status == HomeStatus.active && next.status != HomeStatus.active) {
      debugPrint('[LiveLocation] 경로 종료 → GPS 끄기');
      stopGps();
    }

    if (next.status == HomeStatus.preActive &&
        next.isDepartureImminent &&
        sub == null) {
      debugPrint('[LiveLocation] 출발 임박 → GPS 미리 켜기');
      ensureStompConnected();
      startGps();
    }
  });

  // ── myRouteProvider: 나의 경로 시작/종료 감지 ───────────────────────
  ref.listen<MyRouteState>(myRouteProvider, (prev, next) {
    if (prev?.isActive != true && next.isActive == true) {
      debugPrint('[LiveLocation] 나의 경로 시작 → GPS 켜기 (/app/location/my)');
      ensureStompConnected();
      startGps();
    }
    if (prev?.isActive == true && next.isActive != true) {
      // recoRoute도 꺼진 경우에만 GPS 중단 (둘 다 비활성이면 전송 불필요)
      if (!ref.read(recoRouteProvider).isActive) {
        debugPrint('[LiveLocation] 나의 경로 종료 + reco 비활성 → GPS 끄기');
        stopGps();
      }
    }
  });

  // ── recoRouteProvider: 추천 경로 시작/종료 감지 ─────────────────────
  ref.listen<RecoRouteState>(recoRouteProvider, (prev, next) {
    if (prev?.isActive != true && next.isActive == true) {
      debugPrint('[LiveLocation] 추천 경로 시작 → GPS 켜기 (/app/location/reco)');
      ensureStompConnected();
      if (sub != null) {
        // GPS가 이미 켜진 상태 → isReco=true로 즉시 한 번 전송
        Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
            .then((pos) {
          if (ref.read(homeProvider).activeRoutine == null) return;
          sendLocation(
            latitude:  pos.latitude,
            longitude: pos.longitude,
            speed:     pos.speed < 0 ? 0.0 : pos.speed,
            accuracy:  pos.accuracy,
            isReco:    true,
          );
          debugPrint('[LiveLocation] reco 즉시 위치 전송 (GPS 이미 활성)');
        }).catchError((e) {
          debugPrint('[LiveLocation] reco 즉시 전송 실패 (무시): $e');
        });
      } else {
        startGps();
      }
    }
    if (prev?.isActive == true && next.isActive != true) {
      // myRoute도 꺼진 경우에만 GPS 중단
      if (!ref.read(myRouteProvider).isActive) {
        debugPrint('[LiveLocation] 추천 경로 종료 + my 비활성 → GPS 끄기');
        stopGps();
      } else {
        // myRoute가 아직 active면 계속 전송 (isReco=false로 전환됨)
        debugPrint('[LiveLocation] 추천 경로 종료 → my 경로로 GPS 전환 유지');
      }
    }
  });

  // 1분마다 active인데 GPS 꺼진 경우 재시작
  scheduleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
    final s = ref.read(homeProvider);
    final myActive   = ref.read(myRouteProvider).isActive;
    final recoActive = ref.read(recoRouteProvider).isActive;
    if ((s.status == HomeStatus.active || myActive || recoActive) && sub == null) {
      debugPrint('[LiveLocation] active인데 GPS 꺼짐 → 재시작');
      startGps();
    }
  });

  // 앱 시작 시 이미 active 또는 출발 임박이면 즉시 시작
  final initial = ref.read(homeProvider);
  if (initial.status == HomeStatus.active ||
      (initial.status == HomeStatus.preActive && initial.isDepartureImminent)) {
    ensureStompConnected();
    startGps();
  }

  ref.onDispose(() {
    stopGps();
    scheduleTimer?.cancel();
  });
});
