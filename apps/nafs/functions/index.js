// دالة سحابية: يولّد المعلم المسجّل مسودات أسئلة لمؤشر. المفتاح في Secret Manager ولا يصل المتصفح.
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import Anthropic from '@anthropic-ai/sdk';
import { MODEL, buildPrompt, parseResult } from './generate.js';

const apiKey = defineSecret('ANTHROPIC_API_KEY');

export const generateQuestions = onCall({ secrets: [apiKey], timeoutSeconds: 120, maxInstances: 5 }, async (req) => {
    if (req.auth?.token?.firebase?.sign_in_provider !== 'password') throw new HttpsError('unauthenticated', 'للمعلمين فقط.');
    const { subject, grade, outcome, indicator } = req.data ?? {};
    if (!['reading', 'math', 'science'].includes(subject) || ![3, 6, 9].includes(grade) || typeof indicator !== 'string' || indicator.length > 600 || typeof outcome !== 'string' || outcome.length > 300) {
        throw new HttpsError('invalid-argument', 'بيانات غير صحيحة.');
    }
    const client = new Anthropic({ apiKey: apiKey.value() });
    const msg = await client.messages.create({ model: MODEL, max_tokens: 2000, messages: [{ role: 'user', content: buildPrompt({ subject, grade, outcome, indicator }) }] });
    try {
        return { result: parseResult(msg.content.map((b) => b.text ?? '').join('')) };
    } catch {
        throw new HttpsError('internal', 'تعذر فهم رد الخدمة، أعد المحاولة.');
    }
});
