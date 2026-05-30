import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/address_repository.dart';
import '../../auth/providers/network_provider.dart';

// ✅ Mock → API 실 연동으로 교체
final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  final client = ref.read(apiClientProvider);
  return ApiAddressRepository(client);
});