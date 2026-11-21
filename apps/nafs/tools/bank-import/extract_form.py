import fitz,collections,re,json,sys,os
from PIL import Image
AR=str.maketrans('٠١٢٣٤٥٦٧٨٩'+''.join(chr(0xf030+i) for i in range(10)),'0123456789'*2)
def analyze(path,tag,outdir,dpi=130):
    q=fitz.open(path); os.makedirs(outdir,exist_ok=True)
    out=[];cur_pass=None;np=0
    for pi in range(len(q)):
        qp=q[pi]; words=qp.get_text('words')
        H=collections.defaultdict(list)
        for dr in qp.get_drawings():
            if dr.get('fill')==(0.0,0.0,0.0) or dr.get('color')==(0.0,0.0,0.0):
                r=dr['rect']
                if r.height<1.6 and r.width>8: H[round(r.y0)].append((r.x0,r.x1))
        if not H: continue
        Rf=max(max(b for a,b in xs) for xs in H.values()); Lf=min(min(a for a,b in xs) for xs in H.values())
        full=[y for y,xs in sorted(H.items()) if max(b for a,b in xs)>=Rf-2 and min(a for a,b in xs)<=Lf+2]
        labx=Rf-28
        # نص قبل الجدول (فقرة بلا إطار)
        first=full[0] if full else 0
        pre=[w for w in words if 40<w[1]<first-2]
        if len(pre)>40:
            pix=qp.get_pixmap(dpi=dpi,clip=fitz.Rect(Lf-6,40,Rf+6,first+1)); im=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
            np+=1; fn=f'{tag}-pass{np}.webp'; im.save(os.path.join(outdir,fn),'WEBP',quality=80,method=6); cur_pass={'img':fn,'w':im.width,'h':im.height}
        for y0,y1 in zip(full,full[1:]):
            ws=[w for w in words if y0-1<=w[1]<y1]
            labs=[w for w in ws if w[0]>labx and re.fullmatch(r'[0-9٠-٩\uf030-\uf039]+',w[4])]
            opt=[w for w in ws if w[4] in ('أ','آ','ا') and w[0]>labx-30 and w[0]<Rf-5]
            isq = bool(labs or (opt and len(ws)<=55 and y1-y0<250))
            if not isq and len(ws)>40:
                pix=qp.get_pixmap(dpi=dpi,clip=fitz.Rect(Lf-1,y0,Rf+1,y1+1)); im=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
                np+=1; fn=f'{tag}-pass{np}.webp'; im.save(os.path.join(outdir,fn),'WEBP',quality=80,method=6); cur_pass={'img':fn,'w':im.width,'h':im.height}
                continue
            if not isq: continue
            pix=qp.get_pixmap(dpi=dpi,clip=fitz.Rect(Lf-1,y0,Rf+1,y1+1)); im=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
            # صف خيارات منقسم من الصفحة السابقة: بلا رقم، في أعلى الصفحة، ولسؤال سابق بلا خيارات
            if False:
                prev=out[-1]; pim=Image.open(os.path.join(outdir,prev['img'])).convert('RGB')
                cv=Image.new('RGB',(max(pim.width,im.width),pim.height+im.height),'white'); cv.paste(pim,(0,0)); cv.paste(im,(0,pim.height))
                cv.save(os.path.join(outdir,prev['img']),'WEBP',quality=80,method=6); prev.update(w=cv.width,h=cv.height,noopt=False); continue
            fn=f'{tag}-{len(out)+1:03d}.webp'; im.save(os.path.join(outdir,fn),'WEBP',quality=80,method=6)
            out.append({'n':len(out)+1,'page':pi,'img':fn,'w':im.width,'h':im.height,'pre':cur_pass,'noopt':not opt})
    return out
if __name__=='__main__':
    path,tag=sys.argv[1],sys.argv[2]
    os.makedirs('formout',exist_ok=True)
    out=analyze(path,tag,f'formout/{tag}')
    json.dump(out,open(f'formout/{tag}.json','w'),ensure_ascii=False)
    print(tag,len(out),[r['n'] for r in out])
