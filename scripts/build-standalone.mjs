// يبني dist/rased-standalone.html: التطبيق كاملاً في ملف واحد بدون خادم (وضع تجريبي فقط).
// نفس كود الواجهة ونفس منطق المسح (engine + scan)، مع المزوّد التجريبي بدل Alpha Vantage.
// الناتج جزء HTML بدون <html>/<head>/<body> — مناسب للنشر كـ Claude Artifact.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = f => readFile(path.join(ROOT, f), 'utf8');

// يحوّل وحدة ES بسيطة إلى نطاق مغلق يعيد صادراتها
function wrapModule(name, src) {
  const exported = [];
  const body = src
    .replace(/^import \{([^}]+)\} from '\.\/([\w-]+)\.js';$/gm, (_, names, mod) => `const {${names}} = __mods['${mod}'];`)
    .replace(/^export (async function|function|const|let|class) (\w+)/gm, (_, kind, id) => { exported.push(id); return `${kind} ${id}`; });
  if (/^\s*(import|export)\b/m.test(body)) throw new Error(`${name}: صيغة import/export غير مدعومة في البناء`);
  return `__mods['${name}'] = (() => {\n${body}\nreturn { ${exported.join(', ')} };\n})();`;
}

const html = await read('public/index.html');
const title = html.match(/<title>[\s\S]*?<\/title>/)[0];
const fonts = html.match(/<link rel="preconnect"[^>]*>\s*<link href="https:\/\/fonts[^>]*>/)[0];
const body = html.match(/<body>([\s\S]*)<\/body>/)[1].replace(/<script type="module" src="app\.js"><\/script>/, '');

const css = (await read('public/app.css')) + `
/* النسخة المستقلة: إطار العرض يضيف هامش المنطقة الآمنة للصفحة، فالرأس اللاصق يلتصق تحته */
.topbar{top:env(safe-area-inset-top,0px);padding-top:10px;}
.toast{top:calc(env(safe-area-inset-top,0px) + 62px);}
body{background:var(--bg);color:var(--text);}
`;

const modules = ['engine', 'demo', 'scan'];
const bundled = (await Promise.all(modules.map(async m => wrapModule(m, await read(`server/${m}.js`))))).join('\n\n');

const out = `${title}
${fonts}
<style>
${css}
</style>
${body.trim()}
<script>
(() => {
'use strict';
const __mods = {};
${bundled}
window.RASED_LOCAL = { runScan: req => __mods.scan.runScan(req, __mods.demo.demoProviders) };
})();
</script>
<script>
(() => {
${await read('public/app.js')}
})();
</script>
`;

await mkdir(path.join(ROOT, 'dist'), { recursive: true });
const file = path.join(ROOT, 'dist', 'rased-standalone.html');
await writeFile(file, out);
console.log(`كُتب ${path.relative(ROOT, file)} (${(out.length / 1024).toFixed(1)} KB)`);
