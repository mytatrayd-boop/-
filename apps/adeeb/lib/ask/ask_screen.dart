import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../reader/passage_share.dart';
import '../search/highlighted_text.dart';
import '../search/search_providers.dart';
import '../storage/book_repository.dart';
import '../text/search_query.dart';
import 'ask_api.dart';
import 'ask_passages.dart';
import 'ask_providers.dart';
import 'ask_query.dart';
import 'ask_service.dart';
import 'quote_verifier.dart';

/// مسار «اسأل الأديب»؛ [bookId] يختار نطاق كتاب واحد (من ورقة الفقرة).
String askLocation({String? bookId}) => Uri(
  path: '/ask',
  queryParameters: bookId == null ? null : {'book': bookId},
).toString();

/// مسار القارئ على فقرة مقتبسة مع نص الاقتباس لتظليله.
String quoteLocation(VerifiedCitation c) => Uri(
  path: '/read/${c.bookId}',
  queryParameters: {'p': c.paragraphId, 'quote': c.quote},
).toString();

/// مسار القارئ على فقرة مطابقة مع كلمات السؤال لتظليلها.
String passageLocation(LocalParagraph p, AskQuery query) => Uri(
  path: '/read/${p.bookId}',
  queryParameters: {'p': p.id, 'q': query.words.join(' ')},
).toString();

/// بعد هذه المدة يظهر «يستغرق الأمر وقتاً أطول من المعتاد» (DESIGN §12.3).
const askSlowAfter = Duration(seconds: 15);

/// يظهر عدّاد الأحرف بعد هذا الطول (DESIGN §12.2).
const askCounterFrom = 400;

/// الحد اليومي الافتراضي قبل أن يرد الخادم بـ `limit`.
const defaultDailyLimit = 10;

/// شاشة «اسأل الأديب» (DESIGN §12): سؤال واحد وإجابة واحدة من نصوص الكتب
/// باقتباس متحقَّق منه، أو النصوص المطابقة مع السبب.
class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key, this.initialBookId});

  final String? initialBookId;

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _field = TextEditingController();
  final _fieldFocus = FocusNode();
  final _resultKey = GlobalKey(debugLabel: 'ask-result');

  late String? _scope = widget.initialBookId;

  bool _confirmed = false;
  int? _remaining;
  int _limit = defaultDailyLimit;

  /// ما يُعرض: آخر إجابة محفوظة أو نتيجة السؤال الحالي.
  AskOutcome? _outcome;
  bool _restored = false;

  /// فشل قراءة القاعدة المحلية (لا علاقة له بالخادم).
  bool _localError = false;

  bool _busy = false;
  AskStage? _stage;
  bool _slow = false;
  Timer? _slowTimer;
  Completer<void>? _cancel;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _field.addListener(_onText);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureConsent());
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    final cancel = _cancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
    _field.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  /// تأكيد العمر وتنبيه أول استخدام مرة واحدة (D13، DESIGN §12.1). الرفض
  /// يغلق الشاشة، ولا يُرسل شيء إلى الشبكة قبل التأكيد.
  Future<void> _ensureConsent() async {
    final bool confirmed;
    try {
      confirmed = await ref.read(ageConfirmedProvider.future);
    } on Object {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    if (!mounted) return;
    if (!confirmed) {
      final accepted = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: true,
        builder: (_) => const _ConsentSheet(),
      );
      if (!mounted) return;
      if (accepted != true) {
        Navigator.of(context).maybePop();
        return;
      }
      await ref.read(ageConfirmedProvider.notifier).confirm();
      if (!mounted) return;
    }
    setState(() => _confirmed = true);
    unawaited(_loadQuota());
  }

  /// الرصيد عند فتح الشاشة فقط (ARCHITECTURE §7). الفشل لا يظهر: الشارة تختفي.
  Future<void> _loadQuota() async {
    try {
      final q = await ref.read(askApiProvider).quota();
      if (!mounted) return;
      setState(() {
        _limit = q.limit;
        _remaining = q.remaining;
      });
    } on Object {
      // بلا شارة حتى أول رد من الخادم.
    }
  }

  String get _lang => Localizations.localeOf(context).languageCode;

  String? _effectiveScope(List<InstalledBook>? books) {
    final scope = _scope;
    if (scope == null || books == null) return scope;
    return books.any((b) => b.id == scope) ? scope : null;
  }

  bool get _quotaExhausted => _remaining == 0;

  String get _question => cleanQuestion(_field.text);

  bool get _tooLong => _field.text.length > maxQuestionChars;

  bool get _tooShort => _question.length < minQuestionChars;

  void _announce(String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  String _stageText(AppLocalizations l10n, AskStage stage) => switch (stage) {
    AskStage.searching => l10n.askStageSearching,
    AskStage.answering => l10n.askStageAnswering,
    AskStage.verifying => l10n.askStageVerifying,
  };

  Future<void> _ask() async {
    if (_busy || _tooShort || _tooLong) return;
    final l10n = AppLocalizations.of(context);
    final scope = _effectiveScope(ref.read(searchableBooksProvider).value);
    final generation = ++_generation;
    final cancel = Completer<void>();
    _cancel = cancel;
    _fieldFocus.unfocus();
    setState(() {
      _busy = true;
      _slow = false;
      _stage = null;
      _outcome = null;
      _restored = true;
      _localError = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(askSlowAfter, () {
      if (mounted && generation == _generation) setState(() => _slow = true);
    });
    try {
      final outcome = await ref
          .read(askServiceProvider)
          .ask(
            _field.text,
            lang: _lang,
            bookId: scope,
            localOnly: _quotaExhausted,
            cancel: cancel.future,
            onStage: (stage) {
              if (!mounted || generation != _generation) return;
              setState(() => _stage = stage);
              _announce(_stageText(l10n, stage));
            },
          );
      if (!mounted || generation != _generation) return;
      _finish();
      setState(() {
        _outcome = outcome;
        if (outcome.remaining case final r?) _remaining = r;
      });
      try {
        await ref
            .read(lastAnswerProvider.notifier)
            .set(outcome is AskAnswer ? outcome : null);
      } on Object {
        // فشل حفظ آخر إجابة لا يمنع عرضها؛ تضيع عند العودة فقط.
      }
      if (!mounted) return;
      _afterOutcome(outcome);
    } on Object catch (e) {
      // الإلغاء لا يغيّر الشاشة (أُعيدت حالتها في _cancelAsk).
      if (e is AskApiException && e.failure == AskFailure.cancelled) return;
      // فشل القاعدة المحلية (الاسترجاع).
      if (!mounted || generation != _generation) return;
      _finish();
      setState(() => _localError = true);
      _announce(l10n.askBooksError);
    }
  }

  void _finish() {
    _slowTimer?.cancel();
    _busy = false;
    _stage = null;
    _slow = false;
    _cancel = null;
  }

  /// الإعلان والتمرير إلى النتيجة، ورسالة الرصيد بعد كل إجابة (DESIGN §12.4).
  void _afterOutcome(AskOutcome outcome) {
    final l10n = AppLocalizations.of(context);
    if (outcome is AskAnswer) {
      _announce(l10n.askAnswerArrived);
      if (_remaining case final r?) {
        final screenReader = MediaQuery.accessibleNavigationOf(context);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                l10n.askQuotaBadge(
                  formatInt(r, _lang),
                  formatInt(_limit, _lang),
                ),
              ),
              duration: Duration(seconds: screenReader ? 8 : 4),
            ),
          );
      }
    } else if (outcome is AskFallback) {
      _announce(_fallbackMessage(l10n, outcome.reason));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
        );
      }
    });
  }

  /// الإلغاء لا يعيد الرصيد إن وصل الطلب إلى الخادم (DESIGN §12.3).
  void _cancelAsk() {
    final cancel = _cancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
    _generation++;
    setState(_finish);
  }

  void _newQuestion() {
    setState(() {
      _restored = true;
      _outcome = null;
      _localError = false;
    });
    _field.clear();
    _fieldFocus.requestFocus();
  }

  void _useExample(String text) {
    _field.text = text;
    _field.selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _copyAnswer(AskAnswer a) async {
    final l10n = AppLocalizations.of(context);
    await copyPassage(_answerText(l10n, a));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.textCopied),
          duration: Duration(
            seconds: MediaQuery.accessibleNavigationOf(context) ? 8 : 4,
          ),
        ),
      );
  }

  Future<void> _shareAnswer(AskAnswer a) {
    final l10n = AppLocalizations.of(context);
    return ref.read(shareTextProvider)(_answerText(l10n, a), l10n.askTitle);
  }

  void _showQuotaInfo() {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.askQuotaExplainTitle),
        content: Text(l10n.askQuotaExplain(formatInt(_limit, _lang))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.askQuotaExplainClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final booksAsync = ref.watch(searchableBooksProvider);
    final books = booksAsync.value;
    final scope = _effectiveScope(books);
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;

    // آخر إجابة محفوظة تُعرض عند العودة ما لم يُسأل سؤال جديد.
    if (!_restored) {
      final last = ref.watch(lastAnswerProvider);
      if (last case AsyncData(:final value?)) _outcome = value;
    }

    final badge = _remaining == null || !_confirmed
        ? null
        : _QuotaBadge(
            remaining: _remaining!,
            limit: _limit,
            onTap: _showQuotaInfo,
          );

    final children = <Widget>[
      // ترتيب قارئ الشاشة: العدّاد ← اللافتة ← النطاق ← الحقل ← الزر (§12.6).
      if (large && badge != null)
        Align(alignment: AlignmentDirectional.centerStart, child: badge),
      const _PrivacyBanner(),
      const SizedBox(height: 12),
    ];

    if (books != null && books.isEmpty) {
      children.add(
        _MessageBlock(
          text: l10n.askNoBooks,
          action: l10n.goToLibrary,
          onAction: () => context.go('/'),
        ),
      );
    } else {
      if (books != null && books.length > 1) {
        children.add(
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.searchAllBooks),
                selected: scope == null,
                onSelected: _busy ? null : (_) => setState(() => _scope = null),
              ),
              for (final b in books)
                ChoiceChip(
                  label: Text(b.title.ar, textDirection: TextDirection.rtl),
                  selected: scope == b.id,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _scope = b.id),
                ),
            ],
          ),
        );
        children.add(const SizedBox(height: 12));
      }
      children.addAll(_form(l10n));
      if (_busy) children.add(_waiting(l10n));
      if (!_busy && _outcome == null && !_localError && _field.text.isEmpty) {
        children.add(_Examples(onTap: _useExample));
      }
      if (_localError) {
        children.add(
          _MessageBlock(
            text: l10n.askBooksError,
            isError: true,
            action: l10n.retry,
            onAction: _ask,
          ),
        );
      }
      if (!_busy) {
        switch (_outcome) {
          case final AskAnswer a:
            children.add(
              _AnswerView(
                key: _resultKey,
                answer: a,
                onCopy: () => _copyAnswer(a),
                onShare: () => _shareAnswer(a),
                onNewQuestion: _newQuestion,
              ),
            );
          case final AskFallback f:
            children.add(
              _FallbackView(
                key: _resultKey,
                outcome: f,
                limit: _limit,
                onRetry: _ask,
              ),
            );
          case null:
            break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.askTitle),
        actions: [
          if (!large && badge != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: badge,
            ),
        ],
      ),
      body: SafeArea(
        // كل العناصر مبنية دائماً (المحتوى قصير)، فيبقى الحقل قابلاً للتركيز
        // من «سؤال جديد» وإن كان خارج الشاشة.
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  List<Widget> _form(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final length = _field.text.length;
    final tooLong = _tooLong;
    final tooShort = _field.text.trim().isNotEmpty && _tooShort;
    final canAsk = _confirmed && !_busy && !_tooShort && !tooLong;
    return [
      TextField(
        controller: _field,
        focusNode: _fieldFocus,
        enabled: !_busy,
        minLines: 3,
        maxLines: 6,
        keyboardType: TextInputType.multiline,
        textDirection: _fieldDirection(),
        decoration: InputDecoration(
          labelText: l10n.askFieldLabel,
          hintText: l10n.askHint,
          hintMaxLines: 3,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: const OutlineInputBorder(),
          counterText: length > askCounterFrom
              ? l10n.askCharCount(
                  formatInt(length, _lang),
                  formatInt(maxQuestionChars, _lang),
                )
              : null,
          counterStyle: tooLong
              ? TextStyle(color: theme.colorScheme.error)
              : null,
          errorText: tooLong
              ? l10n.askTooLong(formatInt(maxQuestionChars, _lang))
              : null,
          helperText: tooShort ? l10n.askTooShort : null,
        ),
      ),
      if (_lang != 'ar') ...[
        const SizedBox(height: 4),
        Text(
          l10n.askArabicNote,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      const SizedBox(height: 12),
      if (_busy)
        OutlinedButton(onPressed: _cancelAsk, child: Text(l10n.cancel))
      else
        FilledButton.icon(
          onPressed: canAsk ? _ask : null,
          // أيقونة الإرسال تُعكس في RTL تلقائياً (DESIGN §6.3).
          icon: Icon(_quotaExhausted ? Icons.search : Icons.send),
          label: Text(
            _quotaExhausted ? l10n.askSearchTextsButton : l10n.askButton,
          ),
        ),
      const SizedBox(height: 12),
    ];
  }

  Widget _waiting(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final stage = _stage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 8),
        if (stage != null)
          Text(_stageText(l10n, stage), style: theme.textTheme.bodyLarge),
        if (_slow) ...[
          const SizedBox(height: 4),
          Text(l10n.askSlow, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 4),
        Text(
          l10n.askCancelNote,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  TextDirection? _fieldDirection() {
    for (final c in _field.text.runes) {
      if (c >= 0x0600 && c <= 0x06FF) return TextDirection.rtl;
      if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)) {
        return TextDirection.ltr;
      }
    }
    return null;
  }
}

String _flatQuote(String quote) => quote.replaceAll('\t', '    ');

/// نص النسخ والمشاركة: الإجابة ثم كل اقتباس بمصدره.
String _answerText(AppLocalizations l10n, AskAnswer a) => [
  a.answer,
  for (final c in a.citations)
    l10n.askCopyCitation(_flatQuote(c.quote), c.bookTitle, c.chapterTitle),
].join('\n\n');

String _fallbackMessage(AppLocalizations l10n, FallbackReason reason) =>
    switch (reason) {
      FallbackReason.noLocalMatches ||
      FallbackReason.notFound => l10n.askNotFound,
      FallbackReason.unverified => l10n.askUnverified,
      FallbackReason.offline => l10n.askOffline,
      FallbackReason.dailyLimit => l10n.askQuotaExhausted,
      FallbackReason.rateLimit => l10n.askRateLimit,
      FallbackReason.unavailable => l10n.askUnavailable,
      FallbackReason.upgradeRequired => l10n.askUpgrade,
    };

class _QuotaBadge extends StatelessWidget {
  const _QuotaBadge({
    required this.remaining,
    required this.limit,
    required this.onTap,
  });

  final int remaining;
  final int limit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final extra = context.extraColors;
    final low = remaining <= 3;
    final text = remaining == 0
        ? l10n.askQuotaExhausted
        : l10n.askQuotaBadge(
            formatInt(remaining, lang),
            formatInt(limit, lang),
          );
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: low
            ? extra.warningContainer
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      text,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: low
                            ? extra.onWarning
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// لافتة الخصوصية: دائمة وغير قابلة للإغلاق (DESIGN §12.2، ARCHITECTURE §11).
class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.all(12),
        decoration: BoxDecoration(
          color: context.extraColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.shield_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context).askPrivacyBanner,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Examples extends StatelessWidget {
  const _Examples({required this.onTap});
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.askExamplesTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in l10n.askExamples.split('|'))
              ActionChip(
                label: Text(q, textDirection: TextDirection.rtl),
                onPressed: () => onTap(q),
              ),
          ],
        ),
      ],
    );
  }
}

class _AnswerView extends StatelessWidget {
  const _AnswerView({
    super.key,
    required this.answer,
    required this.onCopy,
    required this.onShare,
    required this.onNewQuestion,
  });

  final AskAnswer answer;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onNewQuestion;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final query = AskQuery.fromQuestion(answer.question);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.askYourQuestion(answer.question),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.askAiLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // الإجابة عربية دائماً (DESIGN §17).
                Text(
                  answer.answer,
                  textDirection: TextDirection.rtl,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 17,
                    height: 1.7,
                  ),
                ),
                for (final c in answer.citations) ...[
                  const SizedBox(height: 16),
                  _CitationBlock(citation: c),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy),
                      label: Text(l10n.copy),
                    ),
                    TextButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share),
                      label: Text(l10n.share),
                    ),
                    TextButton.icon(
                      onPressed: onNewQuestion,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l10n.askNewQuestion),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (answer.others.isNotEmpty) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
            minTileHeight: 48,
            title: Text(
              l10n.askOtherPassages(formatInt(answer.others.length, lang)),
            ),
            children: [
              for (final p in answer.others)
                _PassageCard(paragraph: p, query: query),
            ],
          ),
        ],
      ],
    );
  }
}

/// كتلة اقتباس: النص من الفقرة المحلية بخط أميري، وشريحة المصدر. النقر على
/// أيهما يفتح القارئ على الفقرة مع تظليل الاقتباس (DESIGN §12.4).
class _CitationBlock extends StatelessWidget {
  const _CitationBlock({required this.citation});

  final VerifiedCitation citation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = citation;
    void open() => context.push(quoteLocation(c));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: l10n.askQuoteSemantics(_flatQuote(c.quote)),
          excludeSemantics: true,
          child: InkWell(
            onTap: open,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: AdeebColors.goldOrnament, width: 3),
                ),
              ),
              child: Text(
                l10n.askQuoted(_flatQuote(c.quote)),
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: bookFont,
                  fontSize: 18,
                  height: 1.9,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            button: true,
            label: l10n.askOpenSource(c.bookTitle, c.chapterTitle),
            excludeSemantics: true,
            child: ActionChip(
              avatar: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text(
                l10n.breadcrumb(c.bookTitle, c.chapterTitle),
                textDirection: TextDirection.rtl,
              ),
              onPressed: open,
            ),
          ),
        ),
      ],
    );
  }
}

class _FallbackView extends StatelessWidget {
  const _FallbackView({
    super.key,
    required this.outcome,
    required this.limit,
    required this.onRetry,
  });

  final AskFallback outcome;
  final int limit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final extra = context.extraColors;
    final reason = outcome.reason;
    final notFound =
        reason == FallbackReason.notFound ||
        reason == FallbackReason.noLocalMatches;
    final message = switch (reason) {
      FallbackReason.dailyLimit => l10n.askDailyLimit(formatInt(limit, lang)),
      _ => _fallbackMessage(l10n, reason),
    };
    final warning = !notFound && reason != FallbackReason.unverified;
    final retry =
        reason == FallbackReason.offline ||
        reason == FallbackReason.unavailable;
    final query = AskQuery.fromQuestion(outcome.question);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.all(16),
          decoration: BoxDecoration(
            color: warning ? extra.warningContainer : extra.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(switch (reason) {
                      FallbackReason.offline => Icons.cloud_off,
                      FallbackReason.dailyLimit => Icons.hourglass_empty,
                      _ when notFound => Icons.search_off,
                      _ => Icons.info_outline,
                    }, color: warning ? extra.onWarning : null),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: warning ? extra.onWarning : null,
                          fontWeight: notFound ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (notFound) ...[
                const SizedBox(height: 8),
                Text(l10n.askNotFoundHint, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(l10n.askBooksOnly, style: theme.textTheme.bodyMedium),
              ],
              if (!notFound && outcome.passages.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.askNoLocalMatches,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: warning ? extra.onWarning : null,
                  ),
                ),
              ],
              if (retry) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton(
                    onPressed: onRetry,
                    child: Text(l10n.retry),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (outcome.passages.isNotEmpty) ...[
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              notFound ? l10n.askClosestPassages : l10n.askMatchingPassages,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          for (final p in outcome.passages)
            _PassageCard(paragraph: p, query: query),
        ],
      ],
    );
  }
}

/// بطاقة نص مطابق بشكل نتائج البحث (DESIGN §11.2، §12.4).
class _PassageCard extends StatelessWidget {
  const _PassageCard({required this.paragraph, required this.query});

  final LocalParagraph paragraph;
  final AskQuery query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = paragraph;
    final spans = findMatches(p.text, query.highlightQuery);
    final snippet = buildSnippet(p.text, spans);
    final words = {for (final s in spans) p.text.substring(s.start, s.end)};
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Semantics(
        button: true,
        label: l10n.searchResultSemantics(
          p.chapterTitle,
          p.bookTitle,
          snippet.text,
          words.join('، '),
        ),
        excludeSemantics: true,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(passageLocation(p, query)),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.breadcrumb(p.bookTitle, p.chapterTitle),
                    textDirection: TextDirection.rtl,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: highlightedSpans(
                        snippet.text,
                        snippet.spans,
                        context.extraColors.searchHighlight,
                      ),
                    ),
                    textDirection: TextDirection.rtl,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: bookFont,
                      fontSize: 16,
                      height: 1.8,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBlock extends StatelessWidget {
  const _MessageBlock({
    required this.text,
    this.action,
    this.onAction,
    this.isError = false,
  });

  final String text;
  final String? action;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isError ? theme.colorScheme.error : null,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton(onPressed: onAction, child: Text(action!)),
            ),
          ],
        ],
      ),
    );
  }
}

/// أول استخدام: التنبيهات وتأكيد العمر 18+ (DESIGN §12.1، D13).
class _ConsentSheet extends StatelessWidget {
  const _ConsentSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget line(String text, IconData icon) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, color: theme.colorScheme.primary)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.askConsentTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),
            line(l10n.askConsentBooks, Icons.menu_book_outlined),
            line(l10n.askConsentGemini, Icons.cloud_outlined),
            line(l10n.askConsentPersonal, Icons.shield_outlined),
            line(l10n.askConsentNoFatwa, Icons.block),
            line(l10n.askConsentAge, Icons.person_outline),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.askConsentConfirm),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.askConsentDecline),
            ),
          ],
        ),
      ),
    );
  }
}
