#!/bin/bash
python3 - <<'PY'
import re

MSG = "TMessagesProj/src/main/java/org/telegram/messenger/BadgeManager.java"
PRO = None
import os
for root, dirs, files in os.walk("TMessagesProj/src/main/java/org/telegram/ui"):
    if "ProfileActivity.java" in files:
        PRO = os.path.join(root, "ProfileActivity.java")
        break

# ---------- BadgeManager ----------
s = open(MSG, encoding="ascii", errors="replace").read()
if "decorateChat" in s:
    print("zz-zchannel: BadgeManager already patched")
else:
    ok = True
    a1 = "private static volatile Map<String, String> infos = new HashMap<>();"
    a2 = "icons = newIcons;"
    a3 = "return users.get(userId);"
    for a in (a1, a2, a3):
        if a not in s:
            print("WARNING zz-zchannel: anchor not found: " + a)
            ok = False
    if ok:
        s = s.replace(a1, a1 + "\n    private static volatile Map<String, String> channels = new HashMap<>();\n    private static final Map<Long, String> chatBadges = new HashMap<>();", 1)
        s = s.replace(a2, "Map<String, String> newChannels = new HashMap<>();\n            JSONObject chObj = root.optJSONObject(\"channels\");\n            if (chObj != null) {\n                Iterator<String> it2 = chObj.keys();\n                while (it2.hasNext()) {\n                    String k2 = it2.next();\n                    newChannels.put(k2.toLowerCase(), chObj.optString(k2));\n                }\n            }\n            channels = newChannels;\n            icons = newIcons;", 1)
        s = s.replace(a3, "if (userId < 0) {\n                synchronized (chatBadges) {\n                    return chatBadges.get(-userId);\n                }\n            }\n            return users.get(userId);", 1)
        method = """
    public static String decorateChat(org.telegram.tgnet.TLRPC.Chat chat, String title) {
        try {
            if (chat == null || title == null) {
                return title;
            }
            ensureLoaded();
            String un = ChatObject.getPublicUsername(chat);
            if (un == null) {
                return title;
            }
            String badge = channels.get(un.toLowerCase());
            if (badge == null) {
                return title;
            }
            String icon = icons.get(badge);
            if (icon == null) {
                return title;
            }
            synchronized (chatBadges) {
                chatBadges.put(chat.id, badge);
            }
            boolean hasImage = images.containsKey(badge) && bitmapOf(badge) != null;
            return title + " " + icon + (hasImage ? String.valueOf(MARK) : "");
        } catch (Throwable t) {
            return title;
        }
    }
"""
        i = s.rstrip().rfind("}")
        s = s[:i] + method + "}\n"
        open(MSG, "w", encoding="ascii").write(s)
        print("zz-zchannel: BadgeManager patched")

# ---------- ProfileActivity ----------
if not PRO:
    print("WARNING zz-zchannel: ProfileActivity.java not found")
else:
    p = open(PRO, encoding="utf-8").read()
    if "BadgeManager.decorateChat" in p:
        print("zz-zchannel: ProfileActivity already patched")
    else:
        pat = re.compile(r"(else if \(chat\.title != null\) \{\s*title = )chat\.title;")
        if not pat.search(p):
            print("WARNING zz-zchannel: title anchor not found")
        else:
            p = pat.sub(r"\1org.telegram.messenger.BadgeManager.decorateChat(chat, chat.title);", p, 1)
            h = "BadgeManager.hitBadge(userId,"
            sh = "BadgeManager.showInfo(telegyouView.getContext(), userId)"
            if h in p:
                p = p.replace(h, "BadgeManager.hitBadge(userId != 0 ? userId : -chatId,", 1)
            else:
                print("WARNING zz-zchannel: hitBadge call not found")
            if sh in p:
                p = p.replace(sh, "BadgeManager.showInfo(telegyouView.getContext(), userId != 0 ? userId : -chatId)", 1)
            else:
                print("WARNING zz-zchannel: showInfo call not found")
            open(PRO, "w", encoding="utf-8").write(p)
            print("zz-zchannel: ProfileActivity patched")
PY
