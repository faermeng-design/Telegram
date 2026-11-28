#!/bin/bash
python3 - <<'PY'
import os, re

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

# ---------- 1) Хранилище архива ----------
store = r'''package org.telegram.messenger;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;
import org.telegram.tgnet.TLRPC;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class TelegyouArchive {

    public static class Entry {
        public long dialogId;
        public int id;
        public long date;
        public String from = "";
        public String type = "text";
        public String text = "";
        public String file = "";
    }

    private static final ExecutorService IO = Executors.newSingleThreadExecutor();
    private static final Object LOCK = new Object();
    private static final Set<String> known = new HashSet<>();
    private static Set<String> cleared = null;

    private static SharedPreferences prefs() {
        return ApplicationLoader.applicationContext.getSharedPreferences("telegyou_archive", Context.MODE_PRIVATE);
    }

    private static File dir() {
        File d = new File(ApplicationLoader.applicationContext.getFilesDir(), "telegyou_archive");
        d.mkdirs();
        return d;
    }

    private static File jsonFile(long dialogId) {
        return new File(dir(), dialogId + ".json");
    }

    public static int mode() {
        try {
            return prefs().getInt("mode", 0);
        } catch (Throwable t) {
            return 0;
        }
    }

    public static void setMode(int m) {
        try {
            prefs().edit().putInt("mode", m).apply();
        } catch (Throwable ignored) {
        }
    }

    public static String[] modeNames() {
        return new String[]{"Всё", "Только фото", "Фото и видео", "Сообщения и фото"};
    }

    private static boolean allowed(String type) {
        switch (mode()) {
            case 1:
                return type.equals("photo");
            case 2:
                return type.equals("photo") || type.equals("video");
            case 3:
                return type.equals("text") || type.equals("photo");
            default:
                return true;
        }
    }

    private static Set<String> clearedSet() {
        if (cleared == null) {
            cleared = new HashSet<>();
            try {
                Set<String> s = prefs().getStringSet("cleared", null);
                if (s != null) {
                    cleared.addAll(s);
                }
            } catch (Throwable ignored) {
            }
        }
        return cleared;
    }

    private static ArrayList<Entry> read(long dialogId) {
        ArrayList<Entry> r = new ArrayList<>();
        try {
            File f = jsonFile(dialogId);
            if (!f.exists()) {
                return r;
            }
            BufferedReader br = new BufferedReader(new InputStreamReader(new FileInputStream(f), "UTF-8"));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) {
                sb.append(line).append('\n');
            }
            br.close();
            JSONArray a = new JSONArray(sb.toString());
            for (int i = 0; i < a.length(); i++) {
                JSONObject o = a.getJSONObject(i);
                Entry e = new Entry();
                e.dialogId = dialogId;
                e.id = o.optInt("id");
                e.date = o.optLong("date");
                e.from = o.optString("from", "");
                e.type = o.optString("type", "text");
                e.text = o.optString("text", "");
                e.file = o.optString("file", "");
                r.add(e);
            }
        } catch (Throwable ignored) {
        }
        return r;
    }

    private static void write(long dialogId, ArrayList<Entry> list) {
        try {
            JSONArray a = new JSONArray();
            for (Entry e : list) {
                JSONObject o = new JSONObject();
                o.put("id", e.id);
                o.put("date", e.date);
                o.put("from", e.from);
                o.put("type", e.type);
                o.put("text", e.text);
                o.put("file", e.file);
                a.put(o);
            }
            FileOutputStream out = new FileOutputStream(jsonFile(dialogId));
            out.write(a.toString().getBytes("UTF-8"));
            out.close();
        } catch (Throwable ignored) {
        }
    }

    private static String copyFile(File src, File dst) {
        try {
            InputStream in = new FileInputStream(src);
            OutputStream out = new FileOutputStream(dst);
            byte[] buf = new byte[8192];
            int r;
            while ((r = in.read(buf)) > 0) {
                out.write(buf, 0, r);
            }
            out.close();
            in.close();
            return dst.getPath();
        } catch (Throwable t) {
            return "";
        }
    }

    public static ArrayList<Entry> list(long dialogId) {
        synchronized (LOCK) {
            return read(dialogId);
        }
    }

    public static void clear(long dialogId) {
        synchronized (LOCK) {
            ArrayList<Entry> list = read(dialogId);
            Set<String> cs = clearedSet();
            for (Entry e : list) {
                cs.add(dialogId + "_" + e.id);
                try {
                    if (e.file != null && e.file.length() > 0) {
                        new File(e.file).delete();
                    }
                } catch (Throwable ignored) {
                }
            }
            try {
                jsonFile(dialogId).delete();
                prefs().edit().putStringSet("cleared", new HashSet<>(cs)).apply();
            } catch (Throwable ignored) {
            }
        }
    }

    public static void capture(MessageObject m) {
        try {
            if (m == null || m.messageOwner == null) {
                return;
            }
            if (!GhostMode.isDeleted(m.getChannelId(), m.getId())) {
                return;
            }
            final long dialogId = m.getDialogId();
            if (dialogId == 0) {
                return;
            }
            final String key = dialogId + "_" + m.getId();
            if (known.contains(key)) {
                return;
            }
            String type;
            if (m.isPhoto()) {
                type = "photo";
            } else if (m.isVideo() || m.isRoundVideo()) {
                type = "video";
            } else if (m.isVoice()) {
                type = "voice";
            } else if (m.messageOwner.message != null && m.messageOwner.message.length() > 0) {
                type = "text";
            } else {
                type = "other";
            }
            if (!allowed(type)) {
                return;
            }
            known.add(key);
            synchronized (LOCK) {
                if (clearedSet().contains(key)) {
                    return;
                }
            }
            String text = m.messageOwner.message == null ? "" : m.messageOwner.message;
            if (text.length() == 0 && type.equals("other") && m.messageText != null) {
                text = m.messageText.toString();
            }
            String from = "";
            try {
                if (m.isOutOwner()) {
                    from = "Я";
                } else {
                    TLRPC.User u = MessagesController.getInstance(UserConfig.selectedAccount).getUser(m.getFromChatId());
                    if (u != null && u.first_name != null) {
                        from = u.first_name;
                    }
                }
            } catch (Throwable ignored) {
            }
            File src = null;
            if (type.equals("photo")) {
                try {
                    src = FileLoader.getInstance(UserConfig.selectedAccount).getPathToMessage(m.messageOwner);
                } catch (Throwable ignored) {
                }
            }
            final Entry e = new Entry();
            e.dialogId = dialogId;
            e.id = m.getId();
            e.date = m.messageOwner.date;
            e.from = from;
            e.type = type;
            e.text = text;
            final File srcFinal = src;
            IO.execute(new Runnable() {
                @Override
                public void run() {
                    synchronized (LOCK) {
                        ArrayList<Entry> list = read(dialogId);
                        for (Entry x : list) {
                            if (x.id == e.id) {
                                return;
                            }
                        }
                        if (srcFinal != null && srcFinal.exists()) {
                            e.file = copyFile(srcFinal, new File(dir(), dialogId + "_" + e.id + ".jpg"));
                        }
                        list.add(e);
                        write(dialogId, list);
                    }
                }
            });
        } catch (Throwable ignored) {
        }
    }
}
'''
open(B + "messenger/TelegyouArchive.java", "w", encoding="ascii").write(to_ascii(store))
print("zz-zzarchive: хранилище создано")

# ---------- 2) Окно архива ----------
frag = r'''package org.telegram.ui;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import org.telegram.messenger.AndroidUtilities;
import org.telegram.messenger.R;
import org.telegram.messenger.TelegyouArchive;
import org.telegram.ui.ActionBar.ActionBar;
import org.telegram.ui.ActionBar.ActionBarMenu;
import org.telegram.ui.ActionBar.ActionBarMenuItem;
import org.telegram.ui.ActionBar.AlertDialog;
import org.telegram.ui.ActionBar.BaseFragment;
import org.telegram.ui.ActionBar.Theme;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.Locale;

public class TelegyouArchiveFragment extends BaseFragment {

    private final long dialogId;
    private Context ctx;
    private LinearLayout list;

    public TelegyouArchiveFragment(long dialogId) {
        super();
        this.dialogId = dialogId;
    }

    private int dp(int v) {
        return AndroidUtilities.dp(v);
    }

    private GradientDrawable rounded(int color, int radiusDp) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(color);
        g.setCornerRadius(dp(radiusDp));
        return g;
    }

    private void showSettings() {
        AlertDialog.Builder b = new AlertDialog.Builder(ctx);
        b.setTitle("Что сохранять");
        String[] names = TelegyouArchive.modeNames();
        int cur = TelegyouArchive.mode();
        CharSequence[] items = new CharSequence[names.length];
        for (int i = 0; i < names.length; i++) {
            items[i] = (i == cur ? "✓ " : "") + names[i];
        }
        b.setItems(items, new android.content.DialogInterface.OnClickListener() {
            @Override
            public void onClick(android.content.DialogInterface dlg, int which) {
                TelegyouArchive.setMode(which);
                refresh();
            }
        });
        b.show();
    }

    private void confirmClear() {
        AlertDialog.Builder b = new AlertDialog.Builder(ctx);
        b.setTitle("Очистить архив?");
        b.setMessage("Все сохранённые удалённые сообщения этого чата будут стёрты с телефона.");
        b.setPositiveButton("Очистить", new AlertDialog.OnButtonClickListener() {
            @Override
            public void onClick(AlertDialog dialog, int which) {
                TelegyouArchive.clear(dialogId);
                refresh();
            }
        });
        b.setNegativeButton("Отмена", null);
        b.show();
    }

    private String typeLabel(String t) {
        if ("photo".equals(t)) {
            return "📷 Фото";
        }
        if ("video".equals(t)) {
            return "🎬 Видео";
        }
        if ("voice".equals(t)) {
            return "🎤 Голосовое";
        }
        if ("other".equals(t)) {
            return "📎 Вложение";
        }
        return "";
    }

    private void refresh() {
        if (list == null) {
            return;
        }
        list.removeAllViews();
        ArrayList<TelegyouArchive.Entry> es = TelegyouArchive.list(dialogId);
        int gray = Theme.getColor(Theme.key_windowBackgroundWhiteGrayText2);
        int black = Theme.getColor(Theme.key_windowBackgroundWhiteBlackText);

        TextView head = new TextView(ctx);
        head.setTextSize(13);
        head.setTextColor(gray);
        head.setText("Сохранено: " + es.size() + "   •   Что сохранять: " + TelegyouArchive.modeNames()[TelegyouArchive.mode()]);
        LinearLayout.LayoutParams hp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        hp.bottomMargin = dp(10);
        list.addView(head, hp);

        if (es.isEmpty()) {
            TextView empty = new TextView(ctx);
            empty.setTextSize(15);
            empty.setTextColor(gray);
            empty.setGravity(Gravity.CENTER);
            empty.setText("Архив пуст.\nСообщения попадут сюда, когда собеседник их удалит.");
            LinearLayout.LayoutParams ep = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            ep.topMargin = dp(60);
            list.addView(empty, ep);
            return;
        }

        SimpleDateFormat fmt = new SimpleDateFormat("dd.MM.yyyy HH:mm", Locale.getDefault());
        for (int k = es.size() - 1; k >= 0; k--) {
            TelegyouArchive.Entry e = es.get(k);
            LinearLayout card = new LinearLayout(ctx);
            card.setOrientation(LinearLayout.VERTICAL);
            card.setBackground(rounded(Theme.getColor(Theme.key_windowBackgroundWhite), 12));
            card.setPadding(dp(12), dp(10), dp(12), dp(10));

            TextView meta = new TextView(ctx);
            meta.setTextSize(12);
            meta.setTextColor(gray);
            String who = (e.from == null || e.from.length() == 0) ? "" : e.from + "   ";
            meta.setText(who + fmt.format(new Date(e.date * 1000L)));
            card.addView(meta, new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));

            String tl = typeLabel(e.type);
            if (tl.length() > 0) {
                TextView tv = new TextView(ctx);
                tv.setTextSize(14);
                tv.setTextColor(black);
                tv.setText(tl);
                LinearLayout.LayoutParams tp = new LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
                tp.topMargin = dp(4);
                card.addView(tv, tp);
            }

            if (e.file != null && e.file.length() > 0 && new File(e.file).exists()) {
                try {
                    BitmapFactory.Options o = new BitmapFactory.Options();
                    o.inJustDecodeBounds = true;
                    BitmapFactory.decodeFile(e.file, o);
                    int sample = 1;
                    while (o.outWidth / sample > 800) {
                        sample *= 2;
                    }
                    o.inJustDecodeBounds = false;
                    o.inSampleSize = sample;
                    Bitmap bmp = BitmapFactory.decodeFile(e.file, o);
                    if (bmp != null) {
                        ImageView iv = new ImageView(ctx);
                        iv.setImageBitmap(bmp);
                        iv.setAdjustViewBounds(true);
                        iv.setMaxHeight(dp(320));
                        LinearLayout.LayoutParams ip = new LinearLayout.LayoutParams(
                                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
                        ip.topMargin = dp(6);
                        card.addView(iv, ip);
                    }
                } catch (Throwable ignored) {
                }
            }

            if (e.text != null && e.text.length() > 0) {
                TextView tx = new TextView(ctx);
                tx.setTextSize(16);
                tx.setTextColor(black);
                tx.setText(e.text);
                tx.setTextIsSelectable(true);
                LinearLayout.LayoutParams xp = new LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
                xp.topMargin = dp(6);
                card.addView(tx, xp);
            }

            LinearLayout.LayoutParams cp = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            cp.bottomMargin = dp(8);
            list.addView(card, cp);
        }
    }

    @Override
    public View createView(final Context context) {
        ctx = context;
        actionBar.setBackButtonImage(R.drawable.ic_ab_back);
        actionBar.setAllowOverlayTitle(true);
        actionBar.setTitle("Архив удаленок");

        ActionBarMenu menu = actionBar.createMenu();
        ActionBarMenuItem more = menu.addItem(0, R.drawable.ic_ab_other);
        more.addSubItem(1, R.drawable.msg_settings_old, "Настройки");
        more.addSubItem(2, R.drawable.msg_delete, "Очистить архив");

        actionBar.setActionBarMenuOnItemClick(new ActionBar.ActionBarMenuOnItemClick() {
            @Override
            public void onItemClick(int id) {
                if (id == -1) {
                    finishFragment();
                } else if (id == 1) {
                    showSettings();
                } else if (id == 2) {
                    confirmClear();
                }
            }
        });

        FrameLayout frame = new FrameLayout(context);
        fragmentView = frame;
        frame.setBackgroundColor(Theme.getColor(Theme.key_windowBackgroundGray));

        ScrollView scroll = new ScrollView(context);
        list = new LinearLayout(context);
        list.setOrientation(LinearLayout.VERTICAL);
        list.setPadding(dp(12), dp(12), dp(12), dp(24));
        scroll.addView(list, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        frame.addView(scroll, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        refresh();
        AndroidUtilities.runOnUIThread(new Runnable() {
            @Override
            public void run() {
                refresh();
            }
        }, 700);
        return fragmentView;
    }

    @Override
    public void onResume() {
        super.onResume();
        refresh();
    }
}
'''
open(B + "ui/TelegyouArchiveFragment.java", "w", encoding="ascii").write(to_ascii(frag))
print("zz-zzarchive: окно архива создано")

# ---------- 3) ChatMessageCell: ловим удалённые при показе ----------
cell = B + "ui/Cells/ChatMessageCell.java"
try:
   c = open(cell, encoding="utf-8").read()
    if "TelegyouArchive.capture" in c:
        print("zz-zzarchive: ChatMessageCell уже пропатчен")
    else:
        a = "String telegyouLabel = org.telegram.messenger.TelegyouStyle.label();"
        if a not in c:
            print("WARNING zz-zzarchive: якорь в ChatMessageCell не найден (архив будет ловить только при открытии чата)")
        else:
            c = c.replace(a, "org.telegram.messenger.TelegyouArchive.capture(currentMessageObject);\n                " + a, 1)
           open(cell, "w", encoding="utf-8").write(c)
            print("zz-zzarchive: ChatMessageCell пропатчен")
except FileNotFoundError:
    print("WARNING zz-zzarchive: ChatMessageCell.java не найден")

# ---------- 4) ChatActivity: пункт меню, нажатие, ловля при открытии ----------
chat = B + "ui/ChatActivity.java"
try:
    s = open(chat, encoding="utf-8").read()
except FileNotFoundError:
    print("WARNING zz-zzarchive: ChatActivity.java не найден")
    raise SystemExit(0)

if "7788" in s:
    print("zz-zzarchive: ChatActivity уже пропатчен")
else:
    changed = False

    # 4a) пункт меню
    mk = "headerItem = menu.addItem(chat_menu_options, otherIcon);"
    sv = "menu.setVisibility(inMenuMode ? View.GONE : View.VISIBLE);"
    m = s.rfind(mk)
    j = s.find(sv, m) if m >= 0 else -1
    if m < 0 or j < 0:
        print("WARNING zz-zzarchive: место для пункта меню не найдено")
    else:
        item = to_ascii('''try {
            if (headerItem != null && chatMode == 0 && dialog_id != 0) {
                headerItem.lazilyAddSubItem(7788, R.drawable.msg_delete, "Архив удаленок");
            }
        } catch (Throwable ignored) {
        }
        ''')
        s = s[:j] + item + s[j:]
        changed = True

    # 4b) нажатие на пункт
    ck = "} else if (id == clear_history || id == delete_chat || id == auto_delete_timer) {"
    if ck not in s:
        print("WARNING zz-zzarchive: обработчик нажатий не найден, пункт меню работать не будет")
    else:
        click = """} else if (id == 7788) {
                    try {
                        for (int gi = 0; gi < messages.size(); gi++) {
                            org.telegram.messenger.TelegyouArchive.capture(messages.get(gi));
                        }
                    } catch (Throwable ignored) {
                    }
                    presentFragment(new TelegyouArchiveFragment(dialog_id));
                """
        s = s.replace(ck, click + ck, 1)
        changed = True

    # 4c) ловим удалённые при открытии чата
    rk = "public void onResume() {"
    if rk not in s:
        print("WARNING zz-zzarchive: onResume не найден")
    else:
        res = """public void onResume() {
        try {
            for (int gi = 0; gi < messages.size(); gi++) {
                org.telegram.messenger.TelegyouArchive.capture(messages.get(gi));
            }
        } catch (Throwable ignored) {
        }"""
        s = s.replace(rk, res, 1)
        changed = True

    if changed:
        open(chat, "w", encoding="utf-8").write(s)
        print("zz-zzarchive: ChatActivity пропатчен")
PY
