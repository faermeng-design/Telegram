#!/bin/bash
python3 - <<'PY'
g = "TMessagesProj/src/main/java/org/telegram/messenger/GhostMode.java"
s = open(g, encoding="ascii").read()
if "selfStatus" in s:
    print("selfStatus: уже есть")
else:
    method = r'''
    public static String selfStatus(String original) {
        try {
            if (get("no_online")) {
                return "\u041e\u043d\u043b\u0430\u0439\u043d?";
            }
        } catch (Throwable ignored) {
        }
        return original;
    }
'''
    i = s.rindex("}")
    s = s[:i] + method + "}\n"
    open(g, "w", encoding="ascii").write(s)
    print("selfStatus: добавлен")

p = "TMessagesProj/src/main/java/org/telegram/ui/ProfileActivity.java"
t = open(p, encoding="utf-8").read()
old = "newString2 = LocaleController.getString(R.string.Online);"
new = "newString2 = org.telegram.messenger.GhostMode.selfStatus(LocaleController.getString(R.string.Online));"
n = t.count(old)
if n == 0:
    print("Профиль: уже подключено или место не найдено")
else:
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)
    print("Профиль: подключено мест =", n)
PY
