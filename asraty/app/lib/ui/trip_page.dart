import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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

/// Location permission and service are available (asks once when [ask]).
Future<bool> locationReady({bool ask = true}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied && ask) perm = await Geolocator.requestPermission();
    return perm != LocationPermission.denied && perm != LocationPermission.deniedForever;
  } catch (_) {
    return false;
  }
}

/// This phone's position at the best accuracy it can give, or null when location is off or refused.
/// Returns as soon as a reading is good (better than 30 m), and after at most 15 s with the best one
/// it got, so it never hangs indoors where readings stay rough.
Future<Position?> currentPosition({bool ask = true}) async {
  try {
    if (!await locationReady(ask: ask)) return null;
    Position? best;
    final done = Completer<void>();
    final sub = Geolocator.getPositionStream(locationSettings: _locationSettings(background: false)).listen(
      (p) {
        if (best == null || p.accuracy < best!.accuracy) best = p;
        if (p.accuracy <= 30 && !done.isCompleted) done.complete();
      },
      onError: (_) {},
    );
    final timer = Timer(const Duration(seconds: 15), () {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    timer.cancel();
    await sub.cancel();
    return best ?? await Geolocator.getCurrentPosition(locationSettings: _locationSettings(background: false)).timeout(const Duration(seconds: 10));
  } catch (_) {
    return null;
  }
}

/// Android 12+ and iPhone let the user give the app only an *approximate* location (off by about a
/// kilometre). That makes a family map and meeting points useless, so ask for the precise one.
/// Returns false when the user chose not to continue with an approximate location.
Future<bool> ensurePreciseLocation(BuildContext context) async {
  final t = context.t;
  try {
    var acc = await Geolocator.getLocationAccuracy();
    if (acc != LocationAccuracyStatus.reduced) return true;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      acc = await Geolocator.requestTemporaryFullAccuracy(purposeKey: 'FamilyTrip');
      if (acc != LocationAccuracyStatus.reduced) return true;
    }
    if (!context.mounted) return false;
    if (await confirm(context, t.tripApprox, ok: t.tripOpenSettings)) await Geolocator.openAppSettings();
    return false;
  } catch (_) {
    return true;
  }
}

/// Highest accuracy (GPS + all sensors the phone allows). With [background] the phone keeps
/// reporting while the screen is off or the app is hidden: a foreground notification on Android,
/// the blue location indicator on iPhone. Needed in a crowd, where the phone sits in a pocket.
LocationSettings _locationSettings({required bool background}) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: background
            ? const ForegroundNotificationConfig(
                notificationTitle: 'أسرتي — أنا هنا',
                notificationText: 'تشارك مكانك مع أسرتك أثناء الرحلة',
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: background,
        allowBackgroundLocationUpdates: background,
      );
    default:
      return const LocationSettings(accuracy: LocationAccuracy.best);
  }
}

/// Shares this phone's place with the family while sharing is on, even with the screen off.
/// It listens to the GPS continuously and, every 15 s, sends the most accurate fix of that window
/// (so one bad reading in a crowd does not move the pin). It skips a send when the phone barely
/// moved, which also keeps Firestore usage low on the free plan.
class TripSharer extends Notifier<bool> {
  StreamSubscription<Position>? _sub;
  Timer? _timer;
  Position? _best; // most accurate fix since the last send
  Position? _last; // last sent
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  bool build() {
    ref.onDispose(() {
      _sub?.cancel();
      _timer?.cancel();
    });
    return false;
  }

  /// Starts sharing right away: the first reading (even a rough one) is sent at once so the family
  /// sees the pin, then more accurate ones follow. Returns false when location is off or refused.
  Future<bool> start() async {
    if (!await locationReady()) return false;
    state = true;
    ref.read(tripShareErrorProvider.notifier).set(null);
    _best = null;
    _last = null;
    var first = true;
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(locationSettings: _locationSettings(background: true)).listen(
      (p) {
        ref.read(tripMyPositionProvider.notifier).set(p);
        final b = _best;
        // Keep the most accurate fix; a newer one wins when it is not clearly worse.
        if (b == null || p.accuracy <= b.accuracy * 1.5 || p.timestamp.difference(b.timestamp).inSeconds > 10) _best = p;
        if (first) {
          first = false;
          _best = null;
          unawaited(_send(p, force: true));
        }
      },
      onError: (Object e) => ref.read(tripShareErrorProvider.notifier).set('$e'),
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _flush());
    // If the stream gives nothing quickly (rare), fall back to a one-off reading.
    unawaited(Future.delayed(const Duration(seconds: 8), () async {
      if (state && first) {
        final p = await currentPosition(ask: false);
        if (p != null && first) {
          first = false;
          ref.read(tripMyPositionProvider.notifier).set(p);
          await _send(p, force: true);
        }
      }
    }));
    return true;
  }

  void stop() {
    _sub?.cancel();
    _timer?.cancel();
    _sub = null;
    _timer = null;
    _best = null;
    _last = null;
    ref.read(tripMyPositionProvider.notifier).set(null);
    state = false;
  }

  Future<void> _flush() async {
    final p = _best;
    _best = null;
    if (p != null) await _send(p);
  }

  Future<void> _send(Position pos, {bool force = false}) async {
    final now = DateTime.now(), last = _last;
    final still = last != null && distanceMeters(last.latitude, last.longitude, pos.latitude, pos.longitude) < 8;
    if (!force && still && now.difference(_lastAt) < const Duration(seconds: 90)) return;
    try {
      await ref.read(backendProvider).tripPing(lat: pos.latitude, lng: pos.longitude, acc: pos.accuracy);
      _last = pos;
      _lastAt = now;
      ref.read(tripShareErrorProvider.notifier).set(null);
    } on AppError catch (e) {
      if (e.code == 'no-trip') {
        stop();
      } else {
        ref.read(tripShareErrorProvider.notifier).set(e.code);
      }
    } catch (e) {
      // Offline: the next flush tries again, and the screen says so.
      ref.read(tripShareErrorProvider.notifier).set('$e');
    }
  }
}

final tripSharerProvider = NotifierProvider<TripSharer, bool>(TripSharer.new);

/// This phone's latest reading while sharing. The screen shows it at once, without waiting for the
/// round trip to the server, so the pin appears the moment sharing starts.
class TripMyPosition extends Notifier<Position?> {
  @override
  Position? build() => null;
  void set(Position? p) => state = p;
}

final tripMyPositionProvider = NotifierProvider<TripMyPosition, Position?>(TripMyPosition.new);

/// Why the last send of this phone's place failed (null = fine). Shown under the share button
/// so a failure in the field is visible instead of silent.
class TripShareError extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

final tripShareErrorProvider = NotifierProvider<TripShareError, String?>(TripShareError.new);

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

  @override
  void dispose() {
    _hours.dispose();
    _far.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final t = context.t;
    if (!await ensurePreciseLocation(context) || !mounted) return;
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

  /// Opens the map to pick a place by touch; saves it (and sends it to the family if asked).
  Future<void> _pick({MeetPoint? edit}) async {
    final t = context.t, b = ref.read(backendProvider), d = widget.c.data;
    final mine = d.locations[widget.c.me.id], meet = d.trip?.meet;
    final start = edit != null ? LatLng(edit.lat, edit.lng) : (mine != null ? LatLng(mine.lat, mine.lng) : (meet != null ? LatLng(meet.lat, meet.lng) : (d.places.isNotEmpty ? LatLng(d.places.first.lat, d.places.first.lng) : null)));
    final r = await Navigator.of(context).push<PickedPlace>(MaterialPageRoute(builder: (_) => PlacePickerPage(start: start, picked: edit == null ? null : start, label: edit?.label ?? '')));
    if (r == null || !mounted) return;
    await run(context, () => b.placeSave(lat: r.point.latitude, lng: r.point.longitude, label: r.label, share: r.share), ok: r.share ? t.placeShared : t.placeSaved);
  }

  /// Saved places: managers pick, save, send and delete; everyone can open them.
  List<Widget> _places(BuildContext context, bool manager, Backend b) {
    final t = context.t, places = widget.c.data.places;
    return [
      H3('📌 ${t.placesTitle}'),
      if (manager) ...[
        Muted(t.placesHint),
        const SizedBox(height: 8),
        Btn(t.tripPickPlace, icon: Icons.add_location_alt_outlined, expand: true, onPressed: _pick),
        const SizedBox(height: 8),
      ],
      if (places.isEmpty) Muted(t.placesEmpty),
      for (final p in places)
        _Card(
          head: [Expanded(child: TitleSub(p.label, p.by))],
          actions: [
            Btn(t.tripOpenMap, small: true, kind: BtnKind.ghost, icon: Icons.map_outlined, onPressed: () => _openMap(p.lat, p.lng)),
            if (manager) Btn(t.placeSend, small: true, icon: Icons.send_rounded, onPressed: () => run(context, () => b.placeShare(p.id), ok: t.placeShared)),
            if (manager)
              Btn(t.placeDelete, small: true, kind: BtnKind.ghost, onPressed: () async {
                if (await confirm(context, t.placeDeleteConfirm, ok: t.placeDelete, danger: true) && context.mounted) await run(context, () => b.placeDelete(p.id));
              }),
          ],
        ),
    ];
  }

  Future<void> _openMap(double lat, double lng, {bool directions = false}) => openOnMap(context, lat, lng, directions: directions);

  @override
  Widget build(BuildContext context) {
    final t = context.t, d = widget.c.data, me = widget.c.me, b = ref.read(backendProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final sharing = ref.watch(tripSharerProvider);
    final shareError = ref.watch(tripShareErrorProvider);
    final myPos = ref.watch(tripMyPositionProvider);
    final trip = d.trip;
    final manager = can(me, Perm.trip);

    if (trip == null || !trip.liveAt(now)) {
      if (sharing) Future.microtask(() => ref.read(tripSharerProvider.notifier).stop());
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        H2(t.tripTitle),
        Muted(t.tripSub),
        Btn(t.tripSos, icon: Icons.warning_amber_rounded, kind: BtnKind.no, expand: true, onPressed: _sos),
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
        ..._places(context, manager, b),
      ]);
    }

    final paused = trip.paused.contains(me.id);
    if (sharing && paused) Future.microtask(() => ref.read(tripSharerProvider.notifier).stop());
    // The pin of this phone comes from its own reading at once (no wait for the server).
    final locs = Map<String, MemberLoc>.of(d.locations);
    if (sharing && !paused && myPos != null) {
      locs[me.id] = MemberLoc(personId: me.id, lat: myPos.latitude, lng: myPos.longitude, acc: myPos.accuracy.round(), at: now);
    }
    final mine = locs[me.id];
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
            if (sharing && shareError != null) Text('${t.tripSendFailed} ($shareError)', textAlign: TextAlign.center, style: const TextStyle(color: Palette.red, fontWeight: FontWeight.w700, fontSize: 13)),
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
            if (manager) Btn(t.placeEdit, small: true, kind: BtnKind.ghost, icon: Icons.edit_location_alt_outlined, onPressed: () => _pick(edit: meet)),
            if (manager) Btn(t.tripMeetClear, small: true, kind: BtnKind.ghost, onPressed: () => run(context, b.tripMeetClear)),
          ],
        ),
      ],
      TripMap(c: widget.c, trip: trip, now: now, locations: locs),
      H3(t.tripFamily),
      for (final p in d.people) _personRow(context, p, trip, locs[p.id], mine, now, b),
      NoteBox(t.tripPrivacy),
      ..._places(context, manager, b),
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
        Expanded(child: TitleSub(p.name, [if (dist != null) '${t.tripAway} ${_distText(t, dist)}', if (loc != null && loc.acc > 0 && !off) '${t.tripAccuracy} ${loc.acc} ${t.tripMeters}', if (age != null && age.inMinutes > 10) t.tripStaleHint].join(' · '))),
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
  const TripMap({super.key, required this.c, required this.trip, required this.now, required this.locations});
  final Ctx c;
  final TripState trip;
  final DateTime now;
  final Map<String, MemberLoc> locations;
  @override
  State<TripMap> createState() => _TripMapState();
}

class _Pin {
  const _Pin(this.point, this.label, this.color, this.icon, [this.acc = 0]);
  final double acc; // metres, 0 = unknown
  final LatLng point;
  final String label;
  final Color color;
  final IconData icon;
}

class _TripMapState extends State<TripMap> {
  final _ctl = MapController();
  String _fitted = '';
  DateTime _touched = DateTime.fromMillisecondsSinceEpoch(0); // last time the user moved the map by hand

  List<_Pin> _pins() {
    final d = widget.c.data, out = <_Pin>[];
    for (final loc in widget.locations.values) {
      final p = d.person(loc.personId);
      if (p == null || widget.trip.paused.contains(p.id)) continue;
      final min = widget.now.difference(loc.at).inMinutes;
      out.add(_Pin(LatLng(loc.lat, loc.lng), p.name, min <= 2 ? Palette.mint : (min <= 10 ? Palette.sunDeep : Palette.red), Icons.location_on, loc.acc.toDouble()));
    }
    final m = widget.trip.meet;
    if (m != null) out.add(_Pin(LatLng(m.lat, m.lng), m.label, const Color(0xFF1E6FD9), Icons.flag_rounded));
    return out;
  }

  /// Zooms to fit everyone whenever a pin appears or moves (about 10 m), unless the user is
  /// looking around by hand (then it waits 20 s after their last touch).
  void _fit(List<_Pin> pins) {
    if (pins.isEmpty) return;
    final sig = pins.map((p) => '${p.point.latitude.toStringAsFixed(4)},${p.point.longitude.toStringAsFixed(4)}').join('|');
    if (sig == _fitted || DateTime.now().difference(_touched) < const Duration(seconds: 20)) return;
    _fitted = sig;
    try {
      if (pins.length == 1) {
        _ctl.move(pins.first.point, 16);
      } else {
        _ctl.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints([for (final p in pins) p.point]), padding: const EdgeInsets.all(56), maxZoom: 17));
      }
    } catch (_) {
      // The map is not laid out yet; the next rebuild fits it.
      _fitted = '';
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
            options: MapOptions(initialCenter: pins.first.point, initialZoom: 15, maxZoom: 19, onPositionChanged: (_, byHand) {
              if (byHand) _touched = DateTime.now();
            }, interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate)),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'sa.asraty.app', maxNativeZoom: 19),
              // The circle is how sure the phone is of the spot: small outdoors, wide in a crowd or indoors.
              CircleLayer(circles: [
                for (final p in pins)
                  if (p.acc >= 5) CircleMarker(point: p.point, radius: p.acc, useRadiusInMeter: true, color: p.color.withValues(alpha: .14), borderColor: p.color.withValues(alpha: .5), borderStrokeWidth: 1),
              ]),
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

/// What the picker returns: the touched point, its name and whether to send it to the family now.
class PickedPlace {
  const PickedPlace(this.point, this.label, this.share);
  final LatLng point;
  final String label;
  final bool share;
}

/// Full-screen map: touch to choose the place, name it, then save (and optionally send it to the family).
class PlacePickerPage extends StatefulWidget {
  const PlacePickerPage({super.key, this.start, this.picked, this.label = ''});
  final LatLng? start;

  /// When editing: the point and name already chosen (the pin starts there and can be moved by touch).
  final LatLng? picked;
  final String label;
  @override
  State<PlacePickerPage> createState() => _PlacePickerPageState();
}

class _PlacePickerPageState extends State<PlacePickerPage> {
  final _ctl = MapController();
  late final _name = TextEditingController(text: widget.label);
  late LatLng? _picked = widget.picked;
  var _warn = false; // saving before touching the map
  late final LatLng _center = widget.start ?? const LatLng(24.7136, 46.6753);

  @override
  void dispose() {
    _ctl.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _mine() async {
    if (!await ensurePreciseLocation(context) || !mounted) return;
    final pos = await currentPosition();
    if (!mounted) return;
    if (pos == null) return toast(context, context.t.tripDenied);
    final p = LatLng(pos.latitude, pos.longitude);
    _ctl.move(p, 17);
    setState(() {
      _picked = p;
      _warn = false;
    });
  }

  void _done(bool share) {
    final p = _picked;
    if (p == null) return setState(() => _warn = true);
    Navigator.of(context).pop(PickedPlace(p, _name.text.trim(), share));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.placePickTitle)),
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _ctl,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: widget.start == null ? 12 : 17,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onTap: (_, p) => setState(() {
                  _picked = p;
                  _warn = false;
                }),
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'sa.asraty.app', maxNativeZoom: 19),
                if (_picked != null)
                  MarkerLayer(markers: [
                    Marker(point: _picked!, width: 48, height: 48, alignment: Alignment.topCenter, child: const Icon(Icons.location_on, color: Palette.red, size: 44)),
                  ]),
                const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
              ],
            ),
            PositionedDirectional(
              top: 10,
              start: 10,
              end: 10,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _warn ? Palette.red : Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(12)),
                  child: Text(_warn ? t.placeNeedPick : t.placeTapHint, style: TextStyle(fontWeight: FontWeight.w700, color: _warn ? Colors.white : Colors.black87)),
                ),
              ),
            ),
            PositionedDirectional(
              bottom: 12,
              end: 12,
              child: FloatingActionButton.small(heroTag: 'mine', tooltip: t.placeMyLocation, onPressed: _mine, child: const Icon(Icons.my_location_rounded)),
            ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: _name, decoration: InputDecoration(hintText: t.tripMeetLabel)),
              const SizedBox(height: 10),
              Btn(t.placeSaveShare, icon: Icons.send_rounded, expand: true, onPressed: () => _done(true)),
              const SizedBox(height: 8),
              Btn(t.placeSaveOnly, kind: BtnKind.ghost, expand: true, onPressed: () => _done(false)),
            ]),
          ),
        ),
      ]),
    );
  }
}
