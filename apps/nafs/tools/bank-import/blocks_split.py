import fitz,json,sys,os,re,unicodedata
from PIL import Image
# تقطيع عام: كل كتلة متصلة رأسياً (كلمات + رسوم) فاصلها فراغ >= GAP نقطة. سؤال = كتلة فيها >=3 خطوط عمودية أو رمز خيار «أ»؛ نص = كتلة طويلة بلا ذلك.
def blocks(pdf,tag,pages,top=84,bottom=770,gap=7,dpi=130,out=None):
    q=fitz.open(pdf); base=f'formout/{tag}'; os.makedirs(base,exist_ok=True); res=[]; cur=None; npass=0
    for pi in pages:
        p=q[pi]; W=p.rect.width
        iv=[]  # (y0,y1,kind)
        words=p.get_text('words')
        for w in words:
            if top<w[1]<bottom: iv.append((w[1],w[3],'w',w))
        vlines=0
        for d in p.get_drawings():
            r=d['rect']
            if r.y0>top and r.y1<bottom+40 and r.x1>20:
                iv.append((r.y0,r.y1,'d',r))
        iv.sort(key=lambda t:t[0]); groups=[]
        for it in iv:
            if groups and it[0]<=groups[-1]['y1']+gap: g=groups[-1]; g['y1']=max(g['y1'],it[1]); g['items'].append(it)
            else: groups.append({'y0':it[0],'y1':it[1],'items':[it]})
        sp=[]
        for g in groups:
            ins=[i[3] for i in g['items'] if i[2]=='w' and 'قراءتك' in unicodedata.normalize('NFKC',i[3][4])]
            tall=[i[3] for i in g['items'] if i[2]=='d' and i[3].width<1.5 and i[3].height>200]
            if tall or (ins and len([1 for i in g['items'] if i[2]=='w'])>90):
                ys=(max(r.y1 for r in tall)-2) if tall else ins[0][3]+3
                a=[i for i in g['items'] if i[0]<ys]; b=[i for i in g['items'] if i[0]>=ys]
                sp.append({'y0':g['y0'],'y1':max(i[1] for i in a),'items':a,'fp':1})
                if b: sp.append({'y0':min(i[0] for i in b),'y1':g['y1'],'items':b})
            else: sp.append(g)
        for g in sp:
            ws=[i[3] for i in g['items'] if i[2]=='w']; dr=[i[3] for i in g['items'] if i[2]=='d']
            vl=[r for r in dr if r.width<1.5 and r.height>8]
            hl=[r for r in dr if r.height<1.5 and r.width>100]
            opt=[w for w in ws if w[4] in ('أ','آ','ا') and w[0]>380]
            xs=[r.x0 for r in dr]+[r.x1 for r in dr]
            if g.get('fp'): kind='p'
            elif opt or (len(vl)>=3 and g['y1']-g['y0']>60): kind='q'
            elif len(ws)>=40: kind='p'
            else: continue
            if kind=='q' and len(ws)>60 and not opt and len(vl)<3: kind='p'
            x0=min([30]+xs) if xs else 30; x1=max([555]+xs) if xs else 555
            x0=min(x0,min(w[0] for w in ws) if ws else x0); x1=max(x1,max(w[2] for w in ws) if ws else x1)
            clip=fitz.Rect(max(0,x0-3),g['y0']-3,min(W,x1+3),g['y1']+3)
            pix=p.get_pixmap(dpi=dpi,clip=clip); im=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
            if kind=='p':
                npass+=1; fn=f'{tag}-pass{npass}.webp'; im.save(f'{base}/{fn}','WEBP',quality=80,method=6); cur={'img':fn,'w':im.width,'h':im.height}
            else:
                fn=f'{tag}-{len(res)+1:03d}.webp'; im.save(f'{base}/{fn}','WEBP',quality=80,method=6)
                res.append({'n':len(res)+1,'page':pi,'img':fn,'w':im.width,'h':im.height,'pre':cur,'noopt':False,'words':len(ws)})
    return res
if __name__=='__main__':
    pdf,tag,pages=sys.argv[1],sys.argv[2],[int(x) for x in sys.argv[3].split(',')]
    r=blocks(pdf,tag,pages)
    json.dump(r,open(f'formout/{tag}.json','w'),ensure_ascii=False)
    import collections; print(len(r),dict(collections.Counter(x['page'] for x in r)))
