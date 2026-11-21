import fitz,re,json,sys,os
from PIL import Image
# usage: sci_split.py pdf tag page1,page2,...  -> يستبدل سجلات الصفحات الكاملة (علوم) في formout/<tag>.json بأسئلة مقطوعة
D=re.compile(r'^[٠-٩]+[\u064b-\u0652]*$')
def split(pdf,tag,pages,dpi=130):
    q=fitz.open(pdf); base=f'formout/{tag}'; out=[]
    for pi in pages:
        p=q[pi]; ws=p.get_text('words'); mx=max(w[2] for w in ws)
        st=sorted({round(w[1]) for w in ws if D.match(w[4]) and w[0]>mx-18})
        # دمج أرقام متقاربة (نفس السطر)
        starts=[]
        for y in st:
            if not starts or y-starts[-1]>8: starts.append(y)
        lines=[d['rect'].y0 for d in p.get_drawings() if d['rect'].height<2 and d['rect'].width>200 and d['rect'].y0>starts[-1]]
        end=min(lines) if lines else p.rect.height-50
        bounds=[s-4 for s in starts]+[end+1]
        for a,b in zip(bounds,bounds[1:]):
            pix=p.get_pixmap(dpi=dpi,clip=fitz.Rect(30,a,565,b)); im=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
            n=len(out)+1; fn=f'{tag}-sci{n:03d}.webp'; im.save(f'{base}/{fn}','WEBP',quality=80,method=6)
            out.append({'n':n,'page':pi,'img':fn,'w':im.width,'h':im.height,'pre':None,'noopt':False})
    return out
if __name__=='__main__':
    pdf,tag,pages=sys.argv[1],sys.argv[2],[int(x) for x in sys.argv[3].split(',')]
    d=json.load(open(f'formout/{tag}.json')); d=[r for r in d if r['page'] not in pages]
    o=split(pdf,tag,pages); d+=o
    json.dump(d,open(f'formout/{tag}.json','w'),ensure_ascii=False); print(len(o),'علوم؛ المجموع',len(d))
