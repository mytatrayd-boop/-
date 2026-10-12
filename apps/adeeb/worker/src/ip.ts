/**
 * مفتاح عنوان IP للحدود (قبل HMAC): IPv4 كاملاً، وIPv6 ببادئته /64 لأن
 * المزوّد يعطي المشترك الواحد /64 كاملة عادةً، فتغيير آخر 64 بت مجاني.
 * IPv4 المضمّن في IPv6 (`::ffff:a.b.c.d`) يُعامل كـ IPv4.
 */
export function ipLimitKey(raw: string | null): string {
  const ip = (raw ?? "").trim().toLowerCase();
  if (ip === "") return "unknown";
  if (!ip.includes(":")) return `v4:${ip}`;
  const v6 = expandIpv6(ip);
  if (v6 === null) return `raw:${ip}`;
  if (v6.slice(0, 5).every((h) => h === 0) && v6[5] === 0xffff) {
    return `v4:${v6[6] >> 8}.${v6[6] & 255}.${v6[7] >> 8}.${v6[7] & 255}`;
  }
  return `v6:${v6.slice(0, 4).map((h) => h.toString(16)).join(":")}::/64`;
}

/** يفك IPv6 إلى 8 أعداد (16 بت)، أو null إن لم يكن صالحاً. */
function expandIpv6(ip: string): number[] | null {
  let s = ip.replace(/%.*$/, ""); // معرّف المنطقة
  // ذيل IPv4 (مثل ::ffff:1.2.3.4) ← مجموعتان ست عشريتان.
  const v4 = /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(s);
  if (v4) {
    const b = v4.slice(1).map(Number);
    if (b.some((x) => x > 255)) return null;
    s = s.slice(0, v4.index) + `${((b[0] << 8) | b[1]).toString(16)}:${((b[2] << 8) | b[3]).toString(16)}`;
  }
  const halves = s.split("::");
  if (halves.length > 2) return null;
  const parse = (part: string) => (part === "" ? [] : part.split(":"));
  const head = parse(halves[0]);
  const tail = halves.length === 2 ? parse(halves[1]) : [];
  const missing = 8 - head.length - tail.length;
  if (halves.length === 1 ? missing !== 0 : missing < 1) return null;
  const groups = [...head, ...Array<string>(halves.length === 2 ? missing : 0).fill("0"), ...tail];
  const out: number[] = [];
  for (const g of groups) {
    if (!/^[0-9a-f]{1,4}$/.test(g)) return null;
    out.push(parseInt(g, 16));
  }
  return out;
}
