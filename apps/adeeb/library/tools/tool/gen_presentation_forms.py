import unicodedata, sys
def esc(s): return ''.join('\\u%04X' % ord(c) if ord(c) < 0x10000 else '\\u{%X}' % ord(c) for c in s)
mapped, unmapped = [], []
for rng in [(0xFB50, 0xFDFF), (0xFE70, 0xFEFF)]:
    for cp in range(rng[0], rng[1]+1):
        ch = chr(cp)
        if cp == 0xFEFF: continue
        d = unicodedata.decomposition(ch)
        if not d:
            unmapped.append(cp); continue
        r = unicodedata.normalize('NFKC', ch).lstrip(' ')
        assert r and all(not (0xFB50<=ord(c)<=0xFDFF or 0xFE70<=ord(c)<=0xFEFF) for c in r), hex(cp)
        mapped.append((cp, r))
out = []
out.append('// مولَّد آلياً من بيانات Unicode %s (Python unicodedata، NFKC) — لا يُعدَّل يدوياً.' % unicodedata.unidata_version)
out.append('// أشكال العرض العربية U+FB50–U+FDFF وU+FE70–U+FEFE ← حروفها العادية.')
out.append('// المسافة البادئة في تفكيك الحركات المعزولة (مثل U+FE70 → " ً") محذوفة لتلتصق الحركة بحرفها.')
out.append('part of \'presentation_forms.dart\';')
out.append('')
out.append('const Map<int, String> _presentationFormMap = {')
for cp, r in mapped:
    out.append("  0x%04X: '%s'," % (cp, esc(r)))
out.append('};')
out.append('')
out.append('/// نقاط في النطاقين بلا تفكيك في Unicode (مثل ﴾ ﴿ و﷽ والمحارف غير المعرّفة): لا مقابل قياسي.')
out.append('const Set<int> _presentationFormUnmapped = {')
line = '  '
for cp in unmapped:
    line += '0x%04X, ' % cp
    if len(line) > 90:
        out.append(line.rstrip()); line = '  '
if line.strip(): out.append(line.rstrip())
out.append('};')
open(sys.argv[1], 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print(len(mapped), len(unmapped))
