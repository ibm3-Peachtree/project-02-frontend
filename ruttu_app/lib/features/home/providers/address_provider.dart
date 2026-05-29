import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ Provider import 추가
import 'package:ruttu_app/features/auth/providers/network_provider.dart';
import '../../../data/repositories/address_repository.dart';

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
      return ApiAddressRepository(
    ref.read(apiClientProvider).dio,
  );
});