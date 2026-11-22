import json,re
from mapbank import grams
def load(key):
    raw=json.load(open(f'bankout/{key}.json'))['ok']
    final={x['id']:x for x in json.load(open(f'/home/user/-/apps/nafs/public/bank-official/{key}.json'))}
    out=[]
    for r in raw:
        fid=r['img'][:-5]
        if fid in final: out.append((r['text'],final[fid]['skill'],final[fid]['level'],fid))
    return out
def jac(a,b):
    A,B=grams(a),grams(b)
    return len(A&B)/max(1,len(A|B))
def match(text,bank):
    best=max(((jac(text,t),sk,lv,fid) for t,sk,lv,fid in bank),default=(0,None,None,None))
    return best
if __name__=='__main__':
    import sys
    key,mock,sec=sys.argv[1:4]
    bank=load(key)
    d=[r for r in json.load(open(f'mockout/{mock}.json'))['ok'] if r['sec']==sec]
    hit=0
    for r in d:
        s,sk,lv,fid=match(r['text'],bank)
        print(r['n'],round(s,2),sk,lv)
        hit+= s>=0.5
    print('hits',hit,'of',len(d))
