import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class CustomerInfoNotifier extends StateNotifier<CustomerInfo?> {
  CustomerInfoNotifier() : super(null) {
    _init();
  }

  Future<void> _init() async {
    try {
      state = await Purchases.getCustomerInfo();
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        state = customerInfo;
      });
    } catch (e) {
      state = null;
    }
  }
  
  Future<void> refresh() async {
    try {
      state = await Purchases.getCustomerInfo();
    } catch (e) {
    }
  }
}

final customerInfoProvider = StateNotifierProvider<CustomerInfoNotifier, CustomerInfo?>((ref) {
  return CustomerInfoNotifier();
});

final isProProvider = Provider<bool>((ref) {
  final customerInfo = ref.watch(customerInfoProvider);
  return customerInfo?.entitlements.all["pro"]?.isActive == true;
});
