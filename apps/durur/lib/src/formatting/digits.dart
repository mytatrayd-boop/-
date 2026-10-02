/// شكل الأرقام المعروضة (DESIGN §الأرقام و8.7): عربية هندية (الافتراضي) أو
/// لاتينية. يُختار من الإعدادات.
enum DigitStyle {
  arabicIndic('arabic'),
  latin('latin');

  const DigitStyle(this.code);

  /// القيمة المحفوظة في الإعدادات.
  final String code;

  /// null أو قيمة غير معروفة ← الافتراضي (عربية هندية).
  static DigitStyle parse(String? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return arabicIndic;
  }
}

/// تحويل الأرقام اللاتينية (0-9) إلى أرقام عربية هندية (٠-٩).
///
/// الافتراضي في التطبيق أرقام عربية هندية (DESIGN §الأرقام). مكتبة intl
/// تُخرج للّغة `ar` أرقاماً لاتينية، لذلك يتم التحويل هنا.
String toArabicIndicDigits(String input) => input.replaceAllMapped(
      RegExp('[0-9]'),
      (m) => String.fromCharCode(0x0660 + m[0]!.codeUnitAt(0) - 0x30),
    );

/// تحويل الأرقام العربية الهندية (٠-٩) إلى لاتينية (0-9).
String toLatinDigits(String input) => input.replaceAllMapped(
      RegExp('[٠-٩]'),
      (m) => String.fromCharCode(0x30 + m[0]!.codeUnitAt(0) - 0x0660),
    );

/// يحوّل كل الأرقام في [input] (من الصيغتين) إلى [style]. يُستخدم أيضاً
/// للنصوص الثابتة في ملف الترجمة التي فيها أرقام (مثل «٨:٠٠»).
String localizeDigits(String input, DigitStyle style) => switch (style) {
      DigitStyle.arabicIndic => toArabicIndicDigits(input),
      DigitStyle.latin => toLatinDigits(input),
    };

/// عدد صحيح بلا فواصل آلاف (للأيام والسنوات) بشكل الأرقام [style].
String formatInteger(int value, [DigitStyle style = DigitStyle.arabicIndic]) =>
    localizeDigits('$value', style);
