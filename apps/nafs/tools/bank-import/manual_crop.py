import fitz,json,sys
from PIL import Image
# manual_crop.py pdf tag page x0 y0 x1 y1 [replace=N | insert_after=N]   (N = رقم السجل 1-based)
pdf,tag,pg,x0,y0,x1,y1,mode=sys.argv[1],sys.argv[2],int(sys.argv[3]),*map(float,sys.argv[4:8]),sys.argv[8]
q=fitz.open(pdf); p=q[pg]; pix=p.get_pixmap(dpi=130,clip=fitz.Rect(x0,y0,x1,y1)); im=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
d=json.load(open(f'formout/{tag}.json')); k,n=mode.split('='); n=int(n)
fn=f'{tag}-man{pg}_{int(y0)}.webp'; im.save(f'formout/{tag}/{fn}','WEBP',quality=80,method=6)
r={'n':0,'page':pg,'img':fn,'w':im.width,'h':im.height,'pre':None,'noopt':False}
if k=='replace': d[n-1]=r
else: d.insert(n,r)
for i,x in enumerate(d,1): x['n']=i
json.dump(d,open(f'formout/{tag}.json','w'),ensure_ascii=False); print(len(d))
