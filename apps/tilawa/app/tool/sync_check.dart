// فحص منطق المزامنة خارج التطبيق: blocks يخرج الكتل، و finish يكمل المزامنة من نصوص الكتل.
//   dart run tool/sync_check.dart blocks audio.f32 > blocks.json
//   dart run tool/sync_check.dart finish audio.f32 quran.json texts.json
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tilawa_app/quran.dart';
import 'package:tilawa_app/sync.dart';

void main(List<String> args) {
  final pcm = File(args[1]).readAsBytesSync();
  final audio = pcm.buffer.asFloat32List(pcm.offsetInBytes, pcm.lengthInBytes ~/ 4);
  final units = breathUnits(Float32List.fromList(audio));
  final blocks = packBlocks(units);
  if (args[0] == 'blocks') {
    print(jsonEncode([for (final (a, b) in blocks) [units[a][0], units[b][1]]]));
    return;
  }
  final q = Quran.fromJson(File(args[2]).readAsStringSync());
  final texts = (jsonDecode(File(args[3]).readAsStringSync()) as List).cast<String>();
  final r = finishSync(q, units, blocks, texts)!;
  print('surah ${r.surah} ${r.from}-${r.to} ${r.segs.length} segs');
  for (final s in r.segs) {
    print('${s.start} ${s.end} ${s.text.length > 50 ? s.text.substring(0, 50) : s.text}');
  }
}
