import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../backend/backend.dart';
import '../core/models.dart';
import '../backend/access.dart';
import 'common.dart';
import 'paywall.dart';
import 'providers.dart';
import 'theme.dart';

/// login: email + password · register: account type, (family), email, password,
/// then the emailed code · reset: email + new password, then the code.
enum _Step { login, register, reset, code }

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Last email that signed in on this device, to pre-fill the next sign-in.
const _lastEmailKey = 'lastEmail';

/// "Remember me": email → password, in the phone's keychain / keystore.
class SavedLogins {
  static const _key = 'savedLogins';
  static const _store = FlutterSecureStorage();

  static Future<Map<String, String>> read() async {
    try {
      final raw = await _store.read(key: _key);
      return raw == null ? {} : Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(String email, String? password) async {
    try {
      final m = await read();
      password == null ? m.remove(email) : m[email] = password;
      await _store.write(key: _key, value: jsonEncode(m));
    } catch (_) {}
  }
}

class Onboarding extends ConsumerStatefulWidget {
  const Onboarding({super.key});
  @override
  ConsumerState<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<Onboarding> {
  var _step = _Step.login;
  // The step that sent the code (register or reset), to go back to.
  var _codeFrom = _Step.register;
  var _role = Role.admin;
  String? _err;
  var _busy = false;
  var _remember = true;
  var _show = false;
  Map<String, String> _saved = {};
  final _fam = TextEditingController(), _name = TextEditingController(), _email = TextEditingController();
  final _pass = TextEditingController(), _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _email.text = ref.read(prefsProvider).getString(_lastEmailKey) ?? '';
    _email.addListener(_fill);
    _pass.addListener(() => setState(() {}));
    SavedLogins.read().then((m) {
      if (!mounted) return;
      _saved = m;
      _fill();
    });
  }

  /// Typing a remembered email brings back its password, and the sign-in button wakes up.
  void _fill() {
    final p = _saved[_email.text.trim().toLowerCase()];
    if (_step == _Step.login && p != null && _pass.text.isEmpty) _pass.text = p;
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_fam, _name, _email, _pass, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Backend get _b => ref.read(backendProvider);
  String get _mail => _email.text.trim().toLowerCase();
  bool get _canLogin => _emailRe.hasMatch(_mail) && _pass.text.length >= 6;

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

  Future<void> _signedIn(VerifyResult r) async {
    final t = context.t;
    if (!_b.isDemo) {
      await ref.read(prefsProvider).setString(_lastEmailKey, _mail);
      await SavedLogins.save(_mail, _remember ? _pass.text : null);
    }
    TextInput.finishAutofillContext();
    if (!mounted) return;
    toast(context, r.first ? t.linkedTo(r.familyName) : t.hello(r.name.isEmpty ? r.familyName : r.name));
  }

  Future<void> _login() => _guard(() async {
        final r = await _b.login(email: _mail, password: _pass.text);
        await _signedIn(r);
      });

  /// Sign-up or reset: the code proves the email, then the password is set.
  Future<void> _requestCode({bool resend = false}) => _guard(() async {
        final t = context.t;
        if (!_emailRe.hasMatch(_mail)) throw AppError('bad-email');
        if (_pass.text.length < 6) throw AppError('weak-password');
        final setup = _step == _Step.register && _role == Role.admin;
        final fam = setup ? _fam.text.trim() : '', name = setup ? _name.text.trim() : '';
        Future<bool> ask(Role r) => _b.requestCode(
              email: _mail, role: r, password: _pass.text, resend: resend,
              familyName: fam.isEmpty ? null : fam, name: name.isEmpty ? null : name);
        bool sent;
        if (_step == _Step.reset || (_step == _Step.code && _codeFrom == _Step.reset)) {
          // Reset: the account type is whatever the email was registered as.
          try {
            sent = await ask(Role.member);
          } on AppError catch (e) {
            if (e.code != 'registered-as-admin') rethrow;
            sent = await ask(Role.admin);
          }
        } else {
          sent = await ask(_role);
        }
        if (!mounted) return;
        toast(context, sent ? t.codeSent(_mail) : t.codeAlreadySent);
        setState(() {
          if (_step != _Step.code) _codeFrom = _step;
          _step = _Step.code;
        });
      });

  Future<void> _verify() => _guard(() async {
        final r = await _b.verifyCode(email: _mail, code: _code.text.trim());
        await _signedIn(r);
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

  void _go(_Step s) => setState(() {
        _step = s;
        _err = null;
        if (s != _Step.login) _pass.clear();
      });

  Widget _emailField() => TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        textDirection: TextDirection.ltr,
        autocorrect: false,
        textInputAction: TextInputAction.next,
        // Offers the email accounts saved on the phone.
        autofillHints: const [AutofillHints.email, AutofillHints.username],
        decoration: InputDecoration(hintText: context.t.emailHint, semanticCounterText: context.t.email, prefixIcon: const Icon(Icons.alternate_email_rounded)),
      );

  Widget _passField({required bool newPassword, required VoidCallback onSubmit}) => TextField(
        controller: _pass,
        obscureText: !_show,
        textDirection: TextDirection.ltr,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: [newPassword ? AutofillHints.newPassword : AutofillHints.password],
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          hintText: context.t.passwordHint,
          semanticCounterText: context.t.password,
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: context.t.showPassword,
            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _show = !_show),
          ),
        ),
      );

  Widget _link(String text, VoidCallback onTap) => Center(
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: context.pal.brandInk),
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final err = _err == null ? null : ErrBox(_err!);
    final demo = _b.isDemo;
    ref.watch(accessProvider);
    final activated = Access.savedCode(ref.read(prefsProvider)) != null;
    switch (_step) {
      case _Step.login:
        return AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            H2(t.welcome),
            Muted(t.loginTitle),
            FormBox(children: [
              _emailField(),
              _passField(newPassword: false, onSubmit: () => _canLogin ? _login() : null),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _remember = !_remember),
                child: Row(children: [
                  Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? false), visualDensity: VisualDensity.compact),
                  Expanded(child: Text(t.rememberMe, style: const TextStyle(fontSize: 14))),
                ]),
              ),
              ?err,
              Btn(t.loginBtn, onPressed: _busy || !_canLogin ? null : _login),
            ]),
            _link(t.forgotPassword, () => _go(_Step.reset)),
            Btn(t.noAccountRegister, kind: BtnKind.ghost, onPressed: () => _go(_Step.register)),
            const SizedBox(height: 6),
            if (activated) NoteBox(t.activatedNote) else _link('🎟️ ${t.useCode}', () => showActivation(context, ref)),
            const SizedBox(height: 18),
            Center(
              child: Btn(t.tryDemo, kind: BtnKind.sun, onPressed: () {
                ref.read(backendProvider.notifier).startDemo();
                toast(context, t.demoWelcome);
              }),
            ),
            const SizedBox(height: 6),
            Muted(t.demoNote, align: TextAlign.center),
            if (demo) NoteBox(t.demoLoginNote),
            const SizedBox(height: 10),
            NoteBox('🔐 ${t.stayLoggedIn}'),
          ]),
        );
      case _Step.register:
      case _Step.reset:
        final register = _step == _Step.register;
        final setup = register && _role == Role.admin;
        return AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Back(() => _go(_Step.login)),
            H2(register ? t.registerTitle : t.resetTitle),
            Muted(register ? t.registerSub : t.resetSub),
            FormBox(children: [
              if (register)
                Labeled(
                  t.accountType,
                  Select<Role>(
                    value: _role,
                    label: t.accountType,
                    items: [(Role.admin, t.chooseAdmin), (Role.member, t.chooseMember)],
                    onChanged: (v) => setState(() {
                      _role = v;
                      _err = null;
                    }),
                  ),
                ),
              if (setup) ...[
                TextField(controller: _fam, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: t.familyNameHint)),
                TextField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: InputDecoration(hintText: t.yourNameHint)),
              ],
              _emailField(),
              _passField(newPassword: true, onSubmit: _requestCode),
              ?err,
              Btn(register ? t.registerBtn : t.sendCode, onPressed: _busy ? null : _requestCode),
            ]),
            if (register) _link(t.haveAccountLogin, () => _go(_Step.login)),
            if (demo) NoteBox(t.demoCodeNote),
          ]),
        );
      case _Step.code:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Back(() => setState(() {
                _step = _codeFrom;
                _err = null;
              })),
          H2(t.enterCode),
          Text.rich(TextSpan(style: TextStyle(color: context.pal.muted, fontSize: 14), children: [
            TextSpan(text: '${t.codeSentTo} '),
            TextSpan(text: _mail, style: const TextStyle(fontWeight: FontWeight.w700)),
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
          if (demo) NoteBox(t.demoCodeNote),
        ]);
    }
  }
}

class _Back extends StatelessWidget {
  const _Back(this.onTap);
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: onTap,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6), foregroundColor: context.pal.brandInk),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
          label: Text(context.t.back, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}
