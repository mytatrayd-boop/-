// قارئ CSV بسيط (يدعم الاقتباس). الأعمدة: image,type,expert_score,expert_class,notes_correct
export function parseCsv(text) {
  const rows = []; let row = [], f = '', q = false;
  const s = text.replace(/^﻿/, '');
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (q) { if (ch === '"') { if (s[i + 1] === '"') { f += '"'; i++; } else q = false; } else f += ch; }
    else if (ch === '"') q = true;
    else if (ch === ',') { row.push(f); f = ''; }
    else if (ch === '\n' || ch === '\r') { if (ch === '\r' && s[i + 1] === '\n') i++; row.push(f); f = ''; if (row.some((x) => x.trim() !== '')) rows.push(row); row = []; }
    else f += ch;
  }
  row.push(f); if (row.some((x) => x.trim() !== '')) rows.push(row);
  const [head, ...body] = rows; const h = head.map((x) => x.trim());
  return body.map((r) => Object.fromEntries(h.map((k, i) => [k, (r[i] ?? '').trim()])));
}

export function toExpertRows(records) {
  return records.map((r, i) => {
    const expert = Number(r.expert_score);
    if (!r.image || !['bean', 'coffee'].includes(r.type) || !Number.isFinite(expert) || expert < 0 || expert > 100 || r.expert_score === '')
      throw new Error(`CSV سطر ${i + 2}: image/type(bean|coffee)/expert_score(0-100) غير صالحة`);
    if (r.expert_class && !['poor', 'mid', 'excellent'].includes(r.expert_class))
      throw new Error(`CSV سطر ${i + 2}: expert_class يجب poor|mid|excellent`);
    const nc = r.notes_correct === '' || r.notes_correct === undefined ? undefined : Number(r.notes_correct);
    if (nc !== undefined && !(nc >= 0 && nc <= 3)) throw new Error(`CSV سطر ${i + 2}: notes_correct بين 0 و3`);
    return { image: r.image, type: r.type, expert, expertClass: r.expert_class || undefined, notesCorrect: nc };
  });
}
