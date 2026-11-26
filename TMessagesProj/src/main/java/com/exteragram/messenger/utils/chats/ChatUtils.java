package com.exteragram.messenger.utils.chats;

import android.text.TextUtils;

import org.telegram.messenger.FileLoader;
import org.telegram.messenger.MessageObject;

import java.io.File;

/** Minimal replacement for the exteraGram helper of the same name. */
public class ChatUtils {
    private static ChatUtils instance;

    public static synchronized ChatUtils getInstance() {
        if (instance == null) {
            instance = new ChatUtils();
        }
        return instance;
    }

    public String getPathToMessage(MessageObject messageObject) {
        if (messageObject == null || messageObject.messageOwner == null) {
            return null;
        }
        try {
            String path = messageObject.messageOwner.attachPath;
            if (!TextUtils.isEmpty(path) && new File(path).exists()) {
                return path;
            }
            File file = FileLoader.getInstance(messageObject.currentAccount).getPathToMessage(messageObject.messageOwner);
            if (file != null && file.exists()) {
                return file.getAbsolutePath();
            }
        } catch (Throwable ignored) {
        }
        return null;
    }
}
