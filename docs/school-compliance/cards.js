/*
 * قراءة بطاقات الاختبارات الوطنية الصادرة من هيئة تقويم التعليم والتدريب (ملفات PDF نصية):
 *  - بطاقة نافس (الإصدار الجديد 1447هـ): نسبة الإتقان العامة، ولكل مادة نسبة الإتقان والتغير وتوزيع المستويات
 *    والمجالات الفرعية مقارنة بإدارة التعليم والمملكة.
 *  - بطاقات القدرات والتحصيلي: عدد المختبرين ومتوسط الدرجات والتغير والتوزيع والترتيب المئيني (المملكة والإدارة).
 * البطاقة القديمة (صورة) لا تحوي نصاً، فتُعاد بنوع 'image'.
 * تعتمد على pdf.js (window.pdfjsLib) وتُحمَّل عند الحاجة.
 */
var NationalCards = (function () {
  'use strict';

  var PDFJS = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/';
  var loading = null;

  function loadPdfJs() {
    if (window.pdfjsLib) return Promise.resolve(window.pdfjsLib);
    if (loading) return loading;
    loading = new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = PDFJS + 'pdf.min.js';
      s.onload = function () {
        // العامل (worker) من نطاق آخر لا يعمل مباشرة، فيُحمَّل نصه ويُشغَّل من رابط محلي
        fetch(PDFJS + 'pdf.worker.min.js').then(function (r) { return r.text(); }).then(function (code) {
          window.pdfjsLib.GlobalWorkerOptions.workerSrc = URL.createObjectURL(new Blob([code], { type: 'text/javascript' }));
          resolve(window.pdfjsLib);
        }).catch(reject);
      };
      s.onerror = function () { reject(new Error('تعذّر تحميل قارئ PDF.')); };
      document.head.appendChild(s);
    });
    return loading;
  }

  // يجمع عناصر النص في أسطر حسب الارتفاع، ويرتب كل سطر من اليمين لليسار
  function pageLines(items) {
    var lines = [];
    items.forEach(function (it) {
      var str = it.str.normalize('NFKC');
      if (!str.trim()) return;
      var y = it.transform[5], x = it.transform[4];
      var line = lines.find(function (l) { return Math.abs(l.y - y) <= 2; });
      if (!line) lines.push(line = { y: y, items: [] });
      line.items.push({ x: x, str: str });
    });
    lines.forEach(function (l) {
      l.items.sort(function (a, b) { return b.x - a.x; });
      l.text = l.items.map(function (i) { return i.str; }).join('').replace(/\s+/g, '');
    });
    return lines.sort(function (a, b) { return b.y - a.y; });
  }

  // الأرقام في الصفحة مع مواضعها
  function numbers(lines) {
    var out = [];
    lines.forEach(function (l) {
      l.items.forEach(function (i) {
        var m = i.str.replace(/‏|‎/g, '').match(/^\s*([+-]?\d+(?:\.\d+)?)\s*(%)?\s*(\*)?\s*$/) ||
                i.str.replace(/‏|‎/g, '').match(/^\s*%([+-]?\d+(?:\.\d+)?)\s*$/);
        if (m) out.push({ x: i.x, y: l.y, v: parseFloat(m[1]), pct: m[2] === '%' || /^%/.test(i.str.trim()), star: !!m[3], raw: i.str });
      });
    });
    return out;
  }

  // يقسم عناصر سطر إلى عبارات منفصلة عند وجود فراغ أفقي كبير (لأسماء المجالات الفرعية)
  function phrases(line, gap) {
    var groups = [], cur = null;
    line.items.forEach(function (i) {
      if (!cur || cur.minX - i.x > gap) groups.push(cur = { maxX: i.x, minX: i.x, text: '' });
      cur.text += i.str;
      cur.minX = i.x;
    });
    return groups.map(function (g) { return { x: (g.maxX + g.minX) / 2, text: g.text.replace(/\s+/g, ' ').trim() }; });
  }

  // مجموعات أعمدة المجالات الفرعية: كل ثلاث قيم متجاورة أفقياً = المدرسة، إدارة التعليم، المملكة (من اليسار)
  function subdomains(lines) {
    var vals = numbers(lines).filter(function (n) { return n.pct; }).sort(function (a, b) { return a.x - b.x; });
    var clusters = [], cur = null;
    vals.forEach(function (n) {
      if (!cur || n.x - cur[cur.length - 1].x > 40) clusters.push(cur = []);
      cur.push(n);
    });
    var labelLine = lines.filter(function (l) { return !/\d/.test(l.text) && l.y < 560 && l.y > 480; })[0];
    var names = labelLine ? phrases(labelLine, 40) : [];
    return clusters.filter(function (c) { return c.length === 3; }).map(function (c) {
      var cx = (c[0].x + c[2].x) / 2;
      var name = names.slice().sort(function (a, b) { return Math.abs(a.x - cx) - Math.abs(b.x - cx); })[0];
      return { name: name ? canonical(name.text) : '', school: c[0].v, admin: c[1].v, kingdom: c[2].v };
    });
  }

  // أسماء المجالات الفرعية الرسمية؛ نص ملف الهيئة يأتي أحياناً بحروف مقلوبة الترتيب (الجرب بدل الجبر)،
  // فيُطابق الاسم المستخرج بأقرب اسم رسمي حسب الحروف المشتركة
  var SUBDOMAINS = ['استيعاب المقروء', 'دلالات الألفاظ', 'الأعداد والعمليات عليها', 'الجبر',
    'الجبر والدوال الحقيقية والتحليل الرياضي', 'الهندسة والقياس', 'البيانات والاحتمالات',
    'علوم الحياة', 'علم الأرض والفلك', 'العلوم الفيزيائية والكيميائية'];
  function canonical(name) {
    var bag = function (t) {
      var m = {};
      t.replace(/[\sـ]/g, '').replace(/[أإآ]/g, 'ا').replace(/ى/g, 'ي').split('').forEach(function (c) { m[c] = (m[c] || 0) + 1; });
      return m;
    };
    var a = bag(name), best = name, bestScore = 0;
    SUBDOMAINS.forEach(function (cand) {
      var b = bag(cand), common = 0, total = 0, k;
      for (k in a) { common += Math.min(a[k], b[k] || 0); total += a[k]; }
      for (k in b) total += b[k];
      var score = 2 * common / total;
      if (score > bestScore) { bestScore = score; best = cand; }
    });
    return bestScore > 0.75 ? best : name;
  }

  var SUBJECTS = [['القراءة', /القراءة|القراءه|اءةالقر/], ['الرياضيات', /الرياضيات/], ['العلوم', /^العلوم$/]];

  function parseNafs(pages) {
    var card = { type: 'nafs', subjects: [] };
    var p1 = pages[0];
    var all = p1.map(function (l) { return l.text; }).join(' ');
    var g = all.match(/(ثالث|سادس)(متوسط|ابتد)/);
    card.grade = g ? g[1] + (g[2] === 'متوسط' ? ' متوسط' : ' ابتدائي') : '';
    var nums = numbers(p1);
    var year = nums.find(function (n) { return n.v >= 1440 && n.v <= 1460; });
    card.year = year ? year.v : null;
    var small = nums.filter(function (n) { return !n.pct && n.v < 2000 && n.v !== card.year; });
    if (small.length >= 2) { card.students = small[0].v; card.testers = small[1].v; }

    // نسبة الإتقان في كل المواد معاً عبر السنوات
    var years = nums.filter(function (n) { return !n.pct && n.v >= 2020 && n.v <= 2040; });
    card.overallTrend = nums.filter(function (n) { return n.pct; }).map(function (n) {
      var yr = years.slice().sort(function (a, b) { return Math.abs(a.x - n.x) - Math.abs(b.x - n.x); })[0];
      return { year: yr ? yr.v : null, value: n.v };
    }).sort(function (a, b) { return a.year - b.year; });
    var last = card.overallTrend[card.overallTrend.length - 1], prev = card.overallTrend[card.overallTrend.length - 2];
    card.overall = last ? last.value : null;
    card.overallChange = last && prev ? Math.round((last.value - prev.value) * 10) / 10 : null;
    var changeLine = p1.find(function (l) { return /مقدارالتغ/.test(l.text); });
    var cm = changeLine && changeLine.text.match(/:([+-]?\d+(?:\.\d+)?)/);
    if (cm) card.overallChange = parseFloat(cm[1]);

    // صفحات المواد: صفحة الرسوم ثم صفحة المجالات الفرعية
    var current = null;
    for (var i = 1; i < pages.length; i++) {
      var lines = pages[i];
      var title = lines.find(function (l) { return l.y > 740 && l.y < 790; });
      var subj = title && SUBJECTS.find(function (s) { return s[1].test(title.text); });
      if (subj) {
        current = { name: subj[0] };
        card.subjects.push(current);
        var n = numbers(lines);
        var dist = n.filter(function (v) { return v.y > 640 && v.y < 680; }).sort(function (a, b) { return b.x - a.x; }).map(function (v) { return v.v; });
        current.distribution = dist;
        var change = n.find(function (v) { return v.star && v.x > 280; });
        current.change = change ? change.v : null;
        var yrs = n.filter(function (v) { return !v.pct && v.v >= 2020 && v.v <= 2040 && v.x > 300; }).sort(function (a, b) { return b.v - a.v; });
        var col = function (yr) { return n.filter(function (v) { return v.pct && yr && Math.abs(v.x - yr.x) < 14 && v.y < 520; }); };
        var nowVals = col(yrs[0]), prevVals = col(yrs[1]);
        var estimate = dist.length >= 2 ? 100 - dist[dist.length - 1] - dist[dist.length - 2] : null;
        var school = null;
        if (current.change !== null && prevVals.length) {
          nowVals.forEach(function (a) {
            prevVals.forEach(function (b) { if (Math.abs(a.v - b.v - current.change) < 0.15) school = a.v; });
          });
        }
        if (school === null && estimate !== null && nowVals.length) {
          school = nowVals.slice().sort(function (a, b) { return Math.abs(a.v - estimate) - Math.abs(b.v - estimate); })[0].v;
        }
        current.mastery = school;
      } else if (current && !current.subdomains) {
        current.subdomains = subdomains(lines);
        var avg = function (k) {
          var l = current.subdomains;
          return l.length ? Math.round(l.reduce(function (s, d) { return s + d[k]; }, 0) / l.length * 10) / 10 : null;
        };
        current.subAvg = { school: avg('school'), admin: avg('admin'), kingdom: avg('kingdom') };
        current.weakest = current.subdomains.slice().sort(function (a, b) { return (a.school - a.kingdom) - (b.school - b.kingdom); })[0] || null;
      }
    }
    return card;
  }

  function parseQudurat(pages) {
    var card = { type: 'qudurat', tests: [] };
    var current = null;
    pages.forEach(function (lines) {
      var title = lines.find(function (l) { return /(التحصيلي|القدرات)(العامة)?-/.test(l.text) && l.y > 500; });
      if (title) {
        current = { name: /التحصيلي/.test(title.text) ? 'التحصيلي' : 'القدرات العامة' };
        var track = title.text.split('-')[1];
        if (track) current.name += ' - ' + track.replace(/[^؀-ۿ]/g, '');
        card.tests.push(current);
        var n = numbers(lines);
        // سطر الإحصاءات: عدد المختبرين ومتوسط الدرجات ومقدار التغير (ثلاثة أرقام، آخرها نسبة بإشارة)
        var stat = lines.find(function (l) { return l.y < title.y && numbers([l]).length === 3 && /[+-]\d/.test(l.text); });
        if (stat) {
          var sn = numbers([stat]).sort(function (a, b) { return b.x - a.x; });
          current.testers = sn[0] ? sn[0].v : null;
          current.mean = sn[1] ? sn[1].v : null;
          current.change = sn[2] ? sn[2].v : null;
        }
        var distLine = lines.find(function (l) { return l.y < (title.y - 60) && l.y > (title.y - 320) && numbers([l]).length >= 3 && !/المختبرين/.test(l.text); });
        current.distribution = distLine ? numbers([distLine]).sort(function (a, b) { return b.x - a.x; }).map(function (v) { return v.v; }) : [];
      }
      var ranks = lines.filter(function (l) { return /^أعلىمن/.test(l.text.replace(/%?[\d.]+%?$/, '')) || /أعلىمن/.test(l.text); });
      if (current && ranks.length) {
        var rank = function (l) {
          var pct = numbers([l])[0];
          var after = lines.slice(lines.indexOf(l) + 1, lines.indexOf(l) + 4).find(function (x) { return /\(/.test(x.text); });
          var countLine = after ? numbers([after]) : [];
          return { pct: pct ? pct.v : null, of: countLine.length === 2 ? { rank: Math.min(countLine[0].v, countLine[1].v), total: Math.max(countLine[0].v, countLine[1].v) } : null };
        };
        current.kingdomRank = rank(ranks[0]);
        if (ranks[1]) current.adminRank = rank(ranks[1]);
      }
    });
    return card;
  }

  // يقرأ ملف PDF ويعيد بيانات البطاقة، أو null إن لم يكن بطاقة اختبارات وطنية
  function parse(data, fileName) {
    return loadPdfJs().then(function (pdfjsLib) {
      return pdfjsLib.getDocument({ data: data }).promise;
    }).then(function (pdf) {
      var jobs = [];
      for (var i = 1; i <= Math.min(pdf.numPages, 14); i++) {
        jobs.push(pdf.getPage(i).then(function (p) { return p.getTextContent(); }).then(function (tc) { return pageLines(tc.items); }));
      }
      return Promise.all(jobs);
    }).then(function (pages) {
      // عنوان البطاقة مكرر الحروف في ملف الهيئة (ببببططططاااا...)، فتُدمج الحروف المتكررة
      var head = pages[0].map(function (l) { return l.text.replace(/(.)\1{2,}/g, '$1'); }).join(' ');
      var textChars = pages.reduce(function (s, p) { return s + p.reduce(function (t, l) { return t + l.text.length; }, 0); }, 0);
      var card = null;
      if (textChars < 20) card = /نافس|nafs/i.test(fileName || '') ? { type: 'image' } : null;
      else if (/القدرات|التحصيلي/.test(head)) card = parseQudurat(pages);
      else if (/نافس|اجتازوا/.test(head)) card = parseNafs(pages);
      if (!card) return null;
      head.replace(/(?:الرقمالوزاري)?([SM]-?\d{5,6})/, function (m, code) { card.code = code; });
      card.file = fileName || '';
      return card;
    });
  }

  function looksLikeCard(name, path) {
    return /\.pdf$/i.test(name) && /نافس|نافيس|nafs|قدرات|القدرات|تحصيلي|التحصيلي|الاختبارات الوطنية|بطاقة/i.test(name + ' ' + (path || ''));
  }

  return { parse: parse, looksLikeCard: looksLikeCard, loadPdfJs: loadPdfJs };
})();
