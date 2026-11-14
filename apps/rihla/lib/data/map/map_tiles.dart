import 'package:flutter/widgets.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

/// طبقة بلاطات الخريطة خلف واجهة مجردة (D15: OpenFreeMap). تُوضع كابن
/// لـFlutterMap. النسخة المزيّفة للاختبار بلا شبكة.
abstract class MapTilesSource {
  Widget buildLayer(BuildContext context);
}

/// OpenFreeMap (بلاطات متجهة، بلا مفتاح). نمط liberty.
/// تحذير: توافق vector_map_tiles مع Flutter 3.50 مُثبت بالتحليل والبناء فقط؛
/// العرض الفعلي والشبكة لم يُجرَّبا على جهاز.
class OpenFreeMapTiles implements MapTilesSource {
  const OpenFreeMapTiles();

  static const styleUrl = 'https://tiles.openfreemap.org/styles/liberty';
  @override
  Widget buildLayer(BuildContext context) => const _OpenFreeMapLayer();
}

class _OpenFreeMapLayer extends StatefulWidget {
  const _OpenFreeMapLayer();

  @override
  State<_OpenFreeMapLayer> createState() => _OpenFreeMapLayerState();
}

class _OpenFreeMapLayerState extends State<_OpenFreeMapLayer> {
  late final Future<Style> _style = StyleReader(uri: OpenFreeMapTiles.styleUrl)
      .read();

  @override
  Widget build(BuildContext context) => FutureBuilder<Style>(
    future: _style,
    builder: (context, snap) {
      if (snap.hasError) {
        // احتياطي: خلفية سادة (يبقى المسار والإسناد مرسومين).
        return const ColoredBox(
          color: Color(0xFF222C33),
          child: SizedBox.expand(),
        );
      }
      final style = snap.data;
      if (style == null) {
        return const ColoredBox(
          color: Color(0xFF222C33),
          child: SizedBox.expand(),
        );
      }
      return VectorTileLayer(
        theme: style.theme,
        sprites: style.sprites,
        tileProviders: style.providers,
        // ذاكرة مؤقتة قصيرة؛ لا استخدام دون اتصال (CLAUDE.md).
        fileCacheTtl: const Duration(hours: 1),
        fileCacheMaximumSizeInBytes: 20 * 1024 * 1024,
      );
    },
  );
}

/// نسخة مزيّفة: خلفية بلا شبكة.
class FakeMapTiles implements MapTilesSource {
  const FakeMapTiles();
  static const layerKey = ValueKey('fake-map-tiles');

  @override
  Widget buildLayer(BuildContext context) => const ColoredBox(
    key: layerKey,
    color: Color(0xFFDDDDDD),
    child: SizedBox.expand(),
  );
}
