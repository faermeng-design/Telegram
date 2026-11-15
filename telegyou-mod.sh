#!/bin/bash
set -e
ROOT="TMessagesProj/src/main/java/org/telegram"

# 1) Логика режима призрака
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
    private static Context appContext;
    private static Set<String> deleted;

    public static void init(Context context) {
        appContext = context;
    }

    private static SharedPreferences prefs() {
        Context c = appContext != null ? appContext : ApplicationLoader.applicationContext;
        return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
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

    /** true = этот запрос нельзя отправлять на сервер. */
    public static boolean shouldBlock(TLObject request) {
        if (request == null) {
            return false;
        }
        String n = request.getClass().getName().toLowerCase().replace('$', '_').replace('.', '_');
        if (n.contains("messages_readhistory") || n.contains("channels_readhistory")
                || n.contains("readmessagecontents")) {
            return get("no_read");
        }
        if (n.contains("readstories") || n.contains("incrementstoryviews")) {
            return get("no_stories");
        }
        if (n.contains("messages_settyping")) {
            return get("no_typing");
        }
        if (n.contains("account_updatestatus")) {
            return get("no_online");
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

# 2) Экран настроек
cat > "$ROOT/messenger/TelegyouSettingsActivity.java" <<'JAVA'
package org.telegram.messenger;

import android.app.Activity;
import android.graphics.Typeface;
import android.os.Bundle;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Switch;
import android.widget.TextView;

public class TelegyouSettingsActivity extends Activity {

    private static final String[][] ITEMS = {
            {"no_read", "Не отмечать прочитанным",
                    "Собеседник не увидит «прочитано». Когда ты сам отвечаешь, Telegram всё равно помечает чат прочитанным."},
            {"no_stories", "Анонимный просмотр историй",
                    "Автор не увидит, что ты смотрел(а) его историю."},
            {"no_typing", "Скрыть «печатает…»",
                    "Собеседник не видит, что ты пишешь или записываешь голосовое."},
            {"no_online", "Скрыть статус «в сети»",
                    "Твой статус онлайн не обновляется."},
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        GhostMode.init(getApplicationContext());
        setTitle("Telegyou");

        int p = dp(20);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(p, dp(56), p, p);

        TextView title = new TextView(this);
        title.setText("Telegyou");
        title.setTextSize(28);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        root.addView(title);

        TextView sub = new TextView(this);
        sub.setText("Режим призрака. Изменения действуют сразу.");
        sub.setTextSize(14);
        sub.setAlpha(0.7f);
        sub.setPadding(0, dp(4), 0, dp(12));
        root.addView(sub);

        for (String[] item : ITEMS) {
            final String key = item[0];
            Switch sw = new Switch(this);
            sw.setText(item[1]);
            sw.setTextSize(17);
            sw.setPadding(0, dp(14), 0, dp(2));
            sw.setChecked(GhostMode.get(key));
            sw.setOnCheckedChangeListener((button, checked) -> GhostMode.set(key, checked));
            root.addView(sw);

            TextView desc = new TextView(this);
            desc.setText(item[2]);
            desc.setTextSize(13);
            desc.setAlpha(0.7f);
            root.addView(desc);
        }

        ScrollView scroll = new ScrollView(this);
        scroll.addView(root);
        setContentView(scroll);
    }

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density);
    }
}
JAVA

# 3) Проверка запросов в ConnectionsManager (если ещё не вставлена)
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

# 4) Регистрируем экран настроек в манифесте
python3 - <<'PY'
import os
snippet = '''        <activity
            android:name="org.telegram.messenger.TelegyouSettingsActivity"
            android:label="Telegyou: настройки"
            android:exported="true"
            android:theme="@android:style/Theme.DeviceDefault">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
'''
done = False
for p in ["TMessagesProj_App/src/main/AndroidManifest.xml",
          "TMessagesProj/src/main/AndroidManifest.xml"]:
    if not os.path.exists(p):
        continue
    s = open(p, encoding="utf-8").read()
    if "TelegyouSettingsActivity" in s:
        print("Manifest: уже есть в", p)
        done = True
        break
    if "</application>" in s:
        s = s.replace("</application>", snippet + "    </application>", 1)
        open(p, "w", encoding="utf-8").write(s)
        print("Manifest: добавлено в", p)
        done = True
        break
if not done:
    print("ВНИМАНИЕ: манифест с </application> не найден, экран настроек не появится")
PY

grep -n -A4 "private void sendRequestInternal(" "$ROOT/tgnet/ConnectionsManager.java" | head -8
