#!/bin/bash
python3 - <<'PY'
import os, re

MSG = "TMessagesProj/src/main/java/org/telegram/messenger/BadgeManager.java"
PRO = None
for root, dirs, files in os.walk("TMessagesProj/src/main/java/org/telegram/ui"):
    if "ProfileActivity.java" in files:
        PRO = os.path.join(root, "ProfileActivity.java")
        break

# ---------- BadgeManager ----------
s = open(MSG, encoding="ascii", errors="replace").read()
if "animFiles" in s:
    print("zz-zzzanim: BadgeManager already patched")
else:
    ok = True
    A_FIELD = "private static volatile Map<String, String> infos = new HashMap<>();"
    A_NEWINFOS = "Map<String, String> newInfos = new HashMap<>();"
    A_INFO = 'String info = o.optString("info", "");'
    A_ICONS = "icons = newIcons;"
    A_DRAW = "Drawable d = new BitmapDrawable(ApplicationLoader.applicationContext.getResources(), bmp);"
    loop_re = re.compile(r"ok = true;\s*for \(Map\.Entry<String, String> e : images\.entrySet\(\)\) \{")
    for a in (A_FIELD, A_NEWINFOS, A_INFO, A_ICONS, A_DRAW):
        if a not in s:
            print("WARNING zz-zzzanim: anchor not found: " + a)
            ok = False
    if not loop_re.search(s):
        print("WARNING zz-zzzanim: download loop not found")
        ok = False
    if ok:
        s = s.replace(A_FIELD, A_FIELD + """
    private static volatile Map<String, String> animFiles = new HashMap<>();
    private static volatile Map<String, Integer> animFps = new HashMap<>();
    private static final Map<String, Bitmap> sheets = new HashMap<>();
    public static volatile boolean animating = false;""", 1)
        s = s.replace(A_NEWINFOS, A_NEWINFOS + """
            Map<String, String> newAnims = new HashMap<>();
            Map<String, Integer> newFps = new HashMap<>();""", 1)
        s = s.replace(A_INFO, """String anim = o.optString("anim", "");
                        if (anim.length() > 0) {
                            newAnims.put(k, anim);
                            newFps.put(k, o.optInt("fps", 15));
                        }
                        """ + A_INFO, 1)
        s = s.replace(A_ICONS, "animFiles = newAnims;\n            animFps = newFps;\n            " + A_ICONS, 1)
        s = s.replace(A_DRAW, "Drawable d = makeDrawable(e.getKey(), bmp);", 1)

        def add_loop(m):
            return """ok = true;
                        for (Map.Entry<String, String> ae : animFiles.entrySet()) {
                            if (download(BASE_URL + ae.getValue(), animFile(ae.getKey()))) {
                                synchronized (sheets) {
                                    sheets.remove(ae.getKey());
                                }
                            }
                        }
                        for (Map.Entry<String, String> e : images.entrySet()) {"""
        s = loop_re.sub(add_loop, s, count=1)

        methods = """
    private static File animFile(String name) {
        return new File(ApplicationLoader.applicationContext.getFilesDir(), "telegyou_badge_" + name + "_anim.png");
    }

    private static Bitmap sheetOf(String name) {
        synchronized (sheets) {
            Bitmap b = sheets.get(name);
            if (b != null) {
                return b;
            }
            File f = animFile(name);
            if (!f.exists()) {
                return null;
            }
            b = BitmapFactory.decodeFile(f.getPath());
            if (b != null && b.getHeight() > 0 && b.getWidth() >= b.getHeight() * 2) {
                sheets.put(name, b);
                return b;
            }
            return null;
        }
    }

    public static boolean isAnimated(long id) {
        try {
            String b = badgeOf(id);
            return b != null && animFiles.containsKey(b) && sheetOf(b) != null;
        } catch (Throwable t) {
            return false;
        }
    }

    private static Drawable makeDrawable(String name, Bitmap staticBmp) {
        try {
            if (animFiles.containsKey(name)) {
                Bitmap sheet = sheetOf(name);
                if (sheet != null) {
                    Integer fps = animFps.get(name);
                    return new SheetDrawable(sheet, fps == null ? 15 : fps.intValue());
                }
            }
        } catch (Throwable ignored) {
        }
        return new BitmapDrawable(ApplicationLoader.applicationContext.getResources(), staticBmp);
    }

    private static class SheetDrawable extends Drawable {
        private final Bitmap sheet;
        private final int frames;
        private final int fw;
        private final int frameMs;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
        private final android.graphics.Rect src = new android.graphics.Rect();

        SheetDrawable(Bitmap sheet, int fps) {
            this.sheet = sheet;
            this.fw = sheet.getHeight();
            this.frames = Math.max(1, sheet.getWidth() / this.fw);
            this.frameMs = 1000 / (fps < 1 ? 1 : fps);
        }

        @Override
        public void draw(android.graphics.Canvas canvas) {
            int idx = 0;
            if (animating) {
                idx = (int) ((android.os.SystemClock.uptimeMillis() / frameMs) % frames);
            }
            src.set(idx * fw, 0, (idx + 1) * fw, fw);
            canvas.drawBitmap(sheet, src, getBounds(), paint);
        }

        @Override
        public void setAlpha(int a) {
            paint.setAlpha(a);
        }

        @Override
        public void setColorFilter(android.graphics.ColorFilter cf) {
            paint.setColorFilter(cf);
        }

        @Override
        public int getOpacity() {
            return android.graphics.PixelFormat.TRANSLUCENT;
        }
    }
"""
        i = s.rstrip().rfind("}")
        s = s[:i] + methods + "}\n"
        open(MSG, "w", encoding="ascii").write(s)
        print("zz-zzzanim: BadgeManager patched")

# ---------- ProfileActivity: перерисовка имени, пока идёт анимация ----------
if not PRO:
    print("WARNING zz-zzzanim: ProfileActivity.java not found")
else:
    p = open(PRO, encoding="utf-8").read()
    if "telegyouTick" in p:
        print("zz-zzzanim: ProfileActivity already patched")
    else:
        i = p.find("nameTextView = new SimpleTextView(context)")
        anchor = "nameTextView.setFocusable(true);"
        j = p.find(anchor, i) if i >= 0 else -1
        if i < 0 or j < 0 or j - i > 6000:
            print("WARNING zz-zzzanim: nameTextView anchor not found")
        else:
            k = j + len(anchor)
            code = """
        nameTextView.addOnAttachStateChangeListener(new android.view.View.OnAttachStateChangeListener() {
            private final Runnable telegyouTick = new Runnable() {
                @Override
                public void run() {
                    if (org.telegram.messenger.BadgeManager.isAnimated(userId != 0 ? userId : -chatId)) {
                        org.telegram.messenger.BadgeManager.animating = true;
                        nameTextView.invalidate();
                        nameTextView.postDelayed(this, 66);
                    } else {
                        org.telegram.messenger.BadgeManager.animating = false;
                        nameTextView.postDelayed(this, 1000);
                    }
                }
            };

            @Override
            public void onViewAttachedToWindow(android.view.View v) {
                v.removeCallbacks(telegyouTick);
                v.post(telegyouTick);
            }

            @Override
            public void onViewDetachedFromWindow(android.view.View v) {
                v.removeCallbacks(telegyouTick);
                org.telegram.messenger.BadgeManager.animating = false;
            }
        });"""
            p = p[:k] + code + p[k:]
            open(PRO, "w", encoding="utf-8").write(p)
            print("zz-zzzanim: ProfileActivity patched")
PY
