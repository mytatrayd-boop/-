// الأعوام الدراسية: التسمية (هجري + ميلادي) وفتح عام جديد وتحديد عام أي سجل من تاريخه. يشترك فيها الموقع وسكربت بداية العام.
const hijriYear = (d) => Number(new Intl.DateTimeFormat('en-u-ca-islamic-umalqura', { year: 'numeric' }).format(d).replace(/\D/g, '').slice(0, 4));

/** العام الدراسي يبدأ في أغسطس: «1448هـ · 2026-2027». */
export function academicYear(now = new Date()) {
    const g = now.getMonth() >= 6 ? now.getFullYear() : now.getFullYear() - 1;
    return `${hijriYear(new Date(g, 7, 15))}هـ · ${g}-${g + 1}`;
}

export function nextYearLabel(label) {
    const m = /^(\d{4})هـ · (\d{4})-(\d{4})$/.exec(label);
    return m ? `${+m[1] + 1}هـ · ${+m[2] + 1}-${+m[3] + 1}` : academicYear();
}

/** عام سجل تاريخه ms ضمن أعوام المدرسة [{label,start}] (الأول يشمل كل ما قبله). */
export function yearOf(years, ms) {
    const ys = (years ?? []).slice().sort((a, b) => a.start - b.start);
    if (!ys.length) return null;
    let label = ys[0].label;
    for (const y of ys) if (ms >= y.start) label = y.label;
    return label;
}
