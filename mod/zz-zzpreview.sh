#!/bin/bash
python3 - <<'PY'

def to_ascii(s):
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
    return "".join(out)

B = "TMessagesProj/src/main/java/org/telegram/"

# ---------- 1) Хранилище стиля: больше пометок + прозрачность в процентах ----------
style = r'''package org.telegram.messenger;

import android.content.Context;
import android.content.SharedPreferences;

public class TelegyouStyle {

    public static boolean dimUsed = false;

    private static final String[] LABEL_TEXT = {
            "", "🗑", "❌", "👻", "🚫", "⛔", "💨", "🔥", "🕳", "⚠️", "✖️", "⌫", "∅"
    };
    private static final int[] OLD_DIM = {100, 85, 70, 50};

    private static SharedPreferences prefs() {
        return ApplicationLoader.applicationContext.getSharedPreferences("telegyou_style", Context.MODE_PRIVATE);
    }

    private static int clamp(int v, int max) {
        return v < 0 ? 0 : (v >= max ? max - 1 : v);
    }

    public static int labelStyle() {
        try {
            return clamp(prefs().getInt("label", 1), LABEL_TEXT.length);
        } catch (Throwable t) {
            return 1;
        }
    }

    public static void setLabelStyle(int v) {
        try {
            prefs().edit().putInt("label", clamp(v, LABEL_TEXT.length)).apply();
        } catch (Throwable ignored) {
        }
    }

    public static String label() {
        return LABEL_TEXT[labelStyle()];
    }

    public static String labelName() {
        String s = LABEL_TEXT[labelStyle()];
        return s.length() == 0 ? "Выкл" : s;
    }

    public static String[] labelNames() {
        String[] r = new String[LABEL_TEXT.length];
        for (int i = 0; i < r.length; i++) {
            r[i] = LABEL_TEXT[i].length() == 0 ? "Выкл" : LABEL_TEXT[i];
        }
        return r;
    }

    public static int dimPercent() {
        try {
            SharedPreferences p = prefs();
            int v = p.getInt("dim_pct", -1);
            if (v < 0) {
                v = OLD_DIM[clamp(p.getInt("dim", 0), OLD_DIM.length)];
            }
            return v < 10 ? 10 : (v > 100 ? 100 : v);
        } catch (Throwable t) {
            return 100;
        }
    }

    public static void setDimPercent(int v) {
        try {
            int x = v < 10 ? 10 : (v > 100 ? 100 : v);
            prefs().edit().putInt("dim_pct", x).apply();
        } catch (Throwable ignored) {
        }
    }

    public static float dim() {
        return dimPercent() / 100f;
    }

    public static int dimLevel() {
        int p = dimPercent();
        int best = 0;
        for (int i = 1; i < OLD_DIM.length; i++) {
            if (Math.abs(OLD_DIM[i] - p) < Math.abs(OLD_DIM[best] - p)) {
                best = i;
            }
        }
        return best;
    }

    public static void setDimLevel(int v) {
        setDimPercent(OLD_DIM[clamp(v, OLD_DIM.length)]);
    }

    public static String dimName() {
        return dimPercent() + "%";
    }

    public static String[] dimNames() {
        return new String[]{"100%", "85%", "70%", "50%"};
    }
}
'''
open(B + "messenger/TelegyouStyle.java", "w", encoding="ascii").write(to_ascii(style))
print("zz-zzpreview: TelegyouStyle обновлён")

# ---------- 2) Окно предпросмотра ----------
frag = r'''package org.telegram.ui;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.TextView;

import org.telegram.messenger.AndroidUtilities;
import org.telegram.messenger.R;
import org.telegram.messenger.TelegyouStyle;
import org.telegram.ui.ActionBar.ActionBar;
import org.telegram.ui.ActionBar.BaseFragment;
import org.telegram.ui.ActionBar.Theme;

import java.util.ArrayList;

public class TelegyouPreviewFragment extends BaseFragment {

    private final String[] titles = {"Сообщение", "Голосовое", "Фото"};
    private final View[] pages = new View[3];
    private final View[] bubbles = new View[3];
    private final TextView[] timeViews = new TextView[3];
    private final ArrayList<TextView> chips = new ArrayList<>();
    private FrameLayout pager;
    private TextView pageTitle;
    private TextView dimText;
    private int cur = 0;
    private boolean animating = false;

    private int dp(int v) {
        return AndroidUtilities.dp(v);
    }

    private GradientDrawable rounded(int color, int radiusDp) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(color);
        g.setCornerRadius(dp(radiusDp));
        return g;
    }

    private String timeText() {
        String l = TelegyouStyle.label();
        return (l.length() > 0 ? l + "  " : "") + "12:30";
    }

    private View buildPage(Context context, int type) {
        FrameLayout page = new FrameLayout(context);
        LinearLayout bubble = new LinearLayout(context);
        bubble.setOrientation(LinearLayout.VERTICAL);
        bubble.setBackground(rounded(Theme.getColor(Theme.key_windowBackgroundWhite), 14));
        int textColor = Theme.getColor(Theme.key_windowBackgroundWhiteBlackText);
        int grayColor = Theme.getColor(Theme.key_windowBackgroundWhiteGrayText2);
        int blueColor = Theme.getColor(Theme.key_windowBackgroundWhiteBlueText4);
        TextView time = new TextView(context);
        time.setTextSize(12);

        if (type == 0) {
            bubble.setPadding(dp(12), dp(8), dp(12), dp(6));
            TextView text = new TextView(context);
            text.setText("Привет! Так будет выглядеть удалённое сообщение.");
            text.setTextSize(16);
            text.setTextColor(textColor);
            text.setMaxWidth(dp(230));
            bubble.addView(text, new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
            time.setTextColor(grayColor);
            LinearLayout.LayoutParams tp = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.END);
            bubble.addView(time, tp);
        } else if (type == 1) {
            bubble.setPadding(dp(12), dp(10), dp(12), dp(6));
            LinearLayout row = new LinearLayout(context);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setGravity(Gravity.CENTER_VERTICAL);
            TextView play = new TextView(context);
            play.setText("▶");
            play.setTextSize(16);
            play.setTextColor(Color.WHITE);
            play.setGravity(Gravity.CENTER);
            GradientDrawable oval = new GradientDrawable();
            oval.setShape(GradientDrawable.OVAL);
            oval.setColor(blueColor);
            play.setBackground(oval);
            row.addView(play, new LinearLayout.LayoutParams(dp(42), dp(42)));
            TextView wave = new TextView(context);
            wave.setText("▂▃▅▇▅▃▂▃▅▇▅▃▂▁▂▃");
            wave.setTextSize(16);
            wave.setTextColor(blueColor);
            LinearLayout.LayoutParams wp = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            wp.leftMargin = dp(10);
            row.addView(wave, wp);
            bubble.addView(row, new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
            time.setTextColor(grayColor);
            LinearLayout.LayoutParams tp = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.END);
            bubble.addView(time, tp);
        } else {
            bubble.setPadding(dp(4), dp(4), dp(4), dp(4));
            FrameLayout photo = new FrameLayout(context);
            GradientDrawable g = new GradientDrawable(GradientDrawable.Orientation.TL_BR,
                    new int[]{0xFF5B86E5, 0xFF36D1DC});
            g.setCornerRadius(dp(10));
            photo.setBackground(g);
            time.setTextColor(Color.WHITE);
            time.setPadding(dp(8), dp(3), dp(8), dp(3));
            time.setBackground(rounded(0x80000000, 10));
            FrameLayout.LayoutParams tp = new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT,
                    Gravity.BOTTOM | Gravity.END);
            tp.rightMargin = dp(6);
            tp.bottomMargin = dp(6);
            photo.addView(time, tp);
            bubble.addView(photo, new LinearLayout.LayoutParams(dp(220), dp(150)));
        }
        bubbles[type] = bubble;
        timeViews[type] = time;
        page.addView(bubble, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER));
        return page;
    }

    private void go(int to) {
        if (to < 0 || to > 2 || to == cur || animating || pager == null) {
            return;
        }
        animating = true;
        final View out = pages[cur];
        View in = pages[to];
        float w = pager.getWidth();
        float dir = to > cur ? 1f : -1f;
        in.setVisibility(View.VISIBLE);
        in.setTranslationX(dir * w);
        in.animate().translationX(0).setDuration(220).start();
        out.animate().translationX(-dir * w).setDuration(220).withEndAction(new Runnable() {
            @Override
            public void run() {
                out.setVisibility(View.GONE);
                out.setTranslationX(0);
                animating = false;
            }
        }).start();
        cur = to;
        updateTitle();
    }

    private void updateTitle() {
        pageTitle.setText(titles[cur] + "  (" + (cur + 1) + "/3)");
    }

    private void refresh() {
        for (int i = 0; i < 3; i++) {
            if (timeViews[i] != null) {
                timeViews[i].setText(timeText());
            }
            if (bubbles[i] != null) {
                bubbles[i].setAlpha(TelegyouStyle.dim());
            }
        }
        dimText.setText("Прозрачность: " + TelegyouStyle.dimPercent() + "%");
        int sel = TelegyouStyle.labelStyle();
        int blue = Theme.getColor(Theme.key_windowBackgroundWhiteBlueText4);
        int gray = Theme.getColor(Theme.key_windowBackgroundGray);
        int black = Theme.getColor(Theme.key_windowBackgroundWhiteBlackText);
        for (int i = 0; i < chips.size(); i++) {
            TextView c = chips.get(i);
            if (i == sel) {
                c.setBackground(rounded(blue, 16));
                c.setTextColor(Color.WHITE);
            } else {
                c.setBackground(rounded(gray, 16));
                c.setTextColor(black);
            }
        }
    }

    @Override
    public View createView(final Context context) {
        actionBar.setBackButtonImage(R.drawable.ic_ab_back);
        actionBar.setAllowOverlayTitle(true);
        actionBar.setTitle("Вид удалённых");
        actionBar.setActionBarMenuOnItemClick(new ActionBar.ActionBarMenuOnItemClick() {
            @Override
            public void onItemClick(int id) {
                if (id == -1) {
                    finishFragment();
                }
            }
        });

        FrameLayout frame = new FrameLayout(context);
        fragmentView = frame;
        frame.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundGray));

        ScrollView scroll = new ScrollView(context);
        LinearLayout col = new LinearLayout(context);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setPadding(dp(16), dp(16), dp(16), dp(24));
        scroll.addView(col, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        frame.addView(scroll, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        pageTitle = new TextView(context);
        pageTitle.setTextSize(16);
        pageTitle.setGravity(Gravity.CENTER);
        pageTitle.setTextColor(Theme.getColor(Theme.key_windowBackgroundWhiteBlackText));
        col.addView(pageTitle, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView hint = new TextView(context);
        hint.setText("Свайпай в стороны: сообщение, голосовое, фото");
        hint.setTextSize(13);
        hint.setGravity(Gravity.CENTER);
        hint.setTextColor(Theme.getColor(Theme.key_windowBackgroundWhiteGrayText2));
        LinearLayout.LayoutParams hp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        hp.bottomMargin = dp(10);
        col.addView(hint, hp);

        pager = new FrameLayout(context);
        pager.setBackground(rounded(0x1A808080, 18));
        for (int i = 0; i < 3; i++) {
            pages[i] = buildPage(context, i);
            pages[i].setVisibility(i == 0 ? View.VISIBLE : View.GONE);
            pager.addView(pages[i], new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        }
        pager.setOnTouchListener(new View.OnTouchListener() {
            private float downX;

            @Override
            public boolean onTouch(View v, MotionEvent e) {
                int a = e.getAction();
                if (a == MotionEvent.ACTION_DOWN) {
                    downX = e.getX();
                    v.getParent().requestDisallowInterceptTouchEvent(true);
                    return true;
                }
                if (a == MotionEvent.ACTION_UP) {
                    float dx = e.getX() - downX;
                    if (dx < -dp(50)) {
                        go(cur + 1);
                    } else if (dx > dp(50)) {
                        go(cur - 1);
                    }
                }
                return true;
            }
        });
        col.addView(pager, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(260)));

        dimText = new TextView(context);
        dimText.setTextSize(15);
        dimText.setTextColor(Theme.getColor(Theme.key_windowBackgroundWhiteBlackText));
        LinearLayout.LayoutParams dp1 = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        dp1.topMargin = dp(18);
        col.addView(dimText, dp1);

        SeekBar seek = new SeekBar(context);
        seek.setMax(90);
        seek.setProgress(TelegyouStyle.dimPercent() - 10);
        ColorStateList tint = ColorStateList.valueOf(Theme.getColor(Theme.key_windowBackgroundWhiteBlueText4));
        seek.setProgressTintList(tint);
        seek.setThumbTintList(tint);
        seek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar sb, int progress, boolean fromUser) {
                TelegyouStyle.setDimPercent(progress + 10);
                refresh();
            }

            @Override
            public void onStartTrackingTouch(SeekBar sb) {
            }

            @Override
            public void onStopTrackingTouch(SeekBar sb) {
            }
        });
        col.addView(seek, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView chipsTitle = new TextView(context);
        chipsTitle.setText("Пометка");
        chipsTitle.setTextSize(15);
        chipsTitle.setTextColor(Theme.getColor(Theme.key_windowBackgroundWhiteBlackText));
        LinearLayout.LayoutParams ct = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        ct.topMargin = dp(14);
        ct.bottomMargin = dp(8);
        col.addView(chipsTitle, ct);

        HorizontalScrollView hs = new HorizontalScrollView(context);
        hs.setHorizontalScrollBarEnabled(false);
        LinearLayout chipRow = new LinearLayout(context);
        chipRow.setOrientation(LinearLayout.HORIZONTAL);
        String[] names = TelegyouStyle.labelNames();
        for (int i = 0; i < names.length; i++) {
            final int idx = i;
            TextView c = new TextView(context);
            c.setText(names[i]);
            c.setTextSize(18);
            c.setGravity(Gravity.CENTER);
            c.setPadding(dp(16), dp(9), dp(16), dp(9));
            c.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    TelegyouStyle.setLabelStyle(idx);
                    refresh();
                }
            });
            LinearLayout.LayoutParams cp = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            cp.rightMargin = dp(8);
            chipRow.addView(c, cp);
            chips.add(c);
        }
        hs.addView(chipRow);
        col.addView(hs, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        updateTitle();
        refresh();
        return fragmentView;
    }
}
'''
open(B + "ui/TelegyouPreviewFragment.java", "w", encoding="ascii").write(to_ascii(frag))
print("zz-zzpreview: окно предпросмотра создано")

# ---------- 3) Настройки: вместо двух пунктов одна кнопка ----------
f = B + "ui/TelegyouSettingsFragment.java"
try:
    t = open(f, encoding="ascii", errors="replace").read()
except FileNotFoundError:
    print("WARNING zz-zzpreview: страница настроек не найдена")
    raise SystemExit(0)

if "TelegyouPreviewFragment" in t:
    print("zz-zzpreview: кнопка уже есть")
else:
    start_m = "final org.telegram.ui.Cells.TextSettingsCell labelCell"
    end_m = "keepBody.addView(dimWrap, full());"
    i = t.find(start_m)
    j = t.find(end_m)
    if i < 0 or j < 0 or j < i:
        print("WARNING zz-zzpreview: старые пункты не найдены, кнопка не добавлена")
    else:
        code = r'''final org.telegram.ui.Cells.TextSettingsCell previewCell = new org.telegram.ui.Cells.TextSettingsCell(context);
        previewCell.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
        previewCell.setTextAndValue("Вид удалённых сообщений", "Предпросмотр", false);
        previewCell.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                presentFragment(new TelegyouPreviewFragment());
            }
        });
        LinearLayout previewWrap = new LinearLayout(context);
        previewWrap.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
        LinearLayout.LayoutParams previewLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        previewLp.leftMargin = dp(18);
        previewWrap.addView(previewCell, previewLp);
        keepBody.addView(previewWrap, full());'''
        t = t[:i] + to_ascii(code) + t[j + len(end_m):]
        open(f, "w", encoding="ascii").write(t)
        print("zz-zzpreview: кнопка 'Вид удалённых сообщений' добавлена")
PY
