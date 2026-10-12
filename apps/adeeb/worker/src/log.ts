/**
 * السجل الوحيد في الخادم (ARCHITECTURE §8.5، D15): المسار، الحالة، الزمن، رمز
 * الخطأ. لا نص سؤال ولا فقرات ولا IP ولا معرّف جهاز — الحقول ثابتة النوع.
 */
export interface LogEntry {
  path: "/v1/ask" | "/v1/quota" | "/v1/health" | "other" | string;
  status: number;
  ms: number;
  code: string;
}

export function logRequest(entry: LogEntry): void {
  console.log(
    JSON.stringify({ path: entry.path, status: entry.status, ms: entry.ms, code: entry.code }),
  );
}
