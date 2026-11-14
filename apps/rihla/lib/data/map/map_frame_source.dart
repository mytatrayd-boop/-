import 'package:rihla_recorder/rihla_recorder.dart';

/// إطار خريطة: بايتات RGBA + العرض + الارتفاع + طابع زمني بساعة التسجيل.
typedef MapFrame = RgbaFrame;

/// مصدر إطارات الخريطة للمُركِّب. التنفيذ الحقيقي (takeSnapshot) في F0ب.
abstract class MapFrameSource {
  Stream<MapFrame> frames();
}
