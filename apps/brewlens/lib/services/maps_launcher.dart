import 'package:url_launcher/url_launcher.dart';

import '../domain/models/shop.dart';

/// رابط Google Maps URLs المجاني بلا مفتاح (D14، D22): بالإحداثيات إن وُجدت،
/// وإلا بالاسم مُرمَّزاً.
Uri googleMapsUri(Shop shop) {
  final query = shop.hasLocation
      ? '${shop.latitude},${shop.longitude}'
      : Uri.encodeComponent(shop.name.trim());
  return Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
}

abstract interface class MapsLauncher {
  /// يفتح تطبيق الخرائط أو المتصفح؛ false إن تعذّر.
  Future<bool> open(Shop shop);
}

class UrlMapsLauncher implements MapsLauncher {
  const UrlMapsLauncher();

  @override
  Future<bool> open(Shop shop) async {
    try {
      return await launchUrl(googleMapsUri(shop), mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}
