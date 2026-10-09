import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

enum HKind { national, founding, eidFitr, eidAdha, longWeekend, midTerm, termEnd, summer }

const kindName = {
  HKind.national: 'إجازة اليوم الوطني',
  HKind.founding: 'إجازة يوم التأسيس',
  HKind.eidFitr: 'إجازة عيد الفطر',
  HKind.eidAdha: 'إجازة عيد الأضحى',
  HKind.longWeekend: 'نهاية أسبوع مطولة',
  HKind.midTerm: 'إجازة منتصف الفصل',
  HKind.termEnd: 'إجازة نهاية الفصل',
  HKind.summer: 'الإجازة الصيفية',
};

/// ألوان تُميَّز بالفتحة والحدّ لا باللون وحده.
const kindColor = {
  HKind.national: Color(0xFF0E6B4A),
  HKind.founding: Color(0xFF8A5A12),
  HKind.eidFitr: Color(0xFF7A3E9D),
  HKind.eidAdha: Color(0xFF9D3E5C),
  HKind.longWeekend: Color(0xFF2E6FA8),
  HKind.midTerm: Color(0xFF9A6B00),
  HKind.termEnd: Color(0xFF9A6B00),
  HKind.summer: Color(0xFFB45A1A),
};

class Holiday {
  final HKind kind;
  final DateTime start, end; // شاملان
  final bool approx;
  const Holiday(this.kind, this.start, this.end, {this.approx = false});

  bool covers(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(start) && !x.isAfter(end);
  }
}

DateTime _h(int hy, int hm, int hd) => HijriCalendar().hijriToGregorian(hy, hm, hd);

/// إجازات تُحسب: اليوم الوطني، يوم التأسيس، العيدان (تقريبي حتى يُعلن رسمياً)،
/// ونهايات الأسبوع المطولة المشتقة منها.
/// [extra]: إجازات التعليم من assets/holidays_extra.json (تُملأ من مصدر وزارة التعليم).
List<Holiday> holidaysFor(int year, {List<Holiday> extra = const []}) {
  final base = <Holiday>[
    Holiday(HKind.founding, DateTime(year, 2, 22), DateTime(year, 2, 22)),
    Holiday(HKind.national, DateTime(year, 9, 23), DateTime(year, 9, 23)),
  ];
  for (var hy = year - 580; hy <= year - 576; hy++) {
    // عيد الفطر: 29 رمضان – 4 شوال. عيد الأضحى: 9 – 13 ذو الحجة. (تقريبي)
    final f = Holiday(HKind.eidFitr, _h(hy, 9, 29), _h(hy, 10, 4), approx: true);
    final a = Holiday(HKind.eidAdha, _h(hy, 12, 9), _h(hy, 12, 13), approx: true);
    for (final h in [f, a]) {
      if (h.start.year == year || h.end.year == year) base.add(h);
    }
  }
  final ex = extra.where((e) => e.start.year == year || e.end.year == year).toList();
  // البيانات الرسمية تحلّ محل المحسوب من نفس النوع.
  final official = ex.map((e) => e.kind).toSet();
  final all = [...base.where((b) => !official.contains(b.kind)), ...ex];
  return [...all, ...longWeekends(all)];
}

/// نهاية أسبوع مطولة: إجازة تنتهي الخميس (فتلتصق بجمعة وسبت) أو تبدأ الأحد (فتلتصق بهما قبلها).
List<Holiday> longWeekends(List<Holiday> hs) {
  final out = <Holiday>[];
  for (final h in hs) {
    if (h.kind == HKind.summer) continue;
    if (h.end.weekday == DateTime.thursday) {
      out.add(Holiday(HKind.longWeekend, h.end.add(const Duration(days: 1)), h.end.add(const Duration(days: 2)), approx: h.approx));
    }
    if (h.start.weekday == DateTime.sunday) {
      out.add(Holiday(HKind.longWeekend, h.start.subtract(const Duration(days: 2)), h.start.subtract(const Duration(days: 1)), approx: h.approx));
    }
  }
  return out;
}

Holiday? holidayOn(List<Holiday> hs, DateTime d) {
  for (final h in hs) {
    if (h.kind != HKind.longWeekend && h.covers(d)) return h;
  }
  for (final h in hs) {
    if (h.covers(d)) return h;
  }
  return null;
}

/// يقرأ [{"kind":"midTerm","start":"2026-11-01","end":"2026-11-05"}, ...]
List<Holiday> parseExtra(String json) {
  final out = <Holiday>[];
  for (final e in (jsonDecode(json) as List)) {
    final k = HKind.values.where((x) => x.name == e['kind']);
    if (k.isEmpty) continue;
    out.add(Holiday(k.first, DateTime.parse(e['start']), DateTime.parse(e['end'])));
  }
  return out;
}
