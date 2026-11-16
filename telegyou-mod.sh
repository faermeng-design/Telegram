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
    private static int blockedCount = -1;

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

    public static boolean keepDeleted() {
        return get("keep_deleted");
    }

    private static synchronized void bump() {
        try {
            if (blockedCount < 0) {
                blockedCount = prefs().getInt("blocked", 0);
            }
            blockedCount++;
            prefs().edit().putInt("blocked", blockedCount).apply();
        } catch (Throwable ignored) {
        }
    }

    public static int blocked() {
        try {
            return prefs().getInt("blocked", 0);
        } catch (Throwable t) {
            return 0;
        }
    }

    /** true = этот запрос нельзя отправлять на сервер. */
    public static boolean shouldBlock(TLObject request) {
        if (request == null) {
            return false;
        }
        String n = request.getClass().getName().toLowerCase().replace('$', '_').replace('.', '_');
        boolean block = false;
        if (n.contains("messages_readhistory") || n.contains("channels_readhistory")
                || n.contains("readmessagecontents")) {
            block = get("no_read");
        } else if (n.contains("readstories") || n.contains("incrementstoryviews")) {
            block = get("no_stories");
        } else if (n.contains("messages_settyping")) {
            block = get("no_typing");
               } else if (n.contains("account_updatestatus")) {
            if (get("no_online")) {
                try {
                    request.getClass().getField("offline").setBoolean(request, true);
                } catch (Throwable ignored) {
                }
                bump();
            }
        }
                if (block) {
            bump();
        }
        return block;
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
            {"keep_deleted", "Сохранять удалённые сообщения",
                    "Сообщения, которые собеседник удалил, остаются у тебя в чате."},
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
        sub.setText("Режим призрака, удалённые и значки. Изменения действуют сразу.");
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

    @Override
    protected void onResume() {
        super.onResume();
        updateMe();
    }

    private void updateMe() {
        long myId = 0;
        try {
            myId = UserConfig.getInstance(UserConfig.selectedAccount).getClientUserId();
        } catch (Throwable ignored) {
        }
        String badge = BadgeManager.badgeOf(myId);
        String text = "Твой Telegram ID: " + myId + "\nТвой значок: "
                + (badge == null ? "нет" : BadgeManager.iconOf(badge) + " " + BadgeManager.labelOf(badge))
                + "\nЗаблокировано запросов режима призрака: " + GhostMode.blocked();
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

# 5) Новые Java-файлы делаем независимыми от кодировки (символы -> \uXXXX)
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

# 6) Режим призрака: проверка запросов в ConnectionsManager
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

# 8) Сохранение удалённых сообщений: не добавляем их в список удаления
python3 - <<'PY'
import re
p = "TMessagesProj/src/main/java/org/telegram/messenger/MessagesController.java"
s = open(p, encoding="utf-8").read()
if "GhostMode.markDeleted" in s:
    print("Удалённые: уже подключено")
else:
    total = 0
    for cls, chan in (("TL_updateDeleteMessages", False), ("TL_updateDeleteChannelMessages", True)):
        decl = re.compile(r'TL_update\.' + cls + r'\s+(\w+)\s*=\s*\(TL_update\.' + cls + r'\)\s*\w+;')
        for m in reversed(list(decl.finditer(s))):
            v = m.group(1)
            am = re.compile(r'(\w+)\.addAll\(' + v + r'\.messages\);').search(s, m.end(), m.end() + 1200)
            if not am:
                continue
            lst = am.group(1)
            ch = (v + ".channel_id") if chan else "0"
            new = ("if (GhostMode.keepDeleted()) {\n"
                   "    for (int gi = 0; gi < %s.messages.size(); gi++) {\n"
                   "        GhostMode.markDeleted(%s, %s.messages.get(gi));\n"
                   "    }\n"
                   "} else {\n"
                   "    %s.addAll(%s.messages);\n"
                   "}") % (v, ch, v, lst, v)
            s = s[:am.start()] + new + s[am.end():]
            total += 1
    sig = "protected void deleteMessagesByPush(long dialogId, ArrayList<Integer> ids, long channelId) {"
    pushed = 0
    if sig in s:
        s = s.replace(sig, sig + "\n        if (GhostMode.keepDeleted()) {\n            return;\n        }", 1)
        pushed = 1
    open(p, "w", encoding="utf-8").write(s)
    print("Удалённые: подключено мест =", total, ", push =", pushed)
PY

# 9) Экран настроек в манифесте (иконка + ссылка в информации о приложении)
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
            <intent-filter>
                <action android:name="android.intent.action.APPLICATION_PREFERENCES" />
                <category android:name="android.intent.category.DEFAULT" />
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

# 10) Вкладка Telegyou в настройках Telegram (первая в списке)
python3 - <<'PY'
import re
p = "TMessagesProj/src/main/java/org/telegram/ui/SettingsActivity.java"
s = open(p, encoding="utf-8").read()
if "telegyouRow" in s:
    print("Вкладка: уже есть")
elif "private int languageRow;" not in s or "languageRow = rowCount++;" not in s or "notificationRow = rowCount++;" not in s:
    print("WARNING: нужные строки не найдены, вкладка не появится")
else:
    s = s.replace("private int languageRow;", "private int languageRow;\n    private int telegyouRow;", 1)
    s = s.replace("notificationRow = rowCount++;", "telegyouRow = rowCount++;\n        notificationRow = rowCount++;", 1)
    pat = re.compile(r'\}\s*else if \(position == languageRow\) \{')
    bind = 0
    click = 0
    for m in reversed(list(pat.finditer(s))):
        chunk = s[m.end():m.end() + 500]
        a = chunk.find("setTextAndIcon")
        b = chunk.find("presentFragment")
        if a == -1:
            a = 10**9
        if b == -1:
            b = 10**9
        if a < b:
            vm = re.search(r'(\w+)\.setTextAndIcon\(.*?,\s*(R\.drawable\.\w+)', chunk)
            var = vm.group(1) if vm else "textCell"
            icon = vm.group(2) if vm else "R.drawable.msg_settings_old"
            new = ('} else if (position == telegyouRow) {\n'
                   '                ' + var + '.setTextAndIcon("Telegyou", ' + icon + ', false);\n'
                   '            ' + m.group(0))
            s = s[:m.start()] + new + s[m.end():]
            bind += 1
        elif b < a:
            new = ('} else if (position == telegyouRow) {\n'
                   '                getParentActivity().startActivity(new android.content.Intent(getParentActivity(), org.telegram.messenger.TelegyouSettingsActivity.class));\n'
                   '            ' + m.group(0))
            s = s[:m.start()] + new + s[m.end():]
            click += 1
    open(p, "w", encoding="utf-8").write(s)
    print("Вкладка Telegyou: показ =", bind, ", нажатие =", click)
PY
