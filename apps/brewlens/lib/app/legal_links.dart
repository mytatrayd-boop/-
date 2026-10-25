/// روابط الخصوصية والشروط في ملف واحد (ARCHITECTURE §13). null = لم ينشرها
/// المالك بعد، فتُعرض صفحة داخلية مؤقتة بنص مختصر.
enum LegalDoc { privacy, terms }

abstract final class LegalLinks {
  static const Uri? privacy = null;
  static const Uri? terms = null;

  static Uri? of(LegalDoc doc) => switch (doc) {
        LegalDoc.privacy => privacy,
        LegalDoc.terms => terms,
      };
}
