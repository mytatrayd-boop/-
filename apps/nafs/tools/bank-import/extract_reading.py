import fitz,collections,re,json,sys,os
from PIL import Image
def isyellow(f): return f and len(f)==3 and f[0]>0.9 and f[1]>0.9 and f[2]<0.4
def parse(pdf, answers=False):
    items=[]; 
    for pi,p in enumerate(pdf):
        H=collections.defaultdict(list)
        for dr in p.get_drawings():
            if dr.get('fill')==(0.0,0.0,0.0):
                r=dr['rect']
                if r.height<1.6 and r.width>8: H[round(r.y0)].append((r.x0,r.x1))
        full=[y for y,xs in sorted(H.items()) if max(x[1] for x in xs)>=800 and min(x[0] for x in xs)<80]
        part=[y for y,xs in sorted(H.items()) if max(x[1] for x in xs)<800]
        words=p.get_text('words')
        yel=[dr['rect'] for dr in p.get_drawings() if isyellow(dr.get('fill'))] if answers else []
        for y0,y1 in zip(full,full[1:]):
            ws=[w for w in words if y0-1<=w[1]<y1]
            if not ws: continue
            txt=' '.join(w[4] for w in sorted(ws,key=lambda w:(round(w[1]/6),-w[0])))
            labs=[w for w in ws if w[4]=='السؤال' and w[0]>700]
            ind=[w for w in ws if 'ؤشر' in w[4] and w[0]>740]
            if labs:
                ids=sorted({int((738-(r.x0+r.x1)/2)//166.5) for r in yel if r.y0>=y0-1 and r.y1<=y1+2 and r.x0>=70})
                items.append({'k':'q','page':pi,'y0':y0,'y1':y1,'text':re.sub(r'\s+',' ',' '.join(w[4] for w in ws if w[0]<738)).strip(),'ans':ids})
            elif ind:
                body=' '.join(w[4] for w in sorted(ws,key=lambda w:(round(w[1]/6),-w[0])) if w[0]<738)
                items.append({'k':'i','page':pi,'text':body})
            else:
                ids=sorted({int((738-(r.x0+r.x1)/2)//166.5) for r in yel if r.y0>=y0-1 and r.y1<=y1+2 and r.x0>=70})
                items.append({'k':'p','page':pi,'y0':y0,'y1':y1,'text':txt,'title':'عنوان' in txt and 'النص' in txt,'ans':ids})
    # صف خيارات انقسم إلى الصفحة التالية: يُدمج مع سؤاله
    out=[];i=0
    while i<len(items):
        it=items[i]
        if it['k']=='q' and i+1<len(items):
            nx=items[i+1]
            if nx['k']=='p' and not nx['title'] and nx['page']==it['page']+1 and nx['y0']<120 and nx['y1']-nx['y0']<80:
                it=dict(it); it['cont']=nx; it['ans']=nx['ans'] if not it['ans'] else it['ans']; out.append(it); i+=2; continue
        out.append(it); i+=1
    return out
LV=[('معرف','know'),('تطبيق','apply'),('ستدال','reason')]
def level_of(t):
    tail=re.sub(r'[\u064b-\u065f]','',t)[-45:]
    pos={}
    for k,v in (('عرفة','know'),('تطبيق','apply'),('ستدا','reason'),('ستدل','reason')):
        i=tail.rfind(k)
        if i>=0: pos[v]=i
    return max(pos,key=pos.get) if pos else 'know'
from mapbank import SK,best
def build(key,subject,grade,dest):
    qpdf=fitz.open(f'bankpdf/{key}-q.pdf')
    q=parse(qpdf); a=parse(fitz.open(f'bankpdf/{key}-a.pdf'),True)
    aq=[x for x in a if x['k']=='q']
    os.makedirs(dest,exist_ok=True)
    skills=SK[f'{subject}{grade}']; flat=[(s['id'],s['desc']+' '+s['name']) for o in skills for s in o['skills']]
    cur_ind=None;cur_level=None;pass_rows=[];pass_id=0;pass_img=None;pass_open=False
    out=[];anom=[];qi=0
    def render_rows(rows):
        ims=[]
        for r in rows:
            clip=fitz.Rect(70,r['y0'],818,r['y1']+1)
            pix=qpdf[r['page']].get_pixmap(dpi=110,clip=clip)
            ims.append(Image.frombytes('RGB',(pix.width,pix.height),pix.samples))
        W=max(i.width for i in ims); H=sum(i.height for i in ims)
        canvas=Image.new('RGB',(W,H),'white'); y=0
        for i in ims: canvas.paste(i,(0,y)); y+=i.height
        return canvas
    for it in q:
        if it['k']=='p':
            if it['title']:
                pass_rows=[it]; pass_open=True; pass_id+=1; pass_img=None
            elif pass_open and not pass_img:
                if (it['y1']-it['y0']<80) and ('القراءة' in it['text'] or 'جال' in it['text'] or 'جلال' in it['text']):
                    im=render_rows(pass_rows); fn=f'{key}-p{pass_id:02d}.webp'
                    im.save(os.path.join(dest,fn),'WEBP',quality=80,method=6); pass_img=(fn,im.width,im.height)
                else: pass_rows.append(it)
        elif it['k']=='i':
            if pass_open and not pass_img and pass_rows:
                im=render_rows(pass_rows); fn=f'{key}-p{pass_id:02d}.webp'
                im.save(os.path.join(dest,fn),'WEBP',quality=80,method=6); pass_img=(fn,im.width,im.height)
            cur_ind=it['text']; cur_level=level_of(it['text'])
        else:
            if pass_open and not pass_img and pass_rows:
                im=render_rows(pass_rows); fn=f'{key}-p{pass_id:02d}.webp'
                im.save(os.path.join(dest,fn),'WEBP',quality=80,method=6); pass_img=(fn,im.width,im.height)
            qi+=1
            ans=aq[qi-1]['ans'] if qi-1<len(aq) else []
            rec={'n':qi,'ind':cur_ind,'level':cur_level,'ans':ans,'text':it['text']}
            if len(ans)!=1 or not (0<=ans[0]<4) or not cur_level or not cur_ind: anom.append(rec); continue
            sc=best(cur_ind,flat)
            clip=fitz.Rect(70,it['y0'],740,it['y1']+1)
            pix=qpdf[it['page']].get_pixmap(dpi=130,clip=clip)
            im=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
            if 'cont' in it:
                c=it['cont']; p2=qpdf[c['page']].get_pixmap(dpi=130,clip=fitz.Rect(70,c['y0'],740,c['y1']+1))
                im2=Image.frombytes('RGB',(p2.width,p2.height),p2.samples)
                cv=Image.new('RGB',(max(im.width,im2.width),im.height+im2.height),'white'); cv.paste(im,(0,0)); cv.paste(im2,(0,im.height)); im=cv
            pix_w,pix_h=im.width,im.height
            fn=f'{key}-{qi:03d}.webp'; im.save(os.path.join(dest,fn),'WEBP',quality=80,method=6)
            item={'id':fn[:-5],'skill':sc[0][1],'score':round(sc[0][0],2),'level':cur_level,'img':fn,'w':pix_w,'h':pix_h,'answer':ans[0]}
            if pass_img: item.update(passage=pass_img[0],pw=pass_img[1],ph=pass_img[2])
            out.append(item)
    return out,anom
if __name__=='__main__':
    key=sys.argv[1]; sub,gr=key[:-1],int(key[-1])
    out,anom=build(key,sub,gr,f'readout/{key}')
    json.dump(out,open(f'readout/{key}.json','w'),ensure_ascii=False,indent=0)
    print(key,'ok',len(out),'anom',len(anom),'low-score',sum(1 for x in out if x['score']<0.4))
    for r in anom[:6]: print(' anom',r['n'],r['ans'],r['level'],(r['ind'] or '')[:40])
