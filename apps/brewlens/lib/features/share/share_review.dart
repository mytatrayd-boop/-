import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../domain/models/coffee_type.dart';
import '../../l10n/app_localizations.dart';
import 'share_card.dart';
import 'share_card_renderer.dart';

/// يولّد بطاقة المشاركة بلغة الواجهة واتجاهها ويفتح قائمة المشاركة (F8).
/// الفشل يعرض «تعذّر إنشاء البطاقة»، والإلغاء بلا رسالة.
Future<void> shareReviewCard(
  BuildContext context,
  WidgetRef ref, {
  required Uint8List imageBytes,
  required CoffeeType type,
  required double score,
  required List<String> notes,
  int? rating,
  String? shopName,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final view = View.of(context);
  final direction = Directionality.of(context);
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final share = ref.read(shareServiceProvider);
  try {
    final photo = await decodeImage(imageBytes, targetWidth: 1080);
    final logo = await loadLogo();
    final png = await renderShareCard(
      ShareCardData(
        photo: photo,
        logo: logo,
        score: score,
        scoreText: formatScore(score),
        scoreOutOf: l.scoreOutOf,
        title: l.appearanceScore,
        typeLabel: coffeeTypeLabel(l, type),
        appName: l.appTitle,
        brand: l.shareCardBrand,
        textDirection: direction,
        rating: rating,
        shopName: shopName,
        note: notes.isEmpty ? null : notes.first,
      ),
      view: view,
    );
    photo.dispose();
    logo?.dispose();
    await share.shareImage(png, origin: origin);
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l.failureShareFailed)));
  }
}
