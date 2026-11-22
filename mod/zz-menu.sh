#!/bin/bash
UI="TMessagesProj/src/main/java/org/telegram/ui"
cat > "$UI/TelegyouSettingsFragment.java" <<'JAVA'
package org.telegram.ui;

import android.content.Context;
import android.graphics.Typeface;
import android.view.Gravity;
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

import java.util.ArrayList;

public class TelegyouSettingsFragment extends BaseFragment {

    private static final String[][] GHOST = {
            {"no_online", "Скрыть статус «в сети»", "Твой статус онлайн не обновляется"},
            {"no_typing", "Скрыть «печатает…»", "Собеседник не видит, что ты пишешь"},
            {"no_stories", "Анонимные истории", "Автор не увидит, что ты смотрел(а)"},
            {"no_read", "Не отмечать прочитанным", "Собеседник не увидит «прочитано»"},
    };

    private TextView info;
    private TextCheckCell ghostMaster;
    private final ArrayList<TextCheckCell> ghostCells = new ArrayList<>();

    private int dp(int v) {
        return AndroidUtilities.dp(v);
    }

    private boolean anyGhostOn() {
        for (int i = 0; i < GHOST.length; i++) {
            if (GhostMode.get(GHOST[i][0])) {
                return true;
            }
        }
        return false;
    }

    private LinearLayout.LayoutParams full() {
        return new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
    }

    private View gap(Context context) {
        View v = new View(context);
        v.setLayoutParams(new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(12)));
        return v;
    }

    private LinearLayout body(Context context) {
        LinearLayout b = new LinearLayout(context);
        b.setOrientation(LinearLayout.VERTICAL);
        b.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
        b.setVisibility(View.GONE);
        return b;
    }

    private View indented(Context context, TextCheckCell cell) {
        LinearLayout w = new LinearLayout(context);
        w.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.leftMargin = dp(18);
        w.addView(cell, lp);
        return w;
    }

    private View header(Context context, TextCheckCell cell, final LinearLayout body) {
        FrameLayout row = new FrameLayout(context);
        row.addView(cell, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        final TextView arrow = new TextView(context);
        arrow.setText("▾");
        arrow.setTextSize(22);
        arrow.setGravity(Gravity.CENTER);
        arrow.setTextColor(Theme.getColor(Theme.key_windowBackgroundWhiteGrayText2));
        FrameLayout.LayoutParams ap = new FrameLayout.LayoutParams(
                dp(44), ViewGroup.LayoutParams.MATCH_PARENT, Gravity.RIGHT);
        ap.rightMargin = dp(70);
        row.addView(arrow, ap);
        arrow.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                boolean show = body.getVisibility() != View.VISIBLE;
                body.setVisibility(show ? View.VISIBLE : View.GONE);
                arrow.setText(show ? "▴" : "▾");
            }
        });
        return row;
    }

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

        // ---- 1. Режим призрака
        LinearLayout ghostBody = body(context);
        ghostMaster = new TextCheckCell(context);
        ghostMaster.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
        ghostMaster.setTextAndValueAndCheck("Режим призрака",
                "Включает и выключает все функции списка", anyGhostOn(), true, false);
        ghostMaster.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                boolean now = !ghostMaster.isChecked();
                ghostMaster.setChecked(now);
                for (int i = 0; i < GHOST.length; i++) {
                    GhostMode.set(GHOST[i][0], now);
                    ghostCells.get(i).setChecked(now);
                }
            }
        });
        list.addView(header(context, ghostMaster, ghostBody), full());

        for (int i = 0; i < GHOST.length; i++) {
            final String key = GHOST[i][0];
            final TextCheckCell cell = new TextCheckCell(context);
            cell.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
            cell.setTextAndValueAndCheck(GHOST[i][1], GHOST[i][2], GhostMode.get(key), true,
                    i < GHOST.length - 1);
            cell.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    boolean now = !cell.isChecked();
                    cell.setChecked(now);
                    GhostMode.set(key, now);
                    ghostMaster.setChecked(anyGhostOn());
                }
            });
            ghostCells.add(cell);
            ghostBody.addView(indented(context, cell), full());
        }
        list.addView(ghostBody, full());
        list.addView(gap(context));

        // ---- 2. Сохранять удалённые
        LinearLayout keepBody = body(context);
        final TextCheckCell keepMaster = new TextCheckCell(context);
        keepMaster.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
        keepMaster.setTextAndValueAndCheck("Сохранять удалённые",
                "Удалённые собеседником сообщения остаются", GhostMode.get("keep_deleted"), true, false);
        keepMaster.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                boolean now = !keepMaster.isChecked();
                keepMaster.setChecked(now);
                GhostMode.set("keep_deleted", now);
            }
        });
        list.addView(header(context, keepMaster, keepBody), full());

        TextView soon = new TextView(context);
        soon.setText("Скоро здесь: сохранение сгорающих фото, настройки вида удалённых сообщений.");
        soon.setTextSize(14);
        soon.setTextColor(Theme.getColor(Theme.key_windowBackgroundWhiteGrayText2));
        soon.setPadding(dp(39), dp(10), dp(21), dp(14));
        keepBody.addView(soon, full());
        list.addView(keepBody, full());
        list.addView(gap(context));

        // ---- 3. Информация (внизу)
        LinearLayout card = new LinearLayout(context);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
        info = new TextView(context);
        info.setTextSize(15);
        info.setTextColor(Theme.getColor(Theme.key_windowBackgroundWhiteBlackText));
        info.setPadding(dp(21), dp(16), dp(21), dp(8));
        card.addView(info);

        TextView refresh = new TextView(context);
        refresh.setText("Обновить значки");
        refresh.setTextSize(15);
        refresh.setTypeface(Typeface.DEFAULT_BOLD);
        refresh.setTextColor(Theme.getColor(Theme.key_windowBackgroundWhiteBlueText4));
        refresh.setPadding(dp(21), dp(8), dp(21), dp(16));
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
        list.addView(card, full());

        View bottom = new View(context);
        list.addView(bottom, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(24)));

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
        String badge = BadgeManager.badgeOf(myId);
        info.setText("Твой Telegram ID: " + myId + "\nТвой значок: "
                + (badge == null ? "нет" : BadgeManager.iconOf(badge) + " " + BadgeManager.labelOf(badge))
                + "\nЗаблокировано запросов: " + GhostMode.blocked());
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
print("Меню настроек Telegyou: новая раскладка готова")
PY
