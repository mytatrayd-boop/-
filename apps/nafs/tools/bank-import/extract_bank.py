import fitz,collections,re,json,sys,os
from PIL import Image
import io
RED=0xC00000
def isgreen(f): return f and len(f)==3 and f[0]<0.82 and f[1]>f[0]+0.07 and f[1]>f[2]+0.1
def isyellow(f): return f and len(f)==3 and f[0]>0.9 and f[1]>0.9 and f[2]<0.4
LEVELS={'المعرفة':'know','التطبيق':'apply','الاستدلال':'reason'}
def thin(dr):
    return dr.get('fill')==(0.0,0.0,0.0)
def analyze(name, outdir, dpi=130):
    q=fitz.open(f'bankpdf/{name}-q.pdf'); a=fitz.open(f'bankpdf/{name}-a.pdf')
    os.makedirs(outdir,exist_ok=True)
    out=[]; anomalies=[]
    std=None; level=None; n=0
    for pi in range(len(q)):
        qp,ap=q[pi],a[pi]
        H=collections.defaultdict(list); V=[]
        for dr in qp.get_drawings():
            if thin(dr):
                r=dr['rect']
                if r.height<1.6 and r.width>8: H[round(r.y0)].append((r.x0,r.x1))
                elif r.width<1.6 and r.height>10: V.append(r)
        rules=[y for y,xs in sorted(H.items()) if min(x[0] for x in xs)<50 and max(x[1] for x in xs)>=790]
        words=qp.get_text('words')
        labels=[w for w in words if w[4]=='السؤال' and w[0]>650]
        gfills=[dr['rect'] for dr in ap.get_drawings() if isgreen(dr.get('fill')) and dr['rect'].height<80 and dr['rect'].width<300]
        yfills=[dr['rect'] for dr in ap.get_drawings() if isyellow(dr.get('fill'))]
        reds=[]
        for b in ap.get_text('dict')['blocks']:
            for l in b.get('lines',[]):
                for s in l['spans']:
                    if s['color']==RED and s['text'].strip(): reds.append(fitz.Rect(s['bbox']))
        for y0,y1 in zip(rules,rules[1:]):
            ws=[w for w in words if y0-1<=w[1]<y1]
            txt=' '.join(w[4] for w in sorted(ws,key=lambda w:(round(w[1]/6),-w[0])))
            labs=[l for l in labels if y0<=l[1]<=y1]
            # standard row
            if 'المعيار' in txt and not labs:
                std=re.sub(r'المعيار|[\d\-:٠-٩]+',' ',txt); std=re.sub(r'\s+',' ',std).strip(); continue
            hdr=[w for w in ws if w[4]=='المستوى']
            for w in ws:
                if 'معرف' in w[4] and len(w[4])<8: level='know'
                elif 'تطبيق' in w[4] and len(w[4])<9: level='apply'
                elif 'ستدال' in w[4] and len(w[4])<10: level='reason'
            if not labs:
                continue
            top=y0
            if hdr:  # صف المستوى مدمج مع السؤال
                top=max(w[3] for w in hdr)+9
                # ابحث عن حد الصف
                lvl_words=[w for w in ws if (('معرف' in w[4] and len(w[4])<8) or ('تطبيق' in w[4] and len(w[4])<9) or ('ستدال' in w[4] and len(w[4])<10))]
                if lvl_words: top=max(top,max(w[3] for w in lvl_words)+7)
            n+=1
            # أعمدة الخيارات
            lab=labs[0]
            xs=[r.x0 for r in V if r.y0<=y1 and r.y1>=y0]
            L=min(xs) if xs else 43
            R=max([x for x in xs if x<lab[0]-5] or [699])
            cw=(R-L)/4
            def idx_of(rc):
                cx=(rc.x0+rc.x1)/2
                return int((R-cx)//cw)
            mid=[y for y,xx in H.items() if y0<y<y1 and min(x[0] for x in xx)<50 and 600<max(x[1] for x in xx)<790]
            opt_top=max(mid) if mid else y0+(y1-y0)*0.55
            cand=[]
            for rc in gfills:
                if rc.y0>=top-1 and rc.y1<=y1+1: cand.append(('g',idx_of(rc)))
            for rc in reds:
                if rc.y0>=opt_top-3 and rc.y1<=y1+2 and top-2<=rc.y0: cand.append(('r',idx_of(rc)))
            for rc in yfills:
                if rc.y1<=y1+2 and top-2<=rc.y0: cand.append(('y',idx_of(rc)))
            ids=sorted({i for _,i in cand})
            rec={'name':name,'page':pi,'y0':top,'y1':y1,'level':level,'std':std,'ans':ids,'src':sorted({k for k,_ in cand})}
            # نص السؤال
            rec['text']=re.sub(r'\s+',' ',' '.join(w[4] for w in ws if w[1]>=top and w[0]<R)).strip()
            if len(ids)!=1 or not all(0<=i<4 for i in ids):
                anomalies.append(rec); continue
            rec['answer']=ids[0]
            clip=fitz.Rect(L-1, top, R+1, y1+1)
            pix=qp.get_pixmap(dpi=dpi,clip=clip)
            img=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
            fn=f'{name}-{n:03d}.webp'
            img.save(os.path.join(outdir,fn),'WEBP',quality=80,method=6)
            rec.update(img=fn,w=pix.width,h=pix.height)
            out.append(rec)
    return out,anomalies
if __name__=='__main__':
    name=sys.argv[1]
    out,an=analyze(name,f'bankout/{name}')
    json.dump({'ok':out,'anomalies':an},open(f'bankout/{name}.json','w'),ensure_ascii=False,indent=1)
    print(name,'ok',len(out),'anomalies',len(an))
    for r in an[:12]: print(' ',r['page'],round(r['y0']),round(r['y1']),r['ans'],r['src'],r['text'][:50])
