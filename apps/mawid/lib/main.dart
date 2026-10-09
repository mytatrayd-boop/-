import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  runApp(MawidApp(AppState(prefs)));
}

class MawidApp extends StatelessWidget {
  final AppState state;
  final DateTime? today; // للاختبار
  const MawidApp(this.state, {super.key, this.today});

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
          scaffoldBackgroundColor: ground,
          colorScheme: ColorScheme.fromSeed(seedColor: ink, primary: ink),
        ),
        home: Shell(state: state, today: today ?? DateTime.now()),
      );
}
