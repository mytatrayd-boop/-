import 'package:bgtube/l10n/gen/app_localizations_ar.dart';
import 'package:bgtube/l10n/gen/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ar = AppLocalizationsAr();
  final en = AppLocalizationsEn();

  test('Arabic count strings use ICU plural forms', () {
    expect(ar.itemsCount(1), 'مقطع واحد');
    expect(ar.itemsCount(2), 'مقطعان');
    expect(ar.itemsCount(3), '3 مقاطع');
    expect(ar.itemsCount(11), '11 مقطعاً');
    expect(ar.itemsCount(100), '100 مقطع');
    expect(ar.itemsSummary(5, '12:00'), '5 مقاطع · 12:00');
    expect(ar.queueRemaining(3), '3 متبقية');
    expect(ar.queueRemaining(1), 'واحد متبقٍ');
    expect(ar.queueRemaining(20), '20 متبقياً');
    expect(ar.snackAddedCount(2), 'أُضيف مقطعان إلى الطابور');
    expect(ar.snackAddedCount(15), 'أُضيف 15 مقطعاً إلى الطابور');
    expect(ar.queueTruncated(500), 'الطابور ممتلئ (500 مقطع)؛ لم يُضف الباقي');
  });

  test('English count strings use singular and plural', () {
    expect(en.itemsCount(1), '1 item');
    expect(en.itemsCount(4), '4 items');
    expect(en.itemsSummary(1, '3:00'), '1 item · 3:00');
    expect(en.queueRemaining(1), '1 left');
    expect(en.queueRemaining(3), '3 left');
    expect(en.snackAddedCount(1), 'Added 1 item to the queue');
    expect(en.snackAddedCount(1200), 'Added 1,200 items to the queue');
  });

  test('library whole-list messages (D30)', () {
    expect(ar.playlistAddedPartial(50, 120), 'أُضيف 50 من 120. تعذّر جلب الباقي');
    expect(ar.playlistAddedPartialUnknown(1), 'أُضيف مقطع واحد. تعذّر جلب الباقي');
    expect(ar.playlistAddedPartialUnknown(3), 'أُضيف 3 مقاطع. تعذّر جلب الباقي');
    expect(ar.playlistAddedPartialUnknown(11), 'أُضيف 11 مقطعاً. تعذّر جلب الباقي');
    expect(ar.playlistAddingProgress(50, 1200), 'جارٍ إضافة القائمة… 50 من 1,200');
    expect(en.playlistAddedPartial(1050, 2000), "Added 1,050 of 2,000. Couldn't fetch the rest");
    expect(en.playlistAddedPartialUnknown(1), "Added 1 item. Couldn't fetch the rest");
    expect(en.playlistAddedPartialUnknown(4), "Added 4 items. Couldn't fetch the rest");
  });
}
