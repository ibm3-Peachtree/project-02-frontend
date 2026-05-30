import '../models/address_model.dart';
import '../../core/network/api_client.dart';

// ──────────────────────────────────────────────
// Abstract
// ──────────────────────────────────────────────
abstract class AddressRepository {
  /// GET /address — 내 주소 목록 조회
  Future<List<AddressModel>> getAddresses();

  /// GET /address/{addressId} — 단건 조회
  Future<AddressModel> getAddressById(int addressId);

  /// GET /address/{name} — 별칭으로 조회
  Future<AddressModel> getAddressByName(String name);

  /// POST /address — 주소 생성
  Future<AddressModel> createAddress({
    required String name,
    required String roadAddress,
    String jibunAddress,
  });

  /// PUT /address/{addressId} — 주소 수정
  Future<AddressModel> updateAddress({
    required int addressId,
    required String name,
    required String roadAddress,
    String jibunAddress,
  });

  /// DELETE /address/{addressId} — 주소 삭제
  Future<void> deleteAddress(int addressId);

  // 호환용
  Future<AddressModel> addAddress({
    required String name,
    required String address,
    double? latitude,
    double? longitude,
  });
}

// ──────────────────────────────────────────────
// API (실 서버 연동)
// ──────────────────────────────────────────────
class ApiAddressRepository implements AddressRepository {
  ApiAddressRepository(this._client);
  final ApiClient _client;

  @override
  Future<List<AddressModel>> getAddresses() async {
    final res = await _client.dio.get('/address');
    final list = res.data as List<dynamic>;
    return list
        .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AddressModel> getAddressById(int addressId) async {
    final res = await _client.dio.get('/address/$addressId');
    return AddressModel.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<AddressModel> getAddressByName(String name) async {
    final res = await _client.dio.get('/address/name/$name');
    return AddressModel.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<AddressModel> createAddress({
    required String name,
    required String roadAddress,
    String jibunAddress = '',
  }) async {
    final res = await _client.dio.post(
      '/address',
      data: {
        'name': name,
        'roadAddress': roadAddress,
        'jibunAddress': jibunAddress,
      },
    );
    return AddressModel.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<AddressModel> updateAddress({
    required int addressId,
    required String name,
    required String roadAddress,
    String jibunAddress = '',
  }) async {
    final res = await _client.dio.put(
      '/address/$addressId',
      data: {
        'name': name,
        'roadAddress': roadAddress,
        'jibunAddress': jibunAddress,
      },
    );
    return AddressModel.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteAddress(int addressId) async {
    await _client.dio.delete('/address/$addressId');
  }

  // 호환용 (기존 코드 호출 대응)
  @override
  Future<AddressModel> addAddress({
    required String name,
    required String address,
    double? latitude,
    double? longitude,
  }) =>
      createAddress(name: name, roadAddress: address);
}

// ──────────────────────────────────────────────
// Mock (테스트/개발용)
// ──────────────────────────────────────────────
class MockAddressRepository implements AddressRepository {
  final List<AddressModel> _store = [
    AddressModel(
      addressId: 1,
      name: '집',
      roadAddress: '서울특별시 강남구 테헤란로 123',
      jibunAddress: '서울특별시 강남구 역삼동 123-1',
      latitude: 37.5012,
      longitude: 127.0396,
    ),
    AddressModel(
      addressId: 2,
      name: '회사',
      roadAddress: '서울특별시 중구 세종대로 110',
      jibunAddress: '서울특별시 중구 태평로1가 31',
      latitude: 37.5665,
      longitude: 126.9780,
    ),
  ];

  @override
  Future<List<AddressModel>> getAddresses() async => List.of(_store);

  @override
  Future<AddressModel> getAddressById(int addressId) async {
    return _store.firstWhere(
      (a) => a.addressId == addressId,
      orElse: () => throw Exception('주소를 찾을 수 없습니다.'),
    );
  }

  @override
  Future<AddressModel> getAddressByName(String name) async {
    return _store.firstWhere(
      (a) => a.name == name,
      orElse: () => throw Exception('해당 이름의 주소를 찾을 수 없습니다.'),
    );
  }

  @override
  Future<AddressModel> createAddress({
    required String name,
    required String roadAddress,
    String jibunAddress = '',
  }) async {
    final model = AddressModel(
      addressId: DateTime.now().millisecondsSinceEpoch,
      name: name,
      roadAddress: roadAddress,
      jibunAddress: jibunAddress,
    );
    _store.add(model);
    return model;
  }

  @override
  Future<AddressModel> updateAddress({
    required int addressId,
    required String name,
    required String roadAddress,
    String jibunAddress = '',
  }) async {
    final idx = _store.indexWhere((a) => a.addressId == addressId);
    if (idx == -1) throw Exception('주소를 찾을 수 없습니다.');
    final updated = AddressModel(
      addressId: addressId,
      name: name,
      roadAddress: roadAddress,
      jibunAddress: jibunAddress,
      latitude: _store[idx].latitude,
      longitude: _store[idx].longitude,
    );
    _store[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteAddress(int addressId) async {
    _store.removeWhere((a) => a.addressId == addressId);
  }

  @override
  Future<AddressModel> addAddress({
    required String name,
    required String address,
    double? latitude,
    double? longitude,
  }) =>
      createAddress(name: name, roadAddress: address);
}