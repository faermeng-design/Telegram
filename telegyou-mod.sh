#!/bin/bash
set -e
ROOT="TMessagesProj/src/main/java/org/telegram"

# 1) Режим призрака
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

# 2) Значки (creator, tester, ...) из badges.json на GitHub
cat > "$ROOT/messenger/BadgeManager.java" <<'JAVA'
package org.telegram.messenger;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

/** Telegyou: значки, которые владелец выдаёт через файл badges.json на GitHub. */
public class BadgeManager {

    private static final String URL_STR = "__BADGES_URL__";
    private static final long REFRESH_MS = 30 * 60 * 1000L;

    private static volatile Map<Long, String> users = new HashMap<>();
    private static volatile Map<String, String> icons = defaultIcons();
    private static volatile Map<String, String> labels = defaultLabels();
    private static volatile long lastFetch = 0;
    private static volatile boolean loading = false;
    private static boolean cacheLoaded = false;

    private static Map<String, String> defaultIcons() {
        Map<String, String> m = new HashMap<>();
        m.put("creator", "👑");
        m.put("tester", "🧪");
        return m;
    }

    private static Map<String, String> defaultLabels() {
        Map<String, String> m = new HashMap<>();
        m.put("creator", "creator");
        m.put("tester", "tester");
        return m;
    }

    private static SharedPreferences prefs() {
        return ApplicationLoader.applicationContext.getSharedPreferences("telegyou_badges", Context.MODE_PRIVATE);
    }

    private static void parse(String json) {
        try {
            JSONObject root = new JSONObject(json);
            Map<String, String> newIcons = defaultIcons();
            Map<String, String> newLabels = defaultLabels();
            JSONObject b = root.optJSONObject("badges");
            if (b != null) {
                Iterator<String> it = b.keys();
                while (it.hasNext()) {
                    String k = it.next();
                    JSONObject o = b.optJSONObject(k);
                    if (o != null) {
                        newIcons.put(k, o.optString("icon", "*"));
                        newLabels.put(k, o.optString("label", k));
                    }
                }
            }
            Map<Long, String> newUsers = new HashMap<>();
            JSONObject u = root.optJSONObject("users");
            if (u != null) {
                Iterator<String> it = u.keys();
                while (it.hasNext()) {
                    String k = it.next();
                    try {
                        newUsers.put(Long.parseLong(k.trim()), u.optString(k));
                    } catch (Exception ignored) {
                    }
                }
            }
            icons = newIcons;
            labels = newLabels;
            users = newUsers;
        } catch (Throwable ignored) {
        }
    }

    private static void refreshAsync() {
        if (loading) {
            return;
        }
        loading = true;
        new Thread(() -> {
            boolean ok = false;
            try {
                HttpURLConnection c = (HttpURLConnection) new URL(URL_STR + "?t=" + System.currentTimeMillis()).openConnection();
                c.setConnectTimeout(8000);
                c.setReadTimeout(8000);
                if (c.getResponseCode() == 200) {
                    BufferedReader r = new BufferedReader(new InputStreamReader(c.getInputStream(), "UTF-8"));
                    StringBuilder sb = new StringBuilder();
                    String line;
                    while ((line = r.readLine()) != null) {
                        sb.append(line).append('\n');
                    }
                    r.close();
                    String json = sb.toString();
                    parse(json);
                    prefs().edit().putString("json", json).apply();
                    ok = true;
                }
            } catch (Throwable ignored) {
            } finally {
                lastFetch = ok ? System.currentTimeMillis() : System.currentTimeMillis() - REFRESH_MS + 120000L;
                loading = false;
            }
        }, "telegyou-badges").start();
    }

    private static synchronized void ensureLoaded() {
        if (!cacheLoaded) {
            cacheLoaded = true;
            try {
                String saved = prefs().getString("json", null);
                if (saved != null) {
                    parse(saved);
                }
            } catch (Throwable ignored) {
            }
        }
        if (System.currentTimeMillis() - lastFetch > REFRESH_MS) {
            lastFetch = System.currentTimeMillis();
            refreshAsync();
        }
    }

    public static void forceRefresh() {
        lastFetch = 0;
        ensureLoaded();
    }

    public static String badgeOf(long userId) {
        try {
            ensureLoaded();
            return users.get(userId);
        } catch (Throwable t) {
            return null;
        }
    }

    public static String iconOf(String badge) {
        String s = icons.get(badge);
        return s == null ? "" : s;
    }

    public static String labelOf(String badge) {
        String s = labels.get(badge);
        return s == null ? badge : s;
    }

    /** Дописывает значок к имени, если у пользователя он есть. */
    public static String decorate(long userId, String name) {
        if (name == null || userId == 0) {
            return name;
        }
        try {
            String badge = badgeOf(userId);
            if (badge == null) {
                return name;
            }
            String icon = icons.get(badge);
            return icon == null ? name : name + " " + icon;
        } catch (Throwable t) {
            return name;
        }
    }
}
JAVA

# 3) Экран настроек Telegyou
cat > "$ROOT/messenger/TelegyouSettingsActivity.java" <<'JAVA'
package org.telegram.messenger;

import android.app.Activity;
import android.graphics.Typeface;
import android.os.Bundle;
import android.widget.Button;
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

    private TextView me;

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
        sub.setText("Режим призрака и значки. Изменения действуют сразу.");
        sub.setTextSize(14);
        sub.setAlpha(0.7f);
        sub.setPadding(0, dp(4), 0, dp(12));
        root.addView(sub);

        me = new TextView(this);
        me.setTextSize(15);
        me.setPadding(0, dp(8), 0, dp(4));
        root.addView(me);
        updateMe();

        Button refresh = new Button(this);
        refresh.setText("Обновить значки");
        refresh.setOnClickListener(v -> {
            BadgeManager.forceRefresh();
            me.setText("Обновляю…");
            me.postDelayed(this::updateMe, 2500);
        });
        root.addView(refresh);

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

    private void updateMe() {
        long myId = 0;
        try {
            myId = UserConfig.getInstance(UserConfig.selectedAccount).getClientUserId();
        } catch (Throwable ignored) {
        }
        String badge = BadgeManager.badgeOf(myId);
        String text = "Твой Telegram ID: " + myId + "\nТвой значок: "
                + (badge == null ? "нет" : BadgeManager.iconOf(badge) + " " + BadgeManager.labelOf(badge));
        me.setText(text);
    }

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density);
    }
}
JAVA

# 4) Адрес файла badges.json берём из твоего репозитория автоматически
BADGES_URL="https://raw.githubusercontent.com/${GITHUB_REPOSITORY:-faermeng-design/Telegram}/${GITHUB_REF_NAME:-master}/badges.json"
sed -i "s|__BADGES_URL__|$BADGES_URL|" "$ROOT/messenger/BadgeManager.java"
echo "Badges URL: $BADGES_URL"

# 5) Делаем новые Java-файлы независимыми от кодировки (символы -> \uXXXX)
python3 - <<'PY'
base = "TMessagesProj/src/main/java/org/telegram/messenger/"
for name in ["GhostMode.java", "BadgeManager.java", "TelegyouSettingsActivity.java"]:
    p = base + name
    s = open(p, encoding="utf-8").read()
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
    open(p, "w", encoding="ascii").write("".join(out))
print("Новые файлы: кодировка готова")
PY

# 6) Проверка запросов в ConnectionsManager (режим призрака)
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

# 7) Значки в именах: оборачиваем UserObject.getUserName
python3 - <<'PY'
import re
p = "TMessagesProj/src/main/java/org/telegram/messenger/UserObject.java"
try:
    s = open(p, encoding="utf-8").read()
except FileNotFoundError:
    print("WARNING: UserObject.java не найден, значки в именах не появятся")
    s = None
if s is not None:
    if "BadgeManager.decorate" in s:
        print("UserObject: значки уже подключены")
    else:
        m = re.search(r'public static String getUserName\(TLRPC\.User (\w+)\)\s*\{', s)
        if not m:
            print("WARNING: функция getUserName не найдена, значки в именах не появятся")
        else:
            v = m.group(1)
            wrapper = (
                "public static String getUserName(TLRPC.User %s) {\n"
                "        return BadgeManager.decorate(%s == null ? 0 : %s.id, getUserNameOriginal(%s));\n"
                "    }\n\n"
                "    public static String getUserNameOriginal(TLRPC.User %s) {"
            ) % (v, v, v, v, v)
            s = s[:m.start()] + wrapper + s[m.end():]
            open(p, "w", encoding="utf-8").write(s)
            print("UserObject: значки подключены")
PY

# 8) Экран настроек в манифесте
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
    print("WARNING: манифест с </application> не найден, экран настроек не появится")
PY
