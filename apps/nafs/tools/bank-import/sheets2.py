import json,sys
from PIL import Image,ImageDraw
def sheets(tag,per=10):
    d=json.load(open(f'formout/{tag}.json'))
    outs=[]
    for k in range(0,len(d),per):
        chunk=d[k:k+per]; ims=[]
        for i,r in enumerate(chunk):
            im=Image.open(f'formout/{tag}/{r["img"]}').convert('RGB')
            tag_h=26; c=Image.new('RGB',(im.width,im.height+tag_h),'#fff3c4'); c.paste(im,(0,tag_h))
            ImageDraw.Draw(c).text((6,6),f'#{k+i+1}',fill=(200,0,0)); ims.append(c)
        W=max(i.width for i in ims); H=sum(i.height+4 for i in ims)
        cv=Image.new('RGB',(W,H),'white'); y=0
        for i in ims: cv.paste(i,(0,y)); y+=i.height+4
        if cv.height>1900: cv=cv.resize((int(cv.width*1900/cv.height),1900))
        fn=f'bank/sh_{tag}_{k//per}.png'; cv.save(fn); outs.append(fn)
    # passages
    ps=sorted({(r['pre']['img'],r['pre']['w'],r['pre']['h']) for r in d if r['pre']})
    return outs,ps
if __name__=='__main__':
    print(sheets(sys.argv[1]))
