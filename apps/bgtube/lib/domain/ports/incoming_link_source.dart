/// مصدر الروابط الواردة من خارج التطبيق (مشاركة / فتح رابط).
abstract interface class IncomingLinkSource {
  /// النص الذي بدأ به التطبيق (بدء بارد) أو null.
  Future<String?> initialText();

  /// نصوص تصل أثناء تشغيل التطبيق.
  Stream<String> get texts;
}
