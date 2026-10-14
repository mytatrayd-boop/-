/// تنسيق الأرقام والأحجام حسب لغة الواجهة (DESIGN §2.3): أرقام مشرقية
/// وفاصلة عشرية «٫» في العربية، وغربية في الإنجليزية. Dart صافٍ.
library;

const _eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

bool _isArabic(String languageCode) => languageCode == 'ar';

/// يحوّل الأرقام اللاتينية والفاصلة العشرية في [text] حسب اللغة.
String localizeDigits(String text, String languageCode) {
  if (!_isArabic(languageCode)) return text;
  final out = StringBuffer();
  for (final unit in text.runes) {
    if (unit >= 0x30 && unit <= 0x39) {
      out.write(_eastern[unit - 0x30]);
    } else if (unit == 0x2E) {
      out.write('٫');
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

String formatInt(int value, String languageCode) =>
    localizeDigits(value.toString(), languageCode);

/// الحجم بوحدة م.ب أو ك.ب: القيمة المنسّقة ووحدتها.
enum SizeUnit { kb, mb }

class FormattedSize {
  const FormattedSize(this.value, this.unit);
  final String value;
  final SizeUnit unit;
}

/// ميغابايت عشري (1,000,000 بايت) كما يعرضه أندرويد. أقل من 1 م.ب يُعرض
/// بالكيلوبايت بلا كسور (بحد أدنى ١).
FormattedSize formatSize(int bytes, String languageCode) {
  if (bytes >= 1000000) {
    return FormattedSize(
      localizeDigits((bytes / 1000000).toStringAsFixed(1), languageCode),
      SizeUnit.mb,
    );
  }
  final kb = (bytes / 1000).ceil().clamp(1, 999);
  return FormattedSize(formatInt(kb, languageCode), SizeUnit.kb);
}

/// النسبة المئوية الصحيحة (0–100) من تقدّم بين 0 و1.
int percentOf(double fraction) => (fraction.clamp(0.0, 1.0) * 100).floor();
