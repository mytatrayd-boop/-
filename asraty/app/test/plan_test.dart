import 'package:asraty/backend/access.dart';
import 'package:asraty/backend/backend.dart';
import 'package:asraty/backend/demo_backend.dart';
import 'package:asraty/core/logic.dart';
import 'package:asraty/core/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FamilySnapshot snap(FamilyPlan? plan) => FamilySnapshot(
    familyName: 'x', people: [], tasks: [], completions: [], competitions: [], notices: [], daily: {}, weekly: {}, plan: plan);

void main() {
  final now = DateTime.utc(2026, 12, 1);

  test('member limit: five free, a subscription tier raises it, an ended one falls back', () {
    expect(snap(null).memberLimitAt(now), 5);
    expect(snap(FamilyPlan(source: 'apple', tier: 10, until: now.add(const Duration(days: 3)))).memberLimitAt(now), 10);
    expect(snap(FamilyPlan(source: 'apple', tier: 20, until: now.add(const Duration(days: 3)))).memberLimitAt(now), 20);
    expect(snap(FamilyPlan(source: 'apple', tier: 20, until: now.subtract(const Duration(days: 1)))).memberLimitAt(now), 5, reason: 'ended');
    expect(snap(const FamilyPlan(source: 'legacy', tier: 5)).memberLimitAt(now), 5);
  });

  test('who may use the app: only the owner is gated; a code or an active plan opens it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Access.debugGated = true;
    addTearDown(() => Access.debugGated = null);
    expect(Access.ownerAllowed(prefs, null, now), isFalse, reason: 'no code, no plan: paywall');
    expect(Access.ownerAllowed(prefs, const FamilyPlan(source: 'legacy', tier: 5), now), isTrue, reason: 'old families keep using the app');
    expect(Access.ownerAllowed(prefs, FamilyPlan(source: 'apple', tier: 5, until: now.add(const Duration(days: 1))), now), isTrue);
    expect(Access.ownerAllowed(prefs, FamilyPlan(source: 'apple', tier: 5, until: now.subtract(const Duration(days: 1))), now), isFalse, reason: 'subscription ended');
    await Access.saveCode(prefs, 'ASR-AAAA-BBBB');
    expect(Access.ownerAllowed(prefs, null, now), isTrue, reason: 'a free activation code on this device');
    Access.debugGated = false;
    SharedPreferences.setMockInitialValues({});
    expect(Access.ownerAllowed(await SharedPreferences.getInstance(), null, now), isTrue, reason: 'the gate is off (Android, the demo)');
  });

  test('every subscription level has a monthly and a yearly product, in the order of the server table', () {
    expect(Access.tiers.map((t) => t.members), [5, 10, 20]);
    expect(Access.productIds.length, 6);
    expect(Access.productIds, containsAll(['asraty.monthly', 'asraty.yearly', 'asraty.m10', 'asraty.y10', 'asraty.m20', 'asraty.y20']));
  });

  test('demo family: the sixth child is refused like on the server (adults are not counted)', () async {
    final b = DemoBackend(clock: () => DateTime.parse('2026-09-29T12:00:00+03:00'));
    final kids = b.current.data!.members.length;
    for (var i = kids; i < 5; i++) {
      await b.addPerson(role: Role.member, name: 'طفل$i', email: 'k$i@demo.sa', avatar: 'boy_shemagh');
    }
    await expectLater(b.addPerson(role: Role.member, name: 'السادس', email: 'k6@demo.sa', avatar: 'boy_shemagh'), throwsA(isA<AppError>().having((e) => e.code, 'code', 'member-limit')));
    await b.addPerson(role: Role.admin, name: 'مسؤول', email: 'adm@demo.sa', avatar: 'mom_black', perms: {});
  });
}
