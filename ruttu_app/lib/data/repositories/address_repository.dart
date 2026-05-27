import '../models/address_model.dart';

abstract class AddressRepository {
  Future<List<AddressModel>> getAddresses();

  Future<AddressModel> addAddress({
    required String name,
    required String address,
    double? latitude,
    double? longitude,
  });
}
class MockAddressRepository implements AddressRepository {
  @override
  Future<List<AddressModel>> getAddresses() async {
    return [
      AddressModel(
        addressId: 1,
        name: "집",
        address: "서울특별시 강남구 테헤란로 123",
        latitude: 37.5012,
        longitude: 127.0396,
      ),
      AddressModel(
        addressId: 2,
        name: "회사",
        address: "서울특별시 중구 세종대로 110",
        latitude: 37.5665,
        longitude: 126.9780,
      ),
    ];
  }

@override
Future<AddressModel> addAddress({
  required String name,
  required String address,
  double? latitude,
  double? longitude,
}) async {
  return AddressModel(
    addressId: DateTime.now().millisecondsSinceEpoch,
    name: name,
    address: address,
    latitude: latitude,
    longitude: longitude,
  );
}
}