import fitz,json,sys,os
from PIL import Image
# تقطيع بحسب جدول الأسئلة: عمود الرقم (أقصى اليمين) وعمود رمز الخيار؛ السؤال = صفوف تنتهي بصف الخيارات
def rows(pdf,tag,pages,dpi=130):
    q=fitz.open(pdf); base=f'formout/{tag}'; os.makedirs(base,exist_ok=True); out=[]
    for pi in pages:
        p=q[pi]
        V=[d['rect'] for d in p.get_drawings() if d['rect'].width<1.5 and d['rect'].height>8 and d['rect'].x0>480]
        xs=sorted({round(r.x0) for r in V},reverse=True)
        # دمج الإحداثيات المتقاربة
        cl=[]
        for x in xs:
            if not cl or cl[-1]-x>3: cl.append(x)
        edge,lab,opt=cl[0],cl[1],cl[2]
        L=sorted([(r.y0,r.y1) for r in V if abs(r.x0-lab)<=3])
        O=[(r.y0,r.y1) for r in V if abs(r.x0-opt)<=3]
        isopt=lambda a,b:any(abs(a-c)<4 and abs(b-d)<4 for c,d in O)
        cur=None
        for a,b in L:
            if cur is None: cur=[a,b]
            else: cur[1]=b
            if isopt(a,b):
                clip=fitz.Rect(26,cur[0]-1,edge+3,cur[1]+1)
                pix=p.get_pixmap(dpi=dpi,clip=clip); im=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
                fn=f'{tag}-p{pi:02d}r{len(out)+1:03d}.webp'; im.save(f'{base}/{fn}','WEBP',quality=80,method=6)
                out.append({'n':0,'page':pi,'img':fn,'w':im.width,'h':im.height,'pre':None,'noopt':False}); cur=None
    return out
if __name__=='__main__':
    pdf,tag,pages=sys.argv[1],sys.argv[2],[int(x) for x in sys.argv[3].split(',')]
    d=json.load(open(f'formout/{tag}.json')); d=[r for r in d if r['page'] not in pages]+rows(pdf,tag,pages)
    d.sort(key=lambda r:r['page'])
    json.dump(d,open(f'formout/{tag}.json','w'),ensure_ascii=False); print(len(d))
