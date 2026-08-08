import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shared_point.dart';
import '../services/sharing_service.dart';
import 'auth_provider.dart';

final sharingServiceProvider = Provider<SharingService>((ref) {
  ref.watch(currentUserUidProvider);
  return SharingService();
});

final incomingSharesProvider = StreamProvider<List<SharedPoint>>((ref) {
  final service = ref.watch(sharingServiceProvider);
  return service.getIncomingSharesStream();
});

final incomingShareCountProvider = Provider<int>((ref) {
  final shares = ref.watch(incomingSharesProvider);
  return shares.when(
    data: (list) => list.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
