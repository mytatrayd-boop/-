import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/data_providers.dart';
import '../../app/failure_text.dart';
import '../../app/providers.dart';
import '../../domain/models/shop.dart';
import '../../l10n/app_localizations.dart';

/// يفتح المقهى في خرائط جوجل، ورسالة قصيرة إن تعذّر.
Future<void> openShopInMaps(BuildContext context, WidgetRef ref, Shop shop) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = AppLocalizations.of(context);
  final ok = await ref.read(mapsLauncherProvider).open(shop);
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.mapsFailed)));
}

/// إضافة/إزالة مفضلة فورية مع «تراجع» (DESIGN §3.6). يعيد القيمة الجديدة أو
/// null عند الفشل.
Future<bool?> toggleFavorite(
  BuildContext context,
  WidgetRef ref,
  Shop shop, {
  ValueChanged<bool>? onChanged,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = AppLocalizations.of(context);
  final repo = ref.read(shopsRepositoryProvider);
  final next = !shop.isFavorite;
  Future<void> apply(bool value) async {
    await repo.setFavorite(shop.id, favorite: value);
    ref.invalidate(favoritesProvider);
    ref.invalidate(shopsProvider);
    onChanged?.call(value);
  }

  try {
    await apply(next);
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(failureText(l, e))));
    return null;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(next ? l.addedToFavorites : l.removedFromFavorites),
      action: SnackBarAction(label: l.undo, onPressed: () => apply(!next)),
    ));
  return next;
}

Shop withFavorite(Shop s, bool favorite) => Shop(
      id: s.id,
      name: s.name,
      latitude: s.latitude,
      longitude: s.longitude,
      isFavorite: favorite,
      avgRating: s.avgRating,
      avgScore: s.avgScore,
      reviewCount: s.reviewCount,
    );
