#!/bin/bash
set -e
ROOT="TMessagesProj/src/main/java/org/telegram"

# 1) Файл режима призрака
cat > "$ROOT/messenger/GhostMode.java" <<'JAVA'
package org.telegram.messenger;

import android.content.Context;
import android.content.SharedPreferences;

import org.telegram.tgnet.TLObject;

import java.util.HashSet;
import java.util.Set;

/** Telegyou: режим призрака и сохранение удалённых сообщений. */
public class GhostMode {

    private static final String PREFS = "telegyou";
    private static Set<String> deleted;

    private static SharedPreferences prefs() {
        return ApplicationLoader.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    public static boolean get(String key) {
        try {
            return prefs().getBoolean(key, true);
        } catch (Throwable t) {
            return true;
        }
    }

    public static void set(String key, boolean value) {
        try {
            prefs().edit().putBoolean(key, value).apply();
        } catch (Throwable ignored) {
        }
    }

    public static boolean noRead() { return get("no_read"); }
    public static boolean noTyping() { return get("no_typing"); }
    public static boolean noOnline() { return get("no_online"); }
    public static boolean keepDeleted() { return get("keep_deleted"); }

    /** true = этот запрос нельзя отправлять на сервер. */
    public static boolean shouldBlock(TLObject request) {
        if (request == null) {
            return false;
        }
        String n = request.getClass().getName().toLowerCase().replace('$', '_').replace('.', '_');
        if (noRead() && (n.contains("messages_readhistory")
                || n.contains("channels_readhistory")
                || n.contains("readmessagecontents")
                || n.contains("readstories")
                || n.contains("incrementstoryviews"))) {
            return true;
        }
        if (noTyping() && n.contains("messages_settyping")) {
            return true;
        }
        if (noOnline() && n.contains("account_updatestatus")) {
            return true;
        }
        return false;
    }

    private static synchronized Set<String> deletedSet() {
        if (deleted == null) {
            deleted = new HashSet<>();
            try {
                Set<String> saved = prefs().getStringSet("deleted_ids", null);
                if (saved != null) {
                    deleted.addAll(saved);
                }
            } catch (Throwable ignored) {
            }
        }
        return deleted;
    }

    private static String key(long channelId, int messageId) {
        return channelId + "_" + messageId;
    }

    public static synchronized void markDeleted(long channelId, int messageId) {
        Set<String> set = deletedSet();
        if (set.add(key(channelId, messageId))) {
            try {
                prefs().edit().putStringSet("deleted_ids", new HashSet<>(set)).apply();
            } catch (Throwable ignored) {
            }
        }
    }

    public static synchronized boolean isDeleted(long channelId, int messageId) {
        return deletedSet().contains(key(channelId, messageId));
    }
}
JAVA

# 2) Вставляем проверку в ConnectionsManager.java (если её там ещё нет)
python3 - <<'PY'
p = "TMessagesProj/src/main/java/org/telegram/tgnet/ConnectionsManager.java"
s = open(p, encoding="utf-8").read()
if "GhostMode.shouldBlock" in s:
    print("ConnectionsManager: уже исправлен")
else:
    i = s.index("private void sendRequestInternal(")
    j = s.index(") {", i) + 3
    add = "\n        if (org.telegram.messenger.GhostMode.shouldBlock(object)) {\n            return;\n        }"
    s = s[:j] + add + s[j:]
    open(p, "w", encoding="utf-8").write(s)
    print("ConnectionsManager: правка внесена")
PY

grep -n -A4 "private void sendRequestInternal(" "$ROOT/tgnet/ConnectionsManager.java" | head -8
