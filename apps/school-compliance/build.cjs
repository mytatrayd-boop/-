// يولّد apps-script/Code.gs من محرك التقييم المشترك وخدمة الجلب، ليُلصق ملفاً واحداً في مشروع Google Apps Script.
// التشغيل: node apps/school-compliance/build.js
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..', '..');
const engine = fs.readFileSync(path.join(root, 'docs/school-compliance/engine.js'), 'utf8');
const fetcher = fs.readFileSync(path.join(__dirname, 'apps-script/fetch.js'), 'utf8');

const header = '// ملف مُولَّد — لا تعدّله يدوياً. المصدر: docs/school-compliance/engine.js و apps/school-compliance/apps-script/fetch.js\n\n';
fs.writeFileSync(path.join(__dirname, 'apps-script/Code.gs'), header + engine + '\n\n' + fetcher);
console.log('apps-script/Code.gs written');

// رقم نسخة المحرك في الصفحة، حتى لا يعرض المتصفح نسخة قديمة محفوظة من engine.js
const hash = require('crypto').createHash('sha1').update(engine).digest('hex').slice(0, 8);
const pagePath = path.join(root, 'docs/school-compliance/index.html');
const cardsHash = require('crypto').createHash('sha1')
  .update(fs.readFileSync(path.join(root, 'docs/school-compliance/cards.js'))).digest('hex').slice(0, 8);
const page = fs.readFileSync(pagePath, 'utf8')
  .replace(/engine\.js\?v=[0-9a-z]+/, 'engine.js?v=' + hash)
  .replace(/cards\.js\?v=[0-9a-z]+/, 'cards.js?v=' + cardsHash);
fs.writeFileSync(pagePath, page);
console.log('index.html engine version ' + hash);
