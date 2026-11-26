import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/domain/models/youtube_content.dart';
import 'package:bgtube/features/browse/paged_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an empty first page with a nextPageToken has no more', () async {
    final l = PagedLoader<int>((_, _) async => const ApiPage([], nextPageToken: 'P2'));
    await l.load();
    expect(l.loaded, isTrue);
    expect(l.hasMore, isFalse);
  });

  test('an empty later page with a nextPageToken ends the list; loadMore then does nothing', () async {
    final tokens = <String?>[];
    final l = PagedLoader<int>((token, _) async {
      tokens.add(token);
      return token == null ? const ApiPage([1, 2], nextPageToken: 'P2') : const ApiPage([], nextPageToken: 'P3');
    });
    await l.load();
    expect(l.hasMore, isTrue);
    await l.loadMore();
    expect(l.items, [1, 2]);
    expect(l.hasMore, isFalse);
    await l.loadMore();
    expect(tokens, [null, 'P2']);
  });

  test('a failure keeps the items, and the newest load wins', () async {
    var fail = false;
    final l = PagedLoader<int>((_, refresh) async {
      if (fail) throw const AppFailure(FailureKind.network);
      return ApiPage([refresh ? 2 : 1]);
    });
    await l.load();
    fail = true;
    await l.load(refresh: true);
    expect(l.items, [1]);
    expect(l.failure?.kind, FailureKind.network);
  });

  test('pages filtered to nothing (private/deleted, rawCount > 0) are skipped, not treated as the end (D30)', () async {
    final tokens = <String?>[];
    final l = PagedLoader<int>((token, _) async {
      tokens.add(token);
      return switch (token) {
        null => const ApiPage([], nextPageToken: 'P2', rawCount: 50),
        'P2' => const ApiPage([7], nextPageToken: 'P3', rawCount: 50),
        'P3' => const ApiPage([], nextPageToken: 'P4', rawCount: 50),
        _ => const ApiPage([8], rawCount: 1),
      };
    });
    await l.load();
    expect(l.items, [7]);
    expect(l.hasMore, isTrue);
    await l.loadMore();
    expect(l.items, [7, 8]);
    expect(l.hasMore, isFalse);
    expect(tokens, [null, 'P2', 'P3', 'P4']);
  });

  test('skipping filtered pages is bounded', () async {
    var calls = 0;
    final l = PagedLoader<int>((token, _) async {
      calls++;
      return ApiPage(const [], nextPageToken: 'P$calls', rawCount: 50);
    });
    await l.load();
    expect(calls, PagedLoader.maxSkippedPages + 1);
  });
}
