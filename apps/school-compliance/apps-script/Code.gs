/**
 * فاحص امتثال الشواهد المدرسية — Google Apps Script
 *
 * يقرأ مجلد السحابة المدرسية بكل مجلداته الفرعية، ويطابق كل ملف مع المؤشرات الـ 12
 * المعروضة في الصفحة، ثم يحسب نسبة امتثال موزونة حسب أوزان المجالات.
 *
 * طريقة المطابقة (من الأقوى إلى الأضعف):
 *  1. رقم المؤشر في اسم المجلد أو الملف (مثل "1.2" أو "1-2" أو "م1.2").
 *  2. كلمات المؤشر المفتاحية في مسار الملف واسمه، بعد توحيد الحروف العربية.
 *  3. محتوى الملف للملفات التي لم تُحسم من اسمها: مستندات وجداول وعروض جوجل،
 *     وملفات PDF وWord والصور (عبر تحويلها إلى نص بخدمة Drive مع OCR عربي).
 *     نتيجة قراءة كل ملف تُحفظ مؤقتاً 6 ساعات، فإعادة الفحص تكمل ما لم يُقرأ.
 *
 * يتطلب تفعيل الخدمة المتقدمة Drive API في المحرر: Services ثم + ثم Drive API.
 *
 * حالة كل مؤشر:
 *  ok   مكتمل: شاهدان فأكثر غير فارغين، وأحدها على الأقل محدَّث خلال المدة المحددة.
 *  part جزئي: شاهد واحد، أو شواهد قديمة كلها.
 *  miss غير موجود.
 */

var CONFIG = {
  MIN_FILES_OK: 2,          // عدد الشواهد المطلوب لاعتبار المؤشر مكتملاً
  RECENT_DAYS: 365,         // الشاهد "حديث" إذا عُدّل خلال هذه المدة
  MAX_FILES: 3000,          // حد أعلى لعدد الملفات المفحوصة (حماية من مهلة الست دقائق)
  MAX_CONTENT_READS: 60,    // حد أعلى لعدد الملفات التي يُقرأ محتواها في الفحص الواحد
  CONTENT_TIME_MS: 270000,  // التوقف عن قراءة المحتوى بعد 4.5 دقائق (جوجل يوقف السكربت عند 6)
  MAX_OCR_BYTES: 10485760,  // لا يُحوَّل ملف أكبر من 10 ميجابايت
  CONTENT_CHARS: 6000,      // عدد الأحرف المقروءة من كل ملف
  MIN_KEYWORD_HITS: 2       // عدد الكلمات المفتاحية المطلوب للمطابقة من الاسم وحده
};

var DOMAINS = [
  { id: 1, name: 'القيادة المدرسية', weight: 25 },
  { id: 2, name: 'التعليم والتعلم', weight: 35 },
  { id: 3, name: 'البيئة المدرسية', weight: 20 },
  { id: 4, name: 'نواتج التعلم', weight: 20 }
];

// المؤشرات مطابقة لما في الصفحة. الكلمات تُكتب بأي صيغة، وتُوحَّد تلقائياً.
// strong: كلمة واحدة منها تكفي للمطابقة. keywords: يلزم منها MIN_KEYWORD_HITS.
var INDICATORS = [
  { code: '1.1', domain: 1, ind: 'الخطة التشغيلية ومؤشرات الأداء', doc: 'الخطة التشغيلية المعتمدة ومؤشرات الأداء',
    strong: ['الخطة التشغيلية', 'خطة تشغيلية', 'مؤشرات الاداء'], keywords: ['خطة', 'تشغيلية', 'مؤشرات', 'اداء', 'برنامج زمني'] },
  { code: '1.2', domain: 1, ind: 'التقويم الذاتي وخطط التحسين', doc: 'تقرير التقويم الذاتي وخطة التحسين',
    strong: ['التقويم الذاتي', 'التقييم الذاتي', 'خطة التحسين', 'خطط التحسين'], keywords: ['تقويم', 'تقييم', 'ذاتي', 'تحسين'] },
  { code: '1.3', domain: 1, ind: 'تطوير الكادر وتنمية الأداء', doc: 'خطة التطوير المهني وسجلات التدريب',
    strong: ['التطوير المهني', 'تنمية مهنية', 'مجتمعات التعلم'], keywords: ['تطوير', 'مهني', 'تدريب', 'دورة', 'ورشة', 'كادر', 'منسوبين'] },

  { code: '2.1', domain: 2, ind: 'استراتيجيات التدريس الحديثة وتفعيلها', doc: 'نماذج التخطيط والزيارات الصفية',
    strong: ['استراتيجيات التدريس', 'زيارات صفية', 'الزيارات الصفية', 'تبادل الزيارات'], keywords: ['استراتيجية', 'استراتيجيات', 'تدريس', 'زيارة', 'صفية', 'تحضير', 'تخطيط'] },
  { code: '2.2', domain: 2, ind: 'أدوات التقييم التكويني المستمر', doc: 'أدوات وسجلات التقويم التكويني',
    strong: ['التقويم التكويني', 'التقييم التكويني', 'التقويم المستمر'], keywords: ['تقويم', 'تقييم', 'تكويني', 'مستمر', 'اختبار قصير', 'سجل متابعة'] },
  { code: '2.3', domain: 2, ind: 'خطط رعاية الموهوبين ودعم الفئات', doc: 'خطط رعاية الموهوبين وبرامج الدعم',
    strong: ['الموهوبين', 'موهوبين', 'صعوبات التعلم', 'المتعثرين'], keywords: ['موهوب', 'رعاية', 'دعم', 'فئات', 'متعثر', 'علاجي', 'اثرائي'] },

  { code: '3.1', domain: 3, ind: 'اشتراطات الأمن والسلامة وإجراءات الإخلاء', doc: 'خطة الإخلاء وتقارير الأمن والسلامة',
    strong: ['الامن والسلامة', 'الأمن والسلامة', 'خطة الاخلاء', 'تجربة الاخلاء'], keywords: ['امن', 'سلامة', 'اخلاء', 'طوارئ', 'حريق', 'دفاع مدني'] },
  { code: '3.2', domain: 3, ind: 'برامج التوجيه الطلابي والانضباط', doc: 'سجلات التوجيه الطلابي وقواعد السلوك والمواظبة',
    strong: ['التوجيه الطلابي', 'الارشاد الطلابي', 'قواعد السلوك', 'السلوك والمواظبة'], keywords: ['توجيه', 'ارشاد', 'سلوك', 'مواظبة', 'انضباط', 'غياب'] },
  { code: '3.3', domain: 3, ind: 'جاهزية المعامل والمرافق التقنية', doc: 'سجلات المعامل وصيانة المرافق التقنية',
    strong: ['المعامل', 'مصادر التعلم', 'المرافق التقنية', 'المواطنة الرقمية'], keywords: ['معمل', 'مختبر', 'مرافق', 'تقنية', 'صيانة', 'حاسب', 'جاهزية'] },

  { code: '4.1', domain: 4, ind: 'تحليل نتائج التحصيل واختبارات نافس', doc: 'تحليل نتائج نافس والاختبارات',
    strong: ['نافس', 'تحليل النتائج', 'تحليل نتائج'], keywords: ['تحليل', 'نتائج', 'تحصيل', 'اختبارات', 'درجات', 'مركزية'] },
  { code: '4.2', domain: 4, ind: 'تعزيز القيم الوطنية والسلوك الإيجابي', doc: 'برامج القيم الوطنية والسلوك الإيجابي',
    strong: ['القيم الوطنية', 'السلوك الايجابي', 'اليوم الوطني', 'يوم التاسيس'], keywords: ['قيم', 'وطنية', 'وطني', 'سلوك', 'ايجابي', 'هوية', 'مواطنة'] },
  { code: '4.3', domain: 4, ind: 'خطط معالجة الفجوات التعليمية', doc: 'خطط علاج الفجوات والفاقد التعليمي',
    strong: ['الفجوات', 'الفاقد التعليمي', 'خطة علاجية', 'الخطط العلاجية'], keywords: ['فجوة', 'فجوات', 'فاقد', 'علاج', 'علاجية', 'معالجة'] }
];

function doGet(e) {
  var out;
  try {
    var url = (e && e.parameter && e.parameter.url) || '';
    var folderId = extractFolderId(url);
    if (!folderId) throw new Error('رابط المجلد غير صحيح. انسخ رابط مجلد Google Drive كاملاً.');
    var folder;
    try {
      folder = DriveApp.getFolderById(folderId);
    } catch (err) {
      throw new Error('تعذّر فتح المجلد. تأكد أن مشاركته "أي شخص لديه الرابط" أو أنه مشارك مع صاحب السكربت.');
    }
    out = evaluateFiles(collectFiles(folder));
  } catch (err) {
    out = { error: err.message };
  }
  return ContentService.createTextOutput(JSON.stringify(out)).setMimeType(ContentService.MimeType.JSON);
}

function extractFolderId(url) {
  var m = String(url).match(/\/folders\/([a-zA-Z0-9_-]{10,})/) ||
          String(url).match(/[?&]id=([a-zA-Z0-9_-]{10,})/);
  return m ? m[1] : null;
}

// يجمع كل الملفات تحت المجلد مع مساراتها، ويتبع الاختصارات (Shortcuts).
function collectFiles(root) {
  var files = [];
  var seen = {};
  var stack = [{ folder: root, path: '' }];
  while (stack.length && files.length < CONFIG.MAX_FILES) {
    var cur = stack.pop();
    var fid = cur.folder.getId();
    if (seen[fid]) continue;
    seen[fid] = true;

    var fit = cur.folder.getFiles();
    while (fit.hasNext() && files.length < CONFIG.MAX_FILES) {
      var f = fit.next();
      var mime = f.getMimeType();
      if (mime === 'application/vnd.google-apps.shortcut') {
        try {
          var targetId = f.getTargetId();
          var targetMime = f.getTargetMimeType();
          if (targetMime === MimeType.FOLDER) {
            stack.push({ folder: DriveApp.getFolderById(targetId), path: cur.path + '/' + f.getName() });
            continue;
          }
          f = DriveApp.getFileById(targetId);
          mime = f.getMimeType();
        } catch (err) { continue; }
      }
      files.push({
        id: f.getId(),
        name: f.getName(),
        path: cur.path,
        mime: mime,
        size: f.getSize(),
        updated: f.getLastUpdated().getTime(),
        url: f.getUrl()
      });
    }

    var sub = cur.folder.getFolders();
    while (sub.hasNext()) {
      var s = sub.next();
      stack.push({ folder: s, path: cur.path + '/' + s.getName() });
    }
  }
  return files;
}

function evaluateFiles(files) {
  var now = Date.now();
  var buckets = {};
  INDICATORS.forEach(function (it) { buckets[it.code] = []; });

  var unmatched = [];
  files.forEach(function (f) {
    if (isEmptyFile(f)) return;
    var code = matchByName(f);
    if (code) buckets[code].push(f); else unmatched.push(f);
  });

  // قراءة محتوى الملفات التي لم تُطابَق من الاسم
  var started = Date.now();
  var cache = CacheService.getScriptCache();
  var reads = 0, pending = 0;
  unmatched.forEach(function (f) {
    if (!isReadable(f)) return;
    var key = 'c_' + f.id + '_' + f.updated;
    var code = cache.get(key);
    if (code === null) {
      if (reads >= CONFIG.MAX_CONTENT_READS || Date.now() - started > CONFIG.CONTENT_TIME_MS) { pending++; return; }
      reads++;
      code = matchText(readContent(f), true) || '';
      cache.put(key, code, 21600);
    }
    if (code) buckets[code].push(f);
  });

  var results = INDICATORS.map(function (it) {
    var found = buckets[it.code];
    var recent = found.filter(function (f) { return now - f.updated <= CONFIG.RECENT_DAYS * 86400000; });
    var status, text;
    if (found.length >= CONFIG.MIN_FILES_OK && recent.length > 0) {
      status = 'ok'; text = 'مكتمل (' + found.length + ' شواهد)';
    } else if (found.length > 0) {
      status = 'part';
      text = recent.length === 0 ? 'جزئي: الشواهد قديمة' : 'جزئي: شاهد واحد فقط';
    } else {
      status = 'miss'; text = 'غير موجود';
    }
    var domain = DOMAINS[it.domain - 1];
    return {
      code: it.code,
      domain: domain.name,
      weight: domain.weight / 3,
      ind: it.code + ' ' + it.ind,
      doc: it.doc,
      status: status,
      text: text,
      files: found.slice(0, 5).map(function (f) { return { name: f.name, url: f.url }; })
    };
  });

  var score = 0;
  results.forEach(function (r) {
    score += r.weight * (r.status === 'ok' ? 1 : r.status === 'part' ? 0.5 : 0);
  });

  return {
    score: Math.round(score),
    scannedFiles: files.length,
    contentRead: reads,
    contentPending: pending,
    truncated: files.length >= CONFIG.MAX_FILES,
    results: results
  };
}

var OCR_MIMES = {
  'application/pdf': true,
  'application/msword': true,
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': true,
  'image/jpeg': true,
  'image/png': true,
  'image/gif': true,
  'image/bmp': true,
  'image/webp': true
};

function isReadable(f) {
  return f.mime === MimeType.GOOGLE_DOCS || f.mime === MimeType.GOOGLE_SHEETS ||
         f.mime === MimeType.GOOGLE_SLIDES || (OCR_MIMES[f.mime] && f.size <= CONFIG.MAX_OCR_BYTES);
}

// يعيد نص الملف، أو نصاً فارغاً إن تعذرت قراءته
function readContent(f) {
  var max = CONFIG.CONTENT_CHARS;
  try {
    if (f.mime === MimeType.GOOGLE_DOCS) return DocumentApp.openById(f.id).getBody().getText().slice(0, max);
    if (f.mime === MimeType.GOOGLE_SHEETS) {
      var parts = [];
      SpreadsheetApp.openById(f.id).getSheets().slice(0, 3).forEach(function (sh) {
        parts.push(sh.getName());
        var rows = Math.min(sh.getLastRow(), 40), cols = Math.min(sh.getLastColumn(), 15);
        if (rows > 0 && cols > 0) parts.push(sh.getRange(1, 1, rows, cols).getDisplayValues().join(' '));
      });
      return parts.join(' ').slice(0, max);
    }
    if (f.mime === MimeType.GOOGLE_SLIDES) {
      var texts = [];
      SlidesApp.openById(f.id).getSlides().slice(0, 15).forEach(function (sl) {
        sl.getShapes().forEach(function (sh) { try { texts.push(sh.getText().asString()); } catch (e) {} });
      });
      return texts.join(' ').slice(0, max);
    }
    return ocrText(f.id).slice(0, max);
  } catch (err) {
    return '';
  }
}

// ينسخ الملف مؤقتاً كمستند جوجل (يحوّل Word ويطبّق OCR على PDF والصور)، يقرأ نصه، ثم يحذف النسخة
function ocrText(fileId) {
  var copyId;
  try {
    if (Drive.Files.insert) { // Drive API v2
      copyId = Drive.Files.copy({ title: 'tmp-ocr', mimeType: MimeType.GOOGLE_DOCS }, fileId,
        { ocr: true, ocrLanguage: 'ar', supportsAllDrives: true }).id;
    } else { // Drive API v3
      copyId = Drive.Files.copy({ name: 'tmp-ocr', mimeType: MimeType.GOOGLE_DOCS }, fileId,
        { ocrLanguage: 'ar', supportsAllDrives: true, fields: 'id' }).id;
    }
    return DocumentApp.openById(copyId).getBody().getText();
  } finally {
    if (copyId) { try { Drive.Files.remove(copyId); } catch (e) { DriveApp.getFileById(copyId).setTrashed(true); } }
  }
}

function isEmptyFile(f) {
  // ملفات جوجل الأصلية حجمها 0 دائماً، فلا تُعد فارغة
  if (String(f.mime).indexOf('application/vnd.google-apps.') === 0) return false;
  return f.size === 0;
}

function matchByName(f) {
  var codeFromNumber = matchCode(f.path + '/' + f.name);
  if (codeFromNumber) return codeFromNumber;
  // اسم الملف أولاً، ثم المسار كاملاً (مجلد باسم المؤشر يكفي)
  return matchText(f.name, false) || matchText(f.path + ' ' + f.name, false);
}

// يلتقط أعمق رقم مؤشر في المسار مثل "1.2" أو "1-2" أو "1_2" أو "١.٢"
function matchCode(text) {
  var t = toLatinDigits(text);
  var re = /(?:^|[^0-9])([1-4])\s*[.\-_،,]\s*([1-3])(?![0-9])/g;
  var m, last = null;
  while ((m = re.exec(t)) !== null) last = m[1] + '.' + m[2];
  return last;
}

// يعيد رمز المؤشر الأعلى تطابقاً، أو null
function matchText(text, isContent) {
  var t = normalize(text);
  if (!t) return null;
  var best = null, bestScore = 0;
  INDICATORS.forEach(function (it) {
    var s = 0;
    it.strong.forEach(function (k) { if (t.indexOf(normalize(k)) !== -1) s += 3; });
    it.keywords.forEach(function (k) { if (hasWord(t, normalize(k))) s += 1; });
    var needed = isContent ? 4 : CONFIG.MIN_KEYWORD_HITS;
    if (s >= needed && s > bestScore) { best = it.code; bestScore = s; }
  });
  return best;
}

function hasWord(t, k) {
  if (k.indexOf(' ') !== -1) return t.indexOf(k) !== -1;
  // يقبل السوابق الشائعة: ال، و، ب، ل، وال، بال، لل
  var re = new RegExp('(^|\\s)(و|ب|ل|ف)?(ال|لل)?' + k);
  return re.test(t);
}

// توحيد الكتابة العربية: الهمزات، التاء المربوطة، الألف المقصورة، التشكيل، التطويل، الأرقام
function normalize(s) {
  return toLatinDigits(String(s || ''))
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, '')
    .replace(/[أإآٱ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/ؤ/g, 'و')
    .replace(/ئ/g, 'ي')
    .replace(/[_\-.\/\\()\[\]{}،,]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function toLatinDigits(s) {
  return String(s).replace(/[٠-٩]/g, function (d) { return '٠١٢٣٤٥٦٧٨٩'.indexOf(d); })
                  .replace(/[۰-۹]/g, function (d) { return '۰۱۲۳۴۵۶۷۸۹'.indexOf(d); });
}

// يُشغَّل يدوياً من محرر السكربت لتجربة مجلد قبل النشر
function testRun() {
  var res = doGet({ parameter: { url: 'ضع_رابط_مجلد_للتجربة_هنا' } });
  var data = JSON.parse(res.getContent());
  if (data.error) { Logger.log(data.error); return; }
  Logger.log('النسبة: ' + data.score + '% | الملفات: ' + data.scannedFiles +
             ' | قُرئ محتواها: ' + data.contentRead + ' | بقي: ' + data.contentPending);
  data.results.forEach(function (r) {
    Logger.log(r.ind + ' ← ' + r.text + ' | ' + r.files.map(function (f) { return f.name; }).join(' ، '));
  });
}
