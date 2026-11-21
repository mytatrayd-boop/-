import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic.dart';
import '../core/models.dart';
import '../core/prayer.dart';
import 'common.dart';
import 'providers.dart';
import 'shell.dart';
import 'theme.dart';

/// «مهلة أداء الصلاة» (owner's request, Nov 2026): for every prayer, how many minutes after the adhan it
/// keeps its points, for all members or one member. The owner and delegated admins with the tasks
/// permission open it from the dashboard. Changes are drafted here and sent with «حفظ».
class GracePage extends ConsumerStatefulWidget {
  const GracePage(this.c, {super.key});
  final Ctx c;
  @override
  ConsumerState<GracePage> createState() => _GracePageState();
}

class _GracePageState extends ConsumerState<GracePage> {
  /// "all" or a member id.
  var _target = 'all';

  /// Edited values for [_target]: a key with null = back to the default.
  final _draft = <String, int?>{};
  var _saving = false;

  PrayerSettings? get _p => widget.c.data.prayer;

  /// The value in force for [_target] (before the draft): own, else the family's for a member.
  int? _stored(String k) {
    final p = _p;
    if (p == null) return null;
    return _target == 'all' ? (p.grace['all']?[k]) : p.graceFor(_target, k);
  }

  /// A member's value set back to default falls back to the family's value.
  int? _value(String k) {
    if (!_draft.containsKey(k)) return _stored(k);
    return _draft[k] ?? (_target == 'all' ? null : (_p?.grace['all']?[k]));
  }

  /// Minutes the default rule gives today (Isha: until 11 pm), to start the − / + from.
  int _defaultMinutes(String k, DateTime adhan) {
    final slot = PrayerSlot(key: k, start: adhan, end: adhan, dayKey: '');
    final m = slot.lateFrom.difference(adhan).inMinutes;
    return (m / graceStep).round() * graceStep;
  }

  void _step(String k, DateTime adhan, int delta) {
    final cur = _value(k) ?? _defaultMinutes(k, adhan);
    setState(() => _draft[k] = (cur + delta).clamp(graceMin, graceMax));
  }

  Future<void> _save() async {
    final t = context.t;
    if (_draft.isEmpty) return;
    setState(() => _saving = true);
    final ok = await run(context, () => ref.read(backendProvider).setPrayerGrace(_target, Map.of(_draft)), ok: t.graceSaved);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _draft.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, p = _p, d = widget.c.data;
    if (p == null || !p.enabled) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [H2(t.graceTitle), Muted(t.graceNeedPrayer)]);
    }
    final times = prayerTimesOn(p, DateTime.now());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.graceTitle),
      Muted(t.graceSub),
      const SizedBox(height: 8),
      Labeled(
        t.graceTarget,
        Select<String>(
          key: const Key('grace-target'),
          value: _target,
          items: [('all', t.graceAll), for (final m in d.members) (m.id, m.name)],
          onChanged: (v) => setState(() {
            _target = v;
            _draft.clear();
          }),
        ),
      ),
      const SizedBox(height: 8),
      for (final k in prayerKeys) _row(context, k, times[k]!),
      const SizedBox(height: 8),
      Btn(t.save, key: const Key('grace-save'), expand: true, onPressed: _draft.isEmpty || _saving ? null : _save),
    ]);
  }

  Widget _row(BuildContext context, String k, DateTime adhan) {
    final t = context.t, v = _value(k);
    final minutes = v ?? _defaultMinutes(k, adhan);
    final ends = adhan.add(Duration(minutes: minutes));
    return RowCard(key: Key('grace-row-$k'), children: [
      const Icon(Icons.mosque_outlined, color: Palette.brand),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(prayerNames[k]!, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            v == null ? '${t.graceDefault} · ${t.graceEndsAt(clockTime(context, ends))}' : t.graceEndsAt(clockTime(context, ends)),
            style: TextStyle(color: context.pal.muted, fontSize: 13),
          ),
        ]),
      ),
      IconButton(
        key: Key('grace-minus-$k'),
        tooltip: t.graceLess,
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: minutes <= graceMin ? null : () => _step(k, adhan, -graceStep),
      ),
      SizedBox(
        width: 64,
        child: Text(t.graceMinutes(minutes), key: Key('grace-value-$k'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      IconButton(
        key: Key('grace-plus-$k'),
        tooltip: t.graceMore,
        icon: const Icon(Icons.add_circle_outline),
        onPressed: minutes >= graceMax ? null : () => _step(k, adhan, graceStep),
      ),
      if (v != null)
        IconButton(
          key: Key('grace-reset-$k'),
          tooltip: t.graceDefault,
          icon: const Icon(Icons.restart_alt_rounded),
          onPressed: () => setState(() => _draft[k] = null),
        ),
    ]);
  }
}
