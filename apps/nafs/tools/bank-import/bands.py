import fitz,numpy as np,sys,glob
from PIL import Image
def page_bands(pdf,pi,dpi=130,gap=14,margin=0.06):
    q=fitz.open(pdf); pix=q[pi].get_pixmap(dpi=dpi); im=Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
    a=np.array(im.convert('L'))<205; h,w=a.shape
    a[:, :int(w*margin)]=False; a[:, int(w*(1-margin)):]=False; a[:int(h*margin)]=False; a[int(h*(1-margin)):]=False
    rows=a.any(1); b=[];s=None
    for y,v in enumerate(rows):
        if v and s is None:s=y
        if not v and s is not None:b.append([s,y]);s=None
    m=[]
    for x in b:
        if m and x[0]-m[-1][1]<gap: m[-1][1]=x[1]
        else: m.append(x)
    return im,m
if __name__=='__main__':
    pdf=sys.argv[1]
    for pi in map(int,sys.argv[2].split(',')):
        im,m=page_bands(pdf,pi); print(pi,im.size,[(x[0],x[1]) for x in m])
