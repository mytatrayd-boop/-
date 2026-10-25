enum UsagePeriod { day, month }

/// العدّاد كما يعيده الخادم (أو محاكاته في وضع العرض).
class Usage {
  const Usage({
    required this.remaining,
    required this.limit,
    this.period = UsagePeriod.day,
    this.isSubscriber = false,
  });

  final int remaining;
  final int limit;
  final UsagePeriod period;
  final bool isSubscriber;

  factory Usage.fromJson(Map<String, dynamic> json) => Usage(
        remaining: (json['remaining'] as num).toInt(),
        limit: (json['limit'] as num).toInt(),
        period: json['period'] == 'month' ? UsagePeriod.month : UsagePeriod.day,
        isSubscriber: json['is_subscriber'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'remaining': remaining,
        'limit': limit,
        'period': period.name,
        'is_subscriber': isSubscriber,
      };

  @override
  bool operator ==(Object other) =>
      other is Usage &&
      other.remaining == remaining &&
      other.limit == limit &&
      other.period == period &&
      other.isSubscriber == isSubscriber;

  @override
  int get hashCode => Object.hash(remaining, limit, period, isSubscriber);
}
