import '../models/purchase_offer.dart';

abstract interface class PurchasesRepository {
  /// false إن كان الشراء غير متاح (وضع العرض أو غياب مفتاح RevenueCat).
  bool get isAvailable;

  Future<List<PurchaseOffer>> offers();

  /// true عند الشراء، false إن ألغاه المستخدم (إغلاق هادئ). الفشل يُرمى
  /// كـ AppFailure(purchaseFailed / purchaseUnavailable).
  Future<bool> purchase(PurchaseOffer offer);

  /// يرمي AppFailure(noPurchasesToRestore) إن لم توجد مشتريات.
  Future<void> restore();

  Future<bool> isSubscriber();
}
