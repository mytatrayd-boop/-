// يولّد skills.json (الناتج والمؤشرات) لأدوات الاستيراد: node dump-skills.mjs > skills.json
import { outcomesFor } from '../../src/skills.js';
const o = {};
for (const [s, g] of [['math', 3], ['math', 6], ['math', 9], ['science', 6], ['science', 9], ['reading', 3], ['reading', 6], ['reading', 9]]) o[s + g] = outcomesFor(s, g);
console.log(JSON.stringify(o));
