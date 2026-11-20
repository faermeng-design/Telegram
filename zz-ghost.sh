#!/bin/bash
python3 - <<'PY'
p = "TMessagesProj/src/main/java/org/telegram/messenger/GhostMode.java"
s = open(p, encoding="ascii").read()
if "ghost2" in s:
    print("ghost2: уже есть")
else:
    line = "String n = request.getClass().getName().toLowerCase().replace('$', '_').replace('.', '_');"
    i = s.find(line)
    if i < 0:
        print("WARNING: ghost2: место не найдено")
    else:
        i += len(line)
        add = """
        if (n.contains("account_updatestatus")) { // ghost2
            if (!get("no_online")) {
                return false;
            }
            boolean off = false;
            try {
                off = request.getClass().getField("offline").getBoolean(request);
            } catch (Throwable ignored) {
            }
            if (off) {
                return false;
            }
            bump();
            return true;
        }"""
        s = s[:i] + add + s[i:]
        open(p, "w", encoding="ascii").write(s)
        print("ghost2: добавлено")
PY
