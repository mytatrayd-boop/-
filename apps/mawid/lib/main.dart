import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'core/remote_holidays.dart';
import 'model/holidays.dart';
import 'core/settings.dart';
import 'features/shell.dart';

const ink = Color(0xFF1C2B4B);
const ground = Color(0xFFEEF1F6);
const line = Color(0xFFD5DBE6);
const muted = Color(0xFF5E6A80);
const warnBg = Color(0xFFFCEBD3);
const warnFg = Color(0xFF8A4D0B);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  var bundled = <Holiday>[];
  try {
    bundled = parseExtra(await rootBundle.loadString('assets/holidays_extra.json'));
  } catch (_) {}
  final cached = cachedHolidays(prefs);
  final extra = ValueNotifier<List<Holiday>>(cached.isNotEmpty ? cached : bundled);
  runApp(MawidApp(AppState(prefs), extra: extra));
  // تحديث صامت: إذا فشل يبقى المعروض كما هو.
  refreshHolidays(prefs, http.Client()).then((l) {
    if (l != null) extra.value = l;
  });
}

class MawidApp extends StatelessWidget {
  final AppState state;
  final DateTime? today; // للاختبار
  final ValueListenable<List<Holiday>>? extra;
  const MawidApp(this.state, {super.key, this.today, this.extra});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'موعد',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Tajawal',
          scaffoldBackgroundColor: ground,
          colorScheme: ColorScheme.fromSeed(seedColor: ink, primary: ink),
        ),
        home: Shell(state: state, today: today ?? DateTime.now(), extra: extra ?? ValueNotifier<List<Holiday>>(const [])),
      );
}
