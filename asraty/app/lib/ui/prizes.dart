import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic.dart';
import '../core/models.dart';
import 'common.dart';
import 'providers.dart';
import 'shell.dart';
import 'theme.dart';

const prizeEmoji = ['🎁', '🏆', '🏞️', '🍔', '🎮', '🍦', '🎡', '📚', '🏖️', '💵', '🚲', '📱'];

/// Prizes: the owner sets one for a day, week, month or year and when it is
/// handed over; the member with the most points in that period wins it
/// automatically. Everyone sees the prizes, who leads now, and past winners.
class PrizesPage extends ConsumerStatefulWidget {
  const PrizesPage(this.c, {super.key});
  final Ctx c;
  @override
  ConsumerState<PrizesPage> createState() => _PrizesPageState();
}

class _PrizesPageState extends ConsumerState<PrizesPage> {
  final _name = TextEditingController();
  var _emoji = prizeEmoji.first;
  var _period = Span.weekly;
  late DateTime _day;
  var _time = const TimeOfDay(hour: 21, minute: 0);

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _day = DateTime(n.year, n.month, n.day);
    if (!_at.isAfter(n)) _day = _day.add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  DateTime get _at => DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);

  Future<void> _add() async {
    final t = context.t;
    final name = _name.text.trim();
    if (name.isEmpty || !_at.isAfter(DateTime.now())) return toast(context, t.errPrizeInput);
    final ok = await run(context, () => ref.read(backendProvider).addPrize(name: name, emoji: _emoji, period: _period, awardAt: _at), ok: t.prizeAdded);
    if (ok) _name.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data, b = ref.read(backendProvider);
    final owner = widget.c.me.role == Role.owner;
    final loc = MaterialLocalizations.of(context);
    final upcoming = d.prizes.where((p) => !p.awarded).toList(), past = d.prizes.where((p) => p.awarded).toList().reversed.take(10);
    String when(Prize p) => '${loc.formatMediumDate(p.awardAt.toLocal())} · ${clockTime(context, p.awardAt)}';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.prizesTitle),
      Muted(owner ? t.prizesSub : t.prizesSubMember),
      if (owner)
        FormBox(children: [
          TextField(controller: _name, maxLength: 60, decoration: InputDecoration(hintText: t.prizeNameHint, counterText: '')),
          Two(
            Labeled(t.prizeFor, Select<Span>(value: _period, items: [for (final s in Span.values) (s, spanLabel(t, s))], onChanged: (v) => setState(() => _period = v))),
            Labeled(t.icon, Select<String>(value: _emoji, label: t.icon, items: [for (final e in prizeEmoji) (e, e)], onChanged: (v) => setState(() => _emoji = v))),
          ),
          Two(
            Labeled(
              t.awardDate,
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(loc.formatShortMonthDay(_day), overflow: TextOverflow.ellipsis),
                onPressed: () async {
                  final n = DateTime.now();
                  final v = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(n.year, n.month, n.day), lastDate: n.add(const Duration(days: 366)));
                  if (v != null) setState(() => _day = v);
                },
              ),
            ),
            Labeled(
              t.awardTime,
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule_outlined, size: 18),
                label: Text(_time.format(context)),
                onPressed: () async {
                  final v = await showTimePicker(context: context, initialTime: _time);
                  if (v != null) setState(() => _time = v);
                },
              ),
            ),
          ),
          Btn(t.addPrize, onPressed: _add),
        ]),
      H3(t.upcomingPrizes),
      if (upcoming.isEmpty) EmptyState('🎁', owner ? t.noPrizes : t.noPrizesMember),
      for (final p in upcoming)
        Builder(builder: (context) {
          final lead = d.rankingFor(p.period).where((r) => r.points > 0).firstOrNull;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.pal.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Palette.sun.withValues(alpha: .7)),
            ),
            child: Row(children: [
              Text(p.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Muted(t.prizeMeta(t.prizeForPeriod(spanLabel(t, p.period)), when(p))),
                  if (lead != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text('${t.prizeLeading}:', style: TextStyle(color: context.pal.muted, fontSize: 13)),
                        MiniName(lead.person, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Pts('${lead.points}'),
                      ]),
                    ),
                ]),
              ),
              if (owner) XButton(tooltip: t.delete, onPressed: () => run(context, () => b.deletePrize(p.id))),
            ]),
          );
        }),
      if (past.isNotEmpty) ...[
        H3(t.pastPrizes),
        for (final p in past)
          RowCard(children: [
            EmojiCircle(p.emoji),
            Expanded(
              child: TitleSub(
                p.name,
                p.winnerId == null ? t.noWinner : t.prizeWonBy(d.person(p.winnerId!)?.name ?? '—', '${p.winnerPoints}'),
              ),
            ),
            if (p.winnerId != null && d.person(p.winnerId!) != null) AvatarView.of(d.person(p.winnerId!)!, size: 36),
          ]),
      ],
    ]);
  }
}
