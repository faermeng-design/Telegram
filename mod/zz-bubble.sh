#!/bin/bash
python3 - <<'PY'
import re
p = "TMessagesProj/src/main/java/org/telegram/messenger/BadgeManager.java"
s = open(p, encoding="ascii", errors="replace").read()
if "telegyou_bubble" in s:
    print("Плашка значка: уже подключена")
else:
    pat = re.compile(r'(/\*\*[^\n]*\*/\s*)?public static void showInfo\(Context ctx, long userId\) \{.*?\n    \}\n', re.S)
    new = r'''/** Bubble from the bottom: badge icon + text, hides after 2 seconds. */
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
            Context c = ctx;
            while (c instanceof android.content.ContextWrapper && !(c instanceof android.app.Activity)) {
                c = ((android.content.ContextWrapper) c).getBaseContext();
            }
            if (!(c instanceof android.app.Activity)) {
                return;
            }
            final android.app.Activity activity = (android.app.Activity) c;
            final android.view.ViewGroup root = (android.view.ViewGroup) activity.findViewById(android.R.id.content);
            if (root == null) {
                return;
            }
            android.view.View previous = root.findViewWithTag("telegyou_bubble");
            if (previous != null) {
                previous.animate().cancel();
                root.removeView(previous);
            }
            final android.widget.LinearLayout bubble = new android.widget.LinearLayout(activity);
            bubble.setTag("telegyou_bubble");
            bubble.setOrientation(android.widget.LinearLayout.HORIZONTAL);
            bubble.setGravity(android.view.Gravity.CENTER_VERTICAL);
            android.graphics.drawable.GradientDrawable bg = new android.graphics.drawable.GradientDrawable();
            bg.setColor(0xEE2B2B30);
            bg.setCornerRadius(AndroidUtilities.dp(20));
            bubble.setBackground(bg);
            bubble.setPadding(AndroidUtilities.dp(14), AndroidUtilities.dp(10), AndroidUtilities.dp(18), AndroidUtilities.dp(10));
            Bitmap bmp = images.containsKey(badge) ? bitmapOf(badge) : null;
            if (bmp != null) {
                android.widget.ImageView icon = new android.widget.ImageView(activity);
                icon.setImageBitmap(bmp);
                bubble.addView(icon, new android.widget.LinearLayout.LayoutParams(AndroidUtilities.dp(32), AndroidUtilities.dp(32)));
            } else {
                android.widget.TextView emoji = new android.widget.TextView(activity);
                emoji.setText(iconOf(badge));
                emoji.setTextSize(24);
                bubble.addView(emoji);
            }
            android.widget.TextView text = new android.widget.TextView(activity);
            text.setText(info);
            text.setTextColor(0xFFFFFFFF);
            text.setTextSize(15);
            text.setMaxLines(3);
            android.widget.LinearLayout.LayoutParams tp = new android.widget.LinearLayout.LayoutParams(android.view.ViewGroup.LayoutParams.WRAP_CONTENT, android.view.ViewGroup.LayoutParams.WRAP_CONTENT);
            tp.leftMargin = AndroidUtilities.dp(12);
            bubble.addView(text, tp);
            android.widget.FrameLayout.LayoutParams lp = new android.widget.FrameLayout.LayoutParams(android.view.ViewGroup.LayoutParams.WRAP_CONTENT, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, android.view.Gravity.BOTTOM | android.view.Gravity.CENTER_HORIZONTAL);
            lp.bottomMargin = AndroidUtilities.dp(96);
            lp.leftMargin = AndroidUtilities.dp(16);
            lp.rightMargin = AndroidUtilities.dp(16);
            root.addView(bubble, lp);
            final float offset = AndroidUtilities.dp(220);
            bubble.setTranslationY(offset);
            bubble.setAlpha(0f);
            bubble.animate().translationY(0f).alpha(1f).setDuration(250).start();
            bubble.postDelayed(new Runnable() {
                @Override
                public void run() {
                    bubble.animate().translationY(offset).alpha(0f).setDuration(250).withEndAction(new Runnable() {
                        @Override
                        public void run() {
                            if (bubble.getParent() == root) {
                                root.removeView(bubble);
                            }
                        }
                    }).start();
                }
            }, 2250);
        } catch (Throwable ignored) {
        }
    }
'''
    if not pat.search(s):
        print("WARNING: плашка значка: showInfo не найдена")
    else:
        s = pat.sub(lambda m: new, s, count=1)
        open(p, "w", encoding="ascii").write(s)
        print("Плашка значка: подключена (снизу, 2 секунды)")
PY
