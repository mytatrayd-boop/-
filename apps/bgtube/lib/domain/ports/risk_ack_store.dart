/// إقرار المالك بالخطر (D10) قبل أول تسجيل دخول. لا يُمسح عند الخروج.
abstract interface class RiskAckStore {
  Future<bool> isAcknowledged();
  Future<void> acknowledge();
}
