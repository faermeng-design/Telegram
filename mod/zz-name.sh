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
print("Название Telegyou в ресурсах: изменено файлов =", n)

def patch(path, old, new):
    s = open(path, encoding="utf-8").read()
    if old in s:
        open(path, "w", encoding="utf-8").write(s.replace(old, new, 1))
        print("Название в коде: заменено в", path.split("/")[-1])
    elif new in s:
        print("Название в коде: уже есть в", path.split("/")[-1])
    else:
        print("WARNING: название: не найдено в", path.split("/")[-1])

ui = "TMessagesProj/src/main/java/org/telegram/ui/"
patch(ui + "DialogsActivity.java", "new SpannableStringBuilder(getString(R.string.AppName))", 'new SpannableStringBuilder("Telegyou")')
patch(ui + "IntroActivity.java", "new SpannableStringBuilder(LocaleController.getString(R.string.Page1Title))", 'new SpannableStringBuilder("Telegyou")')
PY
