import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/sharing_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/design_tokens.dart';
import 'paywall_view.dart';

class InboxView extends ConsumerWidget {
  const InboxView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharesAsync = ref.watch(incomingSharesProvider);

    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.background,
        elevation: 0,
        centerTitle: true,
        title: const Text('Gelen Kutusu',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: sharesAsync.when(
        data: (shares) {
          if (shares.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64,
                      color: DesignTokens.textGrey.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'Gelen paylaşım yok',
                    style:
                        TextStyle(color: DesignTokens.textGrey, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Arkadaşlarınız size EDS noktası gönderdiğinde\nburada görünecek.',
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
            itemCount: shares.length,
            itemBuilder: (context, index) {
              final share = shares[index];
              final initial = share.ownerName.isNotEmpty
                  ? share.ownerName[0].toUpperCase()
                  : '?';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: DesignTokens.cardDecoration,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              DesignTokens.primaryBlue.withValues(alpha: 0.1),
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
                              Text(share.ownerName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: DesignTokens.textDark)),
                              const Text('size bir EDS noktası gönderdi',
                                  style: TextStyle(
                                      color: DesignTokens.textGrey,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DesignTokens.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: DesignTokens.primaryBlue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              share.edsPoint.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: DesignTokens.textDark),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: DesignTokens.primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${share.edsPoint.speedLimit} km/h',
                              style: const TextStyle(
                                  color: DesignTokens.primaryBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await ref
                                    .read(sharingServiceProvider)
                                    .rejectShare(share.id);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Hata: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Reddet'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DesignTokens.statusViolation,
                              side: const BorderSide(
                                  color: DesignTokens.statusViolation),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final isPro = ref.read(isProProvider);
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
                                    .read(sharingServiceProvider)
                                    .acceptShare(share);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            '${share.edsPoint.name} noktanıza eklendi!')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Hata: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Kabul Et'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DesignTokens.statusSafe,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: DesignTokens.cardDecoration,
              child: Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: 120, height: 14, color: Colors.white),
                            const SizedBox(height: 6),
                            Container(width: 80, height: 10, color: Colors.white),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(width: double.infinity, height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: Container(height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)))),
                        const SizedBox(width: 12),
                        Expanded(child: Container(height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)))),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        error: (err, _) => Center(
          child: Text('Hata: $err',
              style: const TextStyle(color: DesignTokens.textGrey)),
        ),
      ),
    );
  }
}
