#!/bin/bash
set -e
pip install --quiet pillow || true
python3 - <<'PY'
import glob, os, re, sys
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

# 1) Новые картинки только для Основной
res = "TMessagesProj/src/main/res/mipmap-xxxhdpi/"
os.makedirs(res, exist_ok=True)
Image.new("RGBA", (432, 432), corner).save(res + "telegyou_main_bg.png")
fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
k = 285
fg.paste(img.resize((k, k), Image.LANCZOS), ((432 - k) // 2, (432 - k) // 2))
fg.save(res + "telegyou_main_fg.png")
print("Новые картинки: готово")

# 2) Обычные иконки Основной
n = 0
for f in glob.glob("TMessagesProj*/src/*/res/mipmap-*/*.png"):
    name = os.path.basename(f)
    if name not in ("ic_launcher.png", "ic_launcher_round.png", "ic_launcher_sa.png"):
        continue
    w, h = Image.open(f).size
    out = img.resize((w, h), Image.LANCZOS)
    if "round" in name:
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, w - 1, h - 1), fill=255)
        out.putalpha(ImageChops.multiply(out.getchannel("A"), mask))
    out.save(f)
    n += 1
print("Иконка Основная: заменено файлов =", n)

# 3) Адаптивные иконки Основной: подставляем новые картинки
x = 0
names = []
for f in glob.glob("TMessagesProj*/src/*/res/*anydpi*/*.xml"):
    base = os.path.basename(f)
    if not base.startswith("ic_launcher"):
        continue
    names.append(base)
    t = open(f, encoding="utf-8").read()
    t2 = re.sub(r'@(mipmap|drawable)/icon_foreground(_round|_sa)?', '@mipmap/telegyou_main_fg', t)
    t2 = re.sub(r'@(mipmap|drawable)/icon_background_clip(_round)?', '@mipmap/telegyou_main_bg', t2)
    t2 = re.sub(r'@(mipmap|drawable)/icon_background_sa', '@mipmap/telegyou_main_bg', t2)
    if t2 != t:
        open(f, "w", encoding="utf-8").write(t2)
        x += 1
print("Адаптивные иконки: изменено =", x, names)

# 4) Список иконок в настройках: только строка Основной
p = "TMessagesProj/src/main/java/org/telegram/ui/LauncherIconController.java"
s = open(p, encoding="utf-8").read()
if "telegyou_main_bg" in s:
    print("Список иконок: уже изменён")
else:
    s2, c = re.subn(r'(DEFAULT\("DefaultIcon",\s*)[^,]+,\s*[^,]+,',
                    r'\1R.mipmap.telegyou_main_bg, R.mipmap.telegyou_main_fg,', s, count=1)
    if c:
        open(p, "w", encoding="utf-8").write(s2)
        print("Список иконок: Основная изменена")
    else:
        print("WARNING: строка DEFAULT не найдена")
PY
