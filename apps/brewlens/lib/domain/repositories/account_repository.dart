abstract interface class AccountRepository {
  /// يحذف الحساب وكل بياناته نهائياً.
  Future<void> deleteAccount();
}
