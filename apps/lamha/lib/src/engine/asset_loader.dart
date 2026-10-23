import 'dart:convert';

import 'package:flutter/services.dart';

import 'schedule.dart';

/// يقرأ بيانات المحرك من أصول التطبيق (الجزء الوحيد المعتمد على Flutter).
Future<EngineData> loadEngineData([AssetBundle? bundle]) async {
  final b = bundle ?? rootBundle;
  return EngineData.fromStrings(
    depositsJson: await b.loadString('assets/deposits.json'),
    hijriJson: jsonDecode(
        await b.loadString('assets/tables/hijri_umm_al_qura.json')),
    seasonsJson: await b.loadString('assets/seasons.json'),
  );
}
