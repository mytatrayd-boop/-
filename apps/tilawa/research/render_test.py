import sys, xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFont, ImageFilter
xmlp, fontp, out = sys.argv[1:4]
root = ET.parse(xmlp).getroot()
sura = root.find("sura[@index='1']")
ayat = [(a.get('index'), a.get('text')) for a in sura.findall('aya')]
font = ImageFont.truetype(fontp, 64, layout_engine=ImageFont.Layout.RAQM)
print(font.getname())
W, H = 1080, 1920
img = Image.new('RGB', (W, H), (20, 40, 50))
# text layer with shadow
layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(layer)
y = 300
for idx, t in ayat:
    t = f"{t} {''.join('٠١٢٣٤٥٦٧٨٩'[int(c)] for c in idx)}"
    # wrap by words
    words, lines, cur = t.split(' '), [], ''
    for w in words:
        trial = (cur + ' ' + w).strip()
        if d.textlength(trial, font=font, direction='rtl', language='ar') > W - 140 and cur:
            lines.append(cur); cur = w
        else: cur = trial
    lines.append(cur)
    for ln in lines:
        tw = d.textlength(ln, font=font, direction='rtl', language='ar')
        d.text(((W - tw) / 2, y), ln, font=font, fill='white', direction='rtl', language='ar')
        y += 130
shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
shadow.putalpha(layer.getchannel('A').filter(ImageFilter.GaussianBlur(6)))
img.paste((0, 0, 0), (4, 4), shadow.getchannel('A'))
img.paste(layer, (0, 0), layer)
img.save(out)
