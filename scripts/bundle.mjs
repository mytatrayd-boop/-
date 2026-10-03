// يبني صفحة واحدة فيها الواجهة + وحدات server/ المطلوبة (بدون خادم). يستخدمه build-standalone و build-android.
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = f => readFile(path.join(ROOT, f), 'utf8');

// نتائج المختبر وقت البناء (إن وُجدت): top5 كما هو، و backtest بالأسابيع والحساب فقط، وملخص spike و spikes-today.
// ترجع سطر JS يعرّف window.RASED_LAB (أو null) — التطبيق يحدّثها من GitHub وقت التشغيل.
export async function labScript() {
  const json = async f => { try { return JSON.parse(await read(`lab/results/${f}.json`)); } catch { return null; } };
  const top5 = await json('top5'), bt = await json('backtest'), sp = await json('spike'), spikesToday = await json('spikes-today');
  const backtest = bt ? { generatedAt: bt.generatedAt, source: bt.source, dataFrom: bt.dataFrom, dataTo: bt.dataTo, weeks: bt.weeks || [], account: bt.account || null } : null;
  // انفجار السيولة: ملخص المختبر (بدون الصفقات) + آخر مسح ليلي كما هو
  const spike = sp ? { generatedAt: sp.generatedAt, source: sp.source, dataFrom: sp.dataFrom, dataTo: sp.dataTo, defaultKey: sp.defaultKey, default: sp.default || null, account: sp.account || null, walkForward: sp.walkForward || null } : null;
  const lab = top5 || backtest || spike || spikesToday ? { top5, backtest, spike, spikesToday } : null;
  return `window.RASED_LAB = ${JSON.stringify(lab).replace(/</g, '\\u003c')};`;
}

// يحوّل وحدة ES بسيطة إلى نطاق مغلق يعيد صادراتها
function wrapModule(name, src) {
  const exported = [];
  const body = src
    .replace(/^import \{([^}]+)\} from '\.\/([\w-]+)\.js';$/gm, (_, names, mod) => `const {${names}} = __mods['${mod}'];`)
    .replace(/^export (async function|function|const|let|class) (\w+)/gm, (_, kind, id) => { exported.push(id); return `${kind} ${id}`; });
  if (/^\s*(import|export)\b/m.test(body)) throw new Error(`${name}: صيغة import/export غير مدعومة في البناء`);
  return `__mods['${name}'] = (() => {\n${body}\nreturn { ${exported.join(', ')} };\n})();`;
}

// modules: أسماء ملفات server/ بترتيب الاعتماد. init: كود يعرّف window.RASED_LOCAL من __mods.
// document=true: صفحة HTML كاملة (تطبيق الأندرويد)، وإلا جزء بدون <html>/<head>/<body> (Claude Artifact).
export async function buildPage({ modules, init, head = '', css: extraCss = '', document = false }) {
  const html = await read('public/index.html');
  const title = html.match(/<title>[\s\S]*?<\/title>/)[0];
  const fonts = html.match(/<link rel="preconnect"[^>]*>\s*<link href="https:\/\/fonts[^>]*>/)[0];
  const body = html.match(/<body>([\s\S]*)<\/body>/)[1].replace(/<script type="module" src="app\.js"><\/script>/, '');
  const css = (await read('public/app.css')) + extraCss;
  const bundled = (await Promise.all(modules.map(async m => wrapModule(m, await read(`server/${m}.js`))))).join('\n\n');
  const scripts = `<script>
(() => {
'use strict';
const __mods = {};
${bundled}
${init}
})();
</script>
<script>
(() => {
${await read('public/app.js')}
})();
</script>`;
  const headPart = `${title}\n${head}\n${fonts}\n<style>\n${css}\n</style>`;
  return document
    ? `<!DOCTYPE html>\n<html dir="rtl" lang="ar">\n<head>\n<meta charset="UTF-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n${headPart}\n</head>\n<body>\n${body.trim()}\n${scripts}\n</body>\n</html>\n`
    : `${headPart}\n${body.trim()}\n${scripts}\n`;
}
