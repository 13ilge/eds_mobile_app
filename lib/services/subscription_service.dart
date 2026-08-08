import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  static const String _revenueCatApiKey = 'test_lwdBkjfQkrsnbEvyhoYBvcQwcwb';

  Future<void> init() async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);

      PurchasesConfiguration configuration;
      configuration = PurchasesConfiguration(_revenueCatApiKey);

      await Purchases.configure(configuration);
      debugPrint('RevenueCat başarıyla yapılandırıldı.');
    } catch (e) {
      debugPrint('RevenueCat başlatılırken hata oluştu: $e');
    }
  }

  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('Paketler alınırken hata oluştu: $e');
      return null;
    }
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      final purchaseResult = await Purchases.purchase(PurchaseParams.package(package));
      final isPro = purchaseResult.customerInfo.entitlements.all["pro"]?.isActive == true;
      return isPro;
    } catch (e) {
      debugPrint('Satın alma işlemi başarısız: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final isPro = customerInfo.entitlements.all["pro"]?.isActive == true;
      return isPro;
    } catch (e) {
      debugPrint('Satın alımlar geri yüklenirken hata oluştu: $e');
      return false;
    }
  }

  Future<void> manageSubscription() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final url = customerInfo.managementURL;
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Abonelik linki açılamadı: $url');
        }
      }
    } catch (e) {
      debugPrint('Abonelik yönetimi açılırken hata: $e');
    }
  }
}
