import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ Provider import 추가
import '../../../data/repositories/address_repository.dart';

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return MockAddressRepository();
});