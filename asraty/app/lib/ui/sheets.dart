import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/avatars.dart';
import '../core/models.dart';
import 'common.dart';
import 'providers.dart';
import 'theme.dart';

Future<T?> openSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (c) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .82),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(c).bottom),
          child: builder(c),
        ),
      ),
    );

class SheetHeader extends StatelessWidget {
  const SheetHeader(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        XButton(onPressed: () => Navigator.pop(context), tooltip: context.t.close),
      ]);
}

/// Grid of the 12 avatars (.avgrid).
class AvatarGrid extends StatelessWidget {
  const AvatarGrid({super.key, required this.selected, required this.onPick});
  final String selected;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final n = (c.maxWidth / 70).floor().clamp(4, 8);
        final size = (c.maxWidth - (n - 1) * 8) / n;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in avatarKeys)
            Semantics(
              selected: k == selected,
              button: true,
              child: GestureDetector(
                onTap: () => onPick(k),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: k == selected ? Palette.brand : Colors.transparent, width: 3),
                    boxShadow: k == selected ? const [BoxShadow(color: Palette.sun, spreadRadius: 2)] : null,
                  ),
                  child: AvatarView(k, size: size),
                ),
              ),
            ),
        ]);
      });
}

Future<void> showAvatarPicker(BuildContext context, WidgetRef ref, Person p) => openSheet(context, (c) {
      final t = c.t;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader(t.chooseAvatarFor(p.name)),
        const SizedBox(height: 12),
        AvatarGrid(
          selected: p.avatar,
          onPick: (k) async {
            Navigator.pop(c);
            final me = ref.read(appStateProvider).value?.session?.personId;
            await run(context, () => ref.read(backendProvider).setAvatar(p.id, k),
                ok: p.id == me ? t.avatarChangedMine : t.avatarChanged(p.name));
          },
        ),
      ]);
    });

String platformLabel() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.android => 'Android',
    _ => defaultTargetPlatform.name,
  };
}

class FeedbackSheet extends ConsumerStatefulWidget {
  const FeedbackSheet({super.key});
  @override
  ConsumerState<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<FeedbackSheet> {
  var _type = 'suggestion';
  final _text = TextEditingController();
  final _email = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _text.dispose();
    _email.dispose();
    super.dispose();
  }

  List<(String, String, String)> _types(BuildContext c) =>
      [('suggestion', '💡', c.t.fbSuggestion), ('complaint', '📣', c.t.fbComplaint), ('bug', '🛠️', c.t.fbBug)];

  Future<void> _send() async {
    final t = context.t;
    final text = _text.text.trim();
    final email = _email.text.trim().toLowerCase();
    if (text.length < 5) return toast(context, t.errFbShort);
    final signedIn = ref.read(appStateProvider).value?.signedIn ?? false;
    if (!signedIn && email.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) return toast(context, t.errFbEmail);
    setState(() => _busy = true);
    final ok = await run(context, () => ref.read(backendProvider).sendFeedback(
        type: _type, text: text, email: signedIn || email.isEmpty ? null : email, platform: platformLabel()));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.read(feedbackHistoryProvider.notifier).add(SentFeedback(_type, text, DateTime.now()));
      Navigator.pop(context);
      toast(context, t.fbThanks);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, p = context.pal;
    final signedIn = ref.watch(appStateProvider).value?.signedIn ?? false;
    final history = ref.watch(feedbackHistoryProvider);
    final types = _types(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetHeader('💬 ${t.feedback}'),
      Muted(t.fbIntro),
      FormBox(margin: const EdgeInsets.only(top: 12), children: [
        Row(children: [
          for (final (k, e, l) in types)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Semantics(
                  checked: _type == k,
                  child: GestureDetector(
                    onTap: () => setState(() => _type = k),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: _type == k ? p.mintBg : p.card,
                        border: Border.all(color: _type == k ? Palette.brand : p.line, width: 2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(children: [
                        Text(e, style: const TextStyle(fontSize: 22)),
                        Text(l,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _type == k ? p.brandInk : p.ink)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ]),
        TextField(controller: _text, minLines: 4, maxLines: 8, maxLength: 2000, decoration: InputDecoration(hintText: t.fbTextHint, counterText: '')),
        if (!signedIn)
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(hintText: t.fbEmailHint),
          ),
        Btn(t.send, onPressed: _busy ? null : _send),
      ]),
      if (history.isNotEmpty) ...[
        H3(t.fbPrevious),
        for (final f in history)
          RowCard(children: [
            Expanded(
              child: TitleSub(
                '${types.firstWhere((x) => x.$1 == f.type, orElse: () => types.first).$2} ${types.firstWhere((x) => x.$1 == f.type, orElse: () => types.first).$3}',
                f.text.length > 60 ? '${f.text.substring(0, 60)}…' : f.text,
              ),
            ),
            StateTag(t.fbSentAgo(ago(t, f.at, DateTime.now())), Tone.ok),
          ]),
      ],
    ]);
  }
}

Future<void> showMailbox(BuildContext context, List<DemoMail> mail) => openSheet(context, (c) {
      final t = c.t;
      final now = DateTime.now();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader('📧 ${t.demoMailbox}'),
        NoteBox(t.mailboxNote),
        const SizedBox(height: 8),
        if (mail.isEmpty) EmptyState('📭', t.noMail),
        for (final m in mail)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border.all(color: c.pal.line), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Muted('${t.mailTo} '),
                Flexible(child: Text(m.to, textDirection: TextDirection.ltr, style: TextStyle(color: c.pal.muted, fontSize: 14))),
                Muted(' · ${ago(t, m.at, now)}'),
              ]),
              Text(m.subject, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              SelectableText(m.body),
            ]),
          ),
      ]);
    });

/// Full-size proof photo with approve / reject (for approvers).
Future<void> showProof(BuildContext context, WidgetRef ref, Completion comp, Person? kid, {required bool canDecide}) =>
    openSheet(context, (c) {
      final t = c.t;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader('📷 ${comp.title}'),
        Muted('${kid?.name ?? '—'} · ${ago(t, comp.createdAt, DateTime.now())} · ${t.pointsPlus('${comp.points}')}'),
        const SizedBox(height: 12),
        FutureBuilder<ImageProvider?>(
          future: ref.read(backendProvider).proofImage(comp),
          builder: (c, s) => ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              color: Colors.black,
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .6, minHeight: 200),
              alignment: Alignment.center,
              child: s.data == null
                  ? const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
                  : Image(image: s.data!, fit: BoxFit.contain, semanticLabel: comp.title),
            ),
          ),
        ),
        if (canDecide && comp.status == Status.pending) ...[
          const SizedBox(height: 12),
          Two(
            Btn(t.approveBtn, kind: BtnKind.ok, onPressed: () async {
              Navigator.pop(c);
              await run(context, () => ref.read(backendProvider).decideCompletion(comp.id, true),
                  ok: t.approvedToast('${comp.points}', kid?.name ?? ''));
            }),
            Btn(t.rejectBtn, kind: BtnKind.no, onPressed: () async {
              Navigator.pop(c);
              await run(context, () => ref.read(backendProvider).decideCompletion(comp.id, false), ok: t.rejectedToast);
            }),
          ),
        ],
      ]);
    });

/// Thumbnail of a proof photo in the approvals list.
class ProofThumb extends ConsumerWidget {
  const ProofThumb({super.key, required this.comp, required this.onTap});
  final Completion comp;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
        button: true,
        label: context.t.viewPhoto,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.pal.bg,
              border: Border.all(color: context.pal.line, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FutureBuilder<ImageProvider?>(
              future: ref.read(backendProvider).proofImage(comp),
              builder: (c, s) => s.data == null ? const Center(child: Text('📷')) : Image(image: s.data!, fit: BoxFit.cover),
            ),
          ),
        ),
      );
}
