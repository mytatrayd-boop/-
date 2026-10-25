/// أدوات وضع العرض فقط (SPEC F1 معيار 5). في البناء الحقيقي لا يوجد تنفيذ
/// لها، والشاشات تخفي عناصرها حين يكون المزوّد null.
abstract interface class RejectionSimulator {
  /// التحليل التالي يعيد «صورة مرفوضة» ولا يُحتسب.
  bool get rejectNext;
  set rejectNext(bool value);
}

/// «محاكاة مشترك» في الإعدادات (وضع العرض فقط): يرفع الحد المحلي إلى 20/يوم.
abstract interface class SubscriberSimulator {
  bool get simulateSubscriber;
  Future<void> setSimulateSubscriber(bool value);
}
