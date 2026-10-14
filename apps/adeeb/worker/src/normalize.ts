/**
 * نقل حرفي لـ `lib/text/arabic_normalizer.dart` (ARCHITECTURE §6) إلى TypeScript
 * للتحقق من الاقتباس في الخادم. يعمل على وحدات UTF-16 مثل Dart تماماً.
 *
 * أي تعديل هنا يجب أن يطابق ملف Dart، والعكس؛ الحالات المشتركة مختبرة في
 * `test/normalize.test.ts` بنفس توقعات `test/text/arabic_normalizer_test.dart`.
 */

const SPACE = 0x20;
const DROP = -1;
const SEPARATOR = -2;

function classify(c: number): number {
  // حروف لاتينية وأرقام.
  if (c >= 0x61 && c <= 0x7a) return c;
  if (c >= 0x41 && c <= 0x5a) return c + 0x20;
  if (c >= 0x30 && c <= 0x39) return c;
  if (c < 0x0600) return SEPARATOR;
  // التشكيل وعلامات القرآن والتطويل.
  if (c >= 0x064b && c <= 0x065f) return DROP;
  if (c === 0x0670 || c === 0x0640) return DROP;
  if (c >= 0x0610 && c <= 0x061a) return DROP;
  if (c >= 0x06d6 && c <= 0x06ed) return DROP;
  // الأرقام الهندية (٠-٩) والفارسية (۰-۹).
  if (c >= 0x0660 && c <= 0x0669) return 0x30 + c - 0x0660;
  if (c >= 0x06f0 && c <= 0x06f9) return 0x30 + c - 0x06f0;
  switch (c) {
    case 0x0622:
    case 0x0623:
    case 0x0625:
    case 0x0671:
    case 0x0672:
    case 0x0673:
      return 0x0627; // ا
    case 0x0624:
      return 0x0648; // و
    case 0x0626:
    case 0x0649:
    case 0x06cc:
      return 0x064a; // ي
    case 0x0629:
      return 0x0647; // ه
    case 0x06a9:
      return 0x0643; // ك
  }
  // الحروف العربية الأساسية والممتدة.
  if (c >= 0x0621 && c <= 0x063a) return c;
  if (c >= 0x0641 && c <= 0x064a) return c;
  if (c >= 0x0674 && c <= 0x06d3) return c;
  if (c >= 0x06fa && c <= 0x06fc) return c;
  // محارف الوصل والفصل والاتجاه غير المرئية لا تقطع الكلمة.
  if (c === 0x200c || c === 0x200d || c === 0xfeff) return DROP;
  if (c >= 0x200e && c <= 0x200f) return DROP;
  if (c >= 0x202a && c <= 0x202e) return DROP;
  if (c >= 0x2066 && c <= 0x2069) return DROP;
  return SEPARATOR;
}

/** يطبّع [input] كما يفعل `normalizeArabic` في التطبيق. */
export function normalizeArabic(input: string): string {
  const out: number[] = [];
  for (let i = 0; i < input.length; i++) {
    const kind = classify(input.charCodeAt(i));
    if (kind === DROP) continue;
    if (kind === SEPARATOR) {
      if (out.length > 0 && out[out.length - 1] !== SPACE) out.push(SPACE);
      continue;
    }
    out.push(kind);
  }
  if (out.length > 0 && out[out.length - 1] === SPACE) out.pop();
  let s = "";
  // تجنّب تجاوز حد الوسائط في fromCharCode للنصوص الطويلة.
  for (let i = 0; i < out.length; i += 4096) {
    s += String.fromCharCode(...out.slice(i, i + 4096));
  }
  return s;
}
