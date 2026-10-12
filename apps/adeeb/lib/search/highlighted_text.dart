import 'package:flutter/painting.dart';

import '../text/search_query.dart';

/// يقسم [text] إلى مقاطع، والمطابق منها بخلفية [highlight] مع خط سفلي
/// (DESIGN §1: لا يُعتمد على اللون وحده). التظليل لا يُقرأ لقارئ الشاشة.
List<TextSpan> highlightedSpans(
  String text,
  List<MatchSpan> matches,
  Color highlight,
) {
  if (matches.isEmpty) return [TextSpan(text: text)];
  final style = TextStyle(
    backgroundColor: highlight,
    decoration: TextDecoration.underline,
  );
  final spans = <TextSpan>[];
  var at = 0;
  for (final m in matches) {
    if (m.start < at || m.end > text.length) continue;
    if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
    spans.add(TextSpan(text: text.substring(m.start, m.end), style: style));
    at = m.end;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  return spans;
}
