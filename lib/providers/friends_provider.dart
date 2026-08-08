import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/friendship.dart';
import '../services/friend_service.dart';
import 'auth_provider.dart';

final friendServiceProvider = Provider<FriendService>((ref) {
  ref.watch(currentUserUidProvider);
  return FriendService();
});

final friendsListProvider = StreamProvider<List<Friendship>>((ref) {
  final service = ref.watch(friendServiceProvider);
  return service.getFriendsStream();
});

final pendingRequestsProvider = StreamProvider<List<Friendship>>((ref) {
  final service = ref.watch(friendServiceProvider);
  return service.getPendingRequestsStream();
});

final pendingRequestCountProvider = Provider<int>((ref) {
  final pending = ref.watch(pendingRequestsProvider);
  return pending.when(
    data: (list) => list.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
