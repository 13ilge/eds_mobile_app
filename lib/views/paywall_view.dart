import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';
import '../theme/design_tokens.dart';

class PaywallView extends ConsumerStatefulWidget {
  const PaywallView({super.key});

  @override
  ConsumerState<PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends ConsumerState<PaywallView> {
  bool _isLoading = true;
  Offerings? _offerings;

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    final offerings = await SubscriptionService().getOfferings();
    if (mounted) {
      setState(() {
        _offerings = offerings;
        _isLoading = false;
      });
    }
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() => _isLoading = true);
    final isPro = await SubscriptionService().purchasePackage(package);
    if (mounted) {
      setState(() => _isLoading = false);
      if (isPro) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tebrikler! Pro sürüme geçtiniz')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Satın alma işlemi tamamlanamadı.')),
        );
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    final isPro = await SubscriptionService().restorePurchases();
    if (mounted) {
      setState(() => _isLoading = false);
      if (isPro) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Satın alımlarınız geri yüklendi')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geri yüklenecek abonelik bulunamadı.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: DesignTokens.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  DesignTokens.primaryBlue.withOpacity(0.2),
                  DesignTokens.surface,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  const Icon(
                    Icons.workspace_premium,
                    size: 80,
                    color: DesignTokens.primaryBlue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Koridor Pro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: DesignTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tüm sınırları kaldırın ve sürüş deneyiminizi bir üst seviyeye taşıyın.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 48),

                  _buildFeatureItem(Icons.cloud_sync, 'Topluluk Rotalarını İndirme'),
                  const SizedBox(height: 16),
                  _buildFeatureItem(Icons.map, 'Sınırsız Özel EDS Noktası Kaydı'),
                  const SizedBox(height: 16),
                  _buildFeatureItem(Icons.headset, 'Gelişmiş Sesli Asistan Modları'),
                  const SizedBox(height: 16),
                  _buildFeatureItem(Icons.analytics_rounded, 'Detaylı Sürüş Skoru Analizi'),
                  const Spacer(),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_offerings != null && _offerings!.current != null && _offerings!.current!.availablePackages.isNotEmpty)
                    ..._offerings!.current!.availablePackages.map((package) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildPackageButton(package),
                      );
                    }).toList()
                  else
                    const Center(
                      child: Text(
                        'Şu an için erişilebilir paket bulunamadı.',
                        style: TextStyle(color: DesignTokens.textSecondary),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _restorePurchases,
                    child: const Text(
                      'Satın Alımları Geri Yükle',
                      style: TextStyle(
                        color: DesignTokens.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (_isLoading && _offerings != null)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: DesignTokens.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: DesignTokens.primaryBlue, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: DesignTokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPackageButton(Package package) {
    final isAnnual = package.packageType == PackageType.annual;
    
    return InkWell(
      onTap: () => _purchasePackage(package),
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isAnnual ? DesignTokens.primaryBlue : DesignTokens.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAnnual ? DesignTokens.primaryBlue : DesignTokens.cardBorder,
            width: 2,
          ),
          boxShadow: [
            if (isAnnual)
              BoxShadow(
                color: DesignTokens.primaryBlue.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.storeProduct.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isAnnual ? Colors.white : DesignTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  package.storeProduct.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isAnnual ? Colors.white70 : DesignTokens.textSecondary,
                  ),
                ),
              ],
            ),
            Text(
              package.storeProduct.priceString,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isAnnual ? Colors.white : DesignTokens.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
