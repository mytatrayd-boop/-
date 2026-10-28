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
