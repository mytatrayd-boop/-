const encoder = new TextEncoder();

/** HMAC-SHA256 بالملح السري، ست عشري. لا يُخزَّن المعرّف ولا IP خاماً (D11). */
export async function hmacHex(salt: string, value: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(salt),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, encoder.encode(value)));
  let hex = "";
  for (const b of sig) hex += b.toString(16).padStart(2, "0");
  return hex;
}
