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
        String n = request.getClass().getSimpleName();
        if (noRead() && (n.equals("TL_messages_readHistory")
                || n.equals("TL_channels_readHistory")
                || n.equals("TL_messages_readMessageContents")
                || n.equals("TL_channels_readMessageContents")
                || n.contains("readStories")
                || n.contains("incrementStoryViews"))) {
            return true;
        }
        if (noTyping() && n.equals("TL_messages_setTyping")) {
            return true;
        }
        if (noOnline() && n.equals("TL_account_updateStatus")) {
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

    /** Запомнить, что сообщение удалили (channelId = 0 для обычных чатов). */
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
