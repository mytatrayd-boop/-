import { describe, expect, it } from "vitest";
import { normalizeArabic } from "../src/normalize";

// نفس توقعات test/text/arabic_normalizer_test.dart في التطبيق (تطابق الدالتين).
describe("normalizeArabic (مطابق لـ lib/text/arabic_normalizer.dart)", () => {
  const cases: Record<string, string> = {
    "الحِكْمَةُ": "الحكمه",
    "أَسَدٌ": "اسد",
    "كِتَابًا": "كتابا",
    "بِكَلِمَةٍ": "بكلمه",
    "مُحَمَّدٌ": "محمد",
    "قُلْ": "قل",
    "هٰذَا": "هذا",
    "رَحْمٰنِ": "رحمن",
    "ٱلْكِتَٰبُ": "الكتب",
    "الحـــكمة": "الحكمه",
    "كـتـاب": "كتاب",
    "أسد": "اسد",
    "إنسان": "انسان",
    "آخر": "اخر",
    "ٱسم": "اسم",
    "مؤمن": "مومن",
    "سئل": "سيل",
    "بئر": "بير",
    "سماء": "سماء",
    "شيء": "شيء",
    "ءامن": "ءامن",
    "مدرسة": "مدرسه",
    "على": "علي",
    "مستشفى": "مستشفي",
    "علی": "علي",
    "کتاب": "كتاب",
    "قال: «نعم»، ثم؟ ذهب!": "قال نعم ثم ذهب",
    "أ.ب,ج;د(هـ)": "ا ب ج د ه",
    "كلمة؛ كلمة": "كلمه كلمه",
    "  شطر\tشطر\nبيت   ثان  ": "شطر شطر بيت ثان",
    "سنة ٢٥٥هـ": "سنه 255ه",
    "۱۲۳": "123",
    "Gemini GitHub": "gemini github",
    "كت‌اب": "كتاب",
    "‏كتاب‎": "كتاب",
    "": "",
    " ،. ! ": "",
    "ًٌٍ": "",
  };
  for (const [input, expected] of Object.entries(cases)) {
    it(`«${input}» ← «${expected}»`, () => expect(normalizeArabic(input)).toBe(expected));
  }

  it("كل علامات التشكيل U+064B–U+0652 وعلامات القرآن تُحذف", () => {
    const marks = [];
    for (let c = 0x064b; c <= 0x0652; c++) marks.push(c);
    marks.push(0x0610, 0x0615, 0x061a, 0x06d6, 0x06da, 0x06e5, 0x06ed);
    for (const c of marks) expect(normalizeArabic(`ب${String.fromCharCode(c)}ت`)).toBe("بت");
  });

  it("الأشكال المفكوكة تساوي المركّبة", () => {
    expect(normalizeArabic("أسد")).toBe(normalizeArabic("أسد"));
    expect(normalizeArabic("آخر")).toBe(normalizeArabic("آخر"));
    expect(normalizeArabic("ؤمن")).toBe(normalizeArabic("ؤمن"));
  });

  it("ثابت: تطبيع المطبَّع لا يغيّره، ويعمل على نص طويل", () => {
    for (const s of ["الحِكْمَةُ والأَسَدُ", "إلى آخره؛ مؤتمر", "شيءٌ ـ ٣"]) {
      expect(normalizeArabic(normalizeArabic(s))).toBe(normalizeArabic(s));
    }
    expect(normalizeArabic("كلمة ".repeat(5000)).length).toBe(5 * 5000 - 1);
  });
});
