import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../backend/backend.dart';
import '../core/avatars.dart';
import '../core/logic.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

extension L10nX on BuildContext {
  L10n get t => L10n.of(this);
}

void toast(BuildContext context, String msg) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2800)));
}

/// Parses a whole number typed with Latin or Arabic-Indic digits (the Arabic
/// iPhone keypad types ١٢٣).
int? parseDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩', fa = '۰۱۲۳۴۵۶۷۸۹';
  final latin = s.trim().split('').map((c) {
    final i = ar.indexOf(c), j = fa.indexOf(c);
    return i >= 0 ? '$i' : (j >= 0 ? '$j' : c);
  }).join();
  return int.tryParse(latin);
}

String errorText(L10n t, Object e) {
  if (e is! AppError) return t.errGenericCode(e.runtimeType.toString());
  return switch (e.code) {
    'bad-email' => t.errBadEmail,
    'setup-needed' => t.errSetupNeeded,
    'no-account-yet' => t.errNoAccountYet,
    'registered-as-member' => t.errRegisteredAsMember,
    'registered-as-admin' => t.errRegisteredAsAdmin,
    'not-invited' => t.errNotInvited,
    'not-admin-of-family' => t.errNotAdminOf('${e.details['familyName'] ?? ''}'),
    'bad-code' => t.errBadCode,
    'code-expired' => t.errCodeExpired,
    'too-many-attempts' => t.errTooManyAttempts,
    'rate-limited' => t.errRateLimited,
    'too-soon' => t.errTooSoon('${e.details['waitSeconds'] ?? 30}'),
    'already-registered' => t.errAlreadyRegistered,
    'email-taken' => t.errEmailTaken,
    'no-permission' => t.errNoPermission,
    'already-done' => t.errAlreadyDone,
    'already-decided' => t.errAlreadyDecided,
    'comp-over' => t.errCompOver,
    'already-entered' => t.errAlreadyEntered,
    'network' => t.errNetwork,
    'upload-failed' => t.errUpload,
    'owner-must-delete-family' => t.errOwnerMustDeleteFamily,
    'removed' => t.errRemoved,
    'bad-name-email' => t.errNameEmail,
    'too-short' => t.errFbShort,
    'bad-title' => t.errMissingTitle,
    'bad-number' => t.errBadNumber('${e.details['min'] ?? 1}', '${e.details['max'] ?? ''}'),
    'person-not-found' => t.errPersonNotFound,
    'unauthenticated' => t.errSession,
    'bad-login' => t.errBadLogin,
    'no-password' => t.errNoPassword,
    'weak-password' => t.errWeakPassword,
    'locked' => t.errLocked('${e.details['waitMinutes'] ?? 15}'),
    'prayer-over' => t.errPrayerOver,
    'avatar-locked' => t.errAvatarLocked,
    'bad-time' => t.errBadTime,
    // Unknown codes show the code (and the server's reason for internal errors) so a screenshot is enough to diagnose.
    _ => t.errGenericCode([e.code, if (e.details['reason'] is String) e.details['reason'] as String].join(' · ')),
  };
}

/// Runs a backend action and shows either [ok] or the mapped error as a toast.
Future<bool> run(BuildContext context, Future<void> Function() action, {String? ok}) async {
  try {
    await action();
    if (ok != null && context.mounted) toast(context, ok);
    return true;
  } catch (e) {
    if (context.mounted) toast(context, errorText(context.t, e));
    return false;
  }
}

/// Local clock time, e.g. "٤:٣٠ م".
String clockTime(BuildContext context, DateTime at) => MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(at.toLocal()));

String ago(L10n t, DateTime at, DateTime now) {
  final m = now.difference(at).inMinutes;
  if (m < 1) return t.now;
  if (m < 60) return t.minutesAgo('$m');
  final h = m ~/ 60;
  if (h < 24) return t.hoursAgo('$h');
  return '${at.day}/${at.month}/${at.year}';
}

String fmtDuration(Duration d) {
  final s = (d.inMilliseconds / 1000).ceil();
  final h = s ~/ 3600, m = s % 3600 ~/ 60, x = s % 60;
  String p(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${p(m)}:${p(x)}' : '$m:${p(x)}';
}

String roleLabel(L10n t, Role r) => switch (r) { Role.owner => t.roleOwner, Role.admin => t.roleAdmin, Role.member => t.roleMember };

String permLabel(L10n t, Perm p) => switch (p) {
      Perm.addMembers => t.permAddMembers,
      Perm.approve => t.permApprove,
      Perm.tasks => t.permTasks,
      Perm.report => t.permReport,
      Perm.comps => t.permComps,
      Perm.viewReports => t.permViewReports,
    };

// ------------------------------------------------------------------ avatars

/// A pointed arch, the frame of the portrait avatars (and of uploaded photos).
Path archPath(Size s) {
  final w = s.width, h = s.height, shoulder = h * .3;
  return Path()
    ..moveTo(0, h)
    ..lineTo(0, shoulder)
    ..quadraticBezierTo(0, shoulder * .35, w * .28, shoulder * .2)
    ..quadraticBezierTo(w * .44, shoulder * .12, w / 2, 0)
    ..quadraticBezierTo(w * .56, shoulder * .12, w * .72, shoulder * .2)
    ..quadraticBezierTo(w, shoulder * .35, w, shoulder)
    ..lineTo(w, h)
    ..close();
}

class _ArchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => archPath(size);
  @override
  bool shouldReclip(_ArchClipper old) => false;
}

class _ArchBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
      archPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .06
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF3D98B), Palette.sunDeep])
            .createShader(Offset.zero & size));
  @override
  bool shouldRepaint(_ArchBorder old) => false;
}

/// Width-to-height ratio of the portrait avatars.
const avatarAspect = .94;

/// A person's avatar: one of the gold-arch portraits, their own photo in the
/// same arch, or (older accounts) a cartoon drawn in a circle. [size] is the width.
class AvatarView extends StatelessWidget {
  const AvatarView(this.avatar, {super.key, this.size = 44, this.photo});
  AvatarView.of(Person p, {super.key, this.size = 44})
      : avatar = p.avatar,
        photo = p.photo;
  final String avatar;
  final String? photo;
  final double size;

  static final _photos = <String, MemoryImage>{};

  @override
  Widget build(BuildContext context) {
    final h = size / avatarAspect;
    if (avatar == photoAvatar && photo != null) {
      final img = _photos.putIfAbsent(photo!, () => MemoryImage(base64Decode(photo!)));
      return SizedBox(
        width: size,
        height: h,
        child: CustomPaint(
          foregroundPainter: _ArchBorder(),
          child: ClipPath(clipper: _ArchClipper(), child: Image(image: img, fit: BoxFit.cover, gaplessPlayback: true)),
        ),
      );
    }
    if (isPortrait(avatar)) {
      return SizedBox(
        width: size,
        height: h,
        child: Image.asset('assets/avatars/$avatar.webp', fit: BoxFit.contain, cacheWidth: (size * 3).round(), excludeFromSemantics: true),
      );
    }
    return SizedBox(
      width: size,
      height: h,
      child: Center(child: ClipOval(child: SizedBox.square(dimension: size, child: SvgPicture.string(avatarSvg(avatar), fit: BoxFit.cover)))),
    );
  }
}

/// Who may change whose avatar (a member's own lock is checked in the picker).
bool canEditAvatar(Person me, Person target) =>
    me.id == target.id || me.role == Role.owner || (target.role == Role.member && can(me, Perm.addMembers));

/// Avatar that opens the picker when tapped by someone allowed to change it.
class EditableAvatar extends StatelessWidget {
  const EditableAvatar({super.key, required this.person, required this.canEdit, required this.onTap, this.size = 44});
  final Person person;
  final bool canEdit;
  final VoidCallback onTap;
  final double size;
  @override
  Widget build(BuildContext context) {
    if (!canEdit) return AvatarView.of(person, size: size);
    return Semantics(
      button: true,
      label: context.t.changeAvatarOf(person.name),
      child: GestureDetector(onTap: onTap, child: AvatarView.of(person, size: size)),
    );
  }
}

/// Family member in the header: their arch portrait, sized so five fit on a
/// line. No name on it (it is in the tooltip and screen-reader label).
/// Invited (not yet linked) members are dimmed.
class NameRing extends StatelessWidget {
  const NameRing({super.key, required this.person, this.size = 56, this.onTap});
  final Person person;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inv = !person.active;
    final label = inv ? '${person.name} (${context.t.pendingVerification})' : person.name;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        image: true,
        button: onTap != null,
        child: GestureDetector(
          onTap: onTap,
          child: Opacity(opacity: inv ? .5 : 1, child: AvatarView.of(person, size: size)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ building blocks

class H2 extends StatelessWidget {
  const H2(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: heading(context)),
      );
}

class H3 extends StatelessWidget {
  const H3(this.text, {super.key, this.leading});
  final String text;
  final Widget? leading;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Flexible(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ]),
      );
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.align});
  final String text;
  final TextAlign? align;
  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: align, style: TextStyle(color: context.pal.muted, fontSize: 14, height: 1.5));
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.emoji, this.text, {super.key});
  final String emoji, text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(height: 4),
          Muted(text, align: TextAlign.center),
        ]),
      );
}

/// Bordered list row (.row in the prototype).
class RowCard extends StatelessWidget {
  const RowCard({super.key, required this.children, this.faded = false, this.margin = const EdgeInsets.only(bottom: 8)});
  final List<Widget> children;
  final bool faded;
  final EdgeInsets margin;
  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.pal.card,
          border: Border.all(color: context.pal.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: _layout(),
      );

  /// Children after the [Expanded] (status tags, buttons) sit on the same line
  /// while the text fits beside them, and drop to their own line otherwise, so
  /// narrow screens or large fonts never squeeze the text to one letter wide.
  Widget _layout() {
    final i = children.indexWhere((w) => w is Expanded);
    if (i < 0 || i == children.length - 1) return Row(children: _spaced(children));
    final main = children[i] as Expanded;
    return OverflowBar(
      alignment: MainAxisAlignment.spaceBetween,
      overflowAlignment: OverflowBarAlignment.end,
      spacing: 12,
      overflowSpacing: 8,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: _spaced([...children.take(i), Flexible(child: main.child)])),
        Row(mainAxisSize: MainAxisSize.min, children: _spaced(children.skip(i + 1).toList())),
      ],
    );
  }

  static List<Widget> _spaced(List<Widget> c) => [
        for (var i = 0; i < c.length; i++) ...[if (i > 0) const SizedBox(width: 12), c[i]],
      ];
}

class TitleSub extends StatelessWidget {
  const TitleSub(this.title, this.sub, {super.key, this.done = false, this.subLtr = false});
  final String title;
  final String? sub;
  final bool done;
  final bool subLtr;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: done ? .6 : 1,
            child: Text(title,
                style: TextStyle(fontWeight: FontWeight.w700, decoration: done ? TextDecoration.lineThrough : null)),
          ),
          if (sub != null)
            Text(sub!,
                textDirection: subLtr ? TextDirection.ltr : null,
                textAlign: subLtr ? TextAlign.right : null,
                style: TextStyle(color: context.pal.muted, fontSize: 14)),
        ],
      );
}

class Pts extends StatelessWidget {
  const Pts(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(color: Palette.sun, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.onSun, fontSize: 14)),
      );
}

enum Tone { wait, ok, off }

class StateTag extends StatelessWidget {
  const StateTag(this.text, this.tone, {super.key});
  final String text;
  final Tone tone;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final (bg, fg) = switch (tone) { Tone.wait => (p.wait, p.waitInk), Tone.ok => (p.mintBg, Palette.mint), Tone.off => (p.bg, p.muted) };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class Badge2 extends StatelessWidget {
  const Badge2(this.n, {super.key});
  final int n;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 20),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Palette.red, borderRadius: BorderRadius.circular(10)),
        child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

enum BtnKind { main, sun, ok, no, ghost }

/// Button that answers the tap at once: an async action shows a spinner and
/// blocks repeat taps until the server replies.
class Btn extends StatefulWidget {
  const Btn(this.label, {super.key, required this.onPressed, this.kind = BtnKind.main, this.small = false, this.expand = false, this.semantic, this.icon});
  final String label;
  final FutureOr<void> Function()? onPressed;
  final BtnKind kind;
  final bool small;
  final bool expand;
  final String? semantic;
  final IconData? icon;

  @override
  State<Btn> createState() => _BtnState();
}

class _BtnState extends State<Btn> {
  var _busy = false;

  Future<void> _tap() async {
    final r = widget.onPressed!();
    if (r is! Future) return;
    setState(() => _busy = true);
    try {
      await r;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal, w = widget;
    final (bg, fg) = switch (w.kind) {
      BtnKind.main => (Palette.brand, Colors.white),
      BtnKind.sun => (Palette.sun, Palette.onSun),
      BtnKind.ok => (Palette.mint, Colors.white),
      BtnKind.no => (p.redBg, Palette.red),
      BtnKind.ghost => (p.bg, p.ink),
    };
    final text = Text(w.label, semanticsLabel: w.semantic, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false);
    final b = FilledButton(
      onPressed: w.onPressed == null || _busy ? null : _tap,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: _busy ? .8 : .45),
        disabledForegroundColor: fg.withValues(alpha: .7),
        padding: w.small ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: w.small ? const Size(0, 34) : const Size(0, 46),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(w.small ? 10 : 12)),
        textStyle: TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700, fontSize: w.small ? 13 : 16),
      ),
      child: _busy
          ? SizedBox.square(dimension: w.small ? 16 : 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
          : w.icon == null
              ? text
              : Row(mainAxisSize: MainAxisSize.min, children: [Icon(w.icon, size: w.small ? 16 : 20), const SizedBox(width: 6), Flexible(child: text)]),
    );
    return w.expand ? SizedBox(width: double.infinity, child: b) : b;
  }
}

class XButton extends StatefulWidget {
  const XButton({super.key, required this.onPressed, required this.tooltip, this.icon = Icons.close, this.color});
  final FutureOr<void> Function() onPressed;
  final String tooltip;
  final IconData icon;
  final Color? color;
  @override
  State<XButton> createState() => _XButtonState();
}

class _XButtonState extends State<XButton> {
  var _busy = false;
  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: _busy
            ? null
            : () async {
                final r = widget.onPressed();
                if (r is! Future) return;
                setState(() => _busy = true);
                try {
                  await r;
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        tooltip: widget.tooltip,
        visualDensity: VisualDensity.compact,
        icon: _busy
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(widget.icon, size: 20, color: widget.color ?? context.pal.muted),
      );
}

/// Beige form box (.form).
class FormBox extends StatelessWidget {
  const FormBox({super.key, required this.children, this.margin = const EdgeInsets.only(top: 12, bottom: 14)});
  final List<Widget> children;
  final EdgeInsets margin;
  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.pal.bg, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 8), children[i]],
        ]),
      );
}

class Two extends StatelessWidget {
  const Two(this.a, this.b, {super.key});
  final Widget a, b;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: a),
        const SizedBox(width: 8),
        Expanded(child: b),
      ]);
}

class Labeled extends StatelessWidget {
  const Labeled(this.label, this.child, {super.key});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: TextStyle(color: context.pal.muted, fontSize: 14)),
        const SizedBox(height: 4),
        child,
      ]);
}

/// Simple dropdown styled like the prototype's <select>.
class Select<T> extends StatelessWidget {
  const Select({super.key, required this.value, required this.items, required this.onChanged, this.label});
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final String? label;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(semanticCounterText: label),
        items: [for (final (v, l) in items) DropdownMenuItem(value: v, child: Text(l, overflow: TextOverflow.ellipsis))],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );
}

/// Segmented tabs (.tabs).
class SegTabs<T> extends StatelessWidget {
  const SegTabs({super.key, required this.tabs, required this.value, required this.onChanged});
  final List<(T, String, int)> tabs;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (final (v, label, badge) in tabs)
          Expanded(
            child: Semantics(
              selected: v == value,
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                  decoration: BoxDecoration(
                    color: v == value ? p.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: v == value ? const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))] : null,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(
                      child: Text(label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: v == value ? FontWeight.w700 : FontWeight.w500,
                            color: v == value ? p.brandInk : p.muted,
                          )),
                    ),
                    if (badge > 0) ...[const SizedBox(width: 4), Badge2(badge)],
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key});
  final double value;
  @override
  Widget build(BuildContext context) => Container(
        height: 10,
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(color: context.pal.bg, borderRadius: BorderRadius.circular(5)),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 400),
            widthFactor: value.clamp(0, 1),
            child: Container(decoration: BoxDecoration(color: Palette.mint, borderRadius: BorderRadius.circular(5))),
          ),
        ),
      );
}

/// Card with a border (.card).
class OutlineCard extends StatelessWidget {
  const OutlineCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: context.pal.line), borderRadius: BorderRadius.circular(16)),
        child: child,
      );
}

/// Beige tier row (.tier).
class TierBox extends StatelessWidget {
  const TierBox({super.key, required this.emoji, required this.child, this.margin = const EdgeInsets.only(bottom: 8)});
  final String emoji;
  final Widget child;
  final EdgeInsets margin;
  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.pal.bg, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(child: child),
        ]),
      );
}

class EmojiCircle extends StatelessWidget {
  const EmojiCircle(this.emoji, {super.key});
  final String emoji;
  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: context.pal.bg, shape: BoxShape.circle),
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      );
}

class MedalText extends StatelessWidget {
  const MedalText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 28, child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)));
}

class ErrBox extends StatelessWidget {
  const ErrBox(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: context.pal.redBg, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(color: Palette.red, fontSize: 14)),
      );
}

class NoteBox extends StatelessWidget {
  const NoteBox(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: context.pal.wait, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(color: context.pal.waitInk, fontSize: 13)),
      );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: context.pal.mintBg, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Palette.mint)),
      );
}

/// Small avatar next to a name (.mini).
class MiniName extends StatelessWidget {
  const MiniName(this.person, {super.key, this.style});
  final Person person;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        AvatarView.of(person, size: 24),
        const SizedBox(width: 6),
        Flexible(child: Text(person.name, style: style, overflow: TextOverflow.ellipsis)),
      ]);
}

Future<bool> confirm(BuildContext context, String message, {String? ok, bool danger = false}) async {
  final t = context.t;
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok ?? t.remove, style: TextStyle(color: danger ? Palette.red : null, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Alerts addressed to the signed-in person, newest first. Timed alerts that
/// ended move to a dimmed "ended" list (the server deletes them a day later).
class NoticeList extends StatelessWidget {
  const NoticeList(this.notices, {super.key, required this.now});
  final List<Notice> notices;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.t, ns = notices;
    if (ns.isEmpty) return EmptyState('🔔', t.noNotices);
    final active = ns.where((n) => n.activeAt(now)).toList(), ended = ns.where((n) => !n.activeAt(now)).take(5).toList();
    Widget card(Notice n) => n.kind == 'prize' ? PrizeCard(n, now: now) : OutlineCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700))),
              Muted(ago(t, n.createdAt, now)),
            ]),
            const SizedBox(height: 6),
            Text(n.body),
            if (n.expiresAt != null) ...[
              const SizedBox(height: 6),
              n.activeAt(now) ? StateTag(t.endsAt(clockTime(context, n.expiresAt!)), Tone.wait) : StateTag(t.alertEnded, Tone.off),
            ],
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (active.isEmpty) EmptyState('🔔', t.noNotices),
      for (final n in active) card(n),
      if (ended.isNotEmpty) ...[
        H3(t.endedAlerts),
        for (final n in ended) Opacity(opacity: .55, child: card(n)),
      ],
    ]);
  }
}

/// Congratulation card sent to the whole family when a prize is won.
class PrizeCard extends StatelessWidget {
  const PrizeCard(this.n, {super.key, required this.now});
  final Notice n;
  final DateTime now;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFFF7E3A8), Palette.sun, Palette.sunDeep]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x33B8893A), blurRadius: 14, offset: Offset(0, 5))],
        ),
        child: Column(children: [
          const Text('🎉🏆🎉', style: TextStyle(fontSize: 30)),
          const SizedBox(height: 6),
          Text(n.title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: headFont, fontSize: 22, fontWeight: FontWeight.w800, color: Palette.onSun)),
          const SizedBox(height: 6),
          Text(n.body, textAlign: TextAlign.center, style: const TextStyle(color: Palette.onSun, fontSize: 15, height: 1.5)),
          const SizedBox(height: 6),
          Text(ago(context.t, n.createdAt, now), style: const TextStyle(color: Color(0xAA2B2410), fontSize: 12)),
        ]),
      );
}

String repeatLabel(L10n t, Period p) => switch (p) {
      Period.daily => t.dailyF,
      Period.weekly => t.weeklyF,
      Period.monthly => t.monthlyF,
      Period.yearly => t.yearlyF,
      Period.once => t.onceF,
    };

String spanLabel(L10n t, Span s) => switch (s) { Span.daily => t.today, Span.weekly => t.thisWeek, Span.monthly => t.thisMonth, Span.yearly => t.thisYear };

List<(Span, String, int)> spanTabs(L10n t) => [for (final s in Span.values) (s, spanLabel(t, s), 0)];

/// Stat box with a gold outline (dashboard and reports).
class StatBox extends StatelessWidget {
  const StatBox(this.value, this.label, {super.key, this.color});
  final String value, label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: context.pal.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.sun.withValues(alpha: .7)),
        ),
        child: Column(children: [
          FittedBox(child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color ?? context.pal.brandInk))),
          Text(label, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 12.5, color: context.pal.muted, height: 1.2)),
        ]),
      );
}

/// A row of [StatBox]es sharing the width.
class StatRow extends StatelessWidget {
  const StatRow(this.items, {super.key});
  final List<StatBox> items;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: items[i])],
      ]);
}
