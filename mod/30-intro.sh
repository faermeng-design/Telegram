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
    print("WARNING: icon.png не найден")
    sys.exit(0)
img = Image.open("icon.png").convert("RGBA")
n = 0
for f in glob.glob("TMessagesProj*/src/*/res/drawable*/intro_tg_plane.*"):
    ext = os.path.splitext(f)[1].lower()
    fmt = {".webp": "WEBP", ".png": "PNG"}.get(ext)
    try:
        w, h = Image.open(f).size
    except Exception:
        fmt = None
    if not fmt:
        print("пропущен:", f)
        continue
    k = min(w, h)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(img.resize((k, k), Image.LANCZOS), ((w - k) // 2, (h - k) // 2))
    out.save(f, fmt)
    print("заменён:", f, w, h)
    n += 1
print("Приветственный экран: заменено файлов =", n)
PY
