enum PlanPeriod { monthly, annual }

/// عرض اشتراك كما يأتي من المتجر (أو أسعار D8 الثابتة في وضع العرض).
class PurchaseOffer {
  const PurchaseOffer({
    required this.id,
    required this.period,
    required this.priceLabel,
    this.trialDays = 0,
  });

  final String id;
  final PlanPeriod period;

  /// السعر منسّقاً من المتجر بالعملة المحلية.
  final String priceLabel;
  final int trialDays;
}
