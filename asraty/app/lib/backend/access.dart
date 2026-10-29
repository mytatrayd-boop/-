import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Who may use the app on this device: a free activation code (bound to this
/// device by the server), or an App Store subscription (monthly 10 SAR or yearly
/// 75 SAR, each with a 7-day free trial set up in App Store Connect).
///
/// The subscription gate is off until the products exist in App Store Connect:
/// build with `--dart-define=PAYWALL=true` to turn it on (iPhone only).
class Access {
  static const paywallEnabled = bool.fromEnvironment('PAYWALL');
  static const monthlyId = 'asraty.monthly';
  static const yearlyId = 'asraty.yearly';
  static const productIds = {monthlyId, yearlyId};

  static const _codeKey = 'activationCode';
  static const _subKey = 'subscribedUntil';
  static const _store = FlutterSecureStorage();
  static const _channel = MethodChannel('asraty/device');

  /// The subscription gate applies on iPhone builds that turned it on.
  static bool get gated => paywallEnabled && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// A stable id for this phone. Android: the per-app ANDROID_ID (survives a
  /// reinstall); iPhone: a random id kept in the keychain (survives a reinstall too).
  static Future<String> deviceId() async {
    if (debugDeviceId != null) return debugDeviceId!;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final id = await _channel.invokeMethod<String>('androidId');
        if (id != null && id.length >= 8) return 'a-$id';
      } catch (_) {}
    }
    try {
      final saved = await _store.read(key: 'deviceId');
      if (saved != null && saved.length >= 8) return saved;
    } catch (_) {}
    final r = Random.secure();
    final id = 'i-${List.generate(24, (_) => '0123456789abcdef'[r.nextInt(16)]).join()}';
    try {
      await _store.write(key: 'deviceId', value: id);
    } catch (_) {}
    return id;
  }

  /// Tests set this instead of reading platform storage.
  @visibleForTesting
  static String? debugDeviceId;

  static String? savedCode(SharedPreferences p) => p.getString(_codeKey);
  static Future<void> saveCode(SharedPreferences p, String code) => p.setString(_codeKey, code);

  /// A purchase or restore from the App Store said this Apple ID is subscribed.
  /// (No server receipt check yet: that needs an App Store Server API key.)
  static bool subscribed(SharedPreferences p) => p.getBool(_subKey) ?? false;
  static Future<void> setSubscribed(SharedPreferences p, bool v) => p.setBool(_subKey, v);

  static bool allowed(SharedPreferences p) => !gated || savedCode(p) != null || subscribed(p);
}

/// App Store purchases: product prices, buying, and restoring on a new phone.
class Store {
  Store(this.prefs, this.onChange);
  final SharedPreferences prefs;
  final VoidCallback onChange;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> products = [];
  String? error;
  var loading = false;

  InAppPurchase get _iap => InAppPurchase.instance;

  /// Starts after the current frame (the first price lookup notifies listeners).
  void startSoon() => Future<void>.microtask(start);

  Future<void> start() async {
    if (!Access.gated) return;
    _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      error = '$e';
      onChange();
    });
    loading = true;
    onChange();
    try {
      if (!await _iap.isAvailable()) {
        error = 'store-unavailable';
      } else {
        final r = await _iap.queryProductDetails(Access.productIds);
        products = r.productDetails..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
        // Brings back an active subscription (new phone, reinstall, Family Sharing).
        await _iap.restorePurchases();
      }
    } catch (e) {
      error = '$e';
    }
    loading = false;
    onChange();
  }

  Future<void> buy(ProductDetails p) async {
    error = null;
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
  }

  Future<void> restore() => _iap.restorePurchases();

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (!Access.productIds.contains(p.productID)) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await Access.setSubscribed(prefs, true);
        case PurchaseStatus.error:
          error = p.error?.message ?? 'error';
        case PurchaseStatus.pending:
        case PurchaseStatus.canceled:
          break;
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
    onChange();
  }

  void dispose() => _sub?.cancel();
}
