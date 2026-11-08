/* مرتقى — النواة: التصنيفات، بنك الأسئلة، التصحيح، التشفير، التخزين.
   نص عادي (بدون modules) ليعمل الموقع حتى لو فُتح من ملف مباشرة. */
(function (M) {
  'use strict';

  M.NAME = 'محاكي نافس 2026م';

  M.GRADES = { '3p': 'الصف الثالث الابتدائي', '6p': 'الصف السادس الابتدائي', '9m': 'الصف الثالث المتوسط' };
  M.SUBJECTS = { math: 'الرياضيات', sci: 'العلوم', ar: 'لغتي' };
  M.SKILLS = {
    math: { num: 'الأعداد والعمليات', geo: 'الهندسة والقياس', alg: 'الأنماط والجبر', data: 'البيانات والاحتمال' },
    sci: { life: 'علوم الحياة', earth: 'الأرض والفضاء', phys: 'الفيزياء', chem: 'المادة والكيمياء' },
    ar: { read: 'الفهم القرائي', lang: 'بنية اللغة', vocab: 'المفردات والأسلوب' },
  };
  M.skillLabel = function (k) {
    for (const s in M.SKILLS) if (M.SKILLS[s][k]) return M.SKILLS[s][k];
    return k;
  };
  M.LEVELS = [
    { min: 85, name: 'متميز', cls: 'lv4' },
    { min: 65, name: 'متمكن', cls: 'lv3' },
    { min: 40, name: 'يقترب من الإتقان', cls: 'lv2' },
    { min: 0, name: 'يحتاج دعماً', cls: 'lv1' },
  ];
  M.levelOf = (p) => M.LEVELS.find((l) => p >= l.min);

  M.ADVICE = {
    num: 'درّب الطلاب على العمليات الأساسية بأمثلة من الحياة اليومية، وراجع القيمة المنزلية والكسور بنماذج محسوسة.',
    geo: 'استخدم الرسم والقياس الفعلي (مسطرة، مجسمات)، وأعد صياغة قوانين المحيط والمساحة والحجم بتطبيقات واقعية.',
    alg: 'ابدأ بالأنماط المكتوبة ثم انتقل إلى المعادلات، واطلب من الطالب شرح خطوات الحل بصوت مسموع.',
    data: 'اجمع بيانات من الفصل (أطوال، أعمار) ودرّب الطلاب على قراءة الجداول والتمثيلات وحساب المتوسط والوسيط والاحتمال.',
    life: 'اربط الدرس بالملاحظة المباشرة (نبات، خلية بالمجهر)، واستخدم المخططات لتتبع السلاسل والدورات.',
    earth: 'استعن بالنماذج والمجسمات (كرة أرضية، مصباح) لتفسير الظواهر الفلكية والجيولوجية.',
    phys: 'نفّذ تجارب قصيرة في الفصل (قوة، صوت، ضوء) واطلب من الطلاب التنبؤ ثم التفسير.',
    chem: 'ركّز على التمييز بين التغيّر الفيزيائي والكيميائي وخصائص المادة عبر تجارب بسيطة.',
    read: 'اقرأ النص مع الطلاب، ودرّبهم على استخراج الفكرة الرئيسة والتمييز بين المعلومة الصريحة والاستنتاج.',
    lang: 'درّب الطلاب على الإعراب والتصريف بجمل قصيرة من النصوص المقروءة، وراجع القواعد بالتطبيق لا بالحفظ.',
    vocab: 'نوّع التدريب على المرادفات والأضداد والسياق، وشجّع الطلاب على بناء قاموس شخصي للمفردات الجديدة.',
  };

  /* ---------- بنك الأسئلة ---------- */
  M.QUESTIONS = [];
  M.QMAP = {};
  M.PASSAGES = {};

  function hash(s) {
    let h = 2166136261;
    for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
    return h >>> 0;
  }
  function mulberry(a) {
    return function () {
      a |= 0; a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  M.passage = function (id, g, title, text) { M.PASSAGES[id] = { id, g, title, text }; };

  /* كل سؤال: [المهارة، الصعوبة 1-3، النص، الإجابة الصحيحة، [3 مشتتات]، معرّف النص؟]
     ترتيب الخيارات يُخلط بثبات حسب المعرّف، فلا يتغير بين طباعة وأخرى. */
  M.defBank = function (g, s, list) {
    list.forEach((r, i) => {
      const [skill, lvl, q, right, wrong, passage] = r;
      const id = g + '-' + s + '-' + String(i + 1).padStart(2, '0');
      const opts = [right].concat(wrong);
      const rnd = mulberry(hash(id));
      const idx = [0, 1, 2, 3];
      for (let k = 3; k > 0; k--) { const j = Math.floor(rnd() * (k + 1)); const t = idx[k]; idx[k] = idx[j]; idx[j] = t; }
      const item = { id, g, s, skill, lvl, q, o: idx.map((k) => opts[k]), a: idx.indexOf(0), passage: passage || null };
      M.QUESTIONS.push(item);
      M.QMAP[id] = item;
    });
  };

  function shuffle(a) {
    for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); const t = a[i]; a[i] = a[j]; a[j] = t; }
    return a;
  }

  /* الأسئلة المستقلة أولاً ثم أسئلة كل نص متتابعة */
  M.orderQs = function (ids) {
    const alone = ids.filter((id) => !M.QMAP[id].passage);
    const groups = {};
    const order = [];
    ids.forEach((id) => {
      const p = M.QMAP[id].passage;
      if (!p) return;
      if (!groups[p]) { groups[p] = []; order.push(p); }
      groups[p].push(id);
    });
    return alone.concat(...order.map((p) => groups[p]));
  };

  /* اختيار عشوائي متوازن بين المهارات */
  M.pick = function (o) {
    const skills = o.skills || [];
    const ex = o.exclude || [];
    let pool = M.QUESTIONS.filter((q) => q.g === o.g && q.s === o.s && (!skills.length || skills.includes(q.skill)) && !ex.includes(q.id));
    if (o.lvl) pool = pool.filter((q) => q.lvl === o.lvl);
    shuffle(pool);
    const by = {};
    pool.forEach((q) => (by[q.skill] = by[q.skill] || []).push(q));
    const keys = Object.keys(by);
    const out = [];
    let i = 0;
    while (out.length < o.n && keys.some((k) => by[k].length)) {
      const k = keys[i++ % keys.length];
      if (by[k].length) out.push(by[k].shift());
    }
    return M.orderQs(out.map((q) => q.id));
  };

  /* ---------- التصحيح والإحصاء ---------- */
  M.score = function (qids, answers) {
    const r = { correct: 0, total: qids.length, by: {}, wrong: [], blank: 0 };
    qids.forEach((id, i) => {
      const q = M.QMAP[id];
      const b = r.by[q.skill] || (r.by[q.skill] = { c: 0, t: 0 });
      b.t++;
      const a = answers[i];
      if (a === q.a) { r.correct++; b.c++; } else { r.wrong.push(i); if (a == null) r.blank++; }
    });
    r.pct = r.total ? Math.round((r.correct / r.total) * 100) : 0;
    return r;
  };

  M.classStats = function (exam, results) {
    const n = results.length;
    const sc = results.map((r) => ({ r, s: M.score(exam.qids, r.answers) }));
    const pcts = sc.map((x) => x.s.pct);
    const dist = M.LEVELS.map(() => 0);
    sc.forEach((x) => { dist[M.LEVELS.indexOf(M.levelOf(x.s.pct))]++; });
    const skills = {};
    sc.forEach((x) => { for (const k in x.s.by) { const b = skills[k] || (skills[k] = { c: 0, t: 0 }); b.c += x.s.by[k].c; b.t += x.s.by[k].t; } });
    const items = exam.qids.map((id, i) => {
      const q = M.QMAP[id];
      const picks = [0, 0, 0, 0];
      let blank = 0, right = 0;
      results.forEach((r) => { const a = r.answers[i]; if (a == null) blank++; else picks[a]++; if (a === q.a) right++; });
      return { id, i, q, picks, blank, right, pct: n ? Math.round((right / n) * 100) : 0 };
    });
    return {
      n, sc, dist, skills, items,
      avg: n ? Math.round(pcts.reduce((a, b) => a + b, 0) / n) : 0,
      max: n ? Math.max.apply(null, pcts) : 0,
      min: n ? Math.min.apply(null, pcts) : 0,
    };
  };

  /* ---------- التشفير (روابط الاختبار ورموز النتائج) ---------- */
  function b64e(s) {
    const bytes = new TextEncoder().encode(s);
    let t = '';
    bytes.forEach((x) => (t += String.fromCharCode(x)));
    return btoa(t).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }
  function b64d(s) {
    const t = atob(s.replace(/-/g, '+').replace(/_/g, '/'));
    return new TextDecoder().decode(Uint8Array.from(t, (c) => c.charCodeAt(0)));
  }
  M.encodeObj = (o) => b64e(JSON.stringify(o));
  M.decodeObj = (s) => JSON.parse(b64d(s.trim()));
  M.ansToStr = (a) => a.map((x) => (x == null ? '-' : String(x))).join('');
  M.strToAns = (s, n) => {
    const a = [];
    for (let i = 0; i < n; i++) { const c = s[i]; a.push(c >= '0' && c <= '3' ? +c : null); }
    return a;
  };
  M.resultCode = (exam, name, answers, secs) =>
    'R1.' + M.encodeObj({ e: exam.id, n: name, a: M.ansToStr(answers), t: secs || 0 });
  M.parseResultCode = (line) => {
    const m = /R1\.([A-Za-z0-9_-]+)/.exec(line);
    if (!m) throw new Error('رمز غير صالح');
    let o;
    try { o = M.decodeObj(m[1]); } catch (e) { throw new Error('رمز غير صالح'); }
    if (!o || !o.e || typeof o.a !== 'string') throw new Error('رمز غير صالح');
    return o;
  };

  /* إدخال الإجابات الورقية كنص: أبجد / abcd / 1234 ، والشرطة = بلا إجابة */
  const LMAP = { 'أ': 0, 'ا': 0, 'إ': 0, 'آ': 0, a: 0, A: 0, 1: 0, 'ب': 1, b: 1, B: 1, 2: 1, 'ج': 2, c: 2, C: 2, 3: 2, 'د': 3, d: 3, D: 3, 4: 3 };
  M.parsePaper = (str, n) => {
    const out = [];
    for (const ch of String(str).replace(/[\s,،]/g, '')) {
      if (out.length >= n) break;
      out.push(ch in LMAP ? LMAP[ch] : null);
    }
    while (out.length < n) out.push(null);
    return out;
  };
  M.LETTERS = ['أ', 'ب', 'ج', 'د'];

  /* مطابقة اسم طالب */
  M.normName = (s) =>
    String(s || '').replace(/[ً-ْـ]/g, '').replace(/[أإآ]/g, 'ا').replace(/ى/g, 'ي').replace(/ة/g, 'ه').replace(/\s+/g, ' ').trim();
  M.matchStudent = (name, students) => {
    const n = M.normName(name);
    if (!n) return null;
    let m = students.filter((s) => M.normName(s.name) === n);
    if (m.length === 1) return m[0];
    m = students.filter((s) => M.normName(s.name).includes(n) || n.includes(M.normName(s.name)));
    return m.length === 1 ? m[0] : null;
  };

  /* ---------- التخزين المحلي ---------- */
  const KEY = 'murtaqa.v1';
  M.db = { teacher: { name: '', school: '' }, classes: [], exams: [], results: [] };
  M.uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
  M.load = () => {
    try { const s = localStorage.getItem(KEY); if (s) M.db = Object.assign(M.db, JSON.parse(s)); } catch (e) { /* التخزين غير متاح */ }
  };
  M.save = () => {
    try { localStorage.setItem(KEY, JSON.stringify(M.db)); M.saveError = false; } catch (e) { M.saveError = true; }
  };
})((window.M = window.M || {}));
