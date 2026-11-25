/// تخزين لغة الواجهة المختارة (رمز اللغة 'ar' أو 'en'؛ null = لا اختيار).
abstract interface class LocaleStore {
  Future<String?> load();
  Future<void> save(String languageCode);
}
