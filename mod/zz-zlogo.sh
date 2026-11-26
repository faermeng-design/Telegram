#!/bin/bash
python3 - <<'PY'
import os

target = None
for root, dirs, files in os.walk("."):
    if "DialogStoriesCell.java" in files and "Stories" in root:
        target = os.path.join(root, "DialogStoriesCell.java")
        break

if not target:
    print("WARNING zz-zlogo: DialogStoriesCell.java not found")
else:
    s = open(target, encoding="utf-8").read()
    if "TELEGYOU_LOGO" in s:
        print("zz-zlogo: already patched")
    else:
        old = "telegramLogoView.setImageResource(R.drawable.telegram_logo_2);"
        new = """telegramLogoView.setImageDrawable(new android.graphics.drawable.Drawable() {
            // TELEGYOU_LOGO
            private final android.graphics.Paint tgyPaint = new android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG);
            {
                tgyPaint.setColor(0xFFFFFFFF);
                tgyPaint.setTypeface(AndroidUtilities.bold());
                tgyPaint.setTextSize(dp(20));
            }
            @Override
            public void draw(android.graphics.Canvas canvas) {
                android.graphics.Rect b = getBounds();
                float y = b.centerY() - (tgyPaint.ascent() + tgyPaint.descent()) / 2f;
                canvas.drawText("Telegyou", b.left, y, tgyPaint);
            }
            @Override
            public void setAlpha(int alpha) {
                tgyPaint.setAlpha(alpha);
                invalidateSelf();
            }
            @Override
            public void setColorFilter(android.graphics.ColorFilter cf) {
                tgyPaint.setColorFilter(cf);
                invalidateSelf();
            }
            @Override
            public int getOpacity() {
                return android.graphics.PixelFormat.TRANSLUCENT;
            }
            @Override
            public int getIntrinsicWidth() {
                return dp(90);
            }
            @Override
            public int getIntrinsicHeight() {
                return dp(22);
            }
        });"""
        if old not in s:
            print("WARNING zz-zlogo: anchor not found")
        else:
            s = s.replace(old, new, 1)
            open(target, "w", encoding="utf-8").write(s)
            print("zz-zlogo: patched")
PY
