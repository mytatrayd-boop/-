import '../models/shop.dart';

abstract interface class ShopsRepository {
  /// مقاهي المستخدم نفسه فقط، مع حالة المفضلة.
  Future<List<Shop>> list({String query = ''});

  /// ينشئ مقهى أو يعيد الموجود بنفس الاسم (بعد التطبيع)، ويحدّث الموقع إن أُعطي.
  Future<Shop> create({required String name, double? latitude, double? longitude});

  Future<void> setFavorite(String shopId, {required bool favorite});

  /// المفضلة مع متوسطات تقييمات المستخدم نفسه.
  Future<List<Shop>> favorites();
}
