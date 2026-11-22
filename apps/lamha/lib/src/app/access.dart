import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Who may use «لمحة»: a paid subscription (monthly or yearly, each with a 7-day free trial set up in App Store
/// Connect or Google Play). The app has no accounts: it sends Apple's receipt (or Google's purchase token) to the
/// server, which checks it with the store and says until when the subscription lasts. The gate is off unless the
/// build sets `--dart-define=PAYWALL=true` (iPhone and Android), like «أسرتي».
class LamhaAccess {
  static const paywallEnabled = bool.fromEnvironment('PAYWALL');
  static const serverUrl = String.fromEnvironment('SERVER_URL', defaultValue: 'https://asraty-mytatrayd-boop.vercel.app');
  static const monthlyId = 'lamha.monthly';
  static const yearlyId = 'lamha.yearly';
  static const productIds = {monthlyId, yearlyId};
  static const privacyUrl = 'https://github.com/mytatrayd-boop/-/blob/claude/mobile-app-design-gxh65v/apps/lamha/store/PRIVACY.md';
  static const _untilKey = 'lamhaPaidUntil';
  static const _codeKey = 'lamhaCode';
  static const _secure = FlutterSecureStorage();
  static const _channel = MethodChannel('sa.lamha/android');

  /// The store the server should ask about a receipt / purchase token.
  static String get platform => !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';

  static bool get gated => debugGated ?? (paywallEnabled && !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android));

  /// Tests turn the gate on or off.
  @visibleForTesting
  static bool? debugGated;

  static int paidUntil(SharedPreferences p) => p.getInt(_untilKey) ?? 0;
  static Future<void> savePaidUntil(SharedPreferences p, int ms) => p.setInt(_untilKey, ms);

  /// A free activation code the server bound to this phone (like «أسرتي»: one phone per code).
  static String? savedCode(SharedPreferences p) => p.getString(_codeKey);
  static Future<void> saveCode(SharedPreferences p, String code) => p.setString(_codeKey, code);

  /// The app may be used: the gate is off, a code was activated here, or the subscription the server confirmed
  /// has not ended.
  static bool allowed(SharedPreferences p, DateTime now) =>
      !gated || savedCode(p) != null || paidUntil(p) > now.millisecondsSinceEpoch;

  /// A stable id for this phone, so a used code keeps working after a reinstall. Android: the per-app
  /// ANDROID_ID; iPhone: a random id kept in the keychain.
  static Future<String> deviceId() async {
    if (debugDeviceId != null) return debugDeviceId!;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final id = await _channel.invokeMethod<String>('androidId');
        if (id != null && id.length >= 8) return 'a-$id';
      } catch (_) {}
    }
    try {
      final saved = await _secure.read(key: 'deviceId');
      if (saved != null && saved.length >= 8) return saved;
    } catch (_) {}
    final r = Random.secure();
    final id = 'i-${List.generate(24, (_) => '0123456789abcdef'[r.nextInt(16)]).join()}';
    try {
      await _secure.write(key: 'deviceId', value: id);
    } catch (_) {}
    return id;
  }

  /// Tests set this instead of reading platform storage.
  @visibleForTesting
  static String? debugDeviceId;
}

/// Asks the server about a receipt: until when (epoch ms) the subscription lasts, or null when it has none.
abstract interface class ReceiptChecker {
  Future<int?> check(String receipt);
}

/// A failed check ([code] is the server's error code, e.g. plan-unavailable).
class ReceiptCheckError implements Exception {
  ReceiptCheckError(this.code, [this.detail]);
  final String code;

  /// A store status the server passed along (e.g. Apple's 21004 = wrong shared secret), shown to help diagnose.
  final String? detail;

  /// «code» or «code status»: what the subscription screen shows after its message.
  String get label => detail == null ? code : '$code $detail';
  @override
  String toString() => 'ReceiptCheckError($label)';
}

/// One call to the server (the Firebase callable protocol): the `result`, or a [ReceiptCheckError] with its code.
Future<Object?> _callServer(String name, Map<String, Object?> data) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await c.postUrl(Uri.parse('${LamhaAccess.serverUrl}/api/$name'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'data': data}));
    final res = await req.close().timeout(const Duration(seconds: 30));
    final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
    final err = body['error'];
    if (err is Map) {
      final d = err['details'];
      throw ReceiptCheckError(
        d is Map && d['code'] is String ? d['code'] as String : '${err['message'] ?? 'failed'}',
        d is Map && d['status'] != null ? '${d['status']}' : null,
      );
    }
    return body['result'];
  } on ReceiptCheckError {
    rethrow;
  } catch (_) {
    throw ReceiptCheckError('network');
  } finally {
    c.close(force: true);
  }
}

class ServerReceiptChecker implements ReceiptChecker {
  @override
  Future<int?> check(String receipt) async {
    final r = await _callServer('lamhaPlan', {'receipt': receipt, 'platform': LamhaAccess.platform});
    if (r is Map && r['active'] == true && r['until'] is num) return (r['until'] as num).toInt();
    return null;
  }
}

/// Asks the server to bind a free activation code to this phone; throws [ReceiptCheckError]
/// (code-invalid, code-used, rate-limited, network) when it cannot.
abstract interface class CodeRedeemer {
  Future<void> redeem(String code, String deviceId);
}

class ServerCodeRedeemer implements CodeRedeemer {
  @override
  Future<void> redeem(String code, String deviceId) => _callServer('lamhaRedeem', {'code': code, 'deviceId': deviceId});
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

  /// Google Play lists each offer of a subscription as its own product: the one with a free first phase
  /// (the 7-day trial) wins, else the first. App Store products are single.
  ProductDetails? product(String id) {
    final all = products.where((p) => p.id == id).toList();
    return all.where(_hasTrial).firstOrNull ?? all.firstOrNull;
  }

  static bool _hasTrial(ProductDetails p) => offer(p).trial == true;

  /// What the subscription screen shows for a plan. Google Play's `price` is the offer's first phase
  /// («مجانية» for the trial), so the price paid after it is the last phase; and `trial` says whether this
  /// account still gets the free week (Google offers the trial only once). App Store: the price, trial unknown.
  static ({String price, bool? trial}) offer(ProductDetails p) {
    if (p is! GooglePlayProductDetails) return (price: p.price, trial: null);
    final offers = p.productDetails.subscriptionOfferDetails;
    final i = p.subscriptionIndex;
    if (offers == null || i == null || i < 0 || i >= offers.length || offers[i].pricingPhases.isEmpty) {
      return (price: p.price, trial: false);
    }
    final phases = offers[i].pricingPhases;
    return (price: phases.last.formattedPrice, trial: phases.any((ph) => ph.priceAmountMicros == 0));
  }

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
            error = e is ReceiptCheckError ? e.label : '$e';
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
