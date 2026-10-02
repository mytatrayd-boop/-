/// تحويل الأرقام اللاتينية (0-9) إلى أرقام عربية هندية (٠-٩).
///
/// الافتراضي في التطبيق أرقام عربية هندية (DESIGN §الأرقام). مكتبة intl
/// تُخرج للّغة `ar` أرقاماً لاتينية، لذلك يتم التحويل هنا.
String toArabicIndicDigits(String input) => input.replaceAllMapped(
      RegExp('[0-9]'),
      (m) => String.fromCharCode(0x0660 + m[0]!.codeUnitAt(0) - 0x30),
    );

/// عدد صحيح بلا فواصل آلاف (للأيام والسنوات) بأرقام عربية هندية.
String formatInteger(int value) => toArabicIndicDigits('$value');
