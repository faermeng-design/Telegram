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

MC = "TMessagesProj/src/main/java/org/telegram/messenger/MessagesController.java"
s = open(MC, encoding="utf-8").read()

def guard(pattern, code, tag, name):
    global s
    if tag in s:
        print("Сгорающие:", name, "- уже есть")
        return
    m = re.search(pattern, s)
    if not m:
        print("WARNING: сгорающие:", name, "- функция не найдена")
        return
    s = s[:m.end()] + "\n        " + code + " // " + tag + s[m.end():]
    print("Сгорающие:", name, "- правка внесена")

guard(r'public void markMessageContentAsRead\(MessageObject messageObject\) \{',
      'if (messageObject != null && messageObject.messageOwner != null && messageObject.messageOwner.media != null && messageObject.messageOwner.media.ttl_seconds != 0 && GhostMode.get("keep_burn")) { return; }',
      'keep_burn:content', 'не отмечать прочитанным')
guard(r'public void markMessageAsRead2\(long dialogId, int mid, TLRPC\.InputChannel inputChannel, int ttl, long taskId, boolean createDeleteTask\) \{',
      'if (GhostMode.get("keep_burn")) { return; }',
      'keep_burn:read2', 'таймер сгорания фото')
guard(r'public long createDeleteShowOnceTask\(long dialogId, int mid\) \{',
      'if (GhostMode.get("keep_burn")) { return 0; }',
      'keep_burn:showonce', 'задание на удаление гс')
guard(r'void doDeleteShowOnceTask\([^)]*\) \{',
      'if (GhostMode.get("keep_burn")) { return; }',
      'keep_burn:dodelete', 'удаление гс после прослушивания')
open(MC, "w", encoding="utf-8").write(s)

# Переключатель в настройках (внутри "Сохранять удалённые")
f = "TMessagesProj/src/main/java/org/telegram/ui/TelegyouSettingsFragment.java"
try:
    t = open(f, encoding="ascii", errors="replace").read()
except FileNotFoundError:
    print("WARNING: страница настроек не найдена (нужен zz-menu.sh)")
    raise SystemExit(0)
if "keep_burn" in t:
    print("Переключатель: уже есть")
else:
    pat = re.compile(r'TextView soon = new TextView\(context\);.*?keepBody\.addView\(soon, full\(\)\);', re.S)
    if not pat.search(t):
        print("WARNING: переключатель: место в настройках не найдено (нужна страница из zz-menu.sh)")
    else:
        code = to_ascii('''final TextCheckCell burnCell = new TextCheckCell(context);
        burnCell.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
        burnCell.setTextAndValueAndCheck("Сгорающие фото и ГС не исчезают",
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
