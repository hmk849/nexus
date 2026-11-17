#!/usr/bin/env python3
"""生成 NEXUS 图标：深色渐变底 + 由四个节点连接而成的「N」(Nexus = 连接点)。"""
from PIL import Image, ImageDraw, ImageFilter, ImageOps, ImageChops
S = 2048
top, bot = (12, 16, 44), (58, 44, 160)
g = Image.linear_gradient("L").resize((S, S), Image.BICUBIC)
bg = Image.composite(Image.new("RGB", (S, S), bot), Image.new("RGB", (S, S), top), g)
glow = ImageOps.invert(Image.radial_gradient("L").resize((S, S), Image.BICUBIC)).point(lambda v: int(v * 0.40))
bg = Image.composite(Image.new("RGB", (S, S), (96, 150, 255)), bg, glow)

x0, x1, y0, y1 = int(S*.31), int(S*.69), int(S*.29), int(S*.71)
pts = {"bl": (x0, y1), "tl": (x0, y0), "br": (x1, y1), "tr": (x1, y0)}
w, R, r = int(S*.045), int(S*.062), int(S*.030)

def strokes():
    m = Image.new("L", (S, S), 0); d = ImageDraw.Draw(m)
    for a, b in (("bl", "tl"), ("tl", "br"), ("br", "tr")):
        d.line([pts[a], pts[b]], fill=255, width=w)
        for p in (pts[a], pts[b]):
            d.ellipse([p[0]-w//2, p[1]-w//2, p[0]+w//2, p[1]+w//2], fill=255)
    for p in pts.values():
        d.ellipse([p[0]-R, p[1]-R, p[0]+R, p[1]+R], fill=255)
        d.ellipse([p[0]-r, p[1]-r, p[0]+r, p[1]+r], fill=0)
    return m

mask = strokes()
shadow = mask.filter(ImageFilter.GaussianBlur(S*.012)).point(lambda v: int(v*.5))
bg = Image.composite(Image.new("RGB", (S, S), (4, 6, 20)), bg, ImageChops.offset(shadow, 0, int(S*.012)))
fg = Image.composite(Image.new("RGB", (S, S), (170, 205, 255)), Image.new("RGB", (S, S), (255, 255, 255)), g)
bg = Image.composite(fg, bg, mask)
sheen = ImageOps.invert(g).point(lambda v: int(max(0, v-120) * .22))
bg = Image.composite(Image.new("RGB", (S, S), (255, 255, 255)), bg, sheen)
bg.resize((1024, 1024), Image.LANCZOS).save("NEXUS/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
print("ok")
