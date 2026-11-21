import 'dart:convert';
import 'dart:io';

import 'package:lamha/src/engine/deposits.dart';
import 'package:lamha/src/engine/schedule.dart';

String readAsset(String path) => File(path).readAsStringSync();

DepositsConfig loadDeposits() =>
    DepositsConfig.fromJsonString(readAsset('assets/deposits.json'));

EngineData loadEngineDataFromFiles() => EngineData.fromStrings(
      depositsJson: readAsset('assets/deposits.json'),
      hijriJson: jsonDecode(readAsset('assets/tables/hijri_umm_al_qura.json')),
      seasonsJson: readAsset('assets/seasons.json'),
    );
