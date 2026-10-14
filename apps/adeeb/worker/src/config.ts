import type { CounterStore } from "./counters";

/** الربط والإعداد (ARCHITECTURE §8.5). الأسرار من Cloudflare Secrets أو .dev.vars فقط. */
export interface Env {
  COUNTERS: DurableObjectNamespace<CounterStore>;
  RL_DEVICE: RateLimit;
  RL_IP: RateLimit;

  // Secrets
  GEMINI_API_KEY?: string;
  DEVICE_SALT?: string;
  IP_SALT?: string;

  // Vars (wrangler.jsonc)
  GEMINI_MODEL?: string;
  GEMINI_API_BASE?: string;
  GEMINI_TIMEOUT_MS?: string | number;
  DAILY_PER_DEVICE?: string | number;
  DAILY_PER_IP?: string | number;
  DAILY_GLOBAL?: string | number;
  MIN_CLIENT?: string | number;
  MAX_BODY_BYTES?: string | number;
  MAX_QUESTION_CHARS?: string | number;
  MAX_PASSAGES?: string | number;
  MAX_PASSAGE_CHARS?: string | number;
  MAX_PASSAGES_TOTAL_CHARS?: string | number;
  MAX_ANSWER_CHARS?: string | number;
}

export interface Config {
  geminiApiKey: string;
  deviceSalt: string;
  ipSalt: string;
  geminiModel: string;
  geminiApiBase: string;
  geminiTimeoutMs: number;
  dailyPerDevice: number;
  dailyPerIp: number;
  dailyGlobal: number;
  minClient: number;
  maxBodyBytes: number;
  maxQuestionChars: number;
  maxPassages: number;
  maxPassageChars: number;
  maxPassagesTotalChars: number;
  maxAnswerChars: number;
}

export class ConfigError extends Error {}

function int(value: string | number | undefined, name: string, min = 1): number {
  const n = typeof value === "number" ? value : Number(value);
  if (value === undefined || value === "" || !Number.isInteger(n) || n < min) {
    throw new ConfigError(name);
  }
  return n;
}

function str(value: string | undefined, name: string): string {
  if (typeof value !== "string" || value.trim() === "") throw new ConfigError(name);
  return value.trim();
}

/** يقرأ الإعداد ويرمي [ConfigError] باسم الحقل الناقص (لا قيمته) إن نقص شيء. */
export function readConfig(env: Env): Config {
  return {
    geminiApiKey: str(env.GEMINI_API_KEY, "GEMINI_API_KEY"),
    deviceSalt: str(env.DEVICE_SALT, "DEVICE_SALT"),
    ipSalt: str(env.IP_SALT, "IP_SALT"),
    geminiModel: str(env.GEMINI_MODEL, "GEMINI_MODEL"),
    geminiApiBase: str(env.GEMINI_API_BASE, "GEMINI_API_BASE").replace(/\/+$/, ""),
    geminiTimeoutMs: int(env.GEMINI_TIMEOUT_MS, "GEMINI_TIMEOUT_MS"),
    dailyPerDevice: int(env.DAILY_PER_DEVICE, "DAILY_PER_DEVICE"),
    dailyPerIp: int(env.DAILY_PER_IP, "DAILY_PER_IP"),
    dailyGlobal: int(env.DAILY_GLOBAL, "DAILY_GLOBAL"),
    minClient: int(env.MIN_CLIENT, "MIN_CLIENT", 0),
    maxBodyBytes: int(env.MAX_BODY_BYTES, "MAX_BODY_BYTES"),
    maxQuestionChars: int(env.MAX_QUESTION_CHARS, "MAX_QUESTION_CHARS"),
    maxPassages: int(env.MAX_PASSAGES, "MAX_PASSAGES"),
    maxPassageChars: int(env.MAX_PASSAGE_CHARS, "MAX_PASSAGE_CHARS"),
    maxPassagesTotalChars: int(env.MAX_PASSAGES_TOTAL_CHARS, "MAX_PASSAGES_TOTAL_CHARS"),
    maxAnswerChars: int(env.MAX_ANSWER_CHARS, "MAX_ANSWER_CHARS"),
  };
}
