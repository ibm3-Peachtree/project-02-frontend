// GET /address, POST /address 응답
class AddressModel {
  final int addressId;
  final String name;       // 별칭 (예: "집", "회사")
  final String address;    // 도로명주소 (+ 상세주소)
  final double? latitude;  // 백엔드 geocoding 후 채워짐
  final double? longitude;

  const AddressModel({
    required this.addressId,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) => AddressModel(
        addressId: json['addressId'] as int,
        name:      json['name']      as String,
        address:   json['address']   as String,
        latitude:  (json['latitude']  as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'addressId': addressId,
        'name':      name,
        'address':   address,
        if (latitude  != null) 'latitude':  latitude,
        if (longitude != null) 'longitude': longitude,
      };
}
