import 'package:flutter/material.dart';

import '../../app/labels.dart';
import '../../app/theme.dart';
import '../../domain/models/coffee_type.dart';
import '../../domain/models/review.dart';
import '../../domain/models/shop.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/score_ring.dart';
import '../../widgets/star_rating.dart';

/// محتوى النتيجة وتفاصيل التقييم (DESIGN §3.6): الصورة، «تقييم المظهر»،
/// تقرير الباريستا، النجوم، الملاحظات، والمقهى مع المفضلة.
class ReviewBody extends StatelessWidget {
  const ReviewBody({
    super.key,
    required this.image,
    required this.type,
    required this.score,
    required this.notes,
    required this.tip,
    required this.rating,
    required this.onRatingChanged,
    required this.notesController,
    required this.shop,
    required this.onPickShop,
    required this.onToggleFavorite,
    this.editable = true,
  });

  final Widget image;
  final CoffeeType type;
  final double score;
  final List<String> notes;
  final String tip;
  final int? rating;
  final ValueChanged<int?> onRatingChanged;
  final TextEditingController notesController;
  final Shop? shop;
  final VoidCallback onPickShop;
  final VoidCallback onToggleFavorite;

  /// false بعد الحفظ في شاشة النتيجة: النجوم والملاحظات والمقهى للقراءة فقط.
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final limitedNote = type.isVisualLimited ? _LimitedNote(text: l.visualLimitedNote) : null;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Expanded(child: Text(l.appearanceScore, style: text.headlineMedium)),
            Chip(label: Text(coffeeTypeLabel(l, type))),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(height: 220, child: image),
        const SizedBox(height: 16),
        Center(child: ScoreRing(score: score)),
        const SizedBox(height: 8),
        Center(child: Text(scoreLabel(l, score), style: text.titleLarge)),
        if (limitedNote != null) ...[const SizedBox(height: 12), limitedNote],
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.center_focus_strong_outlined, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l.baristaReport, style: text.titleLarge)),
                ]),
                const SizedBox(height: 12),
                for (var i = 0; i < notes.length; i++)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: scheme.primaryContainer,
                          foregroundColor: scheme.onPrimaryContainer,
                          child: Text('${i + 1}', style: text.labelMedium),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(notes[i], style: text.bodyLarge)),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsetsDirectional.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.tipLine(tip),
                          style: text.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                if (limitedNote != null) ...[const SizedBox(height: 12), limitedNote],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(l.tasteRatingPrompt, style: text.titleMedium),
        const SizedBox(height: 8),
        StarRating(value: rating, onChanged: editable ? onRatingChanged : null),
        const SizedBox(height: 12),
        TextField(
          key: const Key('user_notes'),
          controller: notesController,
          enabled: editable,
          maxLines: 4,
          minLines: 2,
          maxLength: Review.maxUserNotes,
          decoration: InputDecoration(labelText: l.userNotesLabel),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Card(
                child: InkWell(
                  key: const Key('shop_row'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: editable ? onPickShop : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.storefront_outlined, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              shop?.name ?? l.shopPrompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyLarge,
                            ),
                          ),
                          if (shop?.hasLocation ?? false)
                            Icon(Icons.place, color: successColor(context), semanticLabel: l.hasSavedLocation),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: const Key('favorite_toggle'),
              tooltip: (shop?.isFavorite ?? false) ? l.removeFavorite : l.addFavorite,
              onPressed: shop == null ? null : onToggleFavorite,
              icon: Icon(
                (shop?.isFavorite ?? false) ? Icons.favorite : Icons.favorite_border,
                color: (shop?.isFavorite ?? false) ? scheme.primary : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// سطر «التحليل البصري محدود» بإطار أصفر فاتح.
class _LimitedNote extends StatelessWidget {
  const _LimitedNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border.all(color: scheme.secondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, color: scheme.onSurfaceVariant, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ]),
    );
  }
}
