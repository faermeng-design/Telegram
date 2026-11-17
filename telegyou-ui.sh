#!/bin/bash
set -e
ROOT="TMessagesProj/src/main/java/org/telegram"

cat > "$ROOT/messenger/TelegyouSettingsActivity.java" <<'JAVA'
package org.telegram.messenger;

import android.app.Activity;
import android.content.res.ColorStateList;
import android.content.res.Configuration;
import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Switch;
import android.widget.TextView;

import androidx.core.graphics.PathParser;

public class TelegyouSettingsActivity extends Activity {

    private static final String ARROW = "M20,11H7.83l5.59,-5.59L12,4l-8,8 8,8 1.41,-1.41L7.83,13H20v-2z";

    private static final String[][] ITEMS = {
            {"no_read", "Не отмечать прочитанным",
                    "Собеседник не увидит «прочитано»",
                    "M18,7l-1.41,-1.41 -6.34,6.34 1.41,1.41L18,7zM22.24,5.58l-10.59,10.6L7.41,11.94 6,13.35l5.65,5.65 12,-12 -1.41,-1.42zM.41,13.41L6,19l1.41,-1.41L1.83,12 .41,13.41z"},
            {"no_stories", "Анонимные истории",
                    "Автор не увидит, что ты смотрел(а)",
                    "M12,4.5C7,4.5 2.73,7.61 1,12c1.73,4.39 6,7.5 11,7.5s9.27,-3.11 11,-7.5c-1.73,-4.39 -6,-7.5 -11,-7.5zM12,17c-2.76,0 -5,-2.24 -5,-5s2.24,-5 5,-5 5,2.24 5,5 -2.24,5 -5,5zM12,9c-1.66,0 -3,1.34 -3,3s1.34,3 3,3 3,-1.34 3,-3 -1.34,-3 -3,-3z"},
            {"no_typing", "Скрыть «печатает…»",
                    "Собеседник не видит, что ты пишешь",
                    "M3,17.25V21h3.75L17.81,9.94l-3.75,-3.75L3,17.25zM20.71,7.04c0.39,-0.39 0.39,-1.02 0,-1.41l-2.34,-2.34c-0.39,-0.39 -1.02,-0.39 -1.41,0l-1.83,1.83 3.75,3.75 1.83,-1.83z"},
            {"no_online", "Скрыть статус «в сети»",
                    "Твой статус онлайн не обновляется",
                    "M12,12c2.21,0 4,-1.79 4,-4s-1.79,-4 -4,-4 -4,1.79 -4,4 1.79,4 4,4zM12,14c-2.67,0 -8,1.34 -8,4v2h16v-2c0,-2.66 -5.33,-4 -8,-4z"},
            {"keep_deleted", "Сохранять удалённые",
                    "Удалённые собеседником сообщения остаются",
                    "M6,19c0,1.1 0.9,2 2,2h8c1.1,0 2,-0.9 2,-2V7H6v12zM19,4h-3.5l-1,-1h-5l-1,1H5v2h14V4z"},
    };

    private int surface, onSurface, onSurfaceVariant, primary, onPrimary, outlineVariant, container;
    private TextView info;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        if (Build.VERSION.SDK_INT >= 29) {
            setTheme(android.R.style.Theme_DeviceDefault_DayNight);
        }
        super.onCreate(savedInstanceState);
        GhostMode.init(getApplicationContext());
        initColors();
        try {
            getWindow().setStatusBarColor(surface);
            getWindow().setNavigationBarColor(surface);
        } catch (Throwable ignored) {
        }

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(surface);
        root.setFitsSystemWindows(true);

        // верхняя панель
        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setGravity(Gravity.CENTER_VERTICAL);
        ImageView back = new ImageView(this);
        back.setImageDrawable(new PathIcon(ARROW, onSurface));
        back.setPadding(dp(16), dp(16), dp(16), dp(16));
        back.setOnClickListener(v -> finish());
        bar.addView(back, new LinearLayout.LayoutParams(dp(56), dp(56)));
        TextView title = text("Telegyou", 22, onSurface, true);
        bar.addView(title);
        root.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(64)));

        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);

        // карточка с информацией
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(20), dp(16), dp(20), dp(16));
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(container);
        bg.setCornerRadius(dp(24));
        card.setBackground(bg);
        info = text("", 15, onSurface, false);
        card.addView(info);

        TextView refresh = text("Обновить значки", 14, onPrimary, true);
        refresh.setGravity(Gravity.CENTER);
        refresh.setPadding(dp(20), dp(10), dp(20), dp(10));
        GradientDrawable pill = new GradientDrawable();
        pill.setColor(primary);
        pill.setCornerRadius(dp(40));
        refresh.setBackground(pill);
        refresh.setOnClickListener(v -> {
            BadgeManager.forceRefresh();
            info.setText("Обновляю…");
            info.postDelayed(this::updateInfo, 2500);
        });
        LinearLayout.LayoutParams rp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        rp.topMargin = dp(12);
        card.addView(refresh, rp);

        LinearLayout.LayoutParams cardP = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        cardP.setMargins(dp(16), dp(8), dp(16), dp(12));
        content.addView(card, cardP);

        for (int i = 0; i < ITEMS.length; i++) {
            String[] it = ITEMS[i];
            content.addView(row(it[0], it[1], it[2], it[3]));
            if (i < ITEMS.length - 1) {
                View line = new View(this);
                line.setBackgroundColor(outlineVariant);
                LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT, dp(1));
                lp.setMargins(dp(16), 0, dp(16), 0);
                content.addView(line, lp);
            }
        }

        ScrollView scroll = new ScrollView(this);
        scroll.addView(content);
        root.addView(scroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        setContentView(root);
        updateInfo();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (info != null) {
            updateInfo();
        }
    }

    private View row(final String key, String title, String desc, String iconPath) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(24), dp(14), dp(24), dp(14));
        row.setMinimumHeight(dp(76));

        ImageView icon = new ImageView(this);
        icon.setImageDrawable(new PathIcon(iconPath, primary));
        row.addView(icon, new LinearLayout.LayoutParams(dp(22), dp(22)));

        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.addView(text(title, 16, onSurface, false));
        col.addView(text(desc, 14, onSurfaceVariant, false));
        LinearLayout.LayoutParams cp = new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        cp.leftMargin = dp(22);
        cp.rightMargin = dp(12);
        row.addView(col, cp);

        final Switch sw = new Switch(this);
        sw.setChecked(GhostMode.get(key));
        int[][] states = {{android.R.attr.state_checked}, new int[0]};
        sw.setThumbTintList(new ColorStateList(states, new int[]{onPrimary, onSurfaceVariant}));
        sw.setTrackTintList(new ColorStateList(states, new int[]{primary, outlineVariant}));
        sw.setOnCheckedChangeListener((v, checked) -> GhostMode.set(key, checked));
        row.addView(sw);
        row.setOnClickListener(v -> sw.toggle());
        return row;
    }

    private void updateInfo() {
        long myId = 0;
        try {
            myId = UserConfig.getInstance(UserConfig.selectedAccount).getClientUserId();
        } catch (Throwable ignored) {
        }
        String badge = BadgeManager.badgeOf(myId);
        info.setText("Твой Telegram ID: " + myId + "\nТвой значок: "
                + (badge == null ? "нет" : BadgeManager.iconOf(badge) + " " + BadgeManager.labelOf(badge))
                + "\nЗаблокировано запросов: " + GhostMode.blocked());
    }

    private TextView text(String s, int sp, int color, boolean bold) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextSize(sp);
        t.setTextColor(color);
        if (bold) {
            t.setTypeface(Typeface.DEFAULT_BOLD);
        }
        return t;
    }

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density + 0.5f);
    }

    private int c(int res) {
        return getResources().getColor(res, getTheme());
    }

    private void initColors() {
        boolean dark = (getResources().getConfiguration().uiMode
                & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
        if (Build.VERSION.SDK_INT >= 31) {
            if (dark) {
                surface = c(android.R.color.system_neutral1_900);
                onSurface = c(android.R.color.system_neutral1_100);
                onSurfaceVariant = c(android.R.color.system_neutral2_200);
                primary = c(android.R.color.system_accent1_200);
                onPrimary = c(android.R.color.system_accent1_800);
                outlineVariant = c(android.R.color.system_neutral2_700);
                container = c(android.R.color.system_neutral1_800);
            } else {
                surface = c(android.R.color.system_neutral1_10);
                onSurface = c(android.R.color.system_neutral1_900);
                onSurfaceVariant = c(android.R.color.system_neutral2_700);
                primary = c(android.R.color.system_accent1_600);
                onPrimary = c(android.R.color.system_accent1_0);
                outlineVariant = c(android.R.color.system_neutral2_200);
                container = c(android.R.color.system_accent2_100);
            }
        } else {
            surface = 0xFF121214;
            onSurface = 0xFFEDEDF0;
            onSurfaceVariant = 0xFFA0A0AA;
            primary = 0xFFB79CFF;
            onPrimary = 0xFF2A1A55;
            outlineVariant = 0xFF3A3A42;
            container = 0xFF1E1E24;
        }
    }

    /** Иконка из строки пути (сетка 24x24). */
    private static class PathIcon extends Drawable {
        private Path path;
        private final Path out = new Path();
        private final Matrix matrix = new Matrix();
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);

        PathIcon(String d, int color) {
            try {
                path = PathParser.createPathFromPathData(d);
            } catch (Throwable t) {
                path = null;
            }
            paint.setColor(color);
        }

        @Override
        public void draw(Canvas canvas) {
            if (path == null) {
                return;
            }
            Rect b = getBounds();
            matrix.setScale(b.width() / 24f, b.height() / 24f);
            matrix.postTranslate(b.left, b.top);
            out.reset();
            path.transform(matrix, out);
            canvas.drawPath(out, paint);
        }

        @Override
        public void setAlpha(int alpha) {
            paint.setAlpha(alpha);
        }

        @Override
        public void setColorFilter(ColorFilter colorFilter) {
            paint.setColorFilter(colorFilter);
        }

        @Override
        public int getOpacity() {
            return PixelFormat.TRANSLUCENT;
        }
    }
}
JAVA

# Делаем файл независимым от кодировки (символы -> \uXXXX)
python3 - <<'PY'
p = "TMessagesProj/src/main/java/org/telegram/messenger/TelegyouSettingsActivity.java"
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
print("UI: экран настроек Material You готов")
PY
