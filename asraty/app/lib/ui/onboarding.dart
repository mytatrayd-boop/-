import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/backend.dart';
import '../core/models.dart';
import 'common.dart';
import 'providers.dart';
import 'theme.dart';

enum _Step { choose, email, code }

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Last email that signed in on this device, to pre-fill the next sign-in.
const _lastEmailKey = 'lastEmail';

class Onboarding extends ConsumerStatefulWidget {
  const Onboarding({super.key});
  @override
  ConsumerState<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<Onboarding> {
  var _step = _Step.choose;
  var _role = Role.member;
  String? _err;
  var _busy = false;
  // Admin: sign in to an existing family (email only) or create a new one.
  var _newFamily = false;
  final _fam = TextEditingController(), _name = TextEditingController(), _email = TextEditingController(), _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _email.text = ref.read(prefsProvider).getString(_lastEmailKey) ?? '';
    // A returning device logs in; a fresh install most likely creates a family.
    _newFamily = _email.text.isEmpty;
  }

  @override
  void dispose() {
    for (final c in [_fam, _name, _email, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Backend get _b => ref.read(backendProvider);

  Future<void> _guard(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await f();
    } catch (e) {
      if (mounted) setState(() => _err = errorText(context.t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestCode({bool resend = false}) => _guard(() async {
        final t = context.t;
        final email = _email.text.trim().toLowerCase();
        if (!_emailRe.hasMatch(email)) throw AppError('bad-email');
        final setup = _role == Role.admin && _newFamily;
        final fam = setup ? _fam.text.trim() : '', name = setup ? _name.text.trim() : '';
        final bool sent;
        try {
          sent = await _b.requestCode(
            email: email,
            role: _role,
            familyName: fam.isEmpty ? null : fam,
            name: name.isEmpty ? null : name,
            resend: resend,
          );
        } on AppError catch (e) {
          // No account for this email yet: offer to create the family instead.
          if (e.code == 'setup-needed' && !setup && mounted) {
            setState(() => _newFamily = true);
            throw AppError('no-account-yet');
          }
          rethrow;
        }
        if (!mounted) return;
        toast(context, sent ? t.codeSent(email) : t.codeAlreadySent);
        setState(() => _step = _Step.code);
      });

  Future<void> _verify() => _guard(() async {
        final t = context.t;
        final email = _email.text.trim().toLowerCase();
        final r = await _b.verifyCode(email: email, code: _code.text.trim());
        if (!_b.isDemo) await ref.read(prefsProvider).setString(_lastEmailKey, email);
        if (!mounted) return;
        toast(context, r.first ? t.linkedTo(r.familyName) : t.hello(r.name.isEmpty ? r.familyName : r.name));
      });

  /// Pastes a 6-digit code copied from the email and verifies it right away.
  Future<void> _paste() async {
    final t = context.t;
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    final m = RegExp(r'(?<!\d)\d{6}(?!\d)').firstMatch(text);
    if (!mounted) return;
    if (m == null) return toast(context, t.noCodeInClipboard);
    _code.text = m[0]!;
    await _verify();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final err = _err == null ? null : ErrBox(_err!);
    switch (_step) {
      case _Step.choose:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          H2(t.welcome),
          Muted(t.howUse),
          _Choice(emoji: '👨‍👩‍👧', title: t.chooseAdmin, sub: t.chooseAdminSub, onTap: () => _go(Role.admin)),
          _Choice(emoji: '🧒', title: t.chooseMember, sub: t.chooseMemberSub, onTap: () => _go(Role.member)),
          const SizedBox(height: 18),
          Center(
            child: Btn(t.tryDemo, kind: BtnKind.ghost, onPressed: () {
              ref.read(backendProvider.notifier).startDemo();
              toast(context, t.demoWelcome);
            }),
          ),
          const SizedBox(height: 6),
          Muted(t.demoNote, align: TextAlign.center),
          const SizedBox(height: 14),
          NoteBox('🔐 ${t.stayLoggedIn}'),
        ]);
      case _Step.email:
        final demoNoFamily = _b.isDemo && _b.current.session == null;
        final admin = _role == Role.admin, setup = admin && _newFamily;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Back(() => setState(() {
                _step = _Step.choose;
                _err = null;
              })),
          H2(admin ? t.loginAdmin : t.loginMember),
          if (admin)
            SegTabs<bool>(
              tabs: [(false, t.adminHaveAccount, 0), (true, t.adminNewFamily, 0)],
              value: _newFamily,
              onChanged: (v) => setState(() {
                _newFamily = v;
                _err = null;
              }),
            ),
          Muted(setup ? t.hintSetup : admin ? t.hintAdminLogin : t.hintMember),
          FormBox(children: [
            if (setup) ...[
              TextField(controller: _fam, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: t.familyNameHint)),
              TextField(controller: _name, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: t.yourNameHint)),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              onSubmitted: (_) => _requestCode(),
              decoration: InputDecoration(hintText: t.emailHint, semanticCounterText: t.email),
            ),
            ?err,
            Btn(t.sendCode, onPressed: _busy ? null : _requestCode),
          ]),
          if (demoNoFamily) NoteBox(t.demoCodeNote),
        ]);
      case _Step.code:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Back(() => setState(() {
                _step = _Step.email;
                _err = null;
              })),
          H2(t.enterCode),
          Text.rich(TextSpan(style: TextStyle(color: context.pal.muted, fontSize: 14), children: [
            TextSpan(text: '${t.codeSentTo} '),
            TextSpan(text: _email.text.trim(), style: const TextStyle(fontWeight: FontWeight.w700)),
          ])),
          FormBox(children: [
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              onSubmitted: (_) => _verify(),
              // The sixth digit verifies right away.
              onChanged: (v) {
                if (v.length == 6 && !_busy) _verify();
              },
              decoration: InputDecoration(hintText: '••••••', counterText: '', semanticCounterText: t.codeFromEmail),
            ),
            ?err,
            Btn(t.verify, onPressed: _busy ? null : _verify),
            Btn('📋 ${t.pasteCode}', kind: BtnKind.ghost, onPressed: _busy ? null : _paste),
            Btn(t.resendCode, kind: BtnKind.ghost, onPressed: _busy ? null : () => _requestCode(resend: true)),
          ]),
          if (_b.isDemo) NoteBox(t.demoCodeNote),
        ]);
    }
  }

  void _go(Role r) => setState(() {
        _role = r;
        _step = _Step.email;
        _err = null;
      });
}

class _Back extends StatelessWidget {
  const _Back(this.onTap);
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4), foregroundColor: context.pal.brandInk),
          child: Text(context.t.back, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.emoji, required this.title, required this.sub, required this.onTap});
  final String emoji, title, sub;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Material(
          color: context.pal.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: context.pal.line, width: 2)),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Muted(sub),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}
