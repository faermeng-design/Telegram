#!/bin/bash
set -e
pip install --quiet pillow || true
python3 - <<'PY'
import glob, os, sys
try:
    from PIL import Image, ImageDraw, ImageChops
except Exception:
    print("WARNING: Pillow не установился")
    sys.exit(0)
if not os.path.exists("icon.png"):
    print("WARNING: icon.png не найден, иконка не меняется")
    sys.exit(0)
img = Image.open("icon.png").convert("RGBA")
corner = img.getpixel((5, 5))
MAIN = {"ic_launcher.png", "ic_launcher_round.png", "ic_launcher_sa.png",
        "icon_background_clip.png", "icon_background_clip_round.png",
        "icon_foreground.png", "icon_foreground_round.png", "icon_foreground_sa.png"}
n = 0
for f in glob.glob("TMessagesProj*/src/*/res/mipmap-*/*.png"):
    name = os.path.basename(f)
    if name not in MAIN:
        continue
    w, h = Image.open(f).size
    if "background_clip" in name:
        out = Image.new("RGBA", (w, h), corner)
    elif "foreground" in name:
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        k = int(w * 0.66)
        out.paste(img.resize((k, k), Image.LANCZOS), ((w - k) // 2, (h - k) // 2))
    else:
        out = img.resize((w, h), Image.LANCZOS)
        if "round" in name:
            mask = Image.new("L", (w, h), 0)
            ImageDraw.Draw(mask).ellipse((0, 0, w - 1, h - 1), fill=255)
            out.putalpha(ImageChops.multiply(out.getchannel("A"), mask))
    out.save(f)
    n += 1
print("Иконка Основная: заменено файлов =", n)
PY
