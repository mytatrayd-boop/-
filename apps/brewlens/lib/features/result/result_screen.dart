import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/data_providers.dart';
import '../../app/failure_text.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../domain/models/review.dart';
import '../../domain/models/shop.dart';
import '../../l10n/app_localizations.dart';
import '../shops/shop_actions.dart';
import '../shops/shop_picker_sheet.dart';
import 'review_body.dart';

/// النتيجة (F5، DESIGN §3.6). النتيجة في الذاكرة حتى «حفظ».
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  final _notes = TextEditingController();
  int? _rating;
  Shop? _shop;
  var _saving = false;
  var _saved = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _leave() {
    ref.read(pendingAnalysisProvider.notifier).set(null);
    context.go(Routes.home);
  }

  Future<void> _close() async {
    if (_saved) return _leave();
    final l = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.discardTitle),
        content: Text(l.discardBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.stay)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.discard)),
        ],
      ),
    );
    if ((discard ?? false) && mounted) _leave();
  }

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

  Future<void> _save(PendingAnalysis pending) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final notes = _notes.text.trim();
    final draft = Review(
      id: '',
      coffeeType: pending.type,
      imagePath: '',
      aiScore: pending.result.score!,
      aiNotes: pending.result.notes,
      aiTip: pending.result.tip!,
      createdAt: DateTime.now(),
      userRating: _rating,
      userNotes: notes.isEmpty ? null : notes,
      shopId: _shop?.id,
    );
    try {
      await ref.read(reviewsRepositoryProvider).save(draft, pending.imageBytes);
      if (!mounted) return;
      refreshCollectionsFromWidget(ref);
      setState(() {
        _saving = false;
        _saved = true;
      });
      messenger.showSnackBar(SnackBar(
        content: Text(l.savedDone),
        action: SnackBarAction(
          label: l.viewInHistory,
          onPressed: () => rootNavigatorKey.currentContext?.go(Routes.history),
        ),
      ));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // البيانات تبقى على الشاشة مع «إعادة».
      messenger.showSnackBar(SnackBar(
        content: Text(failureText(l, e)),
        action: SnackBarAction(label: l.retry, onPressed: () => _save(pending)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pending = ref.watch(pendingAnalysisProvider);
    if (pending == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.home);
      });
      return const Scaffold();
    }
    final result = pending.result;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: l.close, icon: const Icon(Icons.close), onPressed: _close),
          title: Text(l.resultTitle),
        ),
        body: ReviewBody(
          image: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(pending.imageBytes, fit: BoxFit.cover, width: double.infinity),
          ),
          type: pending.type,
          score: result.score!,
          notes: result.notes,
          tip: result.tip!,
          rating: _rating,
          onRatingChanged: (v) => setState(() => _rating = v),
          notesController: _notes,
          shop: _shop,
          onPickShop: _pickShop,
          onToggleFavorite: _toggleFavorite,
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
            child: FilledButton(
              key: const Key('save_review'),
              onPressed: _saving || _saved ? null : () => _save(pending),
              child: _saving
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_saved ? l.savedDone : l.saveReview),
            ),
          ),
        ),
      ),
    );
  }
}
