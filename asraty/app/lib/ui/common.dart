import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../backend/backend.dart';
import '../core/avatars.dart';
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

String errorText(L10n t, Object e) {
  if (e is! AppError) return t.errGeneric;
  return switch (e.code) {
    'bad-email' => t.errBadEmail,
    'setup-needed' => t.errSetupNeeded,
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
    _ => t.errGeneric,
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

class AvatarView extends StatelessWidget {
  const AvatarView(this.avatar, {super.key, this.size = 44});
  final String avatar;
  final double size;
  @override
  Widget build(BuildContext context) => ClipOval(
        child: SizedBox.square(dimension: size, child: SvgPicture.string(avatarSvg(avatar), fit: BoxFit.cover)),
      );
}

/// Avatar that opens the picker when the viewer may change it (the ✎ badge).
class EditableAvatar extends StatelessWidget {
  const EditableAvatar({super.key, required this.person, required this.canEdit, required this.onTap, this.size = 44});
  final Person person;
  final bool canEdit;
  final VoidCallback onTap;
  final double size;
  @override
  Widget build(BuildContext context) {
    if (!canEdit) return AvatarView(person.avatar, size: size);
    return Semantics(
      button: true,
      label: context.t.changeAvatarOf(person.name),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          AvatarView(person.avatar, size: size),
          PositionedDirectional(
            bottom: -3,
            start: -3,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.pal.card,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
              child: Icon(Icons.edit, size: 12, color: context.pal.ink),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Gold ring with the avatar inside and the name written along the top arc.
class NameRing extends StatelessWidget {
  const NameRing({super.key, required this.person, this.size = 80});
  final Person person;
  final double size;
  @override
  Widget build(BuildContext context) {
    final inv = !person.active;
    return Tooltip(
      message: inv ? '${person.name} (${context.t.pendingVerification})' : person.name,
      child: Opacity(
        opacity: inv ? .55 : 1,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(person.name, inv, Directionality.of(context)),
            child: Center(
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: AvatarView(person.avatar, size: size * .57),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.name, this.dashed, this.dir);
  final String name;
  final bool dashed;
  final TextDirection dir;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100; // painter works in the prototype's 100x100 viewBox
    final c = Offset(50 * k, 50 * k);
    canvas.drawCircle(c, 48 * k, Paint()..color = const Color(0x21FFFFFF));
    final stroke = Paint()
      ..color = Palette.sun
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * k;
    if (dashed) {
      const dash = 4.0, gap = 3.0, r = 48.0;
      final step = (dash + gap) / r;
      for (var a = 0.0; a < 2 * math.pi; a += step) {
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * k), a, dash / r, false, stroke);
      }
    } else {
      canvas.drawCircle(c, 48 * k, stroke);
    }

    // Name on the arc: lay the text out once (so Arabic letters stay joined),
    // then draw it in thin vertical slices rotated along the circle.
    final fs = math.min(11.5, 108 / math.max(1, name.length * .62)) * k;
    final tp = TextPainter(
      text: TextSpan(text: name, style: TextStyle(fontFamily: bodyFont, fontSize: fs, fontWeight: FontWeight.w700, color: Colors.white)),
      textDirection: dir,
    )..layout();
    const r = 39.0;
    final radius = r * k;
    final w = tp.width, h = tp.height;
    const slice = 1.0;
    for (var x = 0.0; x < w; x += slice) {
      final theta = (x + slice / 2 - w / 2) / radius;
      final p = c + Offset(math.sin(theta), -math.cos(theta)) * radius;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(theta);
      canvas.clipRect(Rect.fromLTWH(-slice / 2 - .3, -h, slice + .6, h * 2));
      tp.paint(canvas, Offset(-x - slice / 2, -h / 2));
      canvas.restore();
    }

    // ★ under the ring (drawn as a path so it never depends on a symbol font).
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final rr = (i.isEven ? 4.2 : 1.8) * k;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(50 * k + rr * math.cos(a), 92 * k + rr * math.sin(a));
      i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(star..close(), Paint()..color = Palette.sun);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.name != name || old.dashed != dashed;
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
        child: Row(children: _spaced(children)),
      );

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

class Btn extends StatelessWidget {
  const Btn(this.label, {super.key, required this.onPressed, this.kind = BtnKind.main, this.small = false, this.expand = false, this.semantic});
  final String label;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final bool small;
  final bool expand;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final (bg, fg) = switch (kind) {
      BtnKind.main => (Palette.brand, Colors.white),
      BtnKind.sun => (Palette.sun, Palette.onSun),
      BtnKind.ok => (Palette.mint, Colors.white),
      BtnKind.no => (p.redBg, Palette.red),
      BtnKind.ghost => (p.bg, p.ink),
    };
    final b = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: .45),
        disabledForegroundColor: fg.withValues(alpha: .7),
        padding: small ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: small ? const Size(0, 32) : const Size(0, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(small ? 10 : 12)),
        textStyle: TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700, fontSize: small ? 13 : 16),
      ),
      child: Text(label, semanticsLabel: semantic),
    );
    return expand ? SizedBox(width: double.infinity, child: b) : b;
  }
}

class XButton extends StatelessWidget {
  const XButton({super.key, required this.onPressed, required this.tooltip, this.icon = Icons.close});
  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;
  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 20, color: context.pal.muted),
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
        AvatarView(person.avatar, size: 26),
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
