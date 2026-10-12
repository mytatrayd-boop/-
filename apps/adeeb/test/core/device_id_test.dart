import 'dart:io';
import 'dart:math';

import 'package:adeeb/core/client_info.dart';
import 'package:adeeb/core/device_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UUID v4 بالصيغة التي يقبلها الخادم ومختلف في كل مرة', () {
    final ids = {for (var i = 0; i < 200; i++) generateUuidV4()};
    expect(ids.length, 200);
    for (final id in ids) {
      expect(isUuidV4(id), isTrue, reason: id);
    }
    expect(isUuidV4('00000000-0000-0000-0000-000000000000'), isFalse);
  });

  test('يُولَّد مرة ويُحفظ، والمحفوظ غير الصالح يُستبدل', () async {
    String? stored;
    var writes = 0;
    Future<String> load() => loadOrCreateDeviceId(
      read: () => stored,
      write: (id) async {
        writes++;
        stored = id;
      },
      random: Random(1),
    );
    final first = await load();
    expect(await load(), first);
    expect(writes, 1);
    stored = 'not-a-uuid';
    final next = await load();
    expect(isUuidV4(next), isTrue);
    expect(writes, 2);
  });

  test('رقم البناء في X-Client يطابق pubspec.yaml', () {
    final version = RegExp(
      r'^version:\s*\S+\+(\d+)',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!;
    expect(int.parse(version.group(1)!), clientBuildNumber);
    expect(clientHeader(ios: false), 'adeeb-android/$clientBuildNumber');
    expect(
      RegExp(r'^adeeb-(android|ios)/(\d{1,9})$')
          .hasMatch(clientHeader(ios: true)),
      isTrue,
    );
  });
}
