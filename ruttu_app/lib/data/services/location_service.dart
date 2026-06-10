import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// GPS 스트림을 반환하기 전에 런타임 권한을 확인합니다.
  /// - 권한이 이미 있으면 바로 통과
  /// - denied 상태면 요청 (최초 가입 시 요청했어야 하나, 재설치 등으로 초기화됐을 때 대비)
  /// - deniedForever / 서비스 비활성화면 예외를 throw합니다 → 호출부에서 설정 안내
  Future<void> ensurePermission() async {
    // 위치 서비스 자체가 꺼져 있는 경우
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // 아직 허용하지 않은 경우 → 요청
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw PermissionDeniedException(
        permission == LocationPermission.deniedForever
            ? '위치 권한이 영구적으로 거부됐어요. 설정 앱에서 권한을 허용해 주세요.'
            : '위치 권한이 거부됐어요.',
      );
    }
  }

  /// 권한 확인 후 위치 스트림을 반환합니다.
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        // 에뮬레이터·실내 등 GPS 이동이 없어도 최소 5초마다 이벤트 발생
        intervalDuration: const Duration(seconds: 5),
        forceLocationManager: false,
      ),
    );
  }

  /// GPS 권한이 꺼진 경우 설정 유도 다이얼로그를 표시합니다.
  /// live_location_provider의 catchError에서 호출합니다.
  static void showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('위치 권한 필요'),
        content: const Text(
          '실시간 경로 안내를 사용하려면 위치 권한이 필요해요.\n'
          '설정 앱에서 위치 권한을 "앱 사용 중 허용"으로 변경해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );
  }
}
