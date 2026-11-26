// اختبار ترحيل مولَّد (drift_dev make-migrations) ومعدَّل: v1→v2 يحفظ positions، وv2→v3 يحفظ الطابور.
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:bgtube/data/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test('migration from v1 to v2 keeps saved positions', () async {
    // drift يخزّن DateTime ثوانيَ يونكس؛ المخطط المولَّد يراها int.
    final updated = DateTime.utc(2026, 11, 25, 10).millisecondsSinceEpoch ~/ 1000;
    final oldPositionsData = <v1.PositionsData>[
      v1.PositionsData(videoId: 'AAAAAAAAAAA', positionMs: 300000, durationMs: 1200000, updatedAt: updated),
      v1.PositionsData(videoId: 'BBBBBBBBBBB', positionMs: 15000, durationMs: 0, updatedAt: updated),
    ];
    final expectedNewPositionsData = <v2.PositionsData>[
      v2.PositionsData(videoId: 'AAAAAAAAAAA', positionMs: 300000, durationMs: 1200000, updatedAt: updated),
      v2.PositionsData(videoId: 'BBBBBBBBBBB', positionMs: 15000, durationMs: 0, updatedAt: updated),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.positions, oldPositionsData);
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.positions).get(), expectedNewPositionsData);
        // الجداول الجديدة موجودة وفارغة.
        expect(await newDb.select(newDb.queueEntries).get(), isEmpty);
        expect(await newDb.select(newDb.localPlaylists).get(), isEmpty);
      },
    );
  });

  test('after migrating v1 -> v2 the app can use the new tables and positions', () async {
    final schema = await verifier.schemaAt(1);
    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb.into(oldDb.positions).insert(v1.PositionsCompanion.insert(
          videoId: 'AAAAAAAAAAA',
          positionMs: 300000,
          durationMs: 1200000,
          updatedAt: DateTime.utc(2026).millisecondsSinceEpoch ~/ 1000,
        ));
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    final pos = await db.select(db.positions).getSingle();
    expect(pos.positionMs, 300000);
    final id = await db.into(db.localPlaylists).insert(LocalPlaylistsCompanion.insert(
          name: 'x',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ));
    await db.into(db.localPlaylistItems).insert(
        LocalPlaylistItemsCompanion.insert(playlistId: id, ord: 0, videoId: 'AAAAAAAAAAA'));
    // foreign_keys مفعّل بعد الترحيل: حذف القائمة يحذف عناصرها.
    await db.delete(db.localPlaylists).go();
    expect(await db.select(db.localPlaylistItems).get(), isEmpty);
    await db.close();
  });

  test('migration from v2 to v3 keeps the queue, playlists and positions; adds empty cache and quota', () async {
    final updated = DateTime.utc(2026, 11, 26).millisecondsSinceEpoch ~/ 1000;
    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.positions, [
          v2.PositionsData(videoId: 'AAAAAAAAAAA', positionMs: 1000, durationMs: 2000, updatedAt: updated),
        ]);
        batch.insertAll(oldDb.queueEntries, [
          v2.QueueEntriesData(key: 1, ord: 0, videoId: 'AAAAAAAAAAA', failed: 0),
        ]);
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.positions).get(), hasLength(1));
        expect(await newDb.select(newDb.queueEntries).get(), hasLength(1));
        expect(await newDb.select(newDb.apiCache).get(), isEmpty);
        expect(await newDb.select(newDb.quota).get(), isEmpty);
      },
    );
  });
}
