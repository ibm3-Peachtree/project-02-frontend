import 'package:geolocator/geolocator.dart';

class LocationService {
  /// GPS 스트림을 반환하기 전에 런타임 권한을 확인/요청합니다.
  /// 권한이 없으면 [PermissionDeniedException]을 throw합니다.
  Future<void> ensurePermission() async {
    // 위치 서비스 자체가 꺼져 있는 경우
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // 아직 한 번도 묻지 않은 경우 → 요청
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      // deniedForever 이면 설정 앱으로 보내야 함
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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }
}