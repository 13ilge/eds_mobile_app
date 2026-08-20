import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/friendship.dart';
import '../providers/auth_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/subscription_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/design_tokens.dart';
import 'paywall_view.dart';

class FriendsView extends ConsumerStatefulWidget {
  const FriendsView({super.key});

  @override
  ConsumerState<FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends ConsumerState<FriendsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddFriendDialog() {
    final isPro = ref.read(isProProvider);
    if (!isPro) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaywallView()),
      );
      return;
    }

    final emailController = TextEditingController();
    bool isSearching = false;
    String? resultMessage;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: DesignTokens.cardSurface,
              title: Text('Arkadaş Ekle', style: DesignTokens.labelLarge),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                        fontSize: 14, color: DesignTokens.textDark),
                    decoration: const InputDecoration(
                      labelText: 'E-posta Adresi',
                      labelStyle:
                          TextStyle(fontSize: 14, color: DesignTokens.textGrey),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: DesignTokens.textGrey)),
                      focusedBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: DesignTokens.primaryBlue)),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                  if (resultMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        resultMessage!,
                        style: TextStyle(
                          color: resultMessage!.contains('gönderildi')
                              ? DesignTokens.statusSafe
                              : DesignTokens.statusViolation,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal',
                      style: TextStyle(color: DesignTokens.textGrey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSearching
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          if (email.isEmpty) return;

                          setDialogState(() {
                            isSearching = true;
                            resultMessage = null;
                          });

                          try {
                            final service = ref.read(friendServiceProvider);
                            final user =
                                await service.searchUserByEmail(email);

                            if (user == null) {
                              setDialogState(() {
                                isSearching = false;
                                resultMessage =
                                    'Bu e-posta adresine ait kullanıcı bulunamadı.';
                              });
                              return;
                            }

                            final myUid = ref.read(currentUserUidProvider);
                            if (user.uid == myUid) {
                              setDialogState(() {
                                isSearching = false;
                                resultMessage =
                                    'Kendinize arkadaşlık isteği gönderemezsiniz.';
                              });
                              return;
                            }

                            await service.sendFriendRequest(
                                user.uid, user.displayName);

                            setDialogState(() {
                              isSearching = false;
                              resultMessage =
                                  '${user.displayName} kullanıcısına istek gönderildi!';
                            });

                            await Future.delayed(
                                const Duration(milliseconds: 1500));
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            setDialogState(() {
                              isSearching = false;
                              resultMessage = e.toString().replaceAll(
                                  'Exception: ', '');
                            });
                          }
                        },
                  child: const Text('Ara ve Gönder'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmRemoveFriend(Friendship friendship) {
    final myUid = ref.read(currentUserUidProvider) ?? '';
    final friendName = friendship.friendNameFor(myUid);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arkadaşı Sil'),
        content: Text(
            '$friendName kişisini arkadaş listenizden silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal',
                style: TextStyle(color: DesignTokens.textGrey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(friendServiceProvider)
                    .removeFriend(friendship.id);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                        content:
                            Text('$friendName arkadaş listenizden silindi.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Hata: $e')),
                  );
                }
              }
            },
            child: const Text('Sil',
                style: TextStyle(color: DesignTokens.statusViolation)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(pendingRequestCountProvider);

    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.background,
        elevation: 0,
        centerTitle: true,
        title: const Text('Arkadaşlarım',
            style: TextStyle(fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: DesignTokens.primaryBlue,
          unselectedLabelColor: DesignTokens.textGrey,
          indicatorColor: DesignTokens.primaryBlue,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(text: 'Arkadaşlarım'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Bekleyen İstekler'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: DesignTokens.statusViolation,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Sıralama'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFriendDialog,
        backgroundColor: DesignTokens.primaryBlue,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label:
            const Text('Arkadaş Ekle', style: TextStyle(color: Colors.white)),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsTab(),
          _buildPendingTab(),
          _buildLeaderboardTab(),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    final friendsAsync = ref.watch(friendsListProvider);
    final myUid = ref.watch(currentUserUidProvider) ?? '';
    
    return friendsAsync.when(
      data: (friends) {
        final friendUids = friends.map((f) => f.friendUidFor(myUid)).toSet();
        friendUids.add(myUid); // Kendimizi de ekleyelim
        
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .orderBy('averageScore', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}'));
            }

            final allDocs = snapshot.data?.docs ?? [];
            // Sadece arkadaşları ve kendimizi filtrele
            final docs = allDocs.where((doc) => friendUids.contains(doc.id)).toList();
            
            if (docs.isEmpty) {
              return const Center(child: Text('Liderlik tablosu henüz boş.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final isCurrentUser = doc.id == myUid;
                
                final displayName = data['displayName'] ?? '';
                final averageScore = (data['averageScore'] ?? 0.0).toDouble();
                final displayedBadges = List<String>.from(data['displayedBadges'] ?? []);
                final earnedBadges = Map<String, String>.from(data['earnedBadges'] ?? {});

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: DesignTokens.cardDecoration.copyWith(
                    border: isCurrentUser ? Border.all(color: DesignTokens.primaryBlue, width: 2) : null,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: index < 3 ? DesignTokens.primaryBlue.withOpacity(0.2) : Colors.grey.shade200,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: index < 3 ? DesignTokens.primaryBlue : DesignTokens.textGrey,
                        ),
                      ),
                    ),
                    title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Row(
                      children: displayedBadges.map((badgeId) {
                        if (!earnedBadges.containsKey(badgeId)) return const SizedBox();
                        
                        // Icon mapping
                        IconData icon;
                        switch (badgeId) {
                          case 'compliance': icon = Icons.verified_user_rounded; break;
                          case 'accuracy': icon = Icons.radar_rounded; break;
                          case 'smoothness': icon = Icons.eco_rounded; break;
                          case 'master': icon = Icons.workspace_premium_rounded; break;
                          default: icon = Icons.star;
                        }
                        
                        // Color mapping
                        Color color;
                        switch (earnedBadges[badgeId]) {
                          case 'bronze': color = const Color(0xFFCD7F32); break;
                          case 'silver': color = const Color(0xFFC0C0C0); break;
                          case 'gold': color = const Color(0xFFFFD700); break;
                          default: color = DesignTokens.textGrey;
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 4, top: 4),
                          child: Icon(icon, size: 16, color: color),
                        );
                      }).toList(),
                    ),
                    trailing: Text(
                      averageScore.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: DesignTokens.primaryBlue,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Hata: $err')),
    );
  }


  Widget _buildFriendsTab() {
    final friendsAsync = ref.watch(friendsListProvider);
    final myUid = ref.watch(currentUserUidProvider) ?? '';

    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline,
                    size: 64,
                    color: DesignTokens.textGrey.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text(
                  'Henüz arkadaşınız yok',
                  style:
                      TextStyle(color: DesignTokens.textGrey, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sağ alttaki butona basarak arkadaş ekleyebilirsiniz.',
                  style:
                      TextStyle(color: DesignTokens.textGrey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final f = friends[index];
            final friendName = f.friendNameFor(myUid);
            final initial =
                friendName.isNotEmpty ? friendName[0].toUpperCase() : '?';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: DesignTokens.cardDecoration,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor:
                      DesignTokens.primaryBlue.withOpacity(0.1),
                  child: Text(initial,
                      style: const TextStyle(
                          color: DesignTokens.primaryBlue,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(friendName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: DesignTokens.textDark)),
                trailing: IconButton(
                  icon: const Icon(Icons.person_remove,
                      color: DesignTokens.textGrey),
                  onPressed: () => _confirmRemoveFriend(f),
                ),
              ),
            );
          },
        );
      },
      loading: () => _buildShimmerList(),
      error: (err, _) => Center(
        child: Text('Hata: $err',
            style: const TextStyle(color: DesignTokens.textGrey)),
      ),
    );
  }

  Widget _buildPendingTab() {
    final pendingAsync = ref.watch(pendingRequestsProvider);
    final isPro = ref.watch(isProProvider);

    return pendingAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mail_outline,
                    size: 64,
                    color: DesignTokens.textGrey.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text(
                  'Bekleyen istek yok',
                  style:
                      TextStyle(color: DesignTokens.textGrey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final r = requests[index];
            final initial = r.fromName.isNotEmpty
                ? r.fromName[0].toUpperCase()
                : '?';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: DesignTokens.cardDecoration,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        DesignTokens.primaryBlue.withOpacity(0.1),
                    child: Text(initial,
                        style: const TextStyle(
                            color: DesignTokens.primaryBlue,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.fromName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: DesignTokens.textDark)),
                        const SizedBox(height: 2),
                        const Text('Arkadaşlık isteği gönderdi',
                            style: TextStyle(
                                color: DesignTokens.textGrey,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle,
                        color: DesignTokens.statusSafe, size: 32),
                    onPressed: () async {
                      if (!isPro) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PaywallView()),
                        );
                        return;
                      }
                      try {
                        await ref
                            .read(friendServiceProvider)
                            .acceptFriendRequest(r.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    '${r.fromName} artık arkadaşınız!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Hata: $e')),
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel,
                        color: DesignTokens.statusViolation, size: 32),
                    onPressed: () async {
                      try {
                        await ref
                            .read(friendServiceProvider)
                            .rejectFriendRequest(r.id);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Hata: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => _buildShimmerList(),
      error: (err, _) => Center(
        child: Text('Hata: $err',
            style: const TextStyle(color: DesignTokens.textGrey)),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: DesignTokens.cardSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 120, height: 16, color: Colors.white),
                      const SizedBox(height: 8),
                      Container(width: 80, height: 12, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
