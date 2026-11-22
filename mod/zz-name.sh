#!/bin/bash
python3 - <<'PY'
import glob, re
n = 0
for f in glob.glob("TMessagesProj*/src/*/res/values*/strings*.xml"):
    s = open(f, encoding="utf-8").read()
    t = re.sub(r'(<string name="AppName"[^>]*>)[^<]*(</string>)', r'\1Telegyou\2', s)
    if t != s:
        open(f, "w", encoding="utf-8").write(t)
        n += 1
print("Название Telegyou: изменено файлов =", n)
PY
