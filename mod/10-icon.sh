#!/bin/bash
set -e
pip install --quiet pillow || true
python3 - <<'PY'
import glob, os, sys
try:
    from PIL import Image
except Exception:
    print("WARNING: Pillow не установился")
    sys.exit(0)
if not os.path.exists("icon.png"):
    print("WARNING: icon.png не найден, иконка не меняется")
    sys.exit(0)
img = Image.open("icon.png").convert("RGBA")
corner = img.getpixel((5, 5))
n = 0
for d in glob.glob("TMessagesProj*/src/*/res/mipmap-*"):
    for f in glob.glob(d + "/*.png"):
        name = os.path.basename(f).lower()
        if not name.startswith(("ic_launcher", "icon")):
            continue
        w, h = Image.open(f).size
        if "background" in name:
            Image.new("RGBA", (w, h), corner).save(f)
        elif "foreground" in name:
            canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            k = int(w * 0.66)
            canvas.paste(img.resize((k, k), Image.LANCZOS), ((w - k) // 2, (h - k) // 2))
            canvas.save(f)
        else:
            img.resize((w, h), Image.LANCZOS).save(f)
        n += 1
print("Иконка: заменено файлов =", n)
PY
