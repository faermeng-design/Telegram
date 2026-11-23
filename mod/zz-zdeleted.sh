#!/bin/bash
python3 - <<'PY'
import re

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

# 1) Хранилище стиля удалённых сообщений
style = '''package org.telegram.messenger;

import android.content.Context;
import android.content.SharedPreferences;

/** Telegyou: настройки вида удалённых сообщений. */
public class TelegyouStyle {

    public static boolean dimUsed = false;

    private static final String[] LABEL_TEXT = {
            "", "🗑 удалено", "удалено", "🗑", "❌ удалено", "👻 удалено"
    };
    private static final String[] LABEL_NAMES = {
            "Выключена", "🗑 удалено", "удалено", "🗑", "❌ удалено", "👻 удалено"
    };
    private static final float[] DIM = {1f, 0.85f, 0.7f, 0.5f};
    private static final String[] DIM_NAMES = {"Нет", "Слабое", "Среднее", "Сильное"};

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
        return LABEL_NAMES[labelStyle()];
    }

    public static String[] labelNames() {
        return LABEL_NAMES;
    }

    public static int dimLevel() {
        try {
            return clamp(prefs().getInt("dim", 0), DIM.length);
        } catch (Throwable t) {
            return 0;
        }
    }

    public static void setDimLevel(int v) {
        try {
            prefs().edit().putInt("dim", clamp(v, DIM.length)).apply();
        } catch (Throwable ignored) {
        }
    }

    public static float dim() {
        return DIM[dimLevel()];
    }

    public static String dimName() {
        return DIM_NAMES[dimLevel()];
    }

    public static String[] dimNames() {
        return DIM_NAMES;
    }
}
'''
open(B + "messenger/TelegyouStyle.java", "w", encoding="ascii").write(to_ascii(style))
print("Вид удалённых: хранилище стиля создано")

# 2) ChatMessageCell: пометка по выбранному стилю + затемнение
c = B + "ui/Cells/ChatMessageCell.java"
s = open(c, encoding="utf-8").read()
anchor = "timeTextWidth = timeWidth = (int) Math.ceil(Theme.chat_timePaint.measureText(currentTimeString, 0, currentTimeString == null ? 0 : currentTimeString.length()));"
if "TelegyouStyle.label()" in s:
    print("Вид удалённых: сообщение уже подключено")
elif s.count(anchor) != 1:
    print("WARNING: вид удалённых: место найдено раз:", s.count(anchor))
else:
    old = re.compile(r'try \{\n\s*if \(currentMessageObject != null && org\.telegram\.messenger\.GhostMode\.isDeleted\([^\n]*\n[^\n]*\n\s*\}\n\s*\} catch \(Throwable ignored\) \{\n\s*\}\n\s*(?=timeTextWidth = timeWidth)')
    s, removed = old.subn("", s, count=1)
    block = '''try {
            boolean telegyouDeleted = currentMessageObject != null && org.telegram.messenger.GhostMode.isDeleted(currentMessageObject.getChannelId(), currentMessageObject.getId());
            if (telegyouDeleted) {
                String telegyouLabel = org.telegram.messenger.TelegyouStyle.label();
                if (telegyouLabel.length() > 0) {
                    currentTimeString = TextUtils.concat(telegyouLabel + "  ", currentTimeString == null ? "" : currentTimeString);
                }
                float telegyouDim = org.telegram.messenger.TelegyouStyle.dim();
                if (telegyouDim < 1f) {
                    org.telegram.messenger.TelegyouStyle.dimUsed = true;
                }
                setAlpha(telegyouDim);
            } else if (org.telegram.messenger.TelegyouStyle.dimUsed) {
                setAlpha(1f);
            }
        } catch (Throwable ignored) {
        }
        '''
    s = s.replace(anchor, to_ascii(block) + anchor, 1)
    open(c, "w", encoding="utf-8").write(s)
    print("Вид удалённых: сообщение подключено (старый блок убран:", removed, ")")

# 3) Настройки: два пункта внутри "Сохранять удалённые"
f = B + "ui/TelegyouSettingsFragment.java"
try:
    t = open(f, encoding="ascii", errors="replace").read()
except FileNotFoundError:
    print("WARNING: страница настроек не найдена (нужен zz-menu.sh)")
    raise SystemExit(0)
if "TelegyouStyle" in t:
    print("Вид удалённых: пункты в настройках уже есть")
else:
    a1 = "keepBody.addView(indented(context, burnCell), full());"
    a2 = "keepBody.addView(soon, full());"
    anchor = a1 if a1 in t else (a2 if a2 in t else None)
    if anchor is None:
        print("WARNING: вид удалённых: место в настройках не найдено")
    else:
        code = '''
        final org.telegram.ui.Cells.TextSettingsCell labelCell = new org.telegram.ui.Cells.TextSettingsCell(context);
        labelCell.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
        labelCell.setTextAndValue("Пометка удалённых", org.telegram.messenger.TelegyouStyle.labelName(), true);
        labelCell.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                org.telegram.ui.ActionBar.AlertDialog.Builder b = new org.telegram.ui.ActionBar.AlertDialog.Builder(context);
                b.setTitle("Пометка удалённых");
                b.setItems(org.telegram.messenger.TelegyouStyle.labelNames(), (dlg, which) -> {
                    org.telegram.messenger.TelegyouStyle.setLabelStyle(which);
                    labelCell.setTextAndValue("Пометка удалённых", org.telegram.messenger.TelegyouStyle.labelName(), true);
                });
                b.show();
            }
        });
        LinearLayout labelWrap = new LinearLayout(context);
        labelWrap.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
        LinearLayout.LayoutParams labelLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        labelLp.leftMargin = dp(18);
        labelWrap.addView(labelCell, labelLp);
        keepBody.addView(labelWrap, full());

        final org.telegram.ui.Cells.TextSettingsCell dimCell = new org.telegram.ui.Cells.TextSettingsCell(context);
        dimCell.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
        dimCell.setTextAndValue("Затемнение удалённых", org.telegram.messenger.TelegyouStyle.dimName(), false);
        dimCell.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                org.telegram.ui.ActionBar.AlertDialog.Builder b = new org.telegram.ui.ActionBar.AlertDialog.Builder(context);
                b.setTitle("Затемнение удалённых");
                b.setItems(org.telegram.messenger.TelegyouStyle.dimNames(), (dlg, which) -> {
                    org.telegram.messenger.TelegyouStyle.setDimLevel(which);
                    dimCell.setTextAndValue("Затемнение удалённых", org.telegram.messenger.TelegyouStyle.dimName(), false);
                });
                b.show();
            }
        });
        LinearLayout dimWrap = new LinearLayout(context);
        dimWrap.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundWhite));
        LinearLayout.LayoutParams dimLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        dimLp.leftMargin = dp(18);
        dimWrap.addView(dimCell, dimLp);
        keepBody.addView(dimWrap, full());'''
        t = t.replace(anchor, anchor + to_ascii(code), 1)
        open(f, "w", encoding="ascii").write(t)
        print("Вид удалённых: пункты в настройках добавлены")
PY
