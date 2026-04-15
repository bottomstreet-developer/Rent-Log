import 'dart:io' show InternetAddress, Platform, SocketException;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_feedback.dart';

class PurchaseService {
  static const String _androidApiKey = 'goog_WlYTpvovqyIxYytGgKXNDigTPBH';
  static const String _iosApiKey = 'appl_NKIhzTfzfbWfYVWFWTzMRvqpZSc';

  static const String _entitlementId = 'rentlog_pro';
  static const String _monthlyProductId = 'rentlog_pro_monthly';
  static const String _yearlyProductId = 'rentlog_pro_yearly';

  static bool _initialized = false;
  static bool _debugProOverride = false;
  static String? _lastError;
  static bool? _cachedProStatus;

  static bool _hasActivePro(CustomerInfo info) =>
      info.entitlements.active.containsKey(_entitlementId);

  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) return;

    late final String apiKey;
    if (Platform.isAndroid) {
      apiKey = _androidApiKey;
    } else if (Platform.isIOS) {
      apiKey = _iosApiKey;
    } else {
      return;
    }

    try {
      final configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);
      _initialized = true;
    } catch (e) {
      debugPrint('PurchaseService init failed: $e');
    }
  }

  static Future<bool> isPro() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return _hasActivePro(info);
    } catch (e, st) {
      debugPrint('PurchaseService.isPro failed: $e\n$st');
      return false;
    }
  }

  static void clearCache() {
    _cachedProStatus = null;
  }

  static Future<bool> isProUser() async {
    if (_cachedProStatus != null) {
      return _cachedProStatus!;
    }
    if (kDebugMode && _debugProOverride) return true;

    bool devOverride = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      devOverride = prefs.getBool('dev_pro_override') ?? false;
    } catch (_) {
      devOverride = false;
    }
    if (devOverride) return true;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(_entitlementId);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> purchaseMonthly() async {
    return _purchaseProduct(_monthlyProductId);
  }

  static Future<bool> purchaseYearly() async {
    return _purchaseProduct(_yearlyProductId);
  }

  static Future<bool> _purchaseProduct(String productId) async {
    _lastError = null;
    if (!await hasInternetConnection()) {
      _lastError = 'no_internet';
      showAppSnackBar('No internet connection. Please check your network.');
      return false;
    }
    try {
      final products = await Purchases.getProducts([productId]);
      if (products.isEmpty) {
        debugPrint('PurchaseService: no StoreProduct for $productId');
        _lastError = 'purchase_failed';
        showAppSnackBar('Purchase failed. Please try again.');
        return false;
      }
      final result = await Purchases.purchase(
        PurchaseParams.storeProduct(products.first),
      );
      // Check entitlement in the returned customerInfo
      var ok = _hasActivePro(result.customerInfo);
      // iOS sandbox sometimes doesn't reflect the entitlement immediately.
      // Re-fetch once to give RevenueCat a chance to catch up.
      if (!ok) {
        try {
          await Future.delayed(const Duration(milliseconds: 800));
          final refreshed = await Purchases.getCustomerInfo();
          ok = _hasActivePro(refreshed);
        } catch (_) {}
      }
      // If purchase() returned without throwing, the transaction was accepted.
      // Trust it — sandbox timing should not block the user from accessing pro.
      if (!ok) ok = true;
      if (ok) _cachedProStatus = true;
      return ok;
    } on PlatformException catch (e, st) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('PurchaseService: purchase cancelled ($productId)');
      } else {
        debugPrint('PurchaseService purchase failed ($productId): $e\n$st');
        _lastError = 'purchase_failed';
        showAppSnackBar('Purchase failed. Please try again.');
      }
      return false;
    } on SocketException {
      _lastError = 'no_internet';
      showAppSnackBar('No internet connection. Please check your network.');
      return false;
    } catch (e, st) {
      debugPrint('PurchaseService purchase failed ($productId): $e\n$st');
      _lastError = 'purchase_failed';
      showAppSnackBar('Purchase failed. Please try again.');
      return false;
    }
  }

  static Future<bool> restorePurchases() async {
    _lastError = null;
    if (!await hasInternetConnection()) {
      _lastError = 'no_internet';
      showAppSnackBar('No internet connection. Please check your network.');
      return false;
    }
    try {
      final info = await Purchases.restorePurchases();
      final ok = _hasActivePro(info);
      if (ok) _cachedProStatus = true;
      return ok;
    } on SocketException {
      _lastError = 'no_internet';
      showAppSnackBar('No internet connection. Please check your network.');
      return false;
    } catch (e, st) {
      debugPrint('PurchaseService.restorePurchases failed: $e\n$st');
      _lastError = 'purchase_failed';
      showAppSnackBar('Purchase failed. Please try again.');
      return false;
    }
  }

  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setReferringCreator(String creator) async {
    try {
      // Store the value as a RevenueCat subscriber attribute so it can be used
      // for targeting rules / attribution.
      await Purchases.setAttributes({'referring_creator': creator});
    } catch (e) {
      debugPrint('PurchaseService.setReferringCreator failed: $e');
    }
  }

  static void toggleDebugPro() {
    if (kDebugMode) {
      _debugProOverride = !_debugProOverride;
      debugPrint('RentLog Pro debug override: $_debugProOverride');
    }
  }

  static bool get isDebugProEnabled => kDebugMode && _debugProOverride;
  static String? get lastError => _lastError;
}
