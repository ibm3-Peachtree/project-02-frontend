import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/models/address_model.dart';
import '../../../data/services/location_service.dart';
import 'address_provider.dart';
import 'home_provider.dart';
import 'home_state.dart';

const double _arrivalRadiusMeters = 80.0;
const double _departureRadiusMeters = 100.0;

AddressModel? _findAddressByName(List<AddressModel> list, String name) {
  try {
    return list.firstWhere((a) => a.name == name);
  } catch (_) {
    return null;
  }
}

// GPS 켜짐 여부를 외부에서 볼 수 있는 상태 Provider
final gpsActiveProvider = StateProvider<bool>((ref) => false);

final liveLocationProvider = Provider<void>((ref) {
  ref.keepAlive();
  final locationService = LocationService();

  StreamSubscription<Position>? sub;
  List<AddressModel>? cachedAddresses;
  Timer? scheduleTimer;

  Future<List<AddressModel>> getAddresses() async {
    if (cachedAddresses != null) return cachedAddresses!;
    final addressRepo = ref.read(addressRepositoryProvider);
    cachedAddresses = await addressRepo.getAddresses();
    return cachedAddresses!;
  }

  void stopGps() {
    if (sub == null) return;
    sub?.cancel();
    sub = null;
    try { ref.read(gpsActiveProvider.notifier).state = false; } catch (_) {}
    debugPrint('[LiveLocation] GPS 종료됨');
  }

  void startGps() {
    if (sub != null) return; // 이미 실행 중

    locationService.ensurePermission().then((_) {
      sub = locationService.getLocationStream().listen(
        (position) async {
          try {
            if (!(ref.read(gpsActiveProvider))) {
              ref.read(gpsActiveProvider.notifier).state = true;
            }
          } catch (_) {}

          final homeState = ref.read(homeProvider);
          final routine = homeState.activeRoutine;
          if (routine == null) return;

          final safeSpeed = position.speed < 0 ? 0.0 : position.speed;

          try {
            await ref.read(homeRepositoryProvider).sendLiveLocation(
                  latitude: position.latitude,
                  longitude: position.longitude,
                  speed: safeSpeed,
                  accuracy: position.accuracy,
                );
          } catch (e) {
            debugPrint('[LiveLocation] 전송 실패: $e');
          }

          final addresses = await getAddresses();

          // 출발지 이탈 감지 → active 전환 (preActive 상태일 때만)
          if (homeState.status == HomeStatus.preActive) {
            final dep = _findAddressByName(addresses, routine.departureAddressName);
            if (dep?.latitude != null && dep?.longitude != null) {
              final dist = Geolocator.distanceBetween(
                position.latitude, position.longitude,
                dep!.latitude!, dep.longitude!,
              );
              if (dist > _departureRadiusMeters) {
                debugPrint('[LiveLocation] 출발지 이탈 (${dist.toStringAsFixed(0)}m) → 경로 자동 시작');
                await ref.read(homeProvider.notifier).startRoute();
                return;
              }
            }
          }

          // 목적지 도달 체크 (active 상태일 때만)
          if (homeState.status == HomeStatus.active) {
            final arr = _findAddressByName(addresses, routine.arrivalAddressName);
            if (arr?.latitude != null && arr?.longitude != null) {
              final dist = Geolocator.distanceBetween(
                position.latitude, position.longitude,
                arr!.latitude!, arr.longitude!,
              );
              if (dist <= _arrivalRadiusMeters) {
                debugPrint('[LiveLocation] 목적지 도달 (${dist.toStringAsFixed(0)}m) → 자동 종료');
                ref.read(homeProvider.notifier).arriveByGps();
                stopGps(); // ← 도착 시 GPS 종료
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
    }).catchError((e) {
      debugPrint('[LiveLocation] 권한 오류: $e');
    });
  }

  // ─── homeProvider 상태 변화 감지 → GPS 자동 제어 ───────────────
  ref.listen<HomeState>(homeProvider, (prev, next) {
    // 1. 사용자가 "시작" 버튼을 누름 → active 전환 → GPS 켜기
    if (prev?.status != HomeStatus.active && next.status == HomeStatus.active) {
      debugPrint('[LiveLocation] 경로 시작 감지 → GPS 켜기');
      startGps();
    }

    // 2. 사용자가 "종료" 버튼을 누름 또는 도착 → preActive 전환 → GPS 끄기
    if (prev?.status == HomeStatus.active && next.status != HomeStatus.active) {
      debugPrint('[LiveLocation] 경로 종료 감지 → GPS 끄기');
      stopGps();
    }

    // 3. preActive 상태에서 출발 임박(10분 전) → GPS 미리 켜기
    if (next.status == HomeStatus.preActive && next.isDepartureImminent && sub == null) {
      debugPrint('[LiveLocation] 출발 임박 감지 → GPS 미리 켜기');
      startGps();
    }
  });

  // 1분마다 active 상태인데 GPS 꺼진 경우 재시작 (앱 재시작 복구)
  scheduleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
    final homeState = ref.read(homeProvider);
    if (homeState.status == HomeStatus.active && sub == null) {
      debugPrint('[LiveLocation] active인데 GPS 꺼짐 감지 → 재시작');
      startGps();
    }
  });

  // 앱 시작 시 이미 active 상태면 GPS 즉시 시작
  final initialState = ref.read(homeProvider);
  if (initialState.status == HomeStatus.active ||
      (initialState.status == HomeStatus.preActive && initialState.isDepartureImminent)) {
    startGps();
  }

  ref.onDispose(() {
    stopGps();
    scheduleTimer?.cancel();
  });
});