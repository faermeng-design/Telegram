#!/bin/bash
set -e
python3 -m pip install --quiet pillow 2>/dev/null || true
MSG="TMessagesProj/src/main/java/org/telegram/messenger"
UI="TMessagesProj/src/main/java/org/telegram/ui"

# ---------- 1) IconGuard: следит, чтобы у Telegram всегда была иконка ----------
cat > "$MSG/IconGuard.java" <<'JAVA'
package org.telegram.messenger;

import android.content.ComponentName;
import android.content.Context;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;

/** Telegyou: если все иконки Telegram выключены, включает стандартную; прячет иконку настроек. */
public class IconGuard {

    private static final String SETTINGS_ICON = "org.telegram.messenger.TelegyouSettingsIcon";

    public static void ensureAsync(final Context ctx) {
        new Thread(new Runnable() {
            @Override
            public void run() {
                ensure(ctx, false);
            }
        }, "telegyou-iconguard").start();
    }

    public static void ensureDefault(Context ctx) {
        ensure(ctx, true);
    }

    private static void ensure(Context ctx, boolean fromSettings) {
        try {
            PackageManager pm = ctx.getPackageManager();
            String pkg = ctx.getPackageName();
            PackageInfo pi = pm.getPackageInfo(pkg,
                    PackageManager.GET_ACTIVITIES | PackageManager.MATCH_DISABLED_COMPONENTS);
            boolean any = false;
            if (pi.activities != null) {
                for (ActivityInfo ai : pi.activities) {
                    if (ai.targetActivity == null || !ai.targetActivity.endsWith("LaunchActivity")) {
                        continue;
                    }
                    if (!ai.name.startsWith("org.telegram.messenger.") || !ai.name.endsWith("Icon")) {
                        continue;
                    }
                    int st = pm.getComponentEnabledSetting(new ComponentName(pkg, ai.name));
                    if (st == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                            || (st == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && ai.enabled)) {
                        any = true;
                    }
                }
            }
            if (!any) {
                pm.setComponentEnabledSetting(
                        new ComponentName(pkg, "org.telegram.messenger.DefaultIcon"),
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        PackageManager.DONT_KILL_APP);
                return;
            }
            if (!fromSettings) {
                try {
                    ComponentName settings = new ComponentName(pkg, SETTINGS_ICON);
                    if (pm.getComponentEnabledSetting(settings)
                            != PackageManager.COMPONENT_ENABLED_STATE_DISABLED) {
                        pm.setComponentEnabledSetting(settings,
                                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                PackageManager.DONT_KILL_APP);
                    }
                } catch (Throwable ignored) {
                }
            }
        } catch (Throwable ignored) {
        }
    }
}
JAVA

# ---------- 2) Страница настроек Telegyou внутри Telegram ----------
cat > "$UI/TelegyouSettingsFragment.java" <<'JAVA'
package org.telegram.ui;

import android.content.Context;
import android.graphics.Typeface;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import org.telegram.messenger.AndroidUtilities;
import org.telegram.messenger.BadgeManager;
import org.telegram.messenger.GhostMode;
import org.telegram.messenger.R;
import org.telegram.messenger.UserConfig;
import org.telegram.ui.ActionBar.ActionBar;
import org.telegram.ui.ActionBar.BaseFragment;
import org.telegram.ui.ActionBar.Theme;
import org.telegram.ui.Cells.TextCheckCell;

public class TelegyouSettingsFragment extends BaseFragment {

    private static final String[][] ITEMS = {
            {"no_read", "Не отмечать прочитанным", "Собеседник не увидит «прочитано»"},
            {"no_stories", "Анонимные истории", "Автор не увидит, что ты смотрел(а)"},
            {"no_typing", "Скрыть «печатает…»", "Собеседник не видит, что ты пишешь"},
            {"no_online", "Скрыть статус «в сети»", "Твой статус онлайн не обновляется"},
            {"keep_deleted", "Сохранять удалённые", "Удалённые собеседником сообщения остаются"},
    };

    private TextView info;

    @Override
    public View createView(Context context) {
        actionBar.setBackButtonImage(R.drawable.ic_ab_back);
        actionBar.setAllowOverlayTitle(true);
        actionBar.setTitle("Telegyou");
        actionBar.setActionBarMenuOnItemClick(new ActionBar.ActionBarMenuOnItemClick() {
            @Override
            public void onItemClick(int id) {
                if (id == -1) {
                    finishFragment();
                }
            }
        });

        GhostMode.init(context.getApplicationContext());

        FrameLayout frame = new FrameLayout(context);
        fragmentView = frame;
        frame.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundGray));

        ScrollView scroll = new ScrollView(context);
        LinearLayout list = new LinearLayout(context);
        list.setOrientation(LinearLayout.VERTICAL);
        scroll.addView(list, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        frame.addView(scroll, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        // блок с информацией
        LinearLayout card = new LinearLayout(context);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
        info = new TextView(context);
        info.setTextSize(15);
        info.setTextColor(Theme.getColor(Theme.key_windowBackgroundWhiteBlackText));
        info.setPadding(AndroidUtilities.dp(21), AndroidUtilities.dp(16),
                AndroidUtilities.dp(21), AndroidUtilities.dp(8));
        card.addView(info);

        TextView refresh = new TextView(context);
        refresh.setText("Обновить значки");
        refresh.setTextSize(15);
        refresh.setTypeface(Typeface.DEFAULT_BOLD);
        refresh.setTextColor(Theme.getColor(Theme.key_windowBackgroundWhiteBlueText4));
        refresh.setPadding(AndroidUtilities.dp(21), AndroidUtilities.dp(8),
                AndroidUtilities.dp(21), AndroidUtilities.dp(16));
        refresh.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                BadgeManager.forceRefresh();
                info.setText("Обновляю…");
                info.postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        updateInfo();
                    }
                }, 2500);
            }
        });
        card.addView(refresh);
        list.addView(card, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        View gap = new View(context);
        list.addView(gap, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, AndroidUtilities.dp(12)));

        // переключатели
        for (int i = 0; i < ITEMS.length; i++) {
            final String key = ITEMS[i][0];
            final TextCheckCell cell = new TextCheckCell(context);
            cell.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
            cell.setTextAndValueAndCheck(ITEMS[i][1], ITEMS[i][2], GhostMode.get(key), true,
                    i < ITEMS.length - 1);
            cell.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    boolean now = !cell.isChecked();
                    cell.setChecked(now);
                    GhostMode.set(key, now);
                }
            });
            list.addView(cell, new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        }

        updateInfo();
        return fragmentView;
    }

    private void updateInfo() {
        long myId = 0;
        try {
            myId = UserConfig.getInstance(currentAccount).getClientUserId();
        } catch (Throwable ignored) {
        }
        String badge = BadgeManager.badgeOf(myId);
        info.setText("Твой Telegram ID: " + myId + "\nТвой значок: "
                + (badge == null ? "нет" : BadgeManager.iconOf(badge) + " " + BadgeManager.labelOf(badge)));
    }
}
JAVA

# ---------- 3) Всё остальное: иконки, манифест, патчи ----------
python3 - <<'PY'
import glob, os, re, sys

MSG = "TMessagesProj/src/main/java/org/telegram/messenger/"
UI = "TMessagesProj/src/main/java/org/telegram/ui/"

# --- 3.1 Java-файлы без русских букв в исходнике (\uXXXX)
def to_ascii(path):
    s = open(path, encoding="utf-8").read()
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
    open(path, "w", encoding="ascii").write("".join(out))

to_ascii(UI + "TelegyouSettingsFragment.java")
print("Фрагмент настроек: создан")

# --- 3.2 Порядок переключения иконок: сначала включаем выбранную
p = UI + "LauncherIconController.java"
if os.path.exists(p):
    s = open(p, encoding="utf-8").read()
    if "telegyouOrder" in s:
        print("setIcon: уже исправлен")
    else:
        m = re.search(r'public static void setIcon\(\s*LauncherIcon\s+(\w+)\s*\)\s*\{', s)
        if not m:
            print("WARNING: setIcon не найден")
        else:
            v = m.group(1)
            end = m.end()
            window = s[end:end + 1500]
            if "LauncherIcon.values()" not in window:
                print("WARNING: цикл в setIcon не найден")
            else:
                window2 = window.replace("LauncherIcon.values()", "telegyouOrder(%s)" % v, 1)
                helper = (
                    "    private static java.util.List<LauncherIcon> telegyouOrder(LauncherIcon first) {\n"
                    "        java.util.ArrayList<LauncherIcon> list = new java.util.ArrayList<>();\n"
                    "        list.add(first);\n"
                    "        for (LauncherIcon other : LauncherIcon.values()) {\n"
                    "            if (other != first) {\n"
                    "                list.add(other);\n"
                    "            }\n"
                    "        }\n"
                    "        return list;\n"
                    "    }\n\n"
                )
                s = s[:m.start()] + helper + s[m.start():end] + window2 + s[end + 1500:]
                open(p, "w", encoding="utf-8").write(s)
                print("setIcon: теперь сначала включается выбранная иконка")
else:
    print("WARNING: LauncherIconController.java не найден")

# --- 3.3 IconGuard при запуске приложения
p = MSG + "ApplicationLoader.java"
if os.path.exists(p):
    s = open(p, encoding="utf-8").read()
    if "IconGuard.ensureAsync" in s:
        print("ApplicationLoader: IconGuard уже подключён")
    else:
        m = re.search(r'public void onCreate\(\)\s*\{', s)
        i = s.find("super.onCreate();", m.end()) if m else -1
        if m and i > 0 and i - m.end() < 2500:
            j = i + len("super.onCreate();")
            s = s[:j] + "\n        IconGuard.ensureAsync(this);" + s[j:]
            open(p, "w", encoding="utf-8").write(s)
            print("ApplicationLoader: IconGuard подключён")
        else:
            print("WARNING: не нашёл onCreate в ApplicationLoader")
else:
    print("WARNING: ApplicationLoader.java не найден")

# --- 3.4 Вкладка Telegyou открывает страницу внутри Telegram
p = UI + "SettingsActivity.java"
s = open(p, encoding="utf-8").read()
pat = re.compile(r'getParentActivity\(\)\.startActivity\(\s*new android\.content\.Intent\(\s*getParentActivity\(\),\s*org\.telegram\.messenger\.TelegyouSettingsActivity\.class\)\);')
if "new TelegyouSettingsFragment()" in s:
    print("SettingsActivity: уже открывает страницу внутри Telegram")
elif pat.search(s):
    s = pat.sub("presentSettingFragment(new TelegyouSettingsFragment());", s, count=1)
    open(p, "w", encoding="utf-8").write(s)
    print("SettingsActivity: вкладка открывает страницу внутри Telegram")
else:
    print("WARNING: не нашёл вызов экрана настроек в SettingsActivity")

# --- 3.5 Манифест: иконка настроек отдельным алиасом (его прячет IconGuard)
target = None
for mp in ["TMessagesProj_App/src/main/AndroidManifest.xml", "TMessagesProj/src/main/AndroidManifest.xml"]:
    if os.path.exists(mp) and "TelegyouSettingsActivity" in open(mp, encoding="utf-8").read():
        target = mp
        break
if target is None:
    print("WARNING: активити настроек не найдена в манифесте")
else:
    x = open(target, encoding="utf-8").read()
    m = re.search(r'<activity\s+android:name="org\.telegram\.messenger\.TelegyouSettingsActivity".*?</activity>', x, re.S)
    if m:
        inner = m.group(0)
        new = re.sub(r'\s*<intent-filter>\s*<action android:name="android\.intent\.action\.MAIN"\s*/>\s*<category android:name="android\.intent\.category\.LAUNCHER"\s*/>\s*</intent-filter>', '', inner, count=1, flags=re.S)
        if "APPLICATION_PREFERENCES" not in new:
            new = new.replace("</activity>", '''            <intent-filter>
                <action android:name="android.intent.action.APPLICATION_PREFERENCES" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
        </activity>''', 1)
        x = x.replace(inner, new, 1)
    if "TelegyouSettingsIcon" not in x:
        alias = '''        <activity-alias
            android:name="org.telegram.messenger.TelegyouSettingsIcon"
            android:targetActivity="org.telegram.messenger.TelegyouSettingsActivity"
            android:label="Telegyou: настройки"
            android:enabled="true"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity-alias>
'''
        x = x.replace("</application>", alias + "    </application>", 1)
    open(target, "w", encoding="utf-8").write(x)
    print("Манифест: иконка настроек стала алиасом (прячется сама), файл", target)

# --- 3.6 Иконки: нормальный размер, без белого фона и синей оболочки
try:
    from PIL import Image, ImageDraw
except Exception:
    Image = None
    print("WARNING: Pillow недоступен, иконки не исправлены")

if Image is not None:
    DEFAULT_BG = (0x1a, 0x10, 0x33, 255)

    def bg_color(path):
        c = Image.open(path).convert("RGBA").getpixel((5, 5))
        return c if c[3] >= 250 else DEFAULT_BG

    def prep(path):
        img = Image.open(path).convert("RGBA")
        box = img.getchannel("A").getbbox()
        if box:
            img = img.crop(box)
        w, h = img.size
        s = max(w, h)
        sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        sq.paste(img, ((s - w) // 2, (s - h) // 2))
        return sq

    def layers(src, bg_path, fg_path):
        col = bg_color(src)
        art = prep(src)
        os.makedirs(os.path.dirname(bg_path), exist_ok=True)
        Image.new("RGBA", (432, 432), col).save(bg_path)
        fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
        k = 290
        fg.alpha_composite(art.resize((k, k), Image.LANCZOS), dest=((432 - k) // 2, (432 - k) // 2))
        fg.save(fg_path)
        return col, art

    def legacy(path, col, art, round_icon):
        w, h = Image.open(path).size
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        mask = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(mask)
        if round_icon:
            d.ellipse((0, 0, w - 1, h - 1), fill=255)
        else:
            d.rounded_rectangle((0, 0, w - 1, h - 1), radius=int(w * 0.22), fill=255)
        out.paste(Image.new("RGBA", (w, h), col), (0, 0), mask)
        k = int(w * 0.68)
        out.alpha_composite(art.resize((k, k), Image.LANCZOS), dest=((w - k) // 2, (h - k) // 2))
        out.save(path)

    res = "TMessagesProj/src/main/res/"
    if os.path.exists("icon.png"):
        col, art = layers("icon.png", res + "mipmap-xxxhdpi/telegyou_main_bg.png",
                          res + "mipmap-xxxhdpi/telegyou_main_fg.png")
        n = 0
        for f in glob.glob("TMessagesProj*/src/*/res/mipmap-*/*.png"):
            name = os.path.basename(f)
            if name in ("ic_launcher.png", "ic_launcher_round.png", "ic_launcher_sa.png"):
                legacy(f, col, art, "round" in name)
                n += 1
        xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
               '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
               '    <background android:drawable="@mipmap/telegyou_main_bg"/>\n'
               '    <foreground android:drawable="@mipmap/telegyou_main_fg"/>\n'
               '</adaptive-icon>\n')
        m2 = 0
        for f in glob.glob("TMessagesProj*/src/*/res/mipmap-anydpi*/ic_launcher*.xml"):
            open(f, "w", encoding="utf-8").write(xml)
            m2 += 1
        print("Основная иконка: PNG =", n, ", адаптивных XML =", m2)
    else:
        print("WARNING: icon.png не найден")

    if os.path.exists("icon2.png"):
        col2, art2 = layers("icon2.png", res + "mipmap-xxxhdpi/telegyou_icon_background.png",
                            res + "mipmap-xxxhdpi/telegyou_icon_foreground.png")
        lp = res + "mipmap-xxxhdpi/telegyou_icon_launcher.png"
        if os.path.exists(lp):
            legacy(lp, col2, art2, False)
        print("Вторая иконка: исправлена")
    else:
        print("icon2.png не найден, вторая иконка пропущена")

# --- 3.7 GhostMode вызывает IconGuard (если ещё не вызывает)
p = MSG + "GhostMode.java"
if os.path.exists(p):
    s = open(p, encoding="ascii", errors="replace").read()
    if "IconGuard" in s:
        print("GhostMode: IconGuard уже подключён")
    elif "appContext = context;" in s:
        s = s.replace("appContext = context;", "appContext = context;\n        IconGuard.ensureDefault(context);", 1)
        open(p, "w", encoding="ascii").write(s)
        print("GhostMode: IconGuard подключён")
else:
    print("WARNING: GhostMode.java не найден")
PY
