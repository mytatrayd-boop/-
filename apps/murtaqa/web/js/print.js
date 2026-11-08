/* مرتقى — تنسيق النصوص ووثائق الطباعة (ورقة الاختبار، نموذج الإجابة، أوراق الإجابة) */
(function (M) {
  'use strict';

  M.esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  /* الأرقام والعمليات تُعزل اتجاهياً حتى لا تنعكس (3 × 5 تبقى 3 × 5)، والكسور تُرسم رأسياً */
  M.fmt = function (s) {
    return M.esc(s).replace(/[\d(−][\d\s.,+\-−×÷=<>()/^²³°%]*[\d)²³°%]|\d/g, (run) => {
      const r = run
        .replace(/(\d+)\/(\d+)/g, '<span class="frac"><span>$1</span><span>$2</span></span>')
        .replace(/\^(\d+)/g, '<sup>$1</sup>');
      return '<span class="num">' + r + '</span>';
    });
  };

  M.dateStr = () => new Date().toLocaleDateString('ar-SA-u-ca-islamic-umalqura-nu-latn', { dateStyle: 'medium' });
  const gradeOf = (e) => M.GRADES[e.g] || '';
  const subjOf = (e) => M.SUBJECTS[e.s] || '';

  function header(exam, sub, student) {
    const T = M.db.teacher;
    const n = exam.qids.length;
    return (
      '<div class="ph"><div class="r1"><span>' + M.esc(T.school || 'اسم المدرسة') + '</span><span>' + (T.name ? 'المعلم: ' + M.esc(T.name) : '') + '</span></div>' +
      '<h2>' + M.esc(exam.title) + (sub ? ' — ' + sub : '') + '</h2>' +
      '<div class="meta">' + [gradeOf(exam), subjOf(exam), 'عدد الأسئلة: ' + n, exam.dur ? 'الزمن: ' + exam.dur + ' دقيقة' : '', 'الدرجة: ' + n].filter(Boolean).join(' · ') + '</div>' +
      '<div class="fl"><span>اسم الطالب: ' + M.esc(student || '') + '</span><span>الفصل: </span><span>التاريخ: ' + M.dateStr() + '</span></div></div>'
    );
  }

  function questions(exam, withKey) {
    const shown = {};
    let out = '';
    exam.qids.forEach((id, i) => {
      const q = M.QMAP[id];
      if (q.passage && !shown[q.passage]) {
        shown[q.passage] = 1;
        const p = M.PASSAGES[q.passage];
        out += '<div class="pp"><b>' + M.esc(p.title) + '</b><br>' + M.esc(p.text) + '</div>';
      }
      const max = Math.max.apply(null, q.o.map((x) => x.length));
      const cls = max > 40 ? 'v' : max > 14 ? 'w' : '';
      out +=
        '<div class="pq"><div class="qt">' + (i + 1) + '. ' + M.fmt(q.q) + '</div><div class="po ' + cls + '">' +
        q.o.map((o, k) => '<span' + (withKey && k === q.a ? ' class="ok"' : '') + '>' + M.LETTERS[k] + ') ' + M.fmt(o) + '</span>').join('') +
        '</div></div>';
    });
    return out;
  }

  M.paperHtml = (exam, withKey) => header(exam, withKey ? 'نموذج الإجابة' : '') + questions(exam, withKey);

  M.keyHtml = function (exam) {
    let rows = '';
    for (let i = 0; i < exam.qids.length; i += 10) {
      const part = exam.qids.slice(i, i + 10);
      rows +=
        '<tr><th>السؤال</th>' + part.map((_, k) => '<td>' + (i + k + 1) + '</td>').join('') + '</tr>' +
        '<tr><th>الإجابة</th>' + part.map((id) => '<td><b>' + M.LETTERS[M.QMAP[id].a] + '</b></td>').join('') + '</tr>';
    }
    return header(exam, 'مفتاح التصحيح') + '<table class="pk">' + rows + '</table>';
  };

  /* ورقة إجابة بفقاعات، نسخة لكل اسم */
  M.sheetsHtml = function (exam, names) {
    const n = exam.qids.length;
    const half = Math.ceil(n / 2);
    const cell = (i) =>
      '<div><b>' + (i + 1) + '</b>' + M.LETTERS.map((l) => '<i>' + l + '</i>').join('') + '</div>';
    let col1 = '', col2 = '';
    for (let i = 0; i < n; i++) (i < half ? (col1 += cell(i)) : (col2 += cell(i)));
    return names
      .map(
        (nm) =>
          '<section class="sheet">' + header(exam, 'ورقة الإجابة', nm) +
          '<p style="margin:6px 0;font-size:10.5pt">ظلّل الدائرة المناسبة بقلم رصاص أو حبر غامق، ودائرة واحدة فقط لكل سؤال.</p>' +
          '<div class="bub"><section>' + col1 + '</section><section>' + col2 + '</section></div></section>'
      )
      .join('');
  };

  M.printDoc = function (html) {
    const root = document.getElementById('print-root');
    root.innerHTML = html;
    document.body.classList.add('pdoc');
    const done = () => { document.body.classList.remove('pdoc'); window.removeEventListener('afterprint', done); };
    window.addEventListener('afterprint', done);
    setTimeout(() => window.print(), 60);
  };
})(window.M);
