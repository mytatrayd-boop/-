import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';

/// Who may use the app: the family admin (owner) with a free activation code (bound to this device by
/// the server) or an App Store subscription (monthly / yearly, each with a 7-day free trial set up in
/// App Store Connect). Members and delegated admins never see this: they join a family that is already paid.
///
/// The subscription is one group with three levels by the number of members: up to 5, 10 or 20.
/// The server checks Apple's receipt and records the tier on the family (functions/src/plan.ts).
///
/// The gate is off unless the build sets `--dart-define=PAYWALL=true` (iPhone only).
class Access {
  static const paywallEnabled = bool.fromEnvironment('PAYWALL');

  /// Subscription levels: members allowed, monthly product id, yearly product id.
  /// Keep in sync with functions/src/plan.ts PLAN_PRODUCTS.
  static const tiers = [
    (members: 5, monthly: 'asraty.monthly', yearly: 'asraty.yearly'),
    (members: 10, monthly: 'asraty.m10', yearly: 'asraty.y10'),
    (members: 20, monthly: 'asraty.m20', yearly: 'asraty.y20'),
  ];
  static final productIds = {for (final t in tiers) ...[t.monthly, t.yearly]};

  static const _codeKey = 'activationCode';
  static const _store = FlutterSecureStorage();
  static const _channel = MethodChannel('asraty/device');

  /// The subscription gate applies on iPhone builds that turned it on.
  static bool get gated => debugGated ?? (paywallEnabled && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  /// Tests turn the gate on or off.
  @visibleForTesting
  static bool? debugGated;

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

  /// The owner may use the app: a free code on this device, or an active plan the server recorded.
  static bool ownerAllowed(SharedPreferences p, FamilyPlan? plan, DateTime now) => !gated || savedCode(p) != null || (plan?.activeAt(now) ?? false);
}

/// Sends a bought or restored subscription's receipt to the server, which checks it with Apple.
typedef ReceiptSink = Future<void> Function(String productId, String receipt);

/// App Store purchases: product prices, buying, and restoring on a new phone.
class Store {
  Store(this.onChange, this.sink);
  final VoidCallback onChange;
  final ReceiptSink sink;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> products = [];
  String? error;
  var loading = false;

  InAppPurchase get _iap => InAppPurchase.instance;

  ProductDetails? product(String id) => products.where((p) => p.id == id).firstOrNull;

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
      var finish = true;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            // The server checks the receipt with Apple. If it cannot now, the purchase stays open and
            // arrives again at the next launch (so a paid subscription is never lost).
            await sink(p.productID, p.verificationData.serverVerificationData);
            error = null;
          } catch (e) {
            error = e is StoreSinkError ? e.code : '$e';
            finish = false;
          }
        case PurchaseStatus.error:
          error = p.error?.message ?? 'error';
        case PurchaseStatus.pending:
        case PurchaseStatus.canceled:
          break;
      }
      if (finish && p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
    onChange();
  }

  void dispose() => _sub?.cancel();
}

/// The server refused or could not check a receipt ([code] is the server's error code).
class StoreSinkError implements Exception {
  StoreSinkError(this.code);
  final String code;
}
