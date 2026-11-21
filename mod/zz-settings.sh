#!/bin/bash
python3 - <<'PY'
p = "TMessagesProj/src/main/java/org/telegram/ui/SettingsActivity.java"
s = open(p, encoding="utf-8").read()
old = "titleView.setText(UserObject.getUserName(user));"
new = "titleView.setText(Emoji.replaceEmoji(UserObject.getUserName(user), titleView.getPaint().getFontMetricsInt(), false));"
if new in s:
    print("Имя в настройках: уже подключено")
elif old in s:
    s = s.replace(old, new, 1)
    open(p, "w", encoding="utf-8").write(s)
    print("Имя в настройках: значок картинкой подключён")
else:
    print("WARNING: имя в настройках: место не найдено")
PY
