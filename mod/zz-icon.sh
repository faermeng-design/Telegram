#!/bin/bash
python3 -m pip install --quiet pillow 2>/dev/null || true
python3 - <<'PY'
import glob, os, re
try:
    from PIL import Image, ImageDraw
except Exception:
    print("WARNING: Pillow недоступен, иконки не тронуты")
    raise SystemExit(0)

DEFAULT_BG = (0x15, 0x0d, 0x2d, 255)
INTRO_SIZE = 0.92   # размер иконки на приветственном экране (доля круга)
LAYER = 1152        # размер слоёв иконки (больше = чётче заставка)

def keep_main(counts):
    m = max(counts) if counts else 0
    if m == 0:
        return None
    idx = [i for i, c in enumerate(counts) if c >= m * 0.25]
    return idx[0], idx[-1]

def find_tile(path):
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    transparent = sum(1 for y in range(0, h, 4) for x in range(0, w, 4) if px[x, y][3] < 128)
    share = transparent / float(((h + 3) // 4) * ((w + 3) // 4))
    if share > 0.2:
        bg = DEFAULT_BG
        def is_tile(p):
            return p[3] > 128
    else:
        small = img.resize((128, 128))
        cnt = {}
        for c in small.getdata():
            if c[3] >= 250:
                cnt[c] = cnt.get(c, 0) + 1
        bg = max(cnt, key=cnt.get) if cnt else DEFAULT_BG
        def is_tile(p):
            return p[3] > 128 and max(abs(p[0] - bg[0]), abs(p[1] - bg[1]), abs(p[2] - bg[2])) > 45
    cols = [0] * w
    rows = [0] * h
    for y in range(h):
        for x in range(w):
            if is_tile(px[x, y]):
                cols[x] += 1
                rows[y] += 1
    cx = keep_main(cols)
    ry = keep_main(rows)
    if cx and ry:
        box = (cx[0], ry[0], cx[1] + 1, ry[1] + 1)
    else:
        box = img.getchannel("A").getbbox() or (0, 0, w, h)
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
    Image.new("RGBA", (LAYER, LAYER), bg).save(bg_path)
    fg = Image.new("RGBA", (LAYER, LAYER), (0, 0, 0, 0))
    k = int(LAYER * 0.68)
    fg.alpha_composite(art.resize((k, k), Image.LANCZOS), dest=((LAYER - k) // 2, (LAYER - k) // 2))
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
    # приветственный экран: иконка крупнее
    m = 0
    for f in glob.glob("TMessagesProj*/src/*/res/drawable*/intro_tg_plane.*"):
        ext = os.path.splitext(f)[1].lower()
        fmt = {".webp": "WEBP", ".png": "PNG"}.get(ext)
        if not fmt:
            continue
        w, h = Image.open(f).size
        k = int(min(w, h) * INTRO_SIZE)
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        out.alpha_composite(art.resize((k, k), Image.LANCZOS), dest=((w - k) // 2, (h - k) // 2))
        out.save(f, fmt)
        m += 1
    print("Приветственный экран: иконка крупнее, файлов =", m)
else:
    print("WARNING: icon.png не найден")

if os.path.exists("icon2.png"):
    bg2, art2 = layers("icon2.png", res + "mipmap-xxxhdpi/telegyou_icon_background.png",
                       res + "mipmap-xxxhdpi/telegyou_icon_foreground.png")
    lp = res + "mipmap-xxxhdpi/telegyou_icon_launcher.png"
    if os.path.exists(lp):
        legacy(lp, bg2, art2, False)
    print("Вторая иконка: по центру")

# название на приветственном экране
cnt = 0
for f in glob.glob("TMessagesProj*/src/*/res/values*/strings*.xml"):
    s = open(f, encoding="utf-8").read()
    t = re.sub(r'(<string name="Page1Title"[^>]*>)[^<]*(</string>)', r'\1Telegyou\2', s)
    if t != s:
        open(f, "w", encoding="utf-8").write(t)
        cnt += 1
print("Приветственный экран: название Telegyou, файлов =", cnt)
PY
