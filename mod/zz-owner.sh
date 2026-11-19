#!/bin/bash
set -e
MSG="TMessagesProj/src/main/java/org/telegram/messenger"
REPO="${GITHUB_REPOSITORY:-faermeng-design/Telegram}"
BRANCH="${GITHUB_REF_NAME:-master}"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/"

# ---------- 1) Новый BadgeManager: эмодзи + картинки + текст окошка ----------
cat > "$MSG/BadgeManager.java" <<'JAVA'
package org.telegram.messenger;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Paint;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.text.Spannable;
import android.text.SpannableStringBuilder;
import android.text.Spanned;
import android.text.TextUtils;
import android.text.style.DynamicDrawableSpan;
import android.text.style.ImageSpan;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

/** Telegyou: значки, которые владелец выдаёт через файл badges.json на GitHub. */
public class BadgeManager {

    private static final String BASE_URL = "__BASE_URL__";
    private static final String URL_STR = BASE_URL + "badges.json";
    private static final long REFRESH_MS = 30 * 60 * 1000L;
    /** Невидимый знак после эмодзи: по нему имя заменяется картинкой. */
    public static final char MARK = '\u2063';

    private static volatile Map<Long, String> users = new HashMap<>();
    private static volatile Map<String, String> icons = defaultIcons();
    private static volatile Map<String, String> labels = defaultLabels();
    private static volatile Map<String, String> images = new HashMap<>();
    private static volatile Map<String, String> infos = new HashMap<>();
    private static final Map<String, Bitmap> bitmaps = new HashMap<>();
    private static volatile long lastFetch = 0;
    private static volatile boolean loading = false;
    private static boolean cacheLoaded = false;

    private static Map<String, String> defaultIcons() {
        Map<String, String> m = new HashMap<>();
        m.put("creator", "👑");
        m.put("owner", "👑");
        m.put("tester", "🧪");
        return m;
    }

    private static Map<String, String> defaultLabels() {
        Map<String, String> m = new HashMap<>();
        m.put("creator", "creator");
        m.put("owner", "owner");
        m.put("tester", "tester");
        return m;
    }

    private static SharedPreferences prefs() {
        return ApplicationLoader.applicationContext.getSharedPreferences("telegyou_badges", Context.MODE_PRIVATE);
    }

    private static File imageFile(String name) {
        return new File(ApplicationLoader.applicationContext.getFilesDir(), "telegyou_badge_" + name + ".png");
    }

    private static void parse(String json) {
        try {
            JSONObject root = new JSONObject(json);
            Map<String, String> newIcons = defaultIcons();
            Map<String, String> newLabels = defaultLabels();
            Map<String, String> newImages = new HashMap<>();
            Map<String, String> newInfos = new HashMap<>();
            JSONObject b = root.optJSONObject("badges");
            if (b != null) {
                Iterator<String> it = b.keys();
                while (it.hasNext()) {
                    String k = it.next();
                    JSONObject o = b.optJSONObject(k);
                    if (o != null) {
                        newIcons.put(k, o.optString("icon", "*"));
                        newLabels.put(k, o.optString("label", k));
                        String img = o.optString("image", "");
                        if (img.length() > 0) {
                            newImages.put(k, img);
                        }
                        String info = o.optString("info", "");
                        if (info.length() > 0) {
                            newInfos.put(k, info);
                        }
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
            images = newImages;
            infos = newInfos;
            users = newUsers;
        } catch (Throwable ignored) {
        }
    }

    private static boolean download(String urlStr, File dest) {
        HttpURLConnection c = null;
        try {
            c = (HttpURLConnection) new URL(urlStr + "?t=" + System.currentTimeMillis()).openConnection();
            c.setConnectTimeout(8000);
            c.setReadTimeout(12000);
            if (c.getResponseCode() != 200) {
                return false;
            }
            File tmp = new File(dest.getPath() + ".tmp");
            InputStream in = c.getInputStream();
            FileOutputStream out = new FileOutputStream(tmp);
            byte[] buf = new byte[8192];
            int r;
            while ((r = in.read(buf)) > 0) {
                out.write(buf, 0, r);
            }
            out.close();
            in.close();
            if (dest.exists()) {
                dest.delete();
            }
            return tmp.renameTo(dest);
        } catch (Throwable t) {
            return false;
        } finally {
            if (c != null) {
                c.disconnect();
            }
        }
    }

    private static void refreshAsync() {
        if (loading) {
            return;
        }
        loading = true;
        new Thread(new Runnable() {
            @Override
            public void run() {
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
                        for (Map.Entry<String, String> e : images.entrySet()) {
                            if (download(BASE_URL + e.getValue(), imageFile(e.getKey()))) {
                                synchronized (bitmaps) {
                                    bitmaps.remove(e.getKey());
                                }
                            }
                        }
                    }
                } catch (Throwable ignored) {
                } finally {
                    lastFetch = ok ? System.currentTimeMillis() : System.currentTimeMillis() - REFRESH_MS + 120000L;
                    loading = false;
                }
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

    /** Текст окошка, которое показывается по нажатию на значок. */
    public static String infoOf(String badge) {
        String s = infos.get(badge);
        return s == null ? "" : s;
    }

    private static Bitmap bitmapOf(String name) {
        synchronized (bitmaps) {
            Bitmap b = bitmaps.get(name);
            if (b != null) {
                return b;
            }
            File f = imageFile(name);
            if (!f.exists()) {
                return null;
            }
            b = BitmapFactory.decodeFile(f.getPath());
            if (b != null) {
                bitmaps.put(name, b);
            }
            return b;
        }
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
            if (icon == null) {
                return name;
            }
            boolean hasImage = images.containsKey(badge) && bitmapOf(badge) != null;
            return name + " " + icon + (hasImage ? String.valueOf(MARK) : "");
        } catch (Throwable t) {
            return name;
        }
    }

    /** Заменяет эмодзи значка на картинку (вызывается из Emoji.replaceEmoji). */
    public static CharSequence applyImages(CharSequence cs, Paint.FontMetricsInt fm) {
        try {
            if (cs == null || cs.length() < 2 || TextUtils.indexOf(cs, MARK) < 0 || images.isEmpty()) {
                return cs;
            }
            Spannable sp;
            if (cs instanceof Spannable) {
                sp = (Spannable) cs;
            } else {
                sp = new SpannableStringBuilder(cs);
            }
            int size = fm != null ? Math.abs(fm.descent - fm.ascent) : AndroidUtilities.dp(18);
            if (size <= 0) {
                size = AndroidUtilities.dp(18);
            }
            int n = sp.length();
            for (int i = 0; i < n; i++) {
                if (sp.charAt(i) != MARK) {
                    continue;
                }
                for (Map.Entry<String, String> e : images.entrySet()) {
                    String icon = icons.get(e.getKey());
                    if (icon == null || icon.length() == 0) {
                        continue;
                    }
                    int start = i - icon.length();
                    if (start < 0 || !icon.equals(sp.subSequence(start, i).toString())) {
                        continue;
                    }
                    Bitmap bmp = bitmapOf(e.getKey());
                    if (bmp == null) {
                        continue;
                    }
                    Drawable d = new BitmapDrawable(ApplicationLoader.applicationContext.getResources(), bmp);
                    d.setBounds(0, 0, size, size);
                    DynamicDrawableSpan[] old = sp.getSpans(start, i + 1, DynamicDrawableSpan.class);
                    for (int j = 0; j < old.length; j++) {
                        sp.removeSpan(old[j]);
                    }
                    sp.setSpan(new ImageSpan(d, DynamicDrawableSpan.ALIGN_BOTTOM), start, i + 1,
                            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
                    break;
                }
            }
            return sp;
        } catch (Throwable t) {
            return cs;
        }
    }
}
JAVA
sed -i "s|__BASE_URL__|${BASE_URL}|" "$MSG/BadgeManager.java"
echo "BadgeManager: новая версия, адрес файлов ${BASE_URL}"

python3 - <<'PY'
import os, re
MSG = "TMessagesProj/src/main/java/org/telegram/messenger/"

# --- Java без русских букв и эмодзи в исходнике (\uXXXX)
p = MSG + "BadgeManager.java"
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

# --- Emoji.replaceEmoji: после замены эмодзи ставим картинки значков
p = MSG + "Emoji.java"
s = open(p, encoding="utf-8").read()
sig = "public static CharSequence replaceEmoji(CharSequence cs, Paint.FontMetricsInt fontMetrics, boolean createNew, int[] emojiOnly, int alignment, float scale, int minusLimit) {"
if "replaceEmojiTelegyou" in s:
    print("Emoji: уже подключён")
elif sig not in s:
    print("WARNING: главная replaceEmoji не найдена, картинка значка не подключена")
else:
    new = (
        "public static CharSequence replaceEmoji(CharSequence cs, Paint.FontMetricsInt fontMetrics, boolean createNew, int[] emojiOnly, int alignment, float scale, int minusLimit) {\n"
        "        CharSequence telegyouResult = replaceEmojiTelegyou(cs, fontMetrics, createNew, emojiOnly, alignment, scale, minusLimit);\n"
        "        return BadgeManager.applyImages(telegyouResult, fontMetrics);\n"
        "    }\n\n"
        "    private static CharSequence replaceEmojiTelegyou(CharSequence cs, Paint.FontMetricsInt fontMetrics, boolean createNew, int[] emojiOnly, int alignment, float scale, int minusLimit) {"
    )
    s = s.replace(sig, new, 1)
    open(p, "w", encoding="utf-8").write(s)
    print("Emoji: картинки значков подключены")
PY
