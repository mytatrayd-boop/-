// Entry point when deployed as Firebase Cloud Functions (needs the Blaze plan).
// The default deployment is Vercel (api/[name].ts), which uses the same handlers.
import { setGlobalOptions } from "firebase-functions/v2";
import { onCall, HttpsError } from "firebase-functions/https";
import { REGION } from "./config";
import { ApiError } from "./db";
import { handlers } from "./http";

setGlobalOptions({ region: REGION, maxInstances: 10, memory: "256MiB" });

const wrap = (name: string) =>
  onCall({ secrets: ["RESEND_API_KEY", "GMAIL_APP_PASSWORD"] }, async (req) => {
    try {
      return await handlers[name](req.data, {
        uid: req.auth?.uid,
        familyId: req.auth?.token?.familyId as string | undefined,
        ip: req.rawRequest?.ip,
      });
    } catch (e) {
      if (e instanceof ApiError) throw new HttpsError(e.kind, e.code, e.details);
      throw e;
    }
  });

export const requestCode = wrap("requestCode");
export const verifyCode = wrap("verifyCode");
export const api = wrap("api");
export const sendFeedback = wrap("sendFeedback");
