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
python3 - <<'PY'
d = "TMessagesProj/src/main/java/org/telegram/ui/DialogsActivity.java"
s = open(d, encoding="utf-8").read()
old = "ssb.setSpan(new ImageSpan(logoDrawable), 0, ssb.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);"
new = "ssb.setSpan(new android.text.style.StyleSpan(android.graphics.Typeface.BOLD), 0, ssb.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);"
if old in s:
    open(d, "w", encoding="utf-8").write(s.replace(old, new, 1))
    print("Заголовок списка чатов: логотип-картинка заменён текстом Telegyou")
elif new in s:
    print("Заголовок списка чатов: уже текст")
else:
    print("WARNING: заголовок списка чатов: строка с логотипом не найдена")
PY
