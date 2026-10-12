// نوع `env` من "cloudflare:workers" في الاختبارات = Env الخادم.
import type { Env as WorkerEnv } from "../src/config";

declare global {
  namespace Cloudflare {
    interface Env extends WorkerEnv {}
  }
}
