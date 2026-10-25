import '../domain/models/coffee_type.dart';
import '../domain/models/shop.dart';
import '../l10n/app_localizations.dart';

String coffeeTypeLabel(AppLocalizations l, CoffeeType type) => switch (type) {
      CoffeeType.espresso => l.coffeeEspresso,
      CoffeeType.v60 => l.coffeeV60,
      CoffeeType.frenchPress => l.coffeeFrenchPress,
    };

/// وصف الدرجة (DESIGN §3.6): 0–4 يحتاج عناية، 4.5–6.5 جيد، 7–8.5 ممتاز، 9–10 استثنائي.
String scoreLabel(AppLocalizations l, double score) {
  if (score <= 4) return l.scoreNeedsCare;
  if (score <= 6.5) return l.scoreGood;
  if (score <= 8.5) return l.scoreExcellent;
  return l.scoreExceptional;
}

/// الأرقام لاتينية في اللغتين (DESIGN §1.2): 7.5، 8، 4.2.
String formatScore(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toStringAsFixed(1);
}

/// «★ 4.2 · مظهر 7.8 · 6 تقييمات»، أو «—» مكان النجوم بلا تقييمات بنجوم.
String shopStatsLine(AppLocalizations l, Shop shop) {
  final parts = <String>[
    shop.avgRating == null ? l.noRatingYet : l.shopRating(formatScore(shop.avgRating!)),
    if (shop.avgScore != null) l.shopScore(formatScore(shop.avgScore!)),
    l.reviewsCount(shop.reviewCount),
  ];
  return parts.join(' · ');
}

/// التاريخ النسبي بالأيام حسب تقويم الجهاز.
String relativeDate(AppLocalizations l, DateTime date, DateTime now) {
  final d = DateTime(date.toLocal().year, date.toLocal().month, date.toLocal().day);
  final n = DateTime(now.toLocal().year, now.toLocal().month, now.toLocal().day);
  final days = n.difference(d).inDays;
  if (days <= 0) return l.today;
  if (days == 1) return l.yesterday;
  if (days < 30) return l.daysAgo(days);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}/${two(d.month)}/${two(d.day)}';
}
