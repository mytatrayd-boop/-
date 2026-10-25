import '../../domain/demo_controls.dart';
import '../../domain/models/app_failure.dart';
import '../../domain/models/purchase_offer.dart';
import '../../domain/repositories/purchases_repository.dart';

/// الاشتراك في وضع العرض: أسعار D8 الثابتة، والشراء والاستعادة غير متاحين.
/// حالة المشترك تأتي من مفتاح «محاكاة مشترك» فقط.
class DemoPurchasesRepository implements PurchasesRepository {
  DemoPurchasesRepository(this._simulator);

  final SubscriberSimulator _simulator;

  static const demoOffers = [
    PurchaseOffer(id: 'brewlens_annual', period: PlanPeriod.annual, priceLabel: '99.99', trialDays: 7),
    PurchaseOffer(id: 'brewlens_monthly', period: PlanPeriod.monthly, priceLabel: '14.99'),
  ];

  @override
  bool get isAvailable => false;

  @override
  Future<List<PurchaseOffer>> offers() async => demoOffers;

  @override
  Future<bool> purchase(PurchaseOffer offer) async =>
      throw const AppFailure(FailureCode.purchaseUnavailable);

  @override
  Future<void> restore() async => throw const AppFailure(FailureCode.purchaseUnavailable);

  @override
  Future<bool> isSubscriber() async => _simulator.simulateSubscriber;
}
