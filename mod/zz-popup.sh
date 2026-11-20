#!/bin/bash
set -e
python3 - <<'PY'
import os, re

MSG = "TMessagesProj/src/main/java/org/telegram/messenger/"
UI = "TMessagesProj/src/main/java/org/telegram/ui/"

# --- 1) BadgeManager: проверка попадания по значку и окошко с пояснением
p = MSG + "BadgeManager.java"
s = open(p, encoding="ascii", errors="replace").read()
if "hitBadge" in s:
    print("BadgeManager: окошко уже добавлено")
elif not os.path.exists(p):
    print("WARNING: BadgeManager.java не найден")
else:
    if "import org.telegram.ui.ActionBar.AlertDialog;" not in s:
        s = s.replace("import android.content.Context;",
                      "import android.content.Context;\nimport org.telegram.ui.ActionBar.AlertDialog;", 1)
    method = '''
    /** True if the tap hit the badge in the name (and the badge has an info text). */
    public static boolean hitBadge(long userId, CharSequence text, Paint paint, float x, int paddingLeft) {
        try {
            String badge = badgeOf(userId);
            if (badge == null || text == null || paint == null || infoOf(badge).length() == 0) {
                return false;
            }
            String icon = icons.get(badge);
            if (icon == null || icon.length() == 0) {
                return false;
            }
            String str = text.toString();
            int start = str.lastIndexOf(icon);
            if (start < 0) {
                return false;
            }
            int end = start + icon.length();
            float x0 = paddingLeft + paint.measureText(str, 0, start);
            float x1 = paddingLeft + paint.measureText(str, 0, end);
            float tol = AndroidUtilities.dp(24);
            return x >= x0 - tol && x <= x1 + tol;
        } catch (Throwable t) {
            return false;
        }
    }

    /** Dialog that explains who gets this badge. */
    public static void showInfo(Context ctx, long userId) {
        try {
            String badge = badgeOf(userId);
            if (badge == null) {
                return;
            }
            String info = infoOf(badge);
            if (info.length() == 0) {
                return;
            }
            AlertDialog.Builder builder = new AlertDialog.Builder(ctx);
            builder.setTitle(iconOf(badge) + " " + labelOf(badge));
            builder.setMessage(info);
            builder.setPositiveButton("OK", null);
            builder.show();
        } catch (Throwable ignored) {
        }
    }
'''
    i = s.rstrip().rfind("}")
    s = s[:i] + method + "}\n"
    open(p, "w", encoding="ascii").write(s)
    print("BadgeManager: окошко добавлено")

# --- 2) ProfileActivity: нажатие на значок в имени открывает окошко
p = UI + "ProfileActivity.java"
s = open(p, encoding="utf-8").read()
if "BadgeManager.hitBadge" in s:
    print("ProfileActivity: уже подключено")
else:
    i = s.find("nameTextView = new SimpleTextView(context)")
    j = s.find("nameTextView.setFocusable(true);", i) if i >= 0 else -1
    if i < 0 or j < 0 or j - i > 6000:
        print("WARNING: не нашёл создание nameTextView в ProfileActivity")
    else:
        k = j + len("nameTextView.setFocusable(true);")
        code = '''
        nameTextView.setOnTouchListener(new android.view.View.OnTouchListener() {
            private boolean telegyouDown;
            @Override
            public boolean onTouch(android.view.View telegyouView, android.view.MotionEvent telegyouEvent) {
                int telegyouAction = telegyouEvent.getAction();
                if (telegyouAction == android.view.MotionEvent.ACTION_DOWN) {
                    telegyouDown = org.telegram.messenger.BadgeManager.hitBadge(userId, nameTextView.getText(), nameTextView.getPaint(), telegyouEvent.getX(), nameTextView.getPaddingLeft());
                    return telegyouDown;
                }
                if (telegyouDown) {
                    if (telegyouAction == android.view.MotionEvent.ACTION_UP) {
                        org.telegram.messenger.BadgeManager.showInfo(telegyouView.getContext(), userId);
                    }
                    if (telegyouAction == android.view.MotionEvent.ACTION_UP || telegyouAction == android.view.MotionEvent.ACTION_CANCEL) {
                        telegyouDown = false;
                    }
                    return true;
                }
                return false;
            }
        });'''
        s = s[:k] + code + s[k:]
        open(p, "w", encoding="utf-8").write(s)
        print("ProfileActivity: нажатие на значок подключено")
PY
