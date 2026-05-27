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

// ✅ GPS 실제 켜짐 여부를 외부에서 볼 수 있도록 상태 Provider 분리
final gpsActiveProvider = StateProvider<bool>((ref) => false);

final liveLocationProvider = Provider<void>((ref) {
  ref.keepAlive(); // dispose 방지 — GPS 스트림을 앱 생명주기 동안 유지
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
    // ✅ ref가 살아있을 때만 상태 변경
    try { ref.read(gpsActiveProvider.notifier).state = false; } catch (_) {}
    print('[LiveLocation] GPS 종료됨');
  }

  void startGps() {
    if (sub != null) return;

    locationService.ensurePermission().then((_) {
      // ✅ 권한 확인 후 실제 스트림 연결될 때 GPS 켜짐 표시
      sub = locationService.getLocationStream().listen(
        (position) async {
          // ✅ 첫 위치 수신 시 gpsActive = true 로 변경
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
            print('[LiveLocation] 전송 실패: $e');
          }

          final addresses = await getAddresses();

          // 출발지 이탈 감지 → active 전환
          if (homeState.status == HomeStatus.preActive) {
            final dep = _findAddressByName(addresses, routine.departureAddressName);
            if (dep?.latitude != null && dep?.longitude != null) {
              final dist = Geolocator.distanceBetween(
                position.latitude, position.longitude,
                dep!.latitude!, dep.longitude!,
              );
              if (dist > _departureRadiusMeters) {
                print('[LiveLocation] 출발지 이탈 (${dist.toStringAsFixed(0)}m) → 경로 시작');
                await ref.read(homeProvider.notifier).startRoute();
                return;
              }
            }
          }

          // 목적지 도달 체크
          if (homeState.status == HomeStatus.active) {
            final arr = _findAddressByName(addresses, routine.arrivalAddressName);
            if (arr?.latitude != null && arr?.longitude != null) {
              final dist = Geolocator.distanceBetween(
                position.latitude, position.longitude,
                arr!.latitude!, arr.longitude!,
              );
              if (dist <= _arrivalRadiusMeters) {
                print('[LiveLocation] 목적지 도달 → GPS 종료');
                ref.read(homeProvider.notifier).arriveByGps();
                stopGps();
              }
            }
          }
        },
        onError: (e) {
          print('[LiveLocation] 스트림 에러: $e');
          // ✅ 에러 시에도 GPS 상태 초기화
          try { ref.read(gpsActiveProvider.notifier).state = false; } catch (_) {}
        },
      );
      print('[LiveLocation] GPS 스트림 구독 시작');
    }).catchError((e) {
      print('[LiveLocation] 권한 오류: $e — GPS 켜기 실패');
      // ✅ 권한 거부 시 gpsActive = false 유지, 재시도 안 함
    });
  }

  // 1분마다 출발 임박 여부 확인
  scheduleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
    final homeState = ref.read(homeProvider);
    if (homeState.status == HomeStatus.preActive && homeState.isDepartureImminent) {
      print('[LiveLocation] 출발 예정 10분 전 → GPS 자동 시작');
      startGps();
    }
    // active인데 GPS가 꺼져 있으면 재시작 (앱 재시작 후 복구)
    if (homeState.status == HomeStatus.active && sub == null) {
      print('[LiveLocation] active 상태인데 GPS 꺼짐 → 재시작');
      startGps();
    }
  });

  // 앱 시작 시 즉시 확인
  final initialState = ref.read(homeProvider);
  if (initialState.isDepartureImminent || initialState.status == HomeStatus.active) {
    startGps();
  }

  ref.onDispose(() {
    stopGps();
    scheduleTimer?.cancel();
  });
});