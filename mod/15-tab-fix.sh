#!/bin/bash
set -e
python3 - <<'PY'
import re
p = "TMessagesProj/src/main/java/org/telegram/ui/SettingsActivity.java"
s = open(p, encoding="utf-8").read()
m = re.search(r'items\.add\(SettingCell\.Factory\.of\(7777,[^\n]*\)\);\n        ', s)
if not m:
    print("WARNING: вкладка 7777 не найдена")
else:
    item = m.group(0).split("\n")[0]
    s = s[:m.start()] + s[m.end():]
    i = s.find("private void fillItems(ArrayList<UItem> items, UniversalAdapter adapter) {")
    m2 = re.compile(r'\n {8}items\.add\(SettingCell\.Factory\.of\(').search(s, i)
    if i < 0 or not m2:
        print("WARNING: место для вкладки не найдено")
    else:
        k = m2.start() + 1
        s = s[:k] + "        " + item + "\n" + s[k:]
        open(p, "w", encoding="utf-8").write(s)
        print("Вкладка Telegyou: перенесена наверх списка")
PY
