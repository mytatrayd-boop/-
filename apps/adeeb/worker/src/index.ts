import { createHandler } from "./app";
import type { Env } from "./config";

export { CounterStore } from "./counters";

const handle = createHandler({
  fetch: (input, init) => fetch(input, init),
  now: () => Date.now(),
});

export default {
  fetch: (request, env) => handle(request, env),
} satisfies ExportedHandler<Env>;
