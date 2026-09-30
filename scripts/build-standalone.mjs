// يبني dist/rased-standalone.html: التطبيق كاملاً في ملف واحد بدون خادم (وضع تجريبي فقط).
// نفس كود الواجهة ونفس منطق المسح (engine + scan)، مع المزوّد التجريبي بدل Alpha Vantage.
// الناتج جزء HTML بدون <html>/<head>/<body> — مناسب للنشر كـ Claude Artifact.
import { writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { buildPage, ROOT } from './bundle.mjs';

const out = await buildPage({
  modules: ['engine', 'demo', 'scan'],
  init: `window.RASED_LOCAL = { runScan: req => __mods.scan.runScan(req, __mods.demo.demoProviders) };`,
  css: `
/* النسخة المستقلة: إطار العرض يضيف هامش المنطقة الآمنة للصفحة، فالرأس اللاصق يلتصق تحته */
.topbar{top:env(safe-area-inset-top,0px);padding-top:10px;}
.toast{top:calc(env(safe-area-inset-top,0px) + 62px);}
body{background:var(--bg);color:var(--text);}
`,
});

await mkdir(path.join(ROOT, 'dist'), { recursive: true });
const file = path.join(ROOT, 'dist', 'rased-standalone.html');
await writeFile(file, out);
console.log(`كُتب ${path.relative(ROOT, file)} (${(out.length / 1024).toFixed(1)} KB)`);
