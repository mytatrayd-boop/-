import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

// الاختبارات تعمل داخل workerd محلياً (Miniflare). Gemini مُحاكى دائماً، والأسرار
// هنا قيم وهمية للاختبار فقط.
export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.jsonc" },
      miniflare: {
        bindings: {
          GEMINI_API_KEY: "test-only-not-a-key",
          DEVICE_SALT: "test-device-salt",
          IP_SALT: "test-ip-salt",
        },
      },
    }),
  ],
  test: {
    // سطر السجل لكل طلب يُخفى في الاختبارات الناجحة.
    silent: "passed-only",
  },
});
