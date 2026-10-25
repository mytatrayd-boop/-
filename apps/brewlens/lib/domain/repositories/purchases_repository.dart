import '../models/purchase_offer.dart';

abstract interface class PurchasesRepository {
  /// false إن كان الشراء غير متاح (وضع العرض أو غياب مفتاح RevenueCat).
  bool get isAvailable;

  Future<List<PurchaseOffer>> offers();

  Future<void> purchase(PurchaseOffer offer);

  Future<void> restore();

  Future<bool> isSubscriber();
}
