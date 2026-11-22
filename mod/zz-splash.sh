#!/bin/bash
python3 - <<'PY'
import glob
n = 0
for f in glob.glob("TMessagesProj*/src/*/res/values*/styles.xml"):
    s = open(f, encoding="utf-8").read()
    t = s.replace("@drawable/tg_splash_320", "@mipmap/telegyou_main_fg")
    if t != s:
        open(f, "w", encoding="utf-8").write(t)
        n += 1
print("Заставка запуска: заменено в файлах =", n)
PY
