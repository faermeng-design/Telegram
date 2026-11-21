#!/bin/bash
python3 - <<'PY'
p = "TMessagesProj/src/main/java/org/telegram/messenger/LocaleController.java"
s = open(p, encoding="utf-8").read()
sig = "public static String formatUserStatus(int currentAccount, TLRPC.User user, boolean[] isOnline, boolean[] madeShorter) {"
if "formatUserStatusTelegyou" in s:
    print("Статус: уже подключён")
elif sig not in s:
    print("WARNING: статус: formatUserStatus не найдена")
else:
    new = r'''public static String formatUserStatus(int currentAccount, TLRPC.User user, boolean[] isOnline, boolean[] madeShorter) {
        boolean telegyouGhost = false;
        boolean telegyouSelf = false;
        try {
            telegyouGhost = user != null && GhostMode.get("no_online");
            telegyouSelf = user != null && user.id == UserConfig.getInstance(currentAccount).getClientUserId();
        } catch (Throwable ignored) {
        }
        if (!telegyouGhost) {
            return formatUserStatusTelegyou(currentAccount, user, isOnline, madeShorter);
        }
        if (telegyouSelf) {
            if (isOnline != null) {
                isOnline[0] = false;
            }
            return "\u041e\u043d\u043b\u0430\u0439\u043d?";
        }
        boolean[] telegyouOn = isOnline != null ? isOnline : new boolean[1];
        String telegyouResult = formatUserStatusTelegyou(currentAccount, user, telegyouOn, madeShorter);
        if (telegyouOn[0]) {
            telegyouOn[0] = false;
            return "";
        }
        return telegyouResult;
    }

    private static String formatUserStatusTelegyou(int currentAccount, TLRPC.User user, boolean[] isOnline, boolean[] madeShorter) {'''
    s = s.replace(sig, new, 1)
    open(p, "w", encoding="utf-8").write(s)
    print("Статус: правка внесена")
PY
