import json,re,sys
SK=json.load(open('skills.json'))
def norm(t):
    t=re.sub(r'[ً-ٟـ]','',t)
    t=t.replace('أ','ا').replace('إ','ا').replace('آ','ا').replace('ى','ي').replace('ة','ه')
    t=re.sub(r'[^ء-ي ]',' ',t)
    t=t.replace('ا','').replace('ل','')   # ligature-robust
    return re.sub(r'\s+',' ',t).strip()
def grams(t):
    t=norm(t).replace(' ','')
    return {t[i:i+3] for i in range(len(t)-2)}
def sim(a,b):
    A,B=grams(a),grams(b)
    return len(A&B)/max(1,min(len(A),len(B)))
def best(text,cands):
    sc=[(sim(text,c[1]),c[0]) for c in cands]
    sc.sort(reverse=True); return sc
if __name__=='__main__':
    key=sys.argv[1]  # e.g. math3
    d=json.load(open(f'bankout/{key}.json'))['ok']
    outs=SK[key]
    stds=sorted({r['std'] for r in d})
    for s in stds:
        sc=best(s,[(o['id'],o['desc']+' '+o['name']) for o in outs])
        print(round(sc[0][0],2),sc[0][1],'|',round(sc[1][0],2),sc[1][1],'|',s[:60])
