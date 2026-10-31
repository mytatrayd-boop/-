"""Generate logo-light.png and logo-mark.png from assets/logo.png.
Usage: python3 tools/make_logos.py   (needs Pillow + numpy)"""
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

A = Path(__file__).resolve().parent.parent / "assets"
src = Image.open(A / "logo.png").convert("RGBA")
a = np.array(src)
alpha = a[..., 3].astype(np.float32) / 255
lum = (a[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32)) / 255
density = alpha * (1 - lum)  # ink density; paper/highlights become transparent


def save_white(dens, path):
    out = np.zeros(dens.shape + (4,), np.uint8)
    out[..., :3] = 255
    out[..., 3] = np.clip(dens * 255, 0, 255).astype(np.uint8)
    Image.fromarray(out).save(path)


def components(mask):
    h, w = mask.shape
    lab = np.zeros((h, w), int)
    n = 0
    for y, x in zip(*np.nonzero(mask)):
        if lab[y, x]:
            continue
        n += 1
        lab[y, x] = n
        q = deque([(y, x)])
        while q:
            cy, cx = q.popleft()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = n
                        q.append((ny, nx))
    return lab, n


save_white(density, A / "logo-light.png")

# mark = components (of a slightly dilated mask) belonging to bean + leaves
solid = (alpha > 0.1)
dil = np.array(Image.fromarray((solid * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
lab, n = components(dil)
sizes = [(int(((lab == i) & solid).sum()), i) for i in range(1, n + 1)]
sizes.sort(reverse=True)
print("components (pixels,id):", sizes[:6])
ys, xs = np.nonzero(lab == sizes[0][1])
print("largest bbox y", ys.min(), ys.max(), "x", xs.min(), xs.max())

keep = lab == sizes[0][1]
m = a.copy()
m[..., 3] = np.where(keep, m[..., 3], 0)
mark = Image.fromarray(m)
bbox = mark.getchannel("A").point(lambda v: 255 if v > 0 else 0).getbbox()
pad = 8
bbox = (max(bbox[0] - pad, 0), max(bbox[1] - pad, 0),
        min(bbox[2] + pad, mark.width), min(bbox[3] + pad, mark.height))
mark.crop(bbox).save(A / "logo-mark.png")
print("mark bbox", bbox)
