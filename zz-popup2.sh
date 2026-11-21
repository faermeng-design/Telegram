#!/bin/bash
python3 - <<'PY'
MSG = "TMessagesProj/src/main/java/org/telegram/messenger/BadgeManager.java"
UI = "TMessagesProj/src/main/java/org/telegram/ui/ProfileActivity.java"

s = open(MSG, encoding="ascii", errors="replace").read()
if "hasInfo(" in s:
    print("popup2: BadgeManager уже готов")
else:
    method = '''
    /** True if this user has a badge with an info text. */
    public static boolean hasInfo(long userId) {
        try {
            String b = badgeOf(userId);
            return b != null && infoOf(b).length() > 0;
        } catch (Throwable t) {
            return false;
        }
    }
'''
    i = s.rstrip().rfind("}")
    s = s[:i] + method + "}\n"
    open(MSG, "w", encoding="ascii").write(s)
    print("popup2: hasInfo добавлен")

p = open(UI, encoding="utf-8").read()
old = "telegyouDown = org.telegram.messenger.BadgeManager.hitBadge(userId, nameTextView.getText(), nameTextView.getPaint(), telegyouEvent.getX(), nameTextView.getPaddingLeft());"
new = ("telegyouDown = org.telegram.messenger.BadgeManager.hasInfo(userId);\n"
       "                    android.widget.Toast.makeText(telegyouView.getContext(), \"Telegyou: id=\" + userId + \" znachok=\" + telegyouDown, android.widget.Toast.LENGTH_SHORT).show();")
if "BadgeManager.hasInfo(userId)" in p:
    print("popup2: ProfileActivity уже обновлён")
elif old in p:
    p = p.replace(old, new, 1)
    open(UI, "w", encoding="utf-8").write(p)
    print("popup2: нажатие на имя упрощено + проверка")
else:
    print("WARNING: popup2: не нашёл место в ProfileActivity")
PY
