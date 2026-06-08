import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/network_provider.dart';
import 'routine_repository.dart';

/// RoutineRepository의 단일 Provider.
/// homeRepositoryProvider와 동일한 패턴.
final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  return ApiRoutineRepository(ref.read(apiClientProvider));
});
