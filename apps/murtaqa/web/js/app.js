/* مرتقى — الواجهة والتوجيه */
(function (M) {
  'use strict';
  const D = () => M.db;
  const esc = M.esc, fmt = M.fmt;
  const $ = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));
  const exam = (id) => D().exams.find((e) => e.id === id);
  const klass = (id) => D().classes.find((c) => c.id === id);
  const resultsOf = (id) => D().results.filter((r) => r.examId === id);
  const gradeOf = (e) => M.GRADES[e.g] || 'متعدد';
  const subjOf = (e) => M.SUBJECTS[e.s] || 'متعدد';
  const S = { f: { g: '6p', s: '', skill: '', lvl: '', txt: '' }, sel: new Set(), showAns: false, nw: null, timer: null };

  function toast(msg) {
    const t = document.createElement('div');
    t.className = 'toast'; t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(() => t.remove(), 2200);
  }
  const go = (h) => { location.hash = h; };
  const confirmDo = (m) => window.confirm(m);
  const lvTag = (p) => { const l = M.levelOf(p); return '<span class="tag ' + l.cls + '">' + l.name + '</span>'; };
  const barCls = (p) => M.levelOf(p).cls;
  function copy(text, ok) {
    (navigator.clipboard ? navigator.clipboard.writeText(text) : Promise.reject()).then(() => toast(ok || 'تم النسخ'), () => {
      const ta = document.createElement('textarea'); ta.value = text; document.body.appendChild(ta); ta.select();
      try { document.execCommand('copy'); toast(ok || 'تم النسخ'); } catch (e) { toast('تعذّر النسخ، انسخ يدوياً'); }
      ta.remove();
    });
  }
  function download(name, text, type) {
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([text], { type: type || 'text/plain;charset=utf-8' }));
    a.download = name; document.body.appendChild(a); a.click(); a.remove();
  }
  const printHead = (title) => {
    const T = D().teacher;
    return '<div class="printonly"><div class="ph"><div class="r1"><span>' + esc(T.school || '') + '</span><span>' + (T.name ? 'المعلم: ' + esc(T.name) : '') + '</span></div><h2>' + esc(title) + '</h2><div class="meta">' + M.dateStr() + '</div></div></div>';
  };

  /* ================= الواجهات ================= */
  const V = {};

  V.home = () => {
    const d = D();
    const recent = d.exams.slice().sort((a, b) => b.created - a.created).slice(0, 4);
    return (
      '<div class="hero"><h1>أهلاً ' + esc(d.teacher.name || 'بك أيها المعلم') + '</h1><p>أنشئ اختباراً في دقيقة، اطبعه أو أرسله لطلابك، وخذ تقريراً جاهزاً بنقاط القوة والضعف.</p></div>' +
      '<div class="grid g3">' +
      '<a class="card act" href="#/new"><span class="ic">📝</span><b>اختبار جديد</b><span class="mute small">اختر الصف والمادة والمهارات</span></a>' +
      '<a class="card act" href="#/bank"><span class="ic">🗂️</span><b>بنك الأسئلة</b><span class="mute small">اسحب الأسئلة التي تريدها واطبعها</span></a>' +
      '<a class="card act" href="#/classes"><span class="ic">👥</span><b>فصولي</b><span class="mute small">أضف طلابك لتصل التقارير بأسمائهم</span></a></div>' +
      '<div class="grid g4" style="margin:16px 0">' +
      [['فصول', d.classes.length], ['اختبارات', d.exams.length], ['نتائج مسجلة', d.results.length], ['سؤال في البنك', M.QUESTIONS.length]]
        .map((x) => '<div class="card stat"><b>' + x[1] + '</b><span class="mute">' + x[0] + '</span></div>').join('') + '</div>' +
      '<div class="card"><h2>آخر اختباراتك</h2>' +
      (recent.length
        ? recent.map((e) => '<a class="row" style="padding:8px 0;border-bottom:1px solid var(--line);color:inherit" href="#/exam/' + e.id + '"><b>' + esc(e.title) + '</b><span class="mute small">' + gradeOf(e) + ' · ' + subjOf(e) + '</span><span class="sp"></span><span class="tag">' + resultsOf(e.id).length + ' نتيجة</span></a>').join('')
        : '<div class="empty">لا توجد اختبارات بعد. <a href="#/new">أنشئ أول اختبار</a></div>') + '</div>' +
      '<div class="card" style="margin-top:14px"><h2>كيف يعمل؟</h2><div class="grid g3">' +
      '<div><b>١. أنشئ</b><p class="mute small">اختر الصف والمادة والمهارات وعدد الأسئلة، وعدّل الأسئلة كما تشاء.</p></div>' +
      '<div><b>٢. طبّق</b><p class="mute small">اطبع الورقة مع نموذج الإجابة، أو أرسل رابطاً للطلاب ليحلّوا على أجهزتهم.</p></div>' +
      '<div><b>٣. حلّل</b><p class="mute small">أدخل الإجابات أو استورد رموز الطلاب، فيصدر تقرير الفصل وتقرير كل طالب والتقرير الوصفي.</p></div></div></div>'
    );
  };

  /* ---------- الفصول ---------- */
  V.classes = () => {
    const d = D();
    return (
      '<h1>فصولي</h1><div class="card"><h2>فصل جديد</h2><div class="grid g2">' +
      '<label class="f"><span>اسم الفصل</span><input type="text" id="cn" placeholder="مثال: 6/أ"></label>' +
      '<label class="f"><span>الصف</span><select id="cg">' + Object.keys(M.GRADES).map((k) => '<option value="' + k + '">' + M.GRADES[k] + '</option>').join('') + '</select></label></div>' +
      '<label class="f"><span>أسماء الطلاب (اسم في كل سطر)</span><textarea id="cs" placeholder="أحمد محمد&#10;خالد عبدالله"></textarea></label>' +
      '<button class="btn p" data-act="addClass">حفظ الفصل</button></div>' +
      '<div class="grid g2" style="margin-top:14px">' +
      (d.classes.length ? d.classes.map((c) => '<a class="card act" style="text-align:right" href="#/class/' + c.id + '"><b>' + esc(c.name) + '</b><span class="mute small">' + M.GRADES[c.g] + ' · ' + c.students.length + ' طالب</span></a>').join('') : '<div class="empty card">لم تضف فصولاً بعد. الفصول اختيارية، لكنها تجعل التقارير بأسماء الطلاب.</div>') + '</div>'
    );
  };
  V.class = (id) => {
    const c = klass(id);
    if (!c) return V.classes();
    return (
      '<p><a href="#/classes">← الفصول</a></p><h1>' + esc(c.name) + ' <span class="mute small">' + M.GRADES[c.g] + '</span></h1>' +
      '<div class="card"><h2>الطلاب (' + c.students.length + ')</h2>' +
      (c.students.length ? '<table class="tbl">' + c.students.map((s, i) => '<tr><td>' + (i + 1) + '</td><td>' + esc(s.name) + '</td><td style="text-align:left"><button class="btn s d" data-act="delStudent" data-c="' + c.id + '" data-s="' + s.id + '">حذف</button></td></tr>').join('') + '</table>' : '<div class="empty">لا يوجد طلاب</div>') + '</div>' +
      '<div class="card"><h2>إضافة طلاب</h2><textarea id="cs" placeholder="اسم في كل سطر"></textarea><div class="row" style="margin-top:10px"><button class="btn p" data-act="addStudents" data-c="' + c.id + '">إضافة</button><span class="sp"></span><button class="btn d" data-act="delClass" data-c="' + c.id + '">حذف الفصل</button></div></div>'
    );
  };
  const splitNames = (t) => t.split(/\n/).map((x) => x.trim()).filter(Boolean);

  /* ---------- بنك الأسئلة ---------- */
  function filtered() {
    const f = S.f;
    return M.QUESTIONS.filter((q) => (!f.g || q.g === f.g) && (!f.s || q.s === f.s) && (!f.skill || q.skill === f.skill) && (!f.lvl || q.lvl === +f.lvl) && (!f.txt || q.q.includes(f.txt) || q.o.some((o) => o.includes(f.txt))));
  }
  function qCard(q, opts) {
    opts = opts || {};
    const p = q.passage ? M.PASSAGES[q.passage] : null;
    return (
      '<div class="q' + (opts.sel ? ' sel' : '') + '"><div class="qh">' +
      (opts.check ? '<input type="checkbox" data-on="selq" data-id="' + q.id + '"' + (opts.sel ? ' checked' : '') + ' aria-label="تحديد">' : '') +
      '<div class="qt">' + (opts.n ? opts.n + '. ' : '') + fmt(q.q) + '</div>' + (opts.extra || '') + '</div>' +
      (opts.passage && p ? '<div class="ps"><b>' + esc(p.title) + '</b><br>' + esc(p.text) + '</div>' : '') +
      '<div class="row small mute" style="margin:4px 0">' + '<span class="tag">' + M.skillLabel(q.skill) + '</span>' + (p && !opts.passage ? '<span class="tag">نص: ' + esc(p.title) + '</span>' : '') + '<span>' + ['', 'سهل', 'متوسط', 'صعب'][q.lvl] + '</span></div>' +
      '<ol>' + q.o.map((o, i) => '<li class="' + (opts.ans && i === q.a ? 'ok' : opts.mine === i ? 'mine' : '') + '"><b>' + M.LETTERS[i] + '</b>' + fmt(o) + '</li>').join('') + '</ol></div>'
    );
  }
  V.bank = () => {
    const f = S.f, list = filtered();
    const sk = f.s ? M.SKILLS[f.s] : Object.assign({}, M.SKILLS.math, M.SKILLS.sci, M.SKILLS.ar);
    const opt = (o, cur, all) => '<option value="">' + all + '</option>' + Object.keys(o).map((k) => '<option value="' + k + '"' + (cur == k ? ' selected' : '') + '>' + o[k] + '</option>').join('');
    return (
      '<h1>بنك الأسئلة</h1><div class="card"><div class="grid g4">' +
      '<label class="f"><span>الصف</span><select data-on="flt" data-k="g">' + opt(M.GRADES, f.g, 'كل الصفوف') + '</select></label>' +
      '<label class="f"><span>المادة</span><select data-on="flt" data-k="s">' + opt(M.SUBJECTS, f.s, 'كل المواد') + '</select></label>' +
      '<label class="f"><span>المهارة</span><select data-on="flt" data-k="skill">' + opt(sk, f.skill, 'كل المهارات') + '</select></label>' +
      '<label class="f"><span>الصعوبة</span><select data-on="flt" data-k="lvl">' + opt({ 1: 'سهل', 2: 'متوسط', 3: 'صعب' }, f.lvl, 'الكل') + '</select></label></div>' +
      '<div class="row"><input type="text" style="max-width:280px" placeholder="بحث في نص السؤال" value="' + esc(f.txt) + '" data-on="search"><label class="row small"><input type="checkbox" data-on="showAns"' + (S.showAns ? ' checked' : '') + '> إظهار الإجابات</label><span class="sp"></span><span class="mute">' + list.length + ' سؤال</span><button class="btn s" data-act="selAll">تحديد الكل</button></div></div>' +
      '<div class="stack" style="margin-top:14px">' + (list.length ? list.map((q) => qCard(q, { check: 1, sel: S.sel.has(q.id), ans: S.showAns, passage: 0 })).join('') : '<div class="empty card">لا توجد أسئلة بهذه الشروط</div>') + '</div>' +
      (S.sel.size ? '<div class="bar-act noprint"><div class="wrap"><b>محدد: ' + S.sel.size + '</b><button class="btn p" data-act="selExam">اختبار من المحدد</button><button class="btn" data-act="selPrint">طباعة ورقة عمل</button><button class="btn" data-act="selPrintKey">طباعة مع الإجابات</button><span class="sp"></span><button class="btn s" data-act="selClear">مسح التحديد</button></div></div>' : '')
    );
  };
  function selExam(save) {
    const ids = M.orderQs(Array.from(S.sel));
    const gs = new Set(ids.map((i) => M.QMAP[i].g)), ss = new Set(ids.map((i) => M.QMAP[i].s));
    return { id: M.uid(), title: save ? 'اختبار من بنك الأسئلة' : 'ورقة عمل', g: gs.size === 1 ? Array.from(gs)[0] : 'mix', s: ss.size === 1 ? Array.from(ss)[0] : 'mix', qids: ids, dur: 0, classId: '', showResult: true, created: Date.now() };
  }

  /* ---------- اختبار جديد ---------- */
  V.new = () => {
    if (!S.nw) S.nw = { title: '', g: '6p', s: 'math', skills: [], n: 15, dur: 30, classId: '', showResult: true, lvl: '' };
    const n = S.nw;
    const skills = M.SKILLS[n.s];
    const avail = M.QUESTIONS.filter((q) => q.g === n.g && q.s === n.s && (!n.skills.length || n.skills.includes(q.skill)) && (!n.lvl || q.lvl === +n.lvl)).length;
    const cl = D().classes.filter((c) => c.g === n.g);
    const sel = (k, o, all) => '<select data-on="nw" data-k="' + k + '">' + (all ? '<option value="">' + all + '</option>' : '') + Object.keys(o).map((v) => '<option value="' + v + '"' + (String(n[k]) === v ? ' selected' : '') + '>' + o[v] + '</option>').join('') + '</select>';
    return (
      '<h1>اختبار جديد</h1><div class="card"><label class="f"><span>عنوان الاختبار</span><input type="text" data-on="nwTitle" value="' + esc(n.title) + '" placeholder="مثال: اختبار الرياضيات التحسيني"></label>' +
      '<div class="grid g3"><label class="f"><span>الصف</span>' + sel('g', M.GRADES) + '</label><label class="f"><span>المادة</span>' + sel('s', M.SUBJECTS) + '</label><label class="f"><span>الصعوبة</span>' + sel('lvl', { 1: 'سهل', 2: 'متوسط', 3: 'صعب' }, 'متنوعة') + '</label></div>' +
      '<div class="f"><span class="mute small">المهارات (بدون اختيار = كلها)</span><div class="chips">' + Object.keys(skills).map((k) => '<span class="chip' + (n.skills.includes(k) ? ' on' : '') + '" data-act="nwSkill" data-v="' + k + '" role="button" tabindex="0">' + skills[k] + '</span>').join('') + '</div></div>' +
      '<div class="grid g3"><label class="f"><span>عدد الأسئلة (المتاح ' + avail + ')</span><input type="number" min="1" max="' + avail + '" value="' + n.n + '" data-on="nwNum" data-k="n"></label>' +
      '<label class="f"><span>الزمن بالدقائق (0 = مفتوح)</span><input type="number" min="0" max="180" value="' + n.dur + '" data-on="nwNum" data-k="dur"></label>' +
      '<label class="f"><span>الفصل (اختياري)</span><select data-on="nw" data-k="classId"><option value="">بدون</option>' + cl.map((c) => '<option value="' + c.id + '"' + (n.classId === c.id ? ' selected' : '') + '>' + esc(c.name) + '</option>').join('') + '</select></label></div>' +
      '<label class="row" style="margin-bottom:14px"><input type="checkbox" data-on="nwShow"' + (n.showResult ? ' checked' : '') + '> يرى الطالب درجته بعد التسليم (في الحل الإلكتروني)</label>' +
      '<button class="btn p" data-act="genExam"' + (avail ? '' : ' disabled') + '>إنشاء الاختبار</button></div>'
    );
  };

  /* ---------- الاختبارات ---------- */
  V.exams = () => {
    const l = D().exams.slice().sort((a, b) => b.created - a.created);
    return '<div class="row"><h1 class="sp">اختباراتي</h1><a class="btn p" href="#/new">اختبار جديد</a></div>' +
      (l.length ? '<div class="stack">' + l.map((e) => { const rs = resultsOf(e.id); const st = M.classStats(e, rs); return '<a class="card row" style="color:inherit" href="#/exam/' + e.id + '"><div class="sp"><b>' + esc(e.title) + '</b><div class="mute small">' + gradeOf(e) + ' · ' + subjOf(e) + ' · ' + e.qids.length + ' سؤال</div></div>' + (rs.length ? '<span class="mute small">المتوسط ' + st.avg + '%</span>' + lvTag(st.avg) : '') + '<span class="tag">' + rs.length + ' نتيجة</span></a>'; }).join('') + '</div>' : '<div class="empty card">لا توجد اختبارات. <a href="#/new">أنشئ اختباراً</a> أو اسحب أسئلة من <a href="#/bank">البنك</a>.</div>');
  };

  function shareLink(e) {
    return location.href.split('#')[0] + '#/take/' + M.encodeObj({ e: e.id, t: e.title, q: e.qids, d: e.dur || 0, sr: e.showResult ? 1 : 0 });
  }
  V.exam = (id) => {
    const e = exam(id);
    if (!e) return V.exams();
    const rs = resultsOf(id);
    const cl = D().classes.filter((c) => e.g === 'mix' || c.g === e.g);
    return (
      '<p><a href="#/exams">← اختباراتي</a></p><div class="card"><div class="row"><h1 class="sp" style="margin:0">' + esc(e.title) + '</h1><button class="btn s d" data-act="delExam" data-id="' + id + '">حذف</button></div>' +
      '<div class="mute">' + gradeOf(e) + ' · ' + subjOf(e) + ' · ' + e.qids.length + ' سؤال' + (e.dur ? ' · ' + e.dur + ' دقيقة' : '') + '</div>' +
      '<div class="grid g2" style="margin-top:12px"><label class="f"><span>العنوان</span><input type="text" data-on="exTitle" data-id="' + id + '" value="' + esc(e.title) + '"></label>' +
      '<label class="f"><span>الفصل</span><select data-on="exClass" data-id="' + id + '"><option value="">بدون فصل</option>' + cl.map((c) => '<option value="' + c.id + '"' + (e.classId === c.id ? ' selected' : '') + '>' + esc(c.name) + '</option>').join('') + '</select></label></div></div>' +
      '<div class="grid g3" style="margin-top:14px">' +
      '<div class="card"><h3>🖨️ ورقي</h3><div class="stack"><button class="btn" data-act="pPaper" data-id="' + id + '">طباعة الاختبار</button> <button class="btn" data-act="pKey" data-id="' + id + '">نموذج الإجابة (مع الأسئلة)</button> <button class="btn" data-act="pKeyTbl" data-id="' + id + '">مفتاح التصحيح</button> <button class="btn" data-act="pSheets" data-id="' + id + '">أوراق الإجابة</button></div></div>' +
      '<div class="card"><h3>💻 إلكتروني</h3><p class="mute small">يحلّ الطالب من رابط، ويرسل لك رمز نتيجته.</p><div class="stack"><button class="btn p" data-act="copyLink" data-id="' + id + '">نسخ رابط الطلاب</button> <a class="btn" href="#/import/' + id + '">استيراد رموز الطلاب</a></div></div>' +
      '<div class="card"><h3>📊 النتائج (' + rs.length + ')</h3><div class="stack"><a class="btn" href="#/entry/' + id + '">إدخال إجابات ورقية</a> <a class="btn p" href="#/report/' + id + '"' + (rs.length ? '' : ' aria-disabled="true"') + '>تقرير الفصل</a> <a class="btn" href="#/desc/' + id + '">التقرير الوصفي</a></div></div></div>' +
      '<div class="card" style="margin-top:14px"><h2>الأسئلة</h2><div class="stack">' +
      e.qids.map((qid, i) => qCard(M.QMAP[qid], { n: i + 1, ans: true, passage: 0, extra: '<button class="btn s" data-act="swapQ" data-id="' + id + '" data-i="' + i + '">استبدال</button><button class="btn s d" data-act="rmQ" data-id="' + id + '" data-i="' + i + '">حذف</button>' })).join('') + '</div></div>'
    );
  };

  /* ---------- إدخال النتائج الورقية ---------- */
  V.entry = (id) => {
    const e = exam(id);
    if (!e) return V.exams();
    const c = klass(e.classId);
    if (!c) return '<p><a href="#/exam/' + id + '">← الاختبار</a></p><div class="card empty">اختر فصلاً للاختبار أولاً من صفحة الاختبار، ليظهر الطلاب هنا.<br><a class="btn" href="#/exam/' + id + '">رجوع</a></div>';
    const n = e.qids.length;
    return (
      '<p><a href="#/exam/' + id + '">← ' + esc(e.title) + '</a></p><h1>إدخال الإجابات الورقية</h1><p class="mute">اضغط الخلية لتتنقل بين أ ب ج د. أو اكتب إجابات الطالب كاملة في الحقل (مثال: أبجدأ-ج) والشرطة تعني بلا إجابة.</p>' +
      '<div class="scroll"><table class="tbl"><thead><tr><th>الطالب</th>' + e.qids.map((_, i) => '<th style="text-align:center">' + (i + 1) + '</th>').join('') + '<th>الدرجة</th><th>لصق</th></tr></thead><tbody>' +
      c.students.map((s) => {
        const r = D().results.find((x) => x.examId === id && x.studentId === s.id);
        const a = r ? r.answers : new Array(n).fill(null);
        return '<tr data-s="' + s.id + '"><td class="nm">' + esc(s.name) + '</td>' + a.map((v, i) => cellHtml(e.qids[i], v, s.id, i)).join('') + '<td class="sc"><b>' + rowScore(e, a) + '</b></td><td><input type="text" style="width:150px" data-on="rowPaste" data-id="' + id + '" data-s="' + s.id + '" placeholder="أبجد..."></td></tr>';
      }).join('') + '</tbody></table></div><div class="row" style="margin-top:12px"><a class="btn p" href="#/report/' + id + '">عرض التقرير</a></div>'
    );
  };
  const cellCls = (qid, v) => (v == null ? 'ep' : v === M.QMAP[qid].a ? 'ok' : 'no');
  const cellHtml = (qid, v, sid, i) => '<td style="text-align:center"><button class="cell ' + cellCls(qid, v) + '" data-act="cell" data-s="' + sid + '" data-i="' + i + '">' + (v == null ? '·' : M.LETTERS[v]) + '</button></td>';
  const rowScore = (e, a) => (a.some((x) => x != null) ? M.score(e.qids, a).correct + '/' + e.qids.length : '—');
  function setAnswers(e, sid, answers) {
    const c = klass(e.classId);
    const st = c.students.find((x) => x.id === sid);
    let r = D().results.find((x) => x.examId === e.id && x.studentId === sid);
    const has = answers.some((x) => x != null);
    if (!has) { if (r) D().results.splice(D().results.indexOf(r), 1); }
    else if (r) r.answers = answers;
    else D().results.push({ id: M.uid(), examId: e.id, studentId: sid, name: st.name, answers, secs: 0, src: 'paper' });
    M.save();
  }
  function repaintRow(e, sid) {
    const tr = $('tr[data-s="' + sid + '"]');
    if (!tr) return;
    const r = D().results.find((x) => x.examId === e.id && x.studentId === sid);
    const a = r ? r.answers : new Array(e.qids.length).fill(null);
    $$('.cell', tr).forEach((b, i) => { b.className = 'cell ' + cellCls(e.qids[i], a[i]); b.textContent = a[i] == null ? '·' : M.LETTERS[a[i]]; });
    $('.sc b', tr).textContent = rowScore(e, a);
  }

  /* ---------- استيراد رموز الطلاب ---------- */
  V.import = (id) => {
    const e = exam(id);
    if (!e) return V.exams();
    return '<p><a href="#/exam/' + id + '">← ' + esc(e.title) + '</a></p><h1>استيراد نتائج الطلاب</h1><div class="card"><p class="mute">ألصق الرموز التي أرسلها الطلاب، رمز في كل سطر (تبدأ بـ R1.).</p><textarea id="codes" style="direction:ltr" placeholder="R1.eyJ..."></textarea><div class="row" style="margin-top:10px"><button class="btn p" data-act="doImport" data-id="' + id + '">استيراد</button></div><div id="impout" style="margin-top:12px"></div></div>';
  };

  /* ---------- تقرير الفصل ---------- */
  V.report = (id) => {
    const e = exam(id);
    if (!e) return V.exams();
    const rs = resultsOf(id);
    if (!rs.length) return '<p><a href="#/exam/' + id + '">← الاختبار</a></p><div class="card empty">لا توجد نتائج بعد. <a href="#/entry/' + id + '">أدخل إجابات ورقية</a> أو <a href="#/import/' + id + '">استورد رموز الطلاب</a>.</div>';
    const st = M.classStats(e, rs);
    const tot = st.n || 1;
    const sk = Object.keys(st.skills).map((k) => ({ k, p: Math.round((st.skills[k].c / st.skills[k].t) * 100) })).sort((a, b) => a.p - b.p);
    return (
      '<div class="noprint"><p><a href="#/exam/' + id + '">← ' + esc(e.title) + '</a></p></div>' + printHead('تقرير الفصل — ' + e.title) +
      '<div class="row noprint"><h1 class="sp">تقرير الفصل</h1><button class="btn" data-act="csv" data-id="' + id + '">تصدير Excel</button><a class="btn" href="#/desc/' + id + '">التقرير الوصفي</a><button class="btn p" data-act="print">طباعة / PDF</button></div>' +
      '<div class="mute" style="margin-bottom:12px">' + esc(e.title) + ' · ' + gradeOf(e) + ' · ' + subjOf(e) + '</div>' +
      '<div class="grid g4"><div class="card stat"><b>' + st.avg + '%</b><span class="mute">متوسط الفصل</span><div>' + lvTag(st.avg) + '</div></div><div class="card stat"><b>' + st.n + '</b><span class="mute">عدد الطلاب</span></div><div class="card stat"><b>' + st.max + '%</b><span class="mute">أعلى درجة</span></div><div class="card stat"><b>' + st.min + '%</b><span class="mute">أقل درجة</span></div></div>' +
      '<div class="card" style="margin-top:14px"><h2>توزيع المستويات</h2><div class="stack-bar">' + st.dist.map((c, i) => c ? '<i class="' + M.LEVELS[i].cls + '" style="width:' + (c / tot) * 100 + '%"></i>' : '').join('') + '</div><div class="legend">' + M.LEVELS.map((l, i) => '<span><i class="' + l.cls + '" style="background:var(--' + l.cls + ')"></i>' + l.name + ': ' + st.dist[i] + '</span>').join('') + '</div></div>' +
      '<div class="card" style="margin-top:14px"><h2>إتقان المهارات</h2>' + sk.map((x) => '<div class="sk"><span>' + M.skillLabel(x.k) + '</span><div class="bar ' + barCls(x.p) + '"><i style="width:' + x.p + '%"></i></div><b>' + x.p + '%</b></div>').join('') +
      (sk.filter((x) => x.p < 65).length ? '<div class="note" style="margin-top:10px"><b>للتحسين:</b><ul style="margin:4px 0 0;padding-inline-start:20px">' + sk.filter((x) => x.p < 65).map((x) => '<li><b>' + M.skillLabel(x.k) + ':</b> ' + M.ADVICE[x.k] + '</li>').join('') + '</ul></div>' : '') + '</div>' +
      '<div class="card" style="margin-top:14px"><h2>الطلاب</h2><table class="tbl"><tr><th>#</th><th>الاسم</th><th>الدرجة</th><th>النسبة</th><th>المستوى</th><th class="noprint"></th></tr>' +
      st.sc.slice().sort((a, b) => b.s.pct - a.s.pct).map((x, i) => '<tr><td>' + (i + 1) + '</td><td>' + esc(x.r.name) + '</td><td>' + x.s.correct + '/' + x.s.total + '</td><td>' + x.s.pct + '%</td><td>' + lvTag(x.s.pct) + '</td><td class="noprint"><a href="#/sreport/' + id + '/' + x.r.id + '">تقرير الطالب</a></td></tr>').join('') + '</table></div>' +
      '<div class="card" style="margin-top:14px"><h2>تحليل الأسئلة</h2><div class="scroll"><table class="tbl"><tr><th>#</th><th>السؤال</th><th>المهارة</th><th>أجاب صحيحاً</th><th>اختيارات الطلاب (أ ب ج د)</th></tr>' +
      st.items.map((it) => '<tr><td>' + (it.i + 1) + '</td><td>' + fmt(it.q.q) + '</td><td>' + M.skillLabel(it.q.skill) + '</td><td><div class="bar ' + barCls(it.pct) + '" style="width:80px"><i style="width:' + it.pct + '%"></i></div><b>' + it.pct + '%</b>' + (it.pct < 40 ? ' <span class="tag lv1">صعب</span>' : '') + '</td><td>' + it.picks.map((p, k) => k === it.q.a ? '<b style="color:var(--ok)">' + p + '✓</b>' : p).join(' · ') + (it.blank ? ' <span class="mute small">(بلا إجابة ' + it.blank + ')</span>' : '') + '</td></tr>').join('') + '</table></div></div>'
    );
  };

  /* ---------- تقرير الطالب ---------- */
  V.sreport = (id, rid) => {
    const e = exam(id), r = D().results.find((x) => x.id === rid);
    if (!e || !r) return V.exams();
    const s = M.score(e.qids, r.answers), L = M.levelOf(s.pct);
    const sk = Object.keys(s.by).map((k) => ({ k, p: Math.round((s.by[k].c / s.by[k].t) * 100) }));
    const weak = sk.filter((x) => x.p < 65);
    return (
      '<div class="noprint"><p><a href="#/report/' + id + '">← تقرير الفصل</a></p></div>' + printHead('تقرير الطالب — ' + r.name) +
      '<div class="row noprint"><h1 class="sp">' + esc(r.name) + '</h1><button class="btn p" data-act="print">طباعة / PDF</button></div>' +
      '<div class="card"><div class="grid g2"><div><div class="ring" style="--p:' + s.pct + ';--c:var(--' + L.cls + ')"><b>' + s.pct + '%</b></div></div><div><h2>' + esc(e.title) + '</h2><p>الدرجة: <b>' + s.correct + ' من ' + s.total + '</b></p><p>المستوى: ' + lvTag(s.pct) + '</p><p class="mute small">' + gradeOf(e) + ' · ' + subjOf(e) + (r.src === 'online' && r.secs ? ' · الزمن ' + Math.ceil(r.secs / 60) + ' دقيقة' : '') + '</p></div></div></div>' +
      '<div class="card" style="margin-top:14px"><h2>المهارات</h2>' + sk.map((x) => '<div class="sk"><span>' + M.skillLabel(x.k) + '</span><div class="bar ' + barCls(x.p) + '"><i style="width:' + x.p + '%"></i></div><b>' + x.p + '%</b></div>').join('') + '</div>' +
      (weak.length ? '<div class="card note" style="margin-top:14px"><b>توصيات للتحسين</b><ul style="margin:6px 0 0;padding-inline-start:20px">' + weak.map((x) => '<li><b>' + M.skillLabel(x.k) + ':</b> ' + M.ADVICE[x.k] + '</li>').join('') + '</ul></div>' : '<div class="card okbox" style="margin-top:14px">أداء ممتاز في جميع المهارات، يُنصح بتقديم أنشطة إثرائية.</div>') +
      (s.wrong.length ? '<div class="card" style="margin-top:14px"><h2>الأسئلة التي أخطأ فيها (' + s.wrong.length + ')</h2><div class="stack">' + s.wrong.map((i) => qCard(M.QMAP[e.qids[i]], { n: i + 1, ans: true, mine: r.answers[i], passage: 0 })).join('') + '</div></div>' : '')
    );
  };

  /* ---------- التقرير الوصفي (نموذج تحسين نواتج التعلم) ---------- */
  V.desc = (id) => {
    const e = exam(id);
    if (!e) return V.exams();
    const rs = resultsOf(id), st = M.classStats(e, rs), T = D().teacher, c = klass(e.classId);
    const rep = e.rep || {};
    const low = rs.length ? Math.round((st.sc.filter((x) => x.s.pct <= 50).length / rs.length) * 100) : 0;
    const lvl = st.avg >= 70 ? 0 : st.avg >= 50 ? 1 : 2;
    const sk = Object.keys(st.skills).map((k) => ({ k, p: Math.round((st.skills[k].c / st.skills[k].t) * 100) }));
    const strong = sk.filter((x) => x.p >= 70).sort((a, b) => b.p - a.p), weak = sk.filter((x) => x.p < 70).sort((a, b) => a.p - b.p);
    const list = (a, empty) => (a.length ? '<ol style="margin:4px 0;padding-inline-start:22px">' + a.map((x) => '<li>' + M.skillLabel(x.k) + ' (' + x.p + '%)</li>').join('') + '</ol>' : '<p class="mute">' + empty + '</p>');
    const box = (v) => '<span style="display:inline-block;width:14px;height:14px;border:1.5px solid currentColor;border-radius:3px;vertical-align:middle;margin-inline:4px;text-align:center;line-height:12px">' + (v ? '✓' : '') + '</span>';
    const skAll = Object.keys(st.skills).map((k) => M.skillLabel(k));
    const info = [['تاريخ الاختبار', rep.date || M.dateStr()], ['عدد الطلاب', rs.length], ['الصف', gradeOf(e) + (c ? ' — ' + c.name : '')], ['المادة', subjOf(e)], ['المدرسة', T.school || '']];
    return (
      '<div class="noprint"><p><a href="#/exam/' + id + '">← ' + esc(e.title) + '</a></p></div>' +
      '<div class="row noprint"><h1 class="sp">التقرير الوصفي لتحليل الاختبار</h1><button class="btn p" data-act="print">طباعة / PDF</button></div>' +
      (rs.length ? '' : '<div class="note noprint">لا توجد نتائج بعد؛ ستُملأ الأرقام تلقائياً بعد إدخال النتائج.</div>') +
      '<div class="card" style="margin-top:12px"><div class="ph" style="text-align:center"><b>تقرير وصفي لتحليل اختبارات تحسين نواتج التعلم</b><div>للعام الدراسي: ' + esc(T.year || '1448هـ') + '</div></div>' +
      '<h2>أولاً: البيانات العامة للاختبار</h2><table class="tbl">' + info.map((x) => '<tr><th style="width:30%">' + x[0] + '</th><td>' + esc(x[1]) + '</td></tr>').join('') + '</table>' +
      '<p><b>هدف الاختبار:</b> قياس المستوى لتحديد المهارات المتقنة وغير المتقنة، وبناء الأنشطة العلاجية والإثرائية، ومراجعة خطط التحسين بما يعزّز استمرار التقدّم.</p>' +
      '<h2>ثانياً: وصف الاختبار</h2><p>تكوّن الاختبار من <b>' + e.qids.length + '</b> سؤالاً متنوعاً تقيس المهارات المستهدفة، وهي: ' + (skAll.length ? skAll.map((x, i) => (i + 1) + '- ' + x).join('، ') : Object.keys(M.SKILLS[e.s] || {}).map((k) => M.skillLabel(k)).join('، ')) + '.</p>' +
      '<h2>ثالثاً: التحليل الوصفي للنتائج</h2><p><b>1- التحليل العام:</b> تشير النتائج إلى أن مستوى الطلبة في أداء الاختبار: ' + box(lvl === 0) + 'مرتفع ' + box(lvl === 1) + 'متوسط ' + box(lvl === 2) + 'منخفض</p>' +
      '<table class="tbl"><tr><th>متوسط الدرجات</th><td>' + (rs.length ? (st.avg * e.qids.length / 100).toFixed(1) + ' من ' + e.qids.length + ' (' + st.avg + '%)' : '—') + '</td></tr><tr><th>أعلى درجة</th><td>' + (rs.length ? Math.round(st.max * e.qids.length / 100) + ' من ' + e.qids.length : '—') + '</td></tr><tr><th>أقل درجة</th><td>' + (rs.length ? Math.round(st.min * e.qids.length / 100) + ' من ' + e.qids.length : '—') + '</td></tr><tr><th>نسبة الطلبة الحاصلين على 50% من درجة الاختبار فأقل</th><td>' + (rs.length ? low + '%' : '—') + '</td></tr></table>' +
      '<p><b>2- تحليل المهارات:</b></p><p>ظهرت نقاط القوة لدى الطلبة في المهارات التالية:</p>' + list(strong, 'لا توجد مهارة بلغت نسبة إتقانها 70% فأكثر.') +
      '<p>في حين لوحظ ضعف في المهارات التالية التي تحتاج إلى دعم:</p>' + list(weak, 'لا توجد مهارات ضعف.') +
      '<h2>رابعاً: احتياجات المعلم لمساندته في تحسين أداء طلبته</h2><textarea data-on="repText" data-k="needs" data-id="' + id + '" placeholder="الدعم والأدوات والتطوير المهني والمصادر المساندة">' + esc(rep.needs || '') + '</textarea>' +
      '<h2>خامساً: التوصيات المباشرة من مقدِّم خدمات الدعم مع لجنة التميز بالمدرسة</h2>' +
      (weak.length ? '<div class="note noprint" style="margin-bottom:8px"><b>مقترحات جاهزة (انسخ ما يناسبك):</b><ul style="margin:4px 0 0;padding-inline-start:20px">' + weak.map((x) => '<li>' + M.ADVICE[x.k] + '</li>').join('') + '</ul></div>' : '') +
      '<textarea data-on="repText" data-k="reco" data-id="' + id + '">' + esc(rep.reco || '') + '</textarea>' +
      '<table class="tbl" style="margin-top:18px;text-align:center"><tr><td>اسم المعلم/ـة المعد/ة للتقرير<br><b>' + esc(T.name || '') + '</b><br><br>التوقيع: ..........</td><td>مقدم/ـة خدمة دعم التميز المدرسي<br><br><br>التوقيع: ..........</td><td>مدير/ة المدرسة<br><br><br>التوقيع: ..........</td></tr></table></div>'
    );
  };

  /* ---------- الإعدادات ---------- */
  V.settings = () => {
    const T = D().teacher;
    return (
      '<h1>الإعدادات</h1><div class="card"><h2>بيانات الطباعة</h2><p class="mute small">تظهر في رأس الاختبارات والتقارير.</p><div class="grid g3"><label class="f"><span>اسم المعلم/ـة</span><input type="text" data-on="tch" data-k="name" value="' + esc(T.name) + '"></label><label class="f"><span>اسم المدرسة</span><input type="text" data-on="tch" data-k="school" value="' + esc(T.school) + '"></label><label class="f"><span>العام الدراسي</span><input type="text" data-on="tch" data-k="year" value="' + esc(T.year || '1448هـ') + '"></label></div></div>' +
      '<div class="card" style="margin-top:14px"><h2>نسخة احتياطية</h2><p class="mute small">بياناتك محفوظة في هذا المتصفح فقط. خذ نسخة احتياطية قبل تغيير الجهاز أو مسح بيانات المتصفح.</p><div class="row"><button class="btn" data-act="backup">تنزيل نسخة احتياطية</button><label class="btn">استعادة من ملف<input type="file" accept=".json" data-on="restore" hidden></label><span class="sp"></span><button class="btn d" data-act="wipe">مسح كل البيانات</button></div></div>'
    );
  };

  /* ---------- حل الطالب ---------- */
  const sKey = (e) => 'mq.take.' + e;
  function loadSess(e) { try { return JSON.parse(sessionStorage.getItem(sKey(e))) || null; } catch (x) { return null; } }
  function saveSess(e, s) { try { sessionStorage.setItem(sKey(e), JSON.stringify(s)); } catch (x) { /* لا بأس */ } }
  V.take = (payload) => {
    let o;
    try { o = M.decodeObj(payload); if (!o.q.every((q) => M.QMAP[q])) throw 0; } catch (x) { return '<div class="card empty">رابط الاختبار غير صالح. اطلب رابطاً جديداً من معلمك.</div>'; }
    let s = loadSess(o.e);
    if (!s) s = { name: '', a: new Array(o.q.length).fill(null), i: 0, t0: 0, done: false };
    S.take = { o, s };
    const head = '<div class="take"><h2>' + esc(o.t) + '</h2>';
    if (!s.name) return head + '<div class="card"><label class="f"><span>اكتب اسمك الثلاثي</span><input type="text" id="tn" autocomplete="name"></label><p class="mute small">' + o.q.length + ' سؤال' + (o.d ? ' · الزمن ' + o.d + ' دقيقة' : '') + '</p><button class="btn p" data-act="tStart">ابدأ الاختبار</button></div></div>';
    if (s.done) {
      const sc = M.score(o.q, s.a), code = M.resultCode({ id: o.e }, s.name, s.a, s.secs);
      return head + '<div class="card" style="text-align:center"><h2>تم تسليم إجاباتك ✅</h2>' + (o.sr ? '<div class="ring" style="--p:' + sc.pct + ';--c:var(--' + M.levelOf(sc.pct).cls + ')"><b>' + sc.pct + '%</b></div><p>أجبت صحيحاً على ' + sc.correct + ' من ' + sc.total + '</p>' : '') + '<p>أرسل هذا الرمز إلى معلمك ليُسجَّل لك:</p><div class="code">' + code + '</div><div class="row" style="justify-content:center;margin-top:10px"><button class="btn p" data-act="tCopy" data-v="' + code + '">نسخ الرمز</button></div></div></div>';
    }
    const i = s.i, q = M.QMAP[o.q[i]], p = q.passage ? M.PASSAGES[q.passage] : null;
    return (
      head + '<div class="row"><span class="mute">السؤال ' + (i + 1) + ' من ' + o.q.length + '</span><span class="sp"></span>' + (o.d ? '<b id="timer">--:--</b>' : '') + '</div>' +
      '<div class="dots">' + o.q.map((_, k) => '<i class="' + (s.a[k] != null ? 'd ' : '') + (k === i ? 'c' : '') + '" data-act="tGo" data-i="' + k + '">' + (k + 1) + '</i>').join('') + '</div>' +
      '<div class="card">' + (p ? '<div class="ps"><b>' + esc(p.title) + '</b><br>' + esc(p.text) + '</div>' : '') + '<h3>' + fmt(q.q) + '</h3>' +
      q.o.map((t, k) => '<button class="opt' + (s.a[i] === k ? ' on' : '') + '" data-act="tPick" data-k="' + k + '"><b>' + M.LETTERS[k] + '</b><span>' + fmt(t) + '</span></button>').join('') + '</div>' +
      '<div class="row" style="margin-top:12px"><button class="btn" data-act="tGo" data-i="' + (i - 1) + '"' + (i === 0 ? ' disabled' : '') + '>السابق</button><span class="sp"></span>' + (i < o.q.length - 1 ? '<button class="btn p" data-act="tGo" data-i="' + (i + 1) + '">التالي</button>' : '<button class="btn p" data-act="tSubmit">تسليم الإجابات</button>') + '</div></div>'
    );
  };
  function tickTimer() {
    clearInterval(S.timer);
    const t = S.take;
    if (!t || !t.o.d || t.s.done || !t.s.t0) return;
    const el = () => $('#timer');
    const upd = () => {
      const left = t.o.d * 60 - Math.floor((Date.now() - t.s.t0) / 1000);
      if (left <= 0) { clearInterval(S.timer); submitTake(true); return; }
      if (el()) { el().textContent = String(Math.floor(left / 60)).padStart(2, '0') + ':' + String(left % 60).padStart(2, '0'); el().style.color = left < 60 ? 'var(--bad)' : ''; }
    };
    upd(); S.timer = setInterval(upd, 1000);
  }
  function submitTake(auto) {
    const t = S.take;
    if (!t || t.s.done) return;
    const blank = t.s.a.filter((x) => x == null).length;
    if (!auto && blank && !confirmDo('لديك ' + blank + ' سؤال بلا إجابة. هل تريد التسليم؟')) return;
    t.s.done = true; t.s.secs = Math.round((Date.now() - t.s.t0) / 1000);
    saveSess(t.o.e, t.s); clearInterval(S.timer); render();
  }

  /* ================= الإجراءات ================= */
  const A = {
    addClass() {
      const name = $('#cn').value.trim();
      if (!name) return toast('اكتب اسم الفصل');
      D().classes.push({ id: M.uid(), name, g: $('#cg').value, students: splitNames($('#cs').value).map((n) => ({ id: M.uid(), name: n })) });
      M.save(); render(); toast('تم حفظ الفصل');
    },
    addStudents(el) {
      const c = klass(el.dataset.c);
      splitNames($('#cs').value).forEach((n) => c.students.push({ id: M.uid(), name: n }));
      M.save(); render();
    },
    delStudent(el) {
      if (!confirmDo('حذف الطالب ونتائجه؟')) return;
      const c = klass(el.dataset.c);
      c.students = c.students.filter((s) => s.id !== el.dataset.s);
      D().results = D().results.filter((r) => r.studentId !== el.dataset.s);
      M.save(); render();
    },
    delClass(el) {
      if (!confirmDo('حذف الفصل؟ تبقى الاختبارات لكن تُفصل عن الفصل.')) return;
      const id = el.dataset.c;
      D().classes = D().classes.filter((c) => c.id !== id);
      D().exams.forEach((e) => { if (e.classId === id) e.classId = ''; });
      M.save(); go('#/classes');
    },
    selAll() { filtered().forEach((q) => S.sel.add(q.id)); render(); },
    selClear() { S.sel.clear(); render(); },
    selExam() { const e = selExam(true); D().exams.push(e); M.save(); S.sel.clear(); go('#/exam/' + e.id); },
    selPrint() { const e = selExam(); M.printDoc(M.paperHtml(e, false)); },
    selPrintKey() { const e = selExam(); M.printDoc(M.paperHtml(e, true)); },
    nwSkill(el) { const k = el.dataset.v, a = S.nw.skills, i = a.indexOf(k); i < 0 ? a.push(k) : a.splice(i, 1); render(); },
    genExam() {
      const n = S.nw;
      const qids = M.pick({ g: n.g, s: n.s, skills: n.skills, n: Math.max(1, +n.n || 1), lvl: n.lvl });
      if (!qids.length) return toast('لا توجد أسئلة بهذه الشروط');
      const e = { id: M.uid(), title: n.title.trim() || M.SUBJECTS[n.s] + ' — ' + M.GRADES[n.g], g: n.g, s: n.s, qids, dur: +n.dur || 0, classId: n.classId, showResult: n.showResult, created: Date.now() };
      D().exams.push(e); M.save(); go('#/exam/' + e.id);
    },
    delExam(el) {
      if (!confirmDo('حذف الاختبار وكل نتائجه؟')) return;
      const id = el.dataset.id;
      D().exams = D().exams.filter((e) => e.id !== id);
      D().results = D().results.filter((r) => r.examId !== id);
      M.save(); go('#/exams');
    },
    pPaper(el) { M.printDoc(M.paperHtml(exam(el.dataset.id), false)); },
    pKey(el) { M.printDoc(M.paperHtml(exam(el.dataset.id), true)); },
    pKeyTbl(el) { M.printDoc(M.keyHtml(exam(el.dataset.id))); },
    pSheets(el) {
      const e = exam(el.dataset.id), c = klass(e.classId);
      const names = c && c.students.length ? c.students.map((s) => s.name) : new Array(30).fill('');
      M.printDoc(M.sheetsHtml(e, names));
    },
    copyLink(el) {
      const e = exam(el.dataset.id);
      if (location.protocol === 'file:') toast('الرابط يعمل بعد نشر الموقع على الإنترنت');
      copy(shareLink(e), 'تم نسخ رابط الطلاب');
    },
    swapQ(el) {
      const e = exam(el.dataset.id), i = +el.dataset.i, q = M.QMAP[e.qids[i]];
      const alt = M.pick({ g: q.g, s: q.s, skills: [q.skill], n: 1, exclude: e.qids }).filter((id) => !M.QMAP[id].passage);
      if (!alt.length) return toast('لا يوجد سؤال بديل من المهارة نفسها');
      e.qids[i] = alt[0]; e.qids = M.orderQs(e.qids); M.save(); render();
    },
    rmQ(el) {
      const e = exam(el.dataset.id);
      if (e.qids.length <= 1) return toast('يجب أن يبقى سؤال واحد على الأقل');
      if (resultsOf(e.id).length && !confirmDo('توجد نتائج مسجلة؛ حذف سؤال سيربك ترتيبها. متابعة؟')) return;
      e.qids.splice(+el.dataset.i, 1); D().results = D().results.filter((r) => r.examId !== e.id); M.save(); render();
    },
    cell(el) {
      const e = exam(location.hash.split('/')[2]);
      const sid = el.dataset.s, i = +el.dataset.i;
      const r = D().results.find((x) => x.examId === e.id && x.studentId === sid);
      const a = r ? r.answers.slice() : new Array(e.qids.length).fill(null);
      a[i] = a[i] == null ? 0 : a[i] === 3 ? null : a[i] + 1;
      setAnswers(e, sid, a); repaintRow(e, sid);
    },
    doImport(el) {
      const e = exam(el.dataset.id), lines = $('#codes').value.split(/\n/).map((x) => x.trim()).filter(Boolean);
      const c = klass(e.classId);
      let ok = 0; const bad = [], unmatched = [];
      lines.forEach((ln) => {
        try {
          const o = M.parseResultCode(ln);
          if (o.e !== e.id) throw new Error('الرمز لاختبار آخر');
          const st = c ? M.matchStudent(o.n, c.students) : null;
          if (c && !st) unmatched.push(o.n);
          const rec = { id: M.uid(), examId: e.id, studentId: st ? st.id : null, name: st ? st.name : o.n, answers: M.strToAns(o.a, e.qids.length), secs: o.t || 0, src: 'online' };
          const old = D().results.find((r) => r.examId === e.id && (st ? r.studentId === st.id : M.normName(r.name) === M.normName(o.n)));
          if (old) Object.assign(old, rec, { id: old.id }); else D().results.push(rec);
          ok++;
        } catch (x) { bad.push(ln.slice(0, 24) + '… (' + x.message + ')'); }
      });
      M.save();
      $('#impout').innerHTML = (ok ? '<div class="okbox">تم استيراد ' + ok + ' نتيجة. <a href="#/report/' + e.id + '">عرض التقرير</a></div>' : '') +
        (unmatched.length ? '<div class="note" style="margin-top:8px">أسماء لم تُطابق قائمة الفصل (سُجّلت بأسمائها كما كتبها الطالب): ' + unmatched.map(esc).join('، ') + '</div>' : '') +
        (bad.length ? '<div class="note" style="margin-top:8px">تعذّر استيراد: ' + bad.map(esc).join('، ') + '</div>' : '');
    },
    csv(el) {
      const e = exam(el.dataset.id), st = M.classStats(e, resultsOf(e.id));
      const skills = Object.keys(st.skills);
      const rows = [['الاسم', 'الدرجة', 'من', 'النسبة %', 'المستوى'].concat(skills.map(M.skillLabel), e.qids.map((_, i) => 'س' + (i + 1)))];
      st.sc.forEach((x) => rows.push([x.r.name, x.s.correct, x.s.total, x.s.pct, M.levelOf(x.s.pct).name].concat(skills.map((k) => (x.s.by[k] ? Math.round((x.s.by[k].c / x.s.by[k].t) * 100) : '')), x.r.answers.map((a) => (a == null ? '' : M.LETTERS[a])))));
      download('تقرير-' + e.title + '.csv', '﻿' + rows.map((r) => r.map((v) => '"' + String(v).replace(/"/g, '""') + '"').join(',')).join('\r\n'), 'text/csv;charset=utf-8');
    },
    print() { window.print(); },
    backup() { download('murtaqa-backup.json', JSON.stringify(D()), 'application/json'); },
    wipe() { if (confirmDo('سيُحذف كل شيء نهائياً. هل أنت متأكد؟') && confirmDo('تأكيد أخير: مسح كل البيانات؟')) { M.db = { teacher: { name: '', school: '' }, classes: [], exams: [], results: [] }; M.save(); render(); toast('تم المسح'); } },
    tStart() {
      const n = $('#tn').value.trim();
      if (n.length < 3) return toast('اكتب اسمك');
      S.take.s.name = n; S.take.s.t0 = Date.now(); saveSess(S.take.o.e, S.take.s); render();
    },
    tPick(el) { const t = S.take; t.s.a[t.s.i] = +el.dataset.k; saveSess(t.o.e, t.s); render(); },
    tGo(el) { const t = S.take, i = +el.dataset.i; if (i < 0 || i >= t.o.q.length) return; t.s.i = i; saveSess(t.o.e, t.s); render(); },
    tSubmit() { submitTake(false); },
    tCopy(el) { copy(el.dataset.v, 'تم نسخ الرمز'); },
  };

  const ON = {
    flt(el) { S.f[el.dataset.k] = el.value; if (el.dataset.k === 's') S.f.skill = ''; render(); },
    search(el) { S.f.txt = el.value.trim(); clearTimeout(S.st); S.st = setTimeout(() => { render(); const i = $('[data-on=search]'); if (i) { i.focus(); i.setSelectionRange(i.value.length, i.value.length); } }, 350); },
    showAns(el) { S.showAns = el.checked; render(); },
    selq(el) { el.checked ? S.sel.add(el.dataset.id) : S.sel.delete(el.dataset.id); render(); },
    nw(el) { S.nw[el.dataset.k] = el.value; if (el.dataset.k === 's' || el.dataset.k === 'g') { S.nw.skills = []; S.nw.classId = ''; } render(); },
    nwTitle(el) { S.nw.title = el.value; },
    nwNum(el) { S.nw[el.dataset.k] = el.value; },
    nwShow(el) { S.nw.showResult = el.checked; },
    exTitle(el) { exam(el.dataset.id).title = el.value; M.save(); },
    exClass(el) { exam(el.dataset.id).classId = el.value; M.save(); toast('تم الحفظ'); },
    rowPaste(el) {
      const e = exam(el.dataset.id);
      setAnswers(e, el.dataset.s, M.parsePaper(el.value, e.qids.length));
      el.value = ''; repaintRow(e, el.dataset.s);
    },
    repText(el) { const e = exam(el.dataset.id); e.rep = e.rep || {}; e.rep[el.dataset.k] = el.value; M.save(); },
    tch(el) { D().teacher[el.dataset.k] = el.value; M.save(); },
    restore(el) {
      const f = el.files[0]; if (!f) return;
      f.text().then((t) => { const o = JSON.parse(t); if (!o.exams || !o.classes) throw 0; M.db = Object.assign({ teacher: {}, results: [] }, o); M.save(); render(); toast('تمت الاستعادة'); }).catch(() => toast('الملف غير صالح'));
    },
  };
  const LIVE = { nwTitle: 1, nwNum: 1, exTitle: 1, repText: 1, tch: 1, search: 1, rowPaste: 0 };

  /* ================= التوجيه ================= */
  function render() {
    clearInterval(S.timer);
    const p = location.hash.replace(/^#\/?/, '').split('/');
    const name = p[0] || 'home';
    const v = V[name] || V.home;
    const y = window.scrollY;
    document.body.classList.toggle('taking', name === 'take');
    document.getElementById('app').innerHTML = v(p[1], p[2]);
    $$('#nav a').forEach((a) => a.classList.toggle('on', a.dataset.r === name || (name === 'class' && a.dataset.r === 'classes') || (['exam', 'entry', 'import', 'report', 'sreport', 'desc'].includes(name) && a.dataset.r === 'exams')));
    if (name === 'take') tickTimer();
    window.scrollTo(0, S.keepScroll ? y : 0);
    S.keepScroll = false;
  }
  window.addEventListener('hashchange', render);
  document.addEventListener('click', (ev) => {
    const el = ev.target.closest('[data-act]');
    if (!el || !A[el.dataset.act]) return;
    if (['nwSkill', 'selAll', 'selClear', 'tPick', 'swapQ', 'rmQ'].includes(el.dataset.act)) S.keepScroll = true;
    A[el.dataset.act](el, ev);
  });
  document.addEventListener('keydown', (ev) => {
    if ((ev.key === 'Enter' || ev.key === ' ') && ev.target.matches('.chip')) { ev.preventDefault(); ev.target.click(); }
  });
  const onEv = (ev) => {
    const el = ev.target.closest('[data-on]');
    if (!el || !ON[el.dataset.on]) return;
    const live = LIVE[el.dataset.on];
    if ((ev.type === 'input') !== !!live) return;
    if (!live) S.keepScroll = true;
    ON[el.dataset.on](el);
  };
  document.addEventListener('change', onEv);
  document.addEventListener('input', onEv);

  M.load();
  M.V = V;
  render();
})(window.M);
