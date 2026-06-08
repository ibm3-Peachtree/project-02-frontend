import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/network_provider.dart';
import 'home_repository.dart';

/// HomeRepository의 단일 Provider.
/// home_provider, live_route_provider, reco_live_route_provider 모두 여기서 import.
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return ApiHomeRepository(ref.read(apiClientProvider).dio);
});
