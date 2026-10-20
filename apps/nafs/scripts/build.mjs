// يبني dist/: app.js مجمّع (Firebase + SheetJS) و app.css من Tailwind، بأسماء فيها بصمة المحتوى.
import { build } from 'esbuild';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';

const root = new URL('..', import.meta.url).pathname;
const dist = root + 'dist/';
rmSync(dist, { recursive: true, force: true });
mkdirSync(dist);

const js = await build({
    entryPoints: [root + 'src/app.js'], bundle: true, minify: true, format: 'esm', splitting: true,
    target: 'es2020', outdir: dist, entryNames: 'app.[hash]', chunkNames: 'chunk.[hash]',
    legalComments: 'none', metafile: true,
});
const jsName = Object.entries(js.metafile.outputs).find(([, o]) => o.entryPoint)[0].split('/').pop();
execFileSync(root + 'node_modules/.bin/tailwindcss', [
    '-c', root + 'tailwind.config.cjs', '-i', root + 'src/app.css', '-o', dist + 'app.tmp.css', '--minify',
], { cwd: root, stdio: 'inherit' });
const css = readFileSync(dist + 'app.tmp.css');
rmSync(dist + 'app.tmp.css');

const hash = (buf) => createHash('sha256').update(buf).digest('hex').slice(0, 10);
const cssName = `app.${hash(css)}.css`;
writeFileSync(dist + cssName, css);
const html = readFileSync(root + 'src/index.html', 'utf8')
    .replace('href="app.css"', `href="${cssName}"`)
    .replace('src="app.js"', `src="${jsName}"`);
writeFileSync(dist + 'index.html', html);
for (const [file, o] of Object.entries(js.metafile.outputs)) console.log(`${file.split('/').pop()} ${(o.bytes / 1024).toFixed(0)}KB`);
console.log(`${cssName} ${(css.length / 1024).toFixed(0)}KB`);
