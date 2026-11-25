/// اللغات المدعومة. العربية أولاً وهي الاحتياطي.
const supportedLanguageCodes = ['ar', 'en'];

/// يعيد الرمز إن كان مدعوماً وإلا null (قيمة تالفة في التخزين تُتجاهل).
String? validLanguageCode(String? code) =>
    supportedLanguageCodes.contains(code) ? code : null;
