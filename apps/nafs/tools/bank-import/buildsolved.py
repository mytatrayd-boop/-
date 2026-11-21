import json,shutil,os,sys
SK=json.load(open('skills.json'))
valid={s['id'] for k,v in SK.items() for o in v for s in o['skills']}
L={'k':'know','a':'apply','r':'reason'}
dest='/home/user/-/apps/nafs/public/bank-official/solved'
os.makedirs(dest,exist_ok=True)
FILE='/home/user/-/apps/nafs/public/bank-official/solved.json'
def load(): return json.load(open(FILE)) if os.path.exists(FILE) else []
def add(form_id,grade,name,subject,tag,answers,tags):
    """answers: 'ج أ ...' letters; tags: 'skill:level ...'"""
    A={'أ':0,'ب':1,'ج':2,'د':3}
    ans=[A[x] for x in answers.split()]
    tg=[t.split(':') for t in tags.split()]
    d=json.load(open(f'formout/{tag}.json'))
    assert len(d)==len(ans)==len(tg),(len(d),len(ans),len(tg))
    qs=[];prev=None
    for r,a,(sk,lv) in zip(d,ans,tg):
        assert sk in valid,sk
        shutil.copy(f'formout/{tag}/{r["img"]}',f'{dest}/{r["img"]}')
        q={'skill':sk,'level':L[lv],'img':f'solved/{r["img"]}','w':r['w'],'h':r['h'],'answer':a}
        p=r['pre']
        if p and p['img']!=prev:
            shutil.copy(f'formout/{tag}/{p["img"]}',f'{dest}/{p["img"]}')
            q.update(passage=f'solved/{p["img"]}',pw=p['w'],ph=p['h'])
        prev=p['img'] if p else None
        qs.append(q)
    forms=[f for f in load() if f['id']!=form_id]
    forms.append({'id':form_id,'grade':grade,'name':name,'subjects':{subject:qs}})
    json.dump(forms,open(FILE,'w'),ensure_ascii=False,separators=(',',':'))
    print(form_id,len(qs))

def add_form(form_id,grade,name,tag,sections,fix=None):
    """sections: list of dict(subject, idx=[1-based indexes in extraction], answers='...', tags='...', passage={idx:passage_file or None})"""
    from PIL import Image
    A={'أ':0,'ب':1,'ج':2,'د':3}
    d=json.load(open(f'formout/{tag}.json'))
    base=f'formout/{tag}'
    subjects={}
    for sec in sections:
        ans=[A[x] for x in sec['answers'].split()]
        tg=[t.split(':') for t in sec['tags'].split()]
        idxs=sec['idx']
        assert len(idxs)==len(ans)==len(tg),(sec['subject'],len(idxs),len(ans),len(tg))
        qs=[];prev=None
        for i,a,(sk,lv) in zip(idxs,ans,tg):
            assert sk in valid,sk
            r=d[i-1]; img=r['img']
            if fix and i in fix:  # دمج صف خيارات منقسم
                im1=Image.open(f'{base}/{r["img"]}').convert('RGB'); im2=Image.open(f'{base}/{fix[i]}').convert('RGB')
                cv=Image.new('RGB',(max(im1.width,im2.width),im1.height+im2.height),'white'); cv.paste(im1,(0,0)); cv.paste(im2,(0,im1.height))
                img=f'{tag}-{i:03d}m.webp'; cv.save(f'{base}/{img}','WEBP',quality=80,method=6); w,h=cv.size
            else: w,h=r['w'],r['h']
            shutil.copy(f'{base}/{img}',f'{dest}/{img}')
            q={'skill':sk,'level':L[lv],'img':f'solved/{img}','w':w,'h':h,'answer':a}
            pf=sec.get('passage',{}).get(i)
            if pf and pf!=prev:
                shutil.copy(f'{base}/{pf}',f'{dest}/{pf}'); pw,ph=Image.open(f'{base}/{pf}').size
                q.update(passage=f'solved/{pf}',pw=pw,ph=ph)
            prev=pf
            qs.append(q)
        subjects[sec['subject']]=qs
    forms=[f for f in load() if f['id']!=form_id]
    forms.append({'id':form_id,'grade':grade,'name':name,'subjects':subjects})
    json.dump(forms,open(FILE,'w'),ensure_ascii=False,separators=(',',':'))
    print(form_id,{k:len(v) for k,v in subjects.items()})
