import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/logic.dart';
import '../core/prayer.dart';
import 'common.dart';
import 'providers.dart';
import 'shell.dart';
import 'theme.dart';

/// Owner's prayer reminder settings: the family's location (from this phone),
/// points per prayer, on / off, and today's times.
class PrayerPage extends ConsumerStatefulWidget {
  const PrayerPage(this.c, {super.key});
  final Ctx c;
  @override
  ConsumerState<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends ConsumerState<PrayerPage> {
  late final _pts = TextEditingController(text: '${widget.c.data.prayer?.points ?? 5}');
  late var _enabled = widget.c.data.prayer?.enabled ?? true;
  var _locating = false;

  @override
  void dispose() {
    _pts.dispose();
    super.dispose();
  }

  Future<void> _save({double? lat, double? lng}) async {
    final t = context.t, cur = widget.c.data.prayer;
    lat ??= cur?.lat;
    lng ??= cur?.lng;
    if (lat == null || lng == null) return toast(context, t.prayerNotSet);
    final pts = parseDigits(_pts.text) ?? 5;
    await run(context, () => ref.read(backendProvider).setPrayer(lat: lat!, lng: lng!, points: pts < 1 ? 5 : pts, enabled: _enabled), ok: t.prayerSaved);
  }

  Future<void> _locate() async {
    final t = context.t;
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw Exception('denied');
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)));
      if (!mounted) return;
      await _save(lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      if (mounted) toast(context, t.errLocation);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, p = widget.c.data.prayer;
    final now = DateTime.now();
    final times = p == null ? null : prayerTimesOn(p, now);
    final cur = p == null ? null : currentPrayer(p, now);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.prayerTitle),
      Muted(t.prayerSub),
      FormBox(children: [
        Btn(t.useMyLocation, icon: Icons.my_location_rounded, expand: true, onPressed: _locating ? null : _locate),
        if (p != null) NoteBox('📍 ${t.prayerLocationSaved} (${p.lat.toStringAsFixed(3)}, ${p.lng.toStringAsFixed(3)})'),
        Row(children: [
          Expanded(child: Text(t.prayerEnabled, style: const TextStyle(fontWeight: FontWeight.w700))),
          Switch(value: _enabled, activeThumbColor: Palette.brand, onChanged: (v) => setState(() => _enabled = v)),
        ]),
        Labeled(t.prayerPoints, TextField(controller: _pts, keyboardType: TextInputType.number)),
        Btn(t.save, onPressed: p == null ? null : _save),
      ]),
      H3(t.prayerTimesToday),
      if (times == null)
        Muted(t.prayerNotSet)
      else
        for (final k in prayerKeys)
          RowCard(children: [
            Icon(Icons.mosque_outlined, color: cur?.key == k ? Palette.brand : context.pal.muted),
            Expanded(child: Text(prayerNames[k]!, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (cur?.key == k && cur?.dayKey == dayKey(times[k]!)) StateTag(t.prayerNow, Tone.ok),
            Text(clockTime(context, times[k]!), style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
          ]),
    ]);
  }
}
