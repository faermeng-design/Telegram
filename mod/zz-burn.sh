#!/bin/bash
python3 - <<'PY'
import re

def to_ascii(s):
    out = []
    for ch in s:
        o = ord(ch)
        if o < 128:
            out.append(ch)
        elif o < 0x10000:
            out.append("\\u%04x" % o)
        else:
            o -= 0x10000
            out.append("\\u%04x\\u%04x" % (0xD800 + (o >> 10), 0xDC00 + (o & 0x3FF)))
    return "".join(out)

# 1) Сгорающие фото: не отмечаем их просмотренными (ни у нас, ни у отправителя)
p = "TMessagesProj/src/main/java/org/telegram/messenger/MessagesController.java"
s = open(p, encoding="utf-8").read()
sig = "public void markMessageContentAsRead(MessageObject messageObject) {"
if "keep_burn" in s:
    print("Сгорающие фото: уже подключено")
elif sig not in s:
    print("WARNING: сгорающие фото: markMessageContentAsRead не найдена")
else:
    add = ("\n        if (messageObject != null && messageObject.messageOwner != null && messageObject.messageOwner.media != null"
           " && messageObject.messageOwner.media.ttl_seconds != 0 && GhostMode.get(\"keep_burn\")) {\n"
           "            return;\n"
           "        }")
    s = s.replace(sig, sig + add, 1)
    open(p, "w", encoding="utf-8").write(s)
    print("Сгорающие фото: правка внесена")

# 2) Переключатель в настройках (внутри "Сохранять удалённые")
f = "TMessagesProj/src/main/java/org/telegram/ui/TelegyouSettingsFragment.java"
t = open(f, encoding="ascii", errors="replace").read()
if "keep_burn" in t:
    print("Переключатель: уже есть")
else:
    pat = re.compile(r'TextView soon = new TextView\(context\);.*?keepBody\.addView\(soon, full\(\)\);', re.S)
    if not pat.search(t):
        print("WARNING: переключатель: место в настройках не найдено (нужна страница из zz-menu.sh)")
    else:
        code = to_ascii('''final TextCheckCell burnCell = new TextCheckCell(context);
        burnCell.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
        burnCell.setTextAndValueAndCheck("Сгорающие фото не исчезают",
                "Можно открывать много раз, отправитель не узнает", GhostMode.get("keep_burn"), true, false);
        burnCell.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                boolean now = !burnCell.isChecked();
                burnCell.setChecked(now);
                GhostMode.set("keep_burn", now);
            }
        });
        keepBody.addView(indented(context, burnCell), full());''')
        t = pat.sub(lambda m: code, t, count=1)
        open(f, "w", encoding="ascii").write(t)
        print("Переключатель: добавлен")
PY
