import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/data_providers.dart';
import '../../app/failure_text.dart';
import '../../app/providers.dart';
import '../../domain/models/review.dart';
import '../../domain/models/shop.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/review_image.dart';
import '../result/review_body.dart';
import '../share/share_review.dart';
import '../shops/shop_actions.dart';
import '../shops/shop_picker_sheet.dart';

/// تفاصيل التقييم (F7 معيار 3): تعديل النجوم والملاحظات والمقهى، والحذف.
class ReviewDetailScreen extends ConsumerWidget {
  const ReviewDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final review = ref.watch(reviewProvider(id));
    final shops = ref.watch(shopsProvider);
    return switch ((review, shops)) {
      (AsyncData(value: final r), AsyncData(value: final s)) =>
        _Editor(key: ValueKey(r.id), review: r, shops: s),
      (AsyncError(:final error), _) || (_, AsyncError(:final error)) => Scaffold(
          appBar: AppBar(title: Text(l.reviewDetailTitle)),
          body: ErrorState(
            message: failureText(l, error),
            retryLabel: l.retry,
            onRetry: () => ref.invalidate(reviewProvider(id)),
          ),
        ),
      _ => Scaffold(
          appBar: AppBar(title: Text(l.reviewDetailTitle)),
          body: const Center(child: CircularProgressIndicator()),
        ),
    };
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({super.key, required this.review, required this.shops});

  final Review review;
  final List<Shop> shops;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final _notes = TextEditingController(text: widget.review.userNotes ?? '');
  late int? _rating = widget.review.userRating;
  late Shop? _shop = widget.shops.where((s) => s.id == widget.review.shopId).firstOrNull;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _notes.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String? get _cleanNotes => _notes.text.trim().isEmpty ? null : _notes.text.trim();

  bool get _changed =>
      _rating != widget.review.userRating ||
      _cleanNotes != widget.review.userNotes ||
      _shop?.id != widget.review.shopId;

  Future<void> _pickShop() async {
    final pick = await showShopPicker(context, current: _shop);
    if (pick != null && mounted) setState(() => _shop = pick.shop);
  }

  Future<void> _toggleFavorite() async {
    final shop = _shop;
    if (shop == null) return;
    await toggleFavorite(context, ref, shop, onChanged: (v) {
      if (mounted && _shop?.id == shop.id) setState(() => _shop = withFavorite(shop, v));
    });
  }

  Future<void> _saveChanges() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(reviewsRepositoryProvider).update(
            widget.review.copyWith(userRating: _rating, userNotes: _cleanNotes, shopId: _shop?.id),
          );
      if (!mounted) return;
      refreshCollectionsFromWidget(ref);
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l.savedDone)));
    } on Object catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, e))));
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.deleteReviewConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(reviewsRepositoryProvider).delete(widget.review.id);
      if (!mounted) return;
      context.pop();
      refreshCollectionsFromWidget(ref);
      messenger.showSnackBar(SnackBar(content: Text(l.reviewDeleted)));
    } on Object catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(failureText(l, e))));
    }
  }

  Future<void> _share(BuildContext buttonContext) async {
    final r = widget.review;
    final Uint8List bytes;
    try {
      bytes = await ref.read(reviewImageProvider(r).future);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).failureShareFailed)));
      }
      return;
    }
    if (!buttonContext.mounted) return;
    await shareReviewCard(
      buttonContext,
      ref,
      imageBytes: bytes,
      type: r.coffeeType,
      score: r.aiScore,
      notes: r.aiNotes,
      rating: _rating,
      shopName: _shop?.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = widget.review;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.reviewDetailTitle),
        actions: [
          Builder(
            builder: (context) => IconButton(
              key: const Key('share_card'),
              tooltip: l.shareCard,
              icon: const Icon(Icons.ios_share),
              onPressed: _busy ? null : () => _share(context),
            ),
          ),
          PopupMenuButton<void>(
            tooltip: l.moreOptions,
            enabled: !_busy,
            itemBuilder: (_) => [
              PopupMenuItem(onTap: _delete, child: Text(l.deleteReview)),
            ],
          ),
        ],
      ),
      body: ReviewBody(
        image: ReviewImage(review: r, width: double.infinity, height: 220, radius: 16),
        type: r.coffeeType,
        score: r.aiScore,
        notes: r.aiNotes,
        tip: r.aiTip,
        rating: _rating,
        onRatingChanged: (v) => setState(() => _rating = v),
        notesController: _notes,
        shop: _shop,
        onPickShop: _pickShop,
        onToggleFavorite: _toggleFavorite,
      ),
      bottomNavigationBar: _changed
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                child: FilledButton(
                  key: const Key('save_changes'),
                  onPressed: _busy ? null : _saveChanges,
                  child: Text(l.saveChanges),
                ),
              ),
            )
          : null,
    );
  }
}
