import json,sys
from PIL import Image,ImageDraw
tag,a,b,out=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),sys.argv[4]
d=json.load(open(f'formout/{tag}.json'))
ims=[]
for i in range(a-1,b):
    r=d[i]; im=Image.open(f'formout/{tag}/{r["img"]}').convert('RGB'); c=Image.new('RGB',(im.width,im.height+16),'#fff3c4'); c.paste(im,(0,16)); ImageDraw.Draw(c).text((4,2),f'#{i+1}',fill=(200,0,0)); ims.append(c)
W=max(i.width for i in ims);H=sum(i.height+3 for i in ims);c=Image.new('RGB',(W,H),'white');y=0
for i in ims:c.paste(i,(0,y));y+=i.height+3
c.save(out);print(out,c.size)
