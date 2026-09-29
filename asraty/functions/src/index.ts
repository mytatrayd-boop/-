import { setGlobalOptions } from "firebase-functions/v2";
import { REGION } from "./config";

setGlobalOptions({ region: REGION, maxInstances: 10, memory: "256MiB" });

export { requestCode, verifyCode } from "./authCodes";
export { api } from "./api";
export { sendFeedback } from "./feedback";
