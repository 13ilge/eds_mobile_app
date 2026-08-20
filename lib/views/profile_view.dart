import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/subscription_service.dart';
import '../theme/design_tokens.dart';
import '../models/badge_model.dart';
import '../models/user_profile.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
          'Hesabınızı ve tüm kayıtlı verilerinizi kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'İptal',
              style: TextStyle(color: DesignTokens.textGrey),
            ),
          ),
          TextButton(
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              navigator.pop(); // Sadece AlertDialog'u kapat

              try {
                await authService.deleteAccount();
                navigator.popUntil((route) => route.isFirst);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Hata: ${e.toString()}')),
                );
              }
            },
            child: const Text(
              'Sil',
              style: TextStyle(color: DesignTokens.statusViolation),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleBadge(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
    String badgeId,
  ) {
    List<String> displayed = List.from(profile.displayedBadges);
    if (displayed.contains(badgeId)) {
      displayed.remove(badgeId);
    } else {
      if (displayed.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('En fazla 3 rozet seçebilirsiniz.')),
        );
        return;
      }
      displayed.add(badgeId);
    }
    ref.read(authServiceProvider).updateDisplayedBadges(displayed);
  }

  Widget _buildBadgeItem(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
    BadgeType type,
  ) {
    final badgeId = type.name;
    final isEarned = profile.earnedBadges.containsKey(badgeId);
    final isDisplayed = profile.displayedBadges.contains(badgeId);

    BadgeTier tier = BadgeTier.none;
    if (isEarned) {
      tier = BadgeModel.getTierFromString(profile.earnedBadges[badgeId]!);
    }

    final badgeModel = BadgeModel(
      id: badgeId,
      name: BadgeModel.getBadgeName(type),
      type: type,
      tier: tier,
    );

    return GestureDetector(
      onTap: isEarned
          ? () => _toggleBadge(context, ref, profile, badgeId)
          : null,
      child: Opacity(
        opacity: isEarned ? 1.0 : 0.3,
        child: Container(
          width: 80,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: isDisplayed
                ? DesignTokens.primaryBlue.withValues(alpha: 0.1)
                : DesignTokens.cardSurface,
            border: Border.all(
              color: isDisplayed
                  ? DesignTokens.primaryBlue
                  : DesignTokens.cardBorder,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                badgeModel.icon,
                size: 32,
                color: isEarned ? badgeModel.tierColor : DesignTokens.textGrey,
              ),
              const SizedBox(height: 4),
              Text(
                badgeModel.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
              ),
              if (isEarned)
                Text(
                  BadgeModel.getTierName(tier),
                  style: TextStyle(
                    fontSize: 10,
                    color: badgeModel.tierColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    final userProfileAsync = ref.watch(userProfileProvider);

    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Giriş yapmanız gerekiyor.')),
      );
    }

    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        title: const Text(
          'Profilim',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: DesignTokens.background,
        elevation: 0,
        centerTitle: true,
      ),
      body: userProfileAsync.when(
        data: (profile) {
          final displayName =
              profile?.displayName ?? authUser.displayName ?? 'Kullanıcı';
          final email = profile?.email ?? authUser.email ?? '';

          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Container(
                decoration: DesignTokens.cardDecoration,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: DesignTokens.primaryBlue.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: DesignTokens.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: DesignTokens.labelLarge.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        color: DesignTokens.textGrey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (profile != null) ...[
                const Text(
                  'Kazanılan Rozetler',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: DesignTokens.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildBadgeItem(
                        context,
                        ref,
                        profile,
                        BadgeType.compliance,
                      ),
                      _buildBadgeItem(
                        context,
                        ref,
                        profile,
                        BadgeType.accuracy,
                      ),
                      _buildBadgeItem(
                        context,
                        ref,
                        profile,
                        BadgeType.smoothness,
                      ),
                      _buildBadgeItem(context, ref, profile, BadgeType.master),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Container(
                  decoration: DesignTokens.cardDecoration,
                  child: SwitchListTile(
                    title: const Text(
                      'Skorumu Toplulukta Gizle',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Sıralamada adınız görünmez (Arkadaşlar hariç)',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: profile.isLeaderboardHidden,
                    activeColor: DesignTokens.primaryBlue,
                    onChanged: (val) {
                      ref
                          .read(authServiceProvider)
                          .updateLeaderboardPrivacy(val);
                    },
                  ),
                ),
                const SizedBox(height: 32),
              ],

              if (ref.watch(isProProvider))
                ElevatedButton.icon(
                  onPressed: () => SubscriptionService().manageSubscription(),
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('Aboneliği Yönet / İptal Et'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              if (ref.watch(isProProvider)) const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final authService = ref.read(authServiceProvider);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  await authService.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Çıkış Yap'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: DesignTokens.textDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => _showDeleteConfirmation(context, ref),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Hesabımı Sil'),
                style: TextButton.styleFrom(
                  foregroundColor: DesignTokens.statusViolation,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Profil yüklenemedi: $err')),
      ),
    );
  }
}
