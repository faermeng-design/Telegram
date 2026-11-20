#!/bin/bash
UI="TMessagesProj/src/main/java/org/telegram/ui"
cat > "$UI/TelegyouSettingsFragment.java" <<'JAVA'
package org.telegram.ui;

import android.content.Context;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.CompoundButton;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Switch;
import android.widget.TextView;

import org.telegram.messenger.AndroidUtilities;
import org.telegram.messenger.BadgeManager;
import org.telegram.messenger.GhostMode;
import org.telegram.messenger.R;
import org.telegram.messenger.UserConfig;
import org.telegram.ui.ActionBar.ActionBar;
import org.telegram.ui.ActionBar.BaseFragment;
import org.telegram.ui.ActionBar.Theme;

import java.util.ArrayList;

public class TelegyouSettingsFragment extends BaseFragment {

    private static final int PURPLE = 0xFF8E5CF7;

    private static final String[][] ITEMS = {
            {"no_read", "Не отмечать прочитанным", "✔"},
            {"no_stories", "Анонимные истории", "👁"},
            {"no_typing", "Скрыть «печатает…»", "✎"},
            {"no_online", "Скрыть статус «В сети»", "👤"},
            {"keep_deleted", "Сохранять удалённые", "♻"},
    };

    private TextView info;
    private TextView arrow;
    private Switch master;
    private LinearLayout childBox;
    private final ArrayList<Switch> childSwitches = new ArrayList<>();
    private boolean updating = false;
    private boolean expanded = true;

    private int dp(int v) {
        return AndroidUtilities.dp(v);
    }

    private GradientDrawable shape(int color, int radiusDp, boolean oval) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(color);
        if (oval) {
            d.setShape(GradientDrawable.OVAL);
        } else {
            d.setCornerRadius(dp(radiusDp));
        }
        return d;
    }

    private TextView glyph(Context context, String text, int sizeDp, int textSp) {
        TextView t = new TextView(context);
        t.setText(text);
        t.setTextSize(textSp);
        t.setTextColor(0xFFFFFFFF);
        t.setGravity(Gravity.CENTER);
        t.setBackground(shape(PURPLE, 0, true));
        t.setLayoutParams(new LinearLayout.LayoutParams(dp(sizeDp), dp(sizeDp)));
        return t;
    }

    private boolean anyOn() {
        for (int i = 0; i < ITEMS.length; i++) {
            if (GhostMode.get(ITEMS[i][0])) {
                return true;
            }
        }
        return false;
    }

    @Override
    public View createView(Context context) {
        actionBar.setBackButtonImage(R.drawable.ic_ab_back);
        actionBar.setAllowOverlayTitle(true);
        actionBar.setTitle("Настройки Telegyou");
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
        list.setPadding(dp(12), dp(12), dp(12), dp(100));
        scroll.addView(list, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        frame.addView(scroll, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        LinearLayout card = new LinearLayout(context);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setBackground(shape(Theme.getColor(Theme.key_windowBackgroundWhite), 16, false));
        list.addView(card, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        LinearLayout header = new LinearLayout(context);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(dp(16), dp(14), dp(16), dp(14));
        card.addView(header, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView ghost = glyph(context, "👻", 40, 20);
        header.addView(ghost);

        LinearLayout texts = new LinearLayout(context);
        texts.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams tp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        tp.leftMargin = dp(14);
        header.addView(texts, tp);

        TextView title = new TextView(context);
        title.setText("Режим призрака");
        title.setTextSize(16);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        title.setTextColor(Theme.getColor(Theme.key_windowBackgroundWhiteBlackText));
        texts.addView(title);

        TextView sub = new TextView(context);
        sub.setText("скрывает вас");
        sub.setTextSize(13);
        sub.setTextColor(Theme.getColor(Theme.key_windowBackgroundWhiteGrayText2));
        texts.addView(sub);

        arrow = new TextView(context);
        arrow.setText("▾");
        arrow.setTextSize(20);
        arrow.setTextColor(Theme.getColor(Theme.key_windowBackgroundWhiteBlackText));
        arrow.setPadding(dp(8), 0, dp(12), 0);
        header.addView(arrow);

        master = new Switch(context);
        master.setChecked(anyOn());
        header.addView(master);

        childBox = new LinearLayout(context);
        childBox.setOrientation(LinearLayout.VERTICAL);
        childBox.setPadding(0, 0, 0, dp(8));
        card.addView(childBox, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        for (int i = 0; i < ITEMS.length; i++) {
            final String key = ITEMS[i][0];
            LinearLayout row = new LinearLayout(context);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setGravity(Gravity.CENTER_VERTICAL);
            row.setPadding(dp(28), dp(10), dp(16), dp(10));
            childBox.addView(row, new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

            row.addView(glyph(context, ITEMS[i][2], 26, 12));

            TextView t = new TextView(context);
            t.setText(ITEMS[i][1]);
            t.setTextSize(15);
            t.setTextColor(Theme.getColor(Theme.key_windowBackgroundWhiteBlackText));
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
            lp.leftMargin = dp(12);
            row.addView(t, lp);

            final Switch sw = new Switch(context);
            sw.setChecked(GhostMode.get(key));
            sw.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
                @Override
                public void onCheckedChanged(CompoundButton button, boolean checked) {
                    if (updating) {
                        return;
                    }
                    GhostMode.set(key, checked);
                    updating = true;
                    master.setChecked(anyOn());
                    updating = false;
                }
            });
            childSwitches.add(sw);
            row.addView(sw);
            row.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    sw.toggle();
                }
            });
        }

        master.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton button, boolean checked) {
                if (updating) {
                    return;
                }
                updating = true;
                for (int i = 0; i < ITEMS.length; i++) {
                    GhostMode.set(ITEMS[i][0], checked);
                    childSwitches.get(i).setChecked(checked);
                }
                updating = false;
            }
        });

        header.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                expanded = !expanded;
                childBox.setVisibility(expanded ? View.VISIBLE : View.GONE);
                arrow.setText(expanded ? "▾" : "▸");
            }
        });

        info = new TextView(context);
        info.setTextSize(14);
        info.setTypeface(Typeface.DEFAULT_BOLD);
        info.setTextColor(0xFFAEAEAE);
        info.setBackground(shape(0xFF414141, 18, false));
        info.setPadding(dp(20), dp(12), dp(20), dp(12));
        info.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                BadgeManager.forceRefresh();
                updateInfo();
            }
        });
        FrameLayout.LayoutParams ip = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM);
        ip.setMargins(dp(8), 0, dp(8), dp(12));
        frame.addView(info, ip);

        updateInfo();
        return fragmentView;
    }

    @Override
    public void onResume() {
        super.onResume();
        updateInfo();
    }

    private void updateInfo() {
        if (info == null) {
            return;
        }
        long myId = 0;
        try {
            myId = UserConfig.getInstance(currentAccount).getClientUserId();
        } catch (Throwable ignored) {
        }
        info.setText("Ваш Telegram ID: " + myId + "\nЗаблокировано запросов: " + GhostMode.blocked());
    }
}
JAVA

python3 - <<'PY'
p = "TMessagesProj/src/main/java/org/telegram/ui/TelegyouSettingsFragment.java"
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
print("Новая страница настроек Telegyou: готова")
PY
