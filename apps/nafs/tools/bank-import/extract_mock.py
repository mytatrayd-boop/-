import fitz,collections,re,json,sys,os
from PIL import Image
AR=str.maketrans('٠١٢٣٤٥٦٧٨٩','0123456789')
def isfill(f):
    if not f or len(f)!=3: return False
    g=f[0]<0.82 and f[1]>f[0]+0.07 and f[1]>f[2]+0.1
    y=f[0]>0.9 and f[1]>0.9 and f[2]<0.4
    o=f[0]>0.9 and 0.55<f[1]<0.88 and f[2]<0.78 and f[0]-f[2]>0.2
    return g or y or o
def sec_of(text):
    if 'القراءة' in text or 'لغتي' in text: return 'reading'
    if 'الرياضيات' in text: return 'math'
    if 'العلوم' in text: return 'science'
    return None
def analyze(name,outdir,dpi=130):
    q=fitz.open(f'mock/{name}-q.pdf'); a=fitz.open(f'mock/{name}-a.pdf')
    os.makedirs(outdir,exist_ok=True)
    out=[];anom=[];cur_sec=None;cur_pass=None;passages=[]
    for pi in range(len(q)):
        qp,ap=q[pi],a[pi]
        words=qp.get_text('words')
        # عنوان القسم أعلى الصفحة
        qs=[w for w in words if w[4]=='القسم' and w[0]>520 and w[1]<70]
        if qs:
            y=qs[0][1]
            nxt=sorted([w for w in words if abs(w[1]-y)<3 and w[0]<qs[0][0]],key=lambda w:-w[0])
            o=nxt[0][4] if nxt else ''
            if 'ول' in o: cur_sec='reading'
            elif 'ثاني' in o: cur_sec='math'
            elif 'ثالث' in o: cur_sec='science'
        H=collections.defaultdict(list)
        for dr in qp.get_drawings():
            if dr.get('fill')==(0.0,0.0,0.0):
                r=dr['rect']
                if r.height<1.6 and r.width>8: H[round(r.y0)].append((r.x0,r.x1))
        if not H: continue
        Rf=max(max(b for a_,b in xs) for xs in H.values()); Lf=min(min(a_ for a_,b in xs) for xs in H.values())
        full=[y for y,xs in sorted(H.items()) if max(b for a_,b in xs)>=Rf-2 and min(a_ for a_,b in xs)<=Lf+2]
        labx=Rf-28
        fills=[dr['rect'] for dr in ap.get_drawings() if isfill(dr.get('fill')) and dr['rect'].height<150]
        first_rule=full[0] if full else 0
        for y0,y1 in zip(full,full[1:]):
            ws=[w for w in words if y0-1<=w[1]<y1]
            labs=[w for w in ws if w[0]>labx and re.fullmatch(r'[0-9٠-٩]+',w[4])]
            if not labs:
                if len(ws)>40 and cur_sec=='reading':
                    pix=qp.get_pixmap(dpi=dpi,clip=fitz.Rect(Lf-1,y0,Rf+1,y1+1))
                    im=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
                    fn=f'{name}-pass{len(passages)+1}.webp'; im.save(os.path.join(outdir,fn),'WEBP',quality=80,method=6)
                    passages.append(fn); cur_pass={'img':fn,'w':im.width,'h':im.height}
                continue
            n=int(''.join(w[4] for w in sorted(labs,key=lambda w:w[0])).translate(AR))
            cw=(labx-Lf)/4
            cand=sorted({int((labx-(r.x0+r.x1)/2)//cw) for r in fills if r.y0>=y0-1 and r.y1<=y1+1 and r.x1<=labx+2})
            rec={'name':name,'page':pi,'n':n,'sec':cur_sec,'y0':y0,'y1':y1,'ans':cand,'pre':cur_pass if cur_sec=='reading' else None,
                 'text':re.sub(r'\s+',' ',' '.join(w[4] for w in sorted(ws,key=lambda w:(round(w[1]/8),-w[0])) if w[0]<labx)).strip()}
            if len(cand)!=1 or not 0<=cand[0]<4:
                anom.append(rec); continue
            rec['answer']=cand[0]
            pix=qp.get_pixmap(dpi=dpi,clip=fitz.Rect(Lf-1,y0,Rf+1,y1+1))
            im=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
            fn=f'{name}-{len(out)+1:03d}.webp'; im.save(os.path.join(outdir,fn),'WEBP',quality=80,method=6)
            rec.update(img=fn,w=im.width,h=im.height); out.append(rec)
    return out,anom
if __name__=='__main__':
    n=sys.argv[1]; os.makedirs('mockout',exist_ok=True)
    out,an=analyze(n,f'mockout/{n}')
    json.dump({'ok':out,'anomalies':an},open(f'mockout/{n}.json','w'),ensure_ascii=False,indent=1)
    import collections as C
    print(n,len(out),'anom',len(an),dict(C.Counter(r['sec'] for r in out)))
    for r in an[:5]: print('  anom',r['page'],r['n'],r['ans'],r['sec'])
