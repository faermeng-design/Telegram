#!/bin/bash
python3 - <<'PY'
p = "TMessagesProj/src/main/java/org/telegram/messenger/BadgeManager.java"
s = open(p, encoding="ascii", errors="replace").read()
old = "d.setBounds(0, 0, size, size);"
new = "int telegyouSize = (int) (size * 1.2f);\n                    d.setBounds(0, 0, telegyouSize, telegyouSize);"
if "telegyouSize" in s:
    print("Размер значка: уже изменён")
elif old in s:
    s = s.replace(old, new, 1)
    open(p, "w", encoding="ascii").write(s)
    print("Размер значка: увеличен в 1.2 раза")
else:
    print("WARNING: размер значка: место не найдено")
PY
