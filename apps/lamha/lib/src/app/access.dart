import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Who may use «لمحة»: a paid App Store subscription (monthly or yearly, each with a 7-day free trial set up
/// in App Store Connect). The app has no accounts: it sends Apple's receipt to the server, which checks it
/// with Apple and says until when the subscription lasts. The gate is off unless the build sets
/// `--dart-define=PAYWALL=true` (iPhone only), like «أسرتي».
class LamhaAccess {
  static const paywallEnabled = bool.fromEnvironment('PAYWALL');
  static const serverUrl = String.fromEnvironment('SERVER_URL', defaultValue: 'https://asraty-mytatrayd-boop.vercel.app');
  static const monthlyId = 'lamha.monthly';
  static const yearlyId = 'lamha.yearly';
  static const productIds = {monthlyId, yearlyId};
  static const privacyUrl = 'https://github.com/mytatrayd-boop/-/blob/claude/mobile-app-design-gxh65v/apps/lamha/store/PRIVACY.md';
  static const _untilKey = 'lamhaPaidUntil';

  static bool get gated => debugGated ?? (paywallEnabled && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  /// Tests turn the gate on or off.
  @visibleForTesting
  static bool? debugGated;

  static int paidUntil(SharedPreferences p) => p.getInt(_untilKey) ?? 0;
  static Future<void> savePaidUntil(SharedPreferences p, int ms) => p.setInt(_untilKey, ms);

  /// The app may be used: the gate is off, or the subscription the server confirmed has not ended.
  static bool allowed(SharedPreferences p, DateTime now) => !gated || paidUntil(p) > now.millisecondsSinceEpoch;
}

/// Asks the server about a receipt: until when (epoch ms) the subscription lasts, or null when it has none.
abstract interface class ReceiptChecker {
  Future<int?> check(String receipt);
}

/// A failed check ([code] is the server's error code, e.g. plan-unavailable).
class ReceiptCheckError implements Exception {
  ReceiptCheckError(this.code);
  final String code;
  @override
  String toString() => 'ReceiptCheckError($code)';
}

class ServerReceiptChecker implements ReceiptChecker {
  @override
  Future<int?> check(String receipt) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await c.postUrl(Uri.parse('${LamhaAccess.serverUrl}/api/lamhaPlan'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'data': {'receipt': receipt}}));
      final res = await req.close().timeout(const Duration(seconds: 30));
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final err = body['error'];
      if (err is Map) {
        final d = err['details'];
        throw ReceiptCheckError(d is Map && d['code'] is String ? d['code'] as String : '${err['message'] ?? 'failed'}');
      }
      final r = body['result'];
      if (r is Map && r['active'] == true && r['until'] is num) return (r['until'] as num).toInt();
      return null;
    } on ReceiptCheckError {
      rethrow;
    } catch (_) {
      throw ReceiptCheckError('network');
    } finally {
      c.close(force: true);
    }
  }
}

/// App Store purchases: prices, buying, and restoring on a new phone. A bought or restored subscription
/// is confirmed by the server; if it cannot be now, the purchase stays open and arrives again next launch.
class LamhaStore {
  LamhaStore(this.prefs, this.checker, this.onChange);
  final SharedPreferences prefs;
  final ReceiptChecker checker;
  final VoidCallback onChange;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> products = [];
  String? error;
  var loading = false;
  var checking = false;

  InAppPurchase get _iap => InAppPurchase.instance;

  ProductDetails? product(String id) => products.where((p) => p.id == id).firstOrNull;

  /// Tests do not talk to the App Store.
  @visibleForTesting
  static bool debugNoStart = false;

  Future<void> start() async {
    if (!LamhaAccess.gated || debugNoStart) return;
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
        products = (await _iap.queryProductDetails(LamhaAccess.productIds)).productDetails..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
        await _iap.restorePurchases(); // brings back an active subscription (new phone, reinstall, renewal)
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

  Future<void> restore() async {
    error = null;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (!LamhaAccess.productIds.contains(p.productID)) continue;
      var finish = true;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          checking = true;
          onChange();
          try {
            final until = await checker.check(p.verificationData.serverVerificationData);
            if (until != null && until > DateTime.now().millisecondsSinceEpoch) {
              await LamhaAccess.savePaidUntil(prefs, until);
              error = null;
            } else {
              error = 'not-active'; // an old, ended subscription
            }
          } catch (e) {
            error = e is ReceiptCheckError ? e.code : '$e';
            finish = false; // keep the purchase open: it is delivered again and checked again
          }
          checking = false;
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
