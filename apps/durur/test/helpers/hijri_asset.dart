import 'dart:convert';
import 'dart:io';

import 'package:durur/src/hijri/umm_al_qura_calendar.dart';
import 'package:durur/src/repository/tables_loader.dart';

/// جدول أم القرى المضمّن من assets/tables (D22).
UmmAlQuraCalendar loadAssetHijriCalendar() => UmmAlQuraCalendar.fromJson(
      jsonDecode(File(TablesLoader.hijriPath).readAsStringSync()),
    );
