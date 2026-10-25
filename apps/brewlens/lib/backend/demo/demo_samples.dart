import '../../domain/models/coffee_type.dart';

/// بيانات وضع العرض النموذجية. هذه «مخرجات الخادم» المحاكاة وليست نصوص واجهة.

/// رد ثابت لصورة مرفوضة حسب عقد SPEC §3.1.
const demoRejectedJson = <String, dynamic>{
  'image_valid': false,
  'reason': 'not_coffee',
  'score': null,
  'notes': <String>[],
  'tip': null,
};

/// رد ثابت لصورة صالحة حسب عقد SPEC §3.1 ولغة الواجهة.
Map<String, dynamic> demoResultJson(CoffeeType type, String languageCode) {
  final ar = languageCode == 'ar';
  return switch (type) {
    CoffeeType.espresso => {
        'image_valid': true,
        'reason': null,
        'score': 7.5,
        'notes': ar
            ? [
                'كريما بنية متجانسة بسماكة جيدة تغطي السطح كاملاً.',
                'بقع فاتحة قليلة عند الحافة تدل على استخلاص أسرع قليلاً.',
                'الكوب نظيف والتقديم مرتب على الصحن.',
              ]
            : [
                'Even hazel crema with good thickness covering the whole surface.',
                'A few pale spots near the rim suggest a slightly fast extraction.',
                'Clean cup and a tidy presentation on the saucer.',
              ],
        'tip': ar
            ? 'جرّب طحناً أنعم قليلاً لكريما أغمق وأكثر تجانساً عند الحافة.'
            : 'Try a slightly finer grind for darker, more even crema at the rim.',
      },
    CoffeeType.v60 => {
        'image_valid': true,
        'reason': null,
        'score': 7.0,
        'notes': ar
            ? [
                'القهوة صافية بلون عنبري يدل على تحميص فاتح إلى متوسط.',
                'لا رواسب ظاهرة في قاع الكوب.',
                'الكوب الزجاجي نظيف ويُظهر اللون جيداً.',
              ]
            : [
                'Clear cup with an amber colour typical of a light-medium roast.',
                'No visible sediment at the bottom of the cup.',
                'The clean glass shows the colour well.',
              ],
        'tip': ar
            ? 'قدّمها في كوب شفاف وإضاءة طبيعية ليظهر صفاؤها في الصورة.'
            : 'Serve in clear glass under natural light to show its clarity.',
      },
    CoffeeType.frenchPress => {
        'image_valid': true,
        'reason': null,
        'score': 6.5,
        'notes': ar
            ? [
                'لون بني داكن متجانس وقوام كثيف كما هو متوقع.',
                'طبقة رقيقة من الزيوت على السطح.',
                'بعض الرواسب الناعمة ظاهرة قرب القاع.',
              ]
            : [
                'Even dark brown colour with the expected full body.',
                'A thin layer of oils on the surface.',
                'Some fine sediment is visible near the bottom.',
              ],
        'tip': ar
            ? 'اسكبها ببطء واترك آخر القهوة في الإبريق لتقليل الرواسب.'
            : 'Pour slowly and leave the last bit in the press to cut sediment.',
      },
  };
}

/// مقاهٍ نموذجية في الرياض تُحفظ مسبقاً في وضع العرض (SPEC F1 معيار 5: 3 مقاهٍ).
const demoSeedShops = <Map<String, Object>>[
  {'id': 'demo-shop-1', 'name': 'مقهى النخيل', 'latitude': 24.7136, 'longitude': 46.6753},
  {'id': 'demo-shop-2', 'name': 'Qahwa Lab', 'latitude': 24.6911, 'longitude': 46.6855},
  {'id': 'demo-shop-3', 'name': 'بُن الدرعية', 'latitude': 24.7378, 'longitude': 46.5766},
];
