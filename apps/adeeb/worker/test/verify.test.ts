import { describe, expect, it } from "vitest";
import { quoteInPassage, verifyOutput } from "../src/verify";
import { PASSAGES, TRUE_QUOTE } from "./helpers";

const [p1, p2] = PASSAGES;

describe("quoteInPassage", () => {
  it("اقتباس صحيح بلا تشكيل يطابق النص المشكول", () => {
    expect(quoteInPassage(TRUE_QUOTE, p1.text)).toBe(true);
    expect(quoteInPassage("ومن صبر على الشدة نال ما يريد", p1.text)).toBe(true);
  });
  it("اقتباس بتشكيل مختلف وترقيم مختلف يطابق", () => {
    expect(quoteInPassage("إنَّ الصَّبْرَ: مِفتاحُ الفَرَجِ!", p1.text)).toBe(true);
  });
  it("اقتباس مختلق يُرفض", () => {
    expect(quoteInPassage("إن العلم نور يهدي القلوب", p1.text)).toBe(false);
  });
  it("اقتباس جزئي (أوله صحيح وآخره مختلق) يُرفض", () => {
    expect(quoteInPassage("إن الصبر مفتاح الفرج والعلم نور", p1.text)).toBe(false);
  });
  it("اقتباس يجمع جزأين متباعدين يُرفض", () => {
    expect(quoteInPassage("قال الحكيم لتلميذه نال ما يريد", p1.text)).toBe(false);
  });
  it("أقل من 12 حرفاً بعد التطبيع يُرفض حتى لو كان موجوداً", () => {
    expect(quoteInPassage("الصبر", p1.text)).toBe(false);
  });
  it("نصف كلمة في الطرف يُرفض", () => {
    expect(quoteInPassage("بر مفتاح الفرج ومن", p1.text)).toBe(false);
  });
});

describe("verifyOutput", () => {
  it("يبقي الاقتباسات الصحيحة ويحذف الفاشلة", () => {
    const v = verifyOutput(
      {
        found: true,
        answer: " جواب ",
        citations: [
          { paragraph_id: p1.id, quote: "اقتباس مختلق تماماً لا يوجد" },
          { paragraph_id: p1.id, quote: TRUE_QUOTE },
        ],
      },
      PASSAGES,
    );
    expect(v).toEqual({ found: true, answer: "جواب", citations: [{ paragraph_id: p1.id, quote: TRUE_QUOTE }] });
  });

  it("اقتباس صحيح منسوب إلى فقرة أخرى يُرفض", () => {
    const v = verifyOutput(
      { found: true, answer: "جواب", citations: [{ paragraph_id: p2.id, quote: TRUE_QUOTE }] },
      PASSAGES,
    );
    expect(v).toEqual({ found: false, answer: "", citations: [], reason: "UNVERIFIED" });
  });

  it("معرّف غير مرسل يُرفض", () => {
    const v = verifyOutput(
      { found: true, answer: "جواب", citations: [{ paragraph_id: "kalila-b009-p00009", quote: TRUE_QUOTE }] },
      PASSAGES,
    );
    expect(v.found).toBe(false);
  });

  it("found=true بلا اقتباسات أو بإجابة فارغة ← UNVERIFIED", () => {
    expect(verifyOutput({ found: true, answer: "جواب", citations: [] }, PASSAGES)).toMatchObject({
      found: false,
      reason: "UNVERIFIED",
    });
    expect(
      verifyOutput({ found: true, answer: "  ", citations: [{ paragraph_id: p1.id, quote: TRUE_QUOTE }] }, PASSAGES),
    ).toMatchObject({ found: false, reason: "UNVERIFIED" });
  });

  it("found=false ← NOT_FOUND ولا يُعاد نص النموذج", () => {
    expect(
      verifyOutput({ found: false, answer: "عاصمة فرنسا باريس", citations: [{ paragraph_id: p1.id, quote: TRUE_QUOTE }] }, PASSAGES),
    ).toEqual({ found: false, answer: "", citations: [], reason: "NOT_FOUND" });
  });

  it("المكرر يُحذف والحد 3 اقتباسات", () => {
    const q = [
      TRUE_QUOTE,
      "إنّ الصبرَ مفتاحُ الفرج",
      "قال الحكيم لتلميذه إن الصبر",
      "ومن صبر على الشدة نال ما يريد",
      "مفتاح الفرج ومن صبر على الشدة",
    ];
    const v = verifyOutput(
      { found: true, answer: "جواب", citations: q.map((quote) => ({ paragraph_id: p1.id, quote })) },
      PASSAGES,
    );
    expect(v.citations.map((c) => c.quote)).toEqual([q[0], q[2], q[3]]);
  });
});
