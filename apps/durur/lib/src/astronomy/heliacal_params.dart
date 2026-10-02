import '../domain/month_day.dart';
import 'stars.dart';

/// معاملات معيار قوس الرؤية لنجم (ARCHITECTURE §6، D9).
class HeliacalParams {
  const HeliacalParams({
    required this.star,
    required this.starAltitude,
    required this.arcusVisionis,
    required this.windowStart,
    required this.windowEnd,
  });

  final Star star;

  /// الارتفاع الظاهري للنجم `h_star` (بالدرجات) لحظة الحكم بالرؤية.
  final double starAltitude;

  /// قوس الرؤية `AV`: أقل انخفاض للشمس تحت الأفق (بالدرجات) لترى العين النجم.
  final double arcusVisionis;

  /// نافذة البحث عن الطلوع داخل السنة (شاملة الطرفين).
  final MonthDay windowStart;
  final MonthDay windowEnd;
}

/// قوس الرؤية لسهيل: الرؤية **بالعين المجردة** (قرار المدير، كما في التراث).
///
/// 13.5° بالمعايرة على القيم المرجعية بالعين المجردة في
/// research/REFERENCE_RISINGS.md (القيمة الأولية في ARCHITECTURE §6 كانت 10.5°):
/// - الكويت ≈ 7 سبتمبر (S13: أول رؤية بمنظار 4 سبتمبر ثم العين المجردة بعد نحو
///   3 أيام). المحسوب 6–7 سبتمبر في 2025–2040.
/// - أقصى شمال السعودية ≈ 8 سبتمبر 2026 (S23، تقريبي) ← سكاكا (29.97° ش): 8 سبتمبر.
/// - القيمة 10.5° تعطي الكويت 4 سبتمبر = تاريخ المنظار لا العين المجردة.
/// - **تعارض غير محلول:** الدوحة «الأسبوع الأول من سبتمبر» 2025 (S24) لا تتوافق
///   مع الكويت بأي قيمة واحدة لـ AV (الفرق الهندسي بينهما ≈ 10 أيام).
/// القيم المرجعية **غير معتمدة بعد** من المراجع، وأقل من 5 مدن (شرط SPEC غير مكتمل).
/// القرار: DECISIONS D28. الاختبار الدائم: test/astronomy/heliacal_reference_test.dart.
const suhailArcusVisionis = 13.5;

/// قوس الرؤية للثريا: الرؤية **بالعين المجردة**. 15° هي القيمة الأولية في
/// ARCHITECTURE §6 **بلا معايرة**: لا يوجد رصد منشور بالعين المجردة (الرصد الوحيد
/// بالتصوير، الإمارات 12 يونيو 2025، S26)، فلا يمكن التحقق من ±يومين بعد.
const thurayyaArcusVisionis = 15.0;

final suhailParams = HeliacalParams(
  star: canopus,
  starAltitude: 1,
  arcusVisionis: suhailArcusVisionis,
  windowStart: const MonthDay(7, 15),
  windowEnd: const MonthDay(9, 30),
);

final thurayyaParams = HeliacalParams(
  star: alcyone,
  starAltitude: 1,
  arcusVisionis: thurayyaArcusVisionis,
  windowStart: const MonthDay(5, 15),
  windowEnd: const MonthDay(7, 15),
);
