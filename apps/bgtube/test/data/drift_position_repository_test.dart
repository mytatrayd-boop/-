import 'package:bgtube/data/local/app_database.dart';
import 'package:bgtube/data/local/drift_position_repository.dart';
import 'package:bgtube/domain/models/playback_position.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

PlaybackPosition pos(String id, int sec) => PlaybackPosition(
  videoId: id,
  position: Duration(seconds: sec),
  duration: const Duration(minutes: 10),
  updatedAt: DateTime.utc(2026, 11, 25),
);

void main() {
  late AppDatabase db;
  late DriftPositionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftPositionRepository(db);
  });
  tearDown(() => db.close());

  test('unknown video returns null', () async {
    expect(await repo.get('AAAAAAAAAAA'), isNull);
  });

  test('save then get round-trips', () async {
    await repo.save(pos('AAAAAAAAAAA', 300));
    final p = (await repo.get('AAAAAAAAAAA'))!;
    expect(p.position, const Duration(minutes: 5));
    expect(p.duration, const Duration(minutes: 10));
    expect(p.updatedAt.toUtc(), DateTime.utc(2026, 11, 25));
  });

  test(
    'save overwrites (one row per video) and videos are independent',
    () async {
      await repo.save(pos('AAAAAAAAAAA', 30));
      await repo.save(pos('AAAAAAAAAAA', 90));
      await repo.save(pos('BBBBBBBBBBB', 15));
      expect(
        (await repo.get('AAAAAAAAAAA'))!.position,
        const Duration(seconds: 90),
      );
      expect(
        (await repo.get('BBBBBBBBBBB'))!.position,
        const Duration(seconds: 15),
      );
      expect(await db.select(db.positions).get(), hasLength(2));
    },
  );

  test('delete removes only that video', () async {
    await repo.save(pos('AAAAAAAAAAA', 30));
    await repo.save(pos('BBBBBBBBBBB', 30));
    await repo.delete('AAAAAAAAAAA');
    expect(await repo.get('AAAAAAAAAAA'), isNull);
    expect(await repo.get('BBBBBBBBBBB'), isNotNull);
    await repo.delete('AAAAAAAAAAA'); // لا يرمي
  });
}
