#!/bin/bash
set -e
pip install --quiet pillow || true
python3 - <<'PY'
import os, re, sys
try:
    from PIL import Image
except Exception:
    print("WARNING: Pillow не установился")
    sys.exit(0)
if not os.path.exists("icon2.png"):
    print("WARNING: icon2.png не найден, новая иконка не добавлена")
    sys.exit(0)

# 1) Список иконок: добавляем TELEGYOU после NOX
p = "TMessagesProj/src/main/java/org/telegram/ui/LauncherIconController.java"
s = open(p, encoding="utf-8").read()
if "TELEGYOU(" in s:
    print("enum: уже есть")
else:
    m = re.search(r'NOX\("NoxIcon"[^;]*\);', s)
    if not m:
        print("WARNING: NOX не найден, иконка не добавлена")
        sys.exit(0)
    t = m.group(0)
    new = t[:-1] + ',\n        TELEGYOU("TelegyouIcon", R.mipmap.telegyou_icon_background, R.mipmap.telegyou_icon_foreground, R.string.AppIconTelegyou);'
    s = s.replace(t, new, 1)
    open(p, "w", encoding="utf-8").write(s)
    print("enum: добавлено")

# 2) Картинки и название
res = "TMessagesProj/src/main/res/"
os.makedirs(res + "mipmap-xxxhdpi", exist_ok=True)
os.makedirs(res + "values", exist_ok=True)
img = Image.open("icon2.png").convert("RGBA")
corner = img.getpixel((5, 5))
Image.new("RGBA", (432, 432), corner).save(res + "mipmap-xxxhdpi/telegyou_icon_background.png")
fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
k = 285
fg.paste(img.resize((k, k), Image.LANCZOS), ((432 - k) // 2, (432 - k) // 2))
fg.save(res + "mipmap-xxxhdpi/telegyou_icon_foreground.png")
img.resize((192, 192), Image.LANCZOS).save(res + "mipmap-xxxhdpi/telegyou_icon_launcher.png")
open(res + "values/telegyou_icons.xml", "w", encoding="utf-8").write(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <string name="AppIconTelegyou">Telegyou</string>\n</resources>\n')
print("Картинки и название: готово")

# 3) Манифест: новый блок после последнего activity-alias
mp = "TMessagesProj/src/main/AndroidManifest.xml"
x = open(mp, encoding="utf-8").read()
if "TelegyouIcon" in x:
    print("Манифест: уже есть")
else:
    tag = "</activity-alias>"
    i = x.rfind(tag)
    if i < 0:
        print("WARNING: activity-alias в манифесте не найден")
        sys.exit(0)
    i += len(tag)
    alias = '''        <activity-alias
            android:enabled="false"
            android:name="org.telegram.messenger.TelegyouIcon"
            android:icon="@mipmap/telegyou_icon_launcher"
            android:targetActivity="org.telegram.ui.LaunchActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
                <category android:name="android.intent.category.MULTIWINDOW_LAUNCHER" />
            </intent-filter>
            <meta-data
                android:name="android.app.shortcuts"
                android:resource="@xml/shortcuts" />
        </activity-alias>'''
    x = x[:i] + "\n" + alias + x[i:]
    open(mp, "w", encoding="utf-8").write(x)
    print("Манифест: иконка добавлена")
PY
