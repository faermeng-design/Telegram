#!/bin/bash
python3 -m pip install --quiet pillow 2>/dev/null || true
python3 - <<'PY'
import glob, os
from collections import Counter
try:
    from PIL import Image, ImageDraw
except Exception:
    print("WARNING: Pillow недоступен, иконки не тронуты")
    raise SystemExit(0)

DEFAULT_BG = (0x15, 0x0d, 0x2d, 255)

def find_tile(path):
    img = Image.open(path).convert("RGBA")
    small = img.resize((128, 128))
    cnt = Counter(c for c in small.getdata() if c[3] >= 250)
    bg = cnt.most_common(1)[0][0] if cnt else DEFAULT_BG
    px = img.load()
    w, h = img.size
    x0, y0, x1, y1 = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 128 and max(abs(r - bg[0]), abs(g - bg[1]), abs(b - bg[2])) > 45:
                if x < x0: x0 = x
                if x > x1: x1 = x
                if y < y0: y0 = y
                if y > y1: y1 = y
    if x1 < 0 or (x1 - x0) < w * 0.15:
        box = img.getchannel("A").getbbox() or (0, 0, w, h)
    else:
        box = (x0, y0, x1 + 1, y1 + 1)
    return bg, img.crop(box)

def square(tile):
    w, h = tile.size
    s = max(w, h)
    sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sq.paste(tile, ((s - w) // 2, (s - h) // 2))
    return sq

def layers(src, bg_path, fg_path):
    bg, tile = find_tile(src)
    art = square(tile)
    os.makedirs(os.path.dirname(bg_path), exist_ok=True)
    Image.new("RGBA", (432, 432), bg).save(bg_path)
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    k = 294
    fg.alpha_composite(art.resize((k, k), Image.LANCZOS), dest=((432 - k) // 2, (432 - k) // 2))
    fg.save(fg_path)
    return bg, art

def legacy(path, bg, art, round_icon):
    w, h = Image.open(path).size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    if round_icon:
        d.ellipse((0, 0, w - 1, h - 1), fill=255)
    else:
        d.rounded_rectangle((0, 0, w - 1, h - 1), radius=int(w * 0.22), fill=255)
    out.paste(Image.new("RGBA", (w, h), bg), (0, 0), mask)
    k = int(w * 0.68)
    out.alpha_composite(art.resize((k, k), Image.LANCZOS), dest=((w - k) // 2, (h - k) // 2))
    out.save(path)

res = "TMessagesProj/src/main/res/"
if os.path.exists("icon.png"):
    bg, art = layers("icon.png", res + "mipmap-xxxhdpi/telegyou_main_bg.png",
                     res + "mipmap-xxxhdpi/telegyou_main_fg.png")
    n = 0
    for f in glob.glob("TMessagesProj*/src/*/res/mipmap-*/*.png"):
        name = os.path.basename(f)
        if name in ("ic_launcher.png", "ic_launcher_round.png", "ic_launcher_sa.png"):
            legacy(f, bg, art, "round" in name)
            n += 1
    print("Основная иконка: по центру, PNG =", n)
else:
    print("WARNING: icon.png не найден")

if os.path.exists("icon2.png"):
    bg2, art2 = layers("icon2.png", res + "mipmap-xxxhdpi/telegyou_icon_background.png",
                       res + "mipmap-xxxhdpi/telegyou_icon_foreground.png")
    lp = res + "mipmap-xxxhdpi/telegyou_icon_launcher.png"
    if os.path.exists(lp):
        legacy(lp, bg2, art2, False)
    print("Вторая иконка: по центру")
PY
