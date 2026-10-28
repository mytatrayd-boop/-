/*
 * خدمة فحص السحابة المدرسية — Google Apps Script
 *
 * تستقبل رابط السحابة من الصفحة، وتقرأ قائمة الملفات بكل المجلدات الفرعية، ثم تقيّمها بمحرك التقييم
 * (ComplianceEngine أعلى هذا الملف) وتعيد النتيجة.
 *
 *  - Google Drive: كامل، مع قراءة محتوى الملفات التي لا يكفي عنوانها (يتطلب Drive API في Services).
 *  - OneDrive الشخصي (1drv.ms / onedrive.live.com): تجريبي، أسماء الملفات فقط.
 *  - SharePoint / OneDrive المدرسي: لا يمكن قراءته بلا تسجيل دخول؛ تُوجَّه الصفحة إلى رفع ملف ZIP.
 */

var FETCH = {
  MAX_FILES: 3000,
  CONTENT_TIME_MS: 240000,  // التوقف عن قراءة المحتوى بعد 4 دقائق (جوجل يوقف السكربت عند 6)
  MAX_CONTENT_READS: 60,
  PER_INDICATOR_READS: 2,   // عدد الملفات المقروءة لكل مؤشر لاستكمال دلالات التحقق
  MAX_OCR_BYTES: 10485760,
  CONTENT_CHARS: 4000
};

function doGet(e) {
  var p = (e && e.parameter) || {};
  var out;
  try {
    var opts = { schoolType: p.type === 'private' ? 'private' : 'gov', stage: p.stage || 'primary' };
    var src = detectSource(p.url || '');
    var listing;
    if (src.kind === 'google') listing = googleFiles(src.id, opts);
    else if (src.kind === 'onedrive') listing = oneDriveFiles(src.url);
    else if (src.kind === 'sharepoint')
      throw new Error('روابط SharePoint وOneDrive المدرسية تتطلب تسجيل دخول ولا يمكن قراءتها آلياً. نزّل المجلد ملف ZIP وارفعه في الصفحة من خيار "ملف ZIP".');
    else throw new Error('الرابط غير معروف. استخدم رابط مجلد Google Drive أو OneDrive، أو ارفع ملف ZIP.');

    opts.contentRead = listing.contentRead || 0;
    out = ComplianceEngine.evaluate(listing.files, opts);
    out.source = src.kind;
    out.contentRead = listing.contentRead || 0;
    out.contentPending = listing.contentPending || 0;
    out.truncated = listing.files.length >= FETCH.MAX_FILES;
    // قائمة الملفات ونصوصها لتعيد الصفحة التقييم بمحركها، فلا يلزم تحديث السكربت عند تعديل المعايير
    out.files = listing.files.map(function (f) {
      return { name: f.name, path: f.path, url: f.url, updated: f.updated, size: f.size, mime: f.mime, text: f.text || '' };
    });
  } catch (err) {
    out = { error: err.message };
  }
  return ContentService.createTextOutput(JSON.stringify(out)).setMimeType(ContentService.MimeType.JSON);
}

function detectSource(url) {
  url = String(url).trim();
  var m = url.match(/drive\.google\.com\/.*\/folders\/([a-zA-Z0-9_-]{10,})/) || url.match(/drive\.google\.com\/.*[?&]id=([a-zA-Z0-9_-]{10,})/);
  if (m) return { kind: 'google', id: m[1] };
  if (/sharepoint\.com/i.test(url)) return { kind: 'sharepoint' };
  if (/(1drv\.ms|onedrive\.live\.com)/i.test(url)) return { kind: 'onedrive', url: url };
  return { kind: 'unknown' };
}

// ───────── Google Drive ─────────
function googleFiles(folderId, opts) {
  var root;
  try {
    root = DriveApp.getFolderById(folderId);
  } catch (err) {
    throw new Error('تعذّر فتح المجلد. اجعل مشاركته "أي شخص لديه الرابط"، أو شاركه مع حساب صاحب السكربت.');
  }
  var files = [], seen = {}, stack = [{ folder: root, path: '' }];
  while (stack.length && files.length < FETCH.MAX_FILES) {
    var cur = stack.pop();
    var fid = cur.folder.getId();
    if (seen[fid]) continue;
    seen[fid] = true;
    var it = cur.folder.getFiles();
    while (it.hasNext() && files.length < FETCH.MAX_FILES) {
      var f = it.next(), mime = f.getMimeType();
      if (mime === 'application/vnd.google-apps.shortcut') {
        try {
          if (f.getTargetMimeType() === MimeType.FOLDER) {
            stack.push({ folder: DriveApp.getFolderById(f.getTargetId()), path: cur.path + '/' + f.getName() });
            continue;
          }
          f = DriveApp.getFileById(f.getTargetId());
          mime = f.getMimeType();
        } catch (err) { continue; }
      }
      files.push({ id: f.getId(), name: f.getName(), path: cur.path, mime: mime, size: f.getSize(),
                   updated: f.getLastUpdated().getTime(), url: f.getUrl() });
    }
    var sub = cur.folder.getFolders();
    while (sub.hasNext()) {
      var s = sub.next();
      stack.push({ folder: s, path: cur.path + '/' + s.getName() });
    }
  }
  var read = attachContent(files, opts);
  return { files: files, contentRead: read.read, contentPending: read.pending };
}

// يقرأ محتوى الملفات حسب الأولوية: ملفان لكل مؤشر لاستكمال الدلالات، ثم الملفات التي لم يُعرف مؤشرها
function attachContent(files, opts) {
  var started = Date.now(), cache = CacheService.getScriptCache();
  var perIndicator = {}, first = [], second = [];
  files.forEach(function (f) {
    if (!isReadable(f)) return;
    var n = ComplianceEngine.needsContent(f, opts);
    if (n.unmatched) second.push(f);
    else if (n.indicator && (perIndicator[n.indicator] = (perIndicator[n.indicator] || 0) + 1) <= FETCH.PER_INDICATOR_READS) first.push(f);
  });
  var read = 0, pending = 0;
  first.concat(second).forEach(function (f) {
    var key = 't_' + f.id + '_' + f.updated;
    var text = cache.get(key);
    if (text === null) {
      if (read >= FETCH.MAX_CONTENT_READS || Date.now() - started > FETCH.CONTENT_TIME_MS) { pending++; return; }
      read++;
      text = ComplianceEngine.normalize(readContent(f)).slice(0, FETCH.CONTENT_CHARS);
      try { cache.put(key, text, 21600); } catch (e) {}
    }
    f.text = text;
  });
  return { read: read, pending: pending };
}

var OCR_MIMES = {
  'application/pdf': true,
  'application/msword': true,
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': true,
  'image/jpeg': true, 'image/png': true, 'image/gif': true, 'image/bmp': true, 'image/webp': true
};

function isReadable(f) {
  return f.mime === MimeType.GOOGLE_DOCS || f.mime === MimeType.GOOGLE_SHEETS ||
         f.mime === MimeType.GOOGLE_SLIDES || (OCR_MIMES[f.mime] && f.size <= FETCH.MAX_OCR_BYTES);
}

function readContent(f) {
  try {
    if (f.mime === MimeType.GOOGLE_DOCS) return DocumentApp.openById(f.id).getBody().getText();
    if (f.mime === MimeType.GOOGLE_SHEETS) {
      var parts = [];
      SpreadsheetApp.openById(f.id).getSheets().slice(0, 3).forEach(function (sh) {
        parts.push(sh.getName());
        var rows = Math.min(sh.getLastRow(), 40), cols = Math.min(sh.getLastColumn(), 15);
        if (rows > 0 && cols > 0) parts.push(sh.getRange(1, 1, rows, cols).getDisplayValues().join(' '));
      });
      return parts.join(' ');
    }
    if (f.mime === MimeType.GOOGLE_SLIDES) {
      var texts = [];
      SlidesApp.openById(f.id).getSlides().slice(0, 15).forEach(function (sl) {
        sl.getShapes().forEach(function (sh) { try { texts.push(sh.getText().asString()); } catch (e) {} });
      });
      return texts.join(' ');
    }
    return ocrText(f.id);
  } catch (err) {
    return '';
  }
}

// ينسخ الملف مؤقتاً كمستند جوجل (يحوّل Word ويطبّق OCR عربياً على PDF والصور)، يقرأ نصه ثم يحذف النسخة
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

// ───────── OneDrive الشخصي (تجريبي) ─────────
// يستعمل الطريقة التي يفتح بها موقع OneDrive الروابط العامة دون تسجيل دخول. قد تتغير من مايكروسوفت دون إشعار.
function oneDriveFiles(shareUrl) {
  var tokRes = UrlFetchApp.fetch('https://api-badgerp.svc.ms/v1.0/token', {
    method: 'post', contentType: 'application/json', muteHttpExceptions: true,
    payload: JSON.stringify({ appId: '5cbed6ac-a083-4e14-b191-b4ba07653de2' })
  });
  if (tokRes.getResponseCode() !== 200) throw new Error(oneDriveFailMessage());
  var headers = { Authorization: 'Badger ' + JSON.parse(tokRes.getContentText()).token, Prefer: 'autoredeem' };
  var base = 'https://my.microsoftpersonalcontent.com/_api/v2.0/shares/u!' +
             Utilities.base64EncodeWebSafe(shareUrl).replace(/=+$/, '');

  var root = msGet(base + '/driveItem?$select=id,name,folder', headers);
  if (!root.folder) throw new Error('الرابط لا يشير إلى مجلد. شارك المجلد الرئيسي للشواهد.');
  var files = [], stack = [{ id: root.id, path: '' }];
  while (stack.length && files.length < FETCH.MAX_FILES) {
    var cur = stack.pop();
    var next = base + '/items/' + cur.id + '/children?$top=200&$select=id,name,size,lastModifiedDateTime,webUrl,folder,file';
    while (next) {
      var page = msGet(next, headers);
      (page.value || []).forEach(function (it) {
        if (it.folder) stack.push({ id: it.id, path: cur.path + '/' + it.name });
        else files.push({ id: it.id, name: it.name, path: cur.path, size: it.size, url: it.webUrl,
                          updated: Date.parse(it.lastModifiedDateTime) || null, mime: it.file ? it.file.mimeType : '' });
      });
      next = page['@odata.nextLink'] || null;
    }
  }
  return { files: files, contentRead: 0, contentPending: 0 };
}

function msGet(url, headers) {
  var res = UrlFetchApp.fetch(url, { headers: headers, muteHttpExceptions: true });
  if (res.getResponseCode() !== 200) throw new Error(oneDriveFailMessage());
  return JSON.parse(res.getContentText());
}

function oneDriveFailMessage() {
  return 'تعذّرت قراءة رابط OneDrive. تأكد أن مشاركته "أي شخص لديه الرابط"، أو نزّل المجلد ملف ZIP وارفعه في الصفحة.';
}

// يُشغَّل يدوياً من المحرر لتجربة رابط قبل النشر: ضع الرابط ثم اضغط Run وراجع Execution log
function testRun() {
  var res = JSON.parse(doGet({ parameter: { url: 'ضع_رابط_المجلد_هنا', type: 'gov', stage: 'primary' } }).getContent());
  if (res.error) { Logger.log(res.error); return; }
  Logger.log('نسبة الإنجاز: ' + res.score + '% | المؤشرات: ' + res.indicatorsScore + '% | الالتزام: ' + res.commitmentScore +
             '% | الملفات: ' + res.scannedFiles + ' | قُرئ محتواها: ' + res.contentRead + ' | بقي: ' + res.contentPending);
  res.domains.forEach(function (d) {
    Logger.log('— ' + d.name + ': ' + d.score + '%');
    d.indicators.forEach(function (r) { Logger.log('   ' + r.code + ' ' + r.label + ' ' + r.score + '% (' + r.fileCount + ' ملفات)'); });
  });
  res.commitment.forEach(function (r) { Logger.log('   ' + r.code + ' ' + r.label + ' ' + r.score + '%'); });
  res.generalRecommendations.forEach(function (t) { Logger.log('• ' + t); });
}
