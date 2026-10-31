// نقطة الدخول: لا تصدّر إلا المعالج الافتراضي وأصناف Durable Objects (يشترطه workerd).
import { handle, productionDeps, type Env } from './handler';

export { UserQuota, Limiter } from './quota';

export default {
  fetch: (req: Request, env: Env) => handle(req, env, productionDeps(env)),
};
