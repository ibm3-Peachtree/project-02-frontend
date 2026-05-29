import 'package:dio/dio.dart';
import 'package:ruttu_app/core/constants/api_constants.dart';

import '../models/address_model.dart';

abstract class AddressRepository {
  Future<List<AddressModel>> getAddresses();

  Future<AddressModel> addAddress({
    required String name,
    required String roadAddress,
    String? jibunAddress,
  });
}

class ApiAddressRepository implements AddressRepository {
  final Dio _dio;
  ApiAddressRepository(this._dio);

  @override
  Future<List<AddressModel>> getAddresses() async {
    return [];
  }
  
  @override
  Future<AddressModel> addAddress({
    required String name,
    required String roadAddress,
    String? jibunAddress,
  }) async {
    print("🔥 address 생성 API 호출 시작");
    final res = await _dio.post(
      ApiConstants.addresses,
      data: {
        'name': name,
        'roadAddress': roadAddress,
        'jibunAddress': jibunAddress,
      },
    );
    print("🔥 address 생성 API 응답 옴");

    return AddressModel.fromJson(res.data);
  }

}

class MockAddressRepository implements AddressRepository {
  @override
  Future<List<AddressModel>> getAddresses() async {
    return [
      AddressModel(
        addressId: 1,
        name: "집",
        roadAddress: "서울특별시 강남구 테헤란로 123",
        latitude: 37.5012,
        longitude: 127.0396,
      ),
      AddressModel(
        addressId: 2,
        name: "회사",
        roadAddress: "서울특별시 중구 세종대로 110",
        latitude: 37.5665,
        longitude: 126.9780,
      ),
    ];
  }

@override
Future<AddressModel> addAddress({
  required String name,
  required String roadAddress,
  String? jibunAddress,
}) async {
  return AddressModel(
    addressId: DateTime.now().millisecondsSinceEpoch,
    name: name,
    roadAddress: roadAddress,
    jibunAddress: jibunAddress,
  );
}
}