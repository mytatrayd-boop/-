import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../backend/backend.dart';
import '../core/logic.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'common.dart';
import 'providers.dart';
import 'shell.dart';
import 'theme.dart';

/// "أنا هنا": while a trip is live, family members share their places.
/// Admins with [Perm.trip] start/end the trip, set a meeting point and pause
/// anyone's sharing; members get one big button and a list of where everyone is.

/// This phone's position, or null when location is off or refused.
Future<Position?> currentPosition({bool ask = true}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied && ask) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
  } catch (_) {
    return null;
  }
}

/// Sends this phone's place every 30 s while the app is open and sharing is on.
/// It skips a send when the phone barely moved (keeps Firestore usage low on the free plan).
class TripSharer extends Notifier<bool> {
  Timer? _timer;
  Position? _last;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    return false;
  }

  /// Returns false when location permission was refused.
  Future<bool> start() async {
    final pos = await currentPosition();
    if (pos == null) return false;
    state = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
    await _send(pos, force: true);
    return true;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _last = null;
    state = false;
  }

  Future<void> _tick() async {
    final pos = await currentPosition(ask: false);
    if (pos != null) await _send(pos);
  }

  Future<void> _send(Position pos, {bool force = false}) async {
    final now = DateTime.now(), last = _last;
    final still = last != null && distanceMeters(last.latitude, last.longitude, pos.latitude, pos.longitude) < 20;
    if (!force && still && now.difference(_lastAt) < const Duration(minutes: 2)) return;
    try {
      await ref.read(backendProvider).tripPing(lat: pos.latitude, lng: pos.longitude, acc: pos.accuracy);
      _last = pos;
      _lastAt = now;
    } on AppError catch (e) {
      if (e.code == 'no-trip') stop();
    } catch (_) {
      // Offline: the next tick tries again.
    }
  }
}

final tripSharerProvider = NotifierProvider<TripSharer, bool>(TripSharer.new);

String _agoText(L10n t, DateTime at, DateTime now) {
  final m = now.difference(at).inMinutes;
  if (m < 1) return t.tripNow;
  if (m < 60) return '${t.tripAgo} $m ${t.tripMinute}';
  return '${t.tripAgo} ${m ~/ 60} ${t.tripHour}';
}

String _distText(L10n t, double m) => m < 1000 ? '${m.round()} ${t.tripMeters}' : '${(m / 1000).toStringAsFixed(1)} ${t.tripKm}';

class TripPage extends ConsumerStatefulWidget {
  const TripPage(this.c, {super.key});
  final Ctx c;
  @override
  ConsumerState<TripPage> createState() => _TripPageState();
}

class _TripPageState extends ConsumerState<TripPage> {
  final _hours = TextEditingController(text: '12');
  final _far = TextEditingController(text: '300');
  final _meetLabel = TextEditingController();

  @override
  void dispose() {
    _hours.dispose();
    _far.dispose();
    _meetLabel.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final t = context.t;
    final ok = await ref.read(tripSharerProvider.notifier).start();
    if (!ok && mounted) toast(context, t.tripDenied);
  }

  Future<void> _sos() async {
    final t = context.t, b = ref.read(backendProvider);
    if (!await confirm(context, t.tripSosConfirm, ok: t.tripSosSend, danger: true) || !mounted) return;
    final pos = await currentPosition();
    if (!mounted) return;
    await run(context, () => b.tripSos(lat: pos?.latitude, lng: pos?.longitude), ok: t.tripSosSent);
  }

  Future<void> _setMeet() async {
    final t = context.t, b = ref.read(backendProvider);
    final pos = await currentPosition();
    if (!mounted) return;
    if (pos == null) return toast(context, t.tripDenied);
    final ok = await run(context, () => b.tripMeet(lat: pos.latitude, lng: pos.longitude, label: _meetLabel.text), ok: t.tripMeetSaved);
    if (ok) _meetLabel.clear();
  }

  Future<void> _openMap(double lat, double lng, {bool directions = false}) async {
    final u = Uri.parse(directions ? 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng' : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final ok = await launchUrl(u, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) toast(context, context.t.errLocation);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data, me = widget.c.me, b = ref.read(backendProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final sharing = ref.watch(tripSharerProvider);
    final trip = d.trip;
    final manager = can(me, Perm.trip);

    if (trip == null || !trip.liveAt(now)) {
      if (sharing) Future.microtask(() => ref.read(tripSharerProvider.notifier).stop());
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        H2(t.tripTitle),
        Muted(t.tripSub),
        if (!manager)
          NoteBox(t.tripNoneMember)
        else
          FormBox(children: [
            Text(t.tripNone, style: const TextStyle(fontWeight: FontWeight.w700)),
            Labeled(t.tripHours, TextField(controller: _hours, keyboardType: TextInputType.number)),
            Labeled(t.tripFar, TextField(controller: _far, keyboardType: TextInputType.number)),
            Muted(t.tripFarHint),
            Btn(t.tripStart,
                icon: Icons.flight_takeoff_rounded,
                onPressed: () => run(context, () => b.tripStart(hours: parseDigits(_hours.text) ?? 12, farMeters: parseDigits(_far.text) ?? 300), ok: t.tripStarted)),
          ]),
      ]);
    }

    final paused = trip.paused.contains(me.id);
    if (sharing && paused) Future.microtask(() => ref.read(tripSharerProvider.notifier).stop());
    final mine = d.locations[me.id];
    final meet = trip.meet;
    final meetDist = meet != null && mine != null ? distanceMeters(mine.lat, mine.lng, meet.lat, meet.lng) : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(t.tripTitle),
      Muted('${t.tripEndsAt} ${clockTime(context, trip.endsAt)}'),
      const SizedBox(height: 10),
      // The one big button for everyone.
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.pal.mintBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: Palette.mint.withValues(alpha: .5))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (paused)
            Text(t.tripPausedByAdmin, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))
          else ...[
            Text(sharing ? t.tripSharingOn : t.tripSharingOff, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            if (!sharing) Btn(t.tripImHere, icon: Icons.location_on_rounded, kind: BtnKind.ok, expand: true, onPressed: _share),
            // Children (members) keep sharing until a parent pauses them.
            if (sharing && me.role != Role.member)
              Btn(t.tripStop, icon: Icons.location_off_outlined, kind: BtnKind.ghost, expand: true, onPressed: () => ref.read(tripSharerProvider.notifier).stop()),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Btn(t.tripSos, icon: Icons.warning_amber_rounded, kind: BtnKind.no, expand: true, onPressed: _sos),
      if (meet != null) ...[
        H3('📌 ${t.tripMeet}'),
        _Card(
          head: [Expanded(child: TitleSub(meet.label, [if (meetDist != null) '${t.tripAway} ${_distText(t, meetDist)}', meet.by].join(' · ')))],
          actions: [
            Btn(t.tripMeetGo, small: true, icon: Icons.directions_rounded, onPressed: () => _openMap(meet.lat, meet.lng, directions: true)),
            if (manager) Btn(t.tripMeetClear, small: true, kind: BtnKind.ghost, onPressed: () => run(context, b.tripMeetClear)),
          ],
        ),
      ],
      if (manager && meet == null) ...[
        H3('📌 ${t.tripMeet}'),
        FormBox(children: [
          TextField(controller: _meetLabel, decoration: InputDecoration(hintText: t.tripMeetLabel)),
          Btn(t.tripMeetSet, icon: Icons.add_location_alt_outlined, onPressed: _setMeet),
        ]),
      ],
      TripMap(c: widget.c, trip: trip, now: now),
      H3(t.tripFamily),
      for (final p in d.people) _personRow(context, p, trip, d.locations[p.id], mine, now, b),
      NoteBox(t.tripPrivacy),
      if (manager) ...[
        const SizedBox(height: 14),
        Btn(t.tripEnd,
            icon: Icons.flag_outlined,
            kind: BtnKind.ghost,
            onPressed: () async {
              if (await confirm(context, t.tripEndConfirm, ok: t.tripEnd, danger: true) && context.mounted) {
                await run(context, b.tripEnd, ok: t.tripEnded);
              }
            }),
      ],
    ]);
  }

  Widget _personRow(BuildContext context, Person p, TripState trip, MemberLoc? loc, MemberLoc? mine, DateTime now, Backend b) {
    final t = context.t;
    final off = trip.paused.contains(p.id);
    final age = loc == null ? null : now.difference(loc.at);
    final tone = age == null ? Tone.off : (age.inMinutes <= 2 ? Tone.ok : (age.inMinutes <= 10 ? Tone.wait : Tone.off));
    final dist = loc != null && mine != null && p.id != widget.c.me.id ? distanceMeters(mine.lat, mine.lng, loc.lat, loc.lng) : null;
    final tag = off ? t.tripPaused : (loc == null ? t.tripNotSharing : _agoText(t, loc.at, now));
    final toggle = canToggleShare(widget.c.me, p);
    return _Card(
      faded: off || loc == null,
      head: [
        AvatarView.of(p, size: 40),
        Expanded(child: TitleSub(p.name, [if (dist != null) '${t.tripAway} ${_distText(t, dist)}', if (age != null && age.inMinutes > 10) t.tripStaleHint].join(' · '))),
      ],
      actions: [
        StateTag(tag, off ? Tone.off : tone),
        if (loc != null && !off) Btn(t.tripOpenMap, small: true, kind: BtnKind.ghost, icon: Icons.map_outlined, onPressed: () => _openMap(loc.lat, loc.lng)),
        if (toggle) Btn(off ? t.tripResume : t.tripPause, small: true, kind: BtnKind.ghost, onPressed: () => run(context, () => b.tripShare(p.id, off))),
      ],
    );
  }
}

/// A card with a header row and, below it, action buttons that wrap on narrow screens.
class _Card extends StatelessWidget {
  const _Card({required this.head, this.actions = const [], this.faded = false});
  final List<Widget> head, actions;
  final bool faded;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: faded ? .7 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.pal.card, border: Border.all(color: context.pal.line), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [for (var i = 0; i < head.length; i++) ...[if (i > 0) const SizedBox(width: 10), head[i]]]),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ]),
        ),
      );
}

/// Home-screen entry: shown only while a trip is live (members), as a big green card.
class TripBanner extends ConsumerWidget {
  const TripBanner(this.c, {super.key, required this.onTap});
  final Ctx c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final trip = c.data.trip;
    if (trip == null || !trip.liveAt(now)) return const SizedBox.shrink();
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Btn(t.tripImHere, icon: Icons.location_on_rounded, kind: BtnKind.ok, expand: true, onPressed: onTap),
    );
  }
}

/// The family on one map (OpenStreetMap, free, no key): a pin per person who shares
/// (green = fresh, yellow = a few minutes old, red = old) and the meeting point.
class TripMap extends StatefulWidget {
  const TripMap({super.key, required this.c, required this.trip, required this.now});
  final Ctx c;
  final TripState trip;
  final DateTime now;
  @override
  State<TripMap> createState() => _TripMapState();
}

class _Pin {
  const _Pin(this.point, this.label, this.color, this.icon);
  final LatLng point;
  final String label;
  final Color color;
  final IconData icon;
}

class _TripMapState extends State<TripMap> {
  final _ctl = MapController();
  int _fitted = -1;

  List<_Pin> _pins() {
    final d = widget.c.data, out = <_Pin>[];
    for (final loc in d.locations.values) {
      final p = d.person(loc.personId);
      if (p == null || widget.trip.paused.contains(p.id)) continue;
      final min = widget.now.difference(loc.at).inMinutes;
      out.add(_Pin(LatLng(loc.lat, loc.lng), p.name, min <= 2 ? Palette.mint : (min <= 10 ? Palette.sunDeep : Palette.red), Icons.location_on));
    }
    final m = widget.trip.meet;
    if (m != null) out.add(_Pin(LatLng(m.lat, m.lng), m.label, const Color(0xFF1E6FD9), Icons.flag_rounded));
    return out;
  }

  /// Zooms to fit everyone whenever the number of pins changes.
  void _fit(List<_Pin> pins) {
    if (pins.isEmpty || _fitted == pins.length) return;
    _fitted = pins.length;
    try {
      if (pins.length == 1) {
        _ctl.move(pins.first.point, 16);
      } else {
        _ctl.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints([for (final p in pins) p.point]), padding: const EdgeInsets.all(56), maxZoom: 17));
      }
    } catch (_) {
      // The map is not laid out yet; the next rebuild fits it.
      _fitted = -1;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pins = _pins();
    // Nothing to show until someone shares a place.
    if (pins.isEmpty) return const SizedBox.shrink();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit(pins));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 300,
          child: FlutterMap(
            mapController: _ctl,
            options: MapOptions(initialCenter: pins.first.point, initialZoom: 15, interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate)),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'sa.asraty.app'),
              MarkerLayer(markers: [
                for (final p in pins)
                  Marker(
                    point: p.point,
                    width: 96,
                    height: 62,
                    alignment: Alignment.topCenter,
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: p.color)),
                        child: Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.black87)),
                      ),
                      Icon(p.icon, color: p.color, size: 34),
                    ]),
                  ),
              ]),
              const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
            ],
          ),
        ),
      ),
    );
  }
}
