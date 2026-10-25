final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());

/// الحد الأدنى لكلمة المرور: 8 في البناء الحقيقي (SPEC F2)، و6 في وضع العرض
/// (SPEC F1 معيار 5، DESIGN §3.2).
const realMinPasswordLength = 8;
const demoMinPasswordLength = 6;

int minPasswordLength({required bool isDemo}) =>
    isDemo ? demoMinPasswordLength : realMinPasswordLength;
