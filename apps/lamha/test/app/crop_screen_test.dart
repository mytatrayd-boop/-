import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/l10n/app_localizations.dart';
import 'package:lamha/src/app/crop_screen.dart';

import 'app_helpers.dart' show seShot;

Future<void> openCrop(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: CropScreen(bytes: seShot),
  ));
  for (var i = 0; i < 20 && find.byKey(const Key('crop-frame')).evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('المقاس والموضع يحرّكان الإطار، والكبيرة بلا «وسط»', (tester) async {
    await openCrop(tester);
    final top = tester.getRect(find.byKey(const Key('crop-frame')));
    expect(find.byKey(const Key('crop-slot-middle')), findsNothing);
    await tester.tap(find.byKey(const Key('crop-slot-bottom')));
    await tester.pumpAndSettle();
    final bottom = tester.getRect(find.byKey(const Key('crop-frame')));
    expect(bottom.top, greaterThan(top.top));
    expect(bottom.width, closeTo(top.width, 0.01));
    expect(bottom.height, closeTo(top.height, 0.01));
    await tester.tap(find.byKey(const Key('crop-size-medium')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('crop-slot-middle')), findsOneWidget);
    final medium = tester.getRect(find.byKey(const Key('crop-frame')));
    expect(medium.height, lessThan(top.height / 2));
  });

  testWidgets('سحب الإطار يحرّكه ولا يخرج من اللقطة', (tester) async {
    await openCrop(tester);
    final before = tester.getRect(find.byKey(const Key('crop-frame')));
    final g = await tester.startGesture(before.center);
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(0, 8));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    final after = tester.getRect(find.byKey(const Key('crop-frame')));
    expect(after.top, greaterThan(before.top + 20));
    await tester.drag(find.byKey(const Key('crop-frame')), const Offset(-400, -900));
    await tester.pumpAndSettle();
    final edge = tester.getRect(find.byKey(const Key('crop-frame')));
    final image = tester.getRect(find.byType(RawImage));
    expect(edge.left, closeTo(image.left, 0.5));
    expect(edge.top, closeTo(image.top, 0.5));
  });
}
