import 'dart:io';
import 'dart:typed_data';

import 'package:brewlens/backend/demo/demo_reviews_repository.dart';
import 'package:brewlens/domain/models/coffee_type.dart';
import 'package:brewlens/domain/models/review.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Review draft({int? rating, String? shopId, double score = 7.5}) => Review(
      id: '',
      coffeeType: CoffeeType.espresso,
      imagePath: '',
      aiScore: score,
      aiNotes: const ['a', 'b', 'c'],
      aiTip: 't',
      createdAt: DateTime.utc(2026),
      userRating: rating,
      shopId: shopId,
    );

void main() {
  late Directory dir;
  late SharedPreferences prefs;
  var tick = 0;

  DemoReviewsRepository repo() => DemoReviewsRepository(
        prefs,
        () async => dir,
        clock: () => DateTime.utc(2026, 10, 25, 12).add(Duration(minutes: tick++)),
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('brewlens_reviews');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => dir.delete(recursive: true));

  test('save writes the image into the app folder and the record locally', () async {
    final r = repo();
    final bytes = Uint8List.fromList([1, 2, 3]);
    final saved = await r.save(draft(rating: 4, shopId: 's1'), bytes);
    expect(saved.id, isNotEmpty);
    expect(saved.imagePath, '${saved.id}.jpg');
    expect(File('${dir.path}/${saved.imagePath}').existsSync(), isTrue);
    expect(await r.imageBytes(saved), bytes);
    expect((await r.get(saved.id)).userRating, 4);
  });

  test('data survives a new repository instance (app reopen)', () async {
    final saved = await repo().save(draft(), Uint8List.fromList([9]));
    final reopened = repo();
    final list = await reopened.list();
    expect(list.single.id, saved.id);
    expect(list.single.aiNotes, ['a', 'b', 'c']);
  });

  test('list is newest first and paginated', () async {
    final r = repo();
    final ids = <String>[];
    for (var i = 0; i < 25; i++) {
      ids.add((await r.save(draft(), Uint8List.fromList([i]))).id);
    }
    final first = await r.list(limit: 20);
    final second = await r.list(offset: 20, limit: 20);
    expect(first, hasLength(20));
    expect(second, hasLength(5));
    expect(first.first.id, ids.last);
    expect(second.last.id, ids.first);
  });

  test('update edits stars, notes and shop; clearing works', () async {
    final r = repo();
    final saved = await r.save(draft(rating: 2, shopId: 's1'), Uint8List.fromList([1]));
    await r.update(saved.copyWith(userRating: 5, userNotes: 'رائع', shopId: null));
    final got = await r.get(saved.id);
    expect(got.userRating, 5);
    expect(got.userNotes, 'رائع');
    expect(got.shopId, isNull);
    expect(got.aiScore, saved.aiScore);
  });

  test('delete removes the record and its image', () async {
    final r = repo();
    final saved = await r.save(draft(), Uint8List.fromList([1]));
    final file = File('${dir.path}/${saved.imagePath}');
    expect(file.existsSync(), isTrue);
    await r.delete(saved.id);
    expect(file.existsSync(), isFalse);
    expect(await r.list(), isEmpty);
  });
}
