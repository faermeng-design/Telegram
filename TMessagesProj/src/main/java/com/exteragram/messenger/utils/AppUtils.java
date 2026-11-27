package com.exteragram.messenger.utils;

import org.telegram.messenger.FileLog;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.ArrayList;

/** Minimal replacement for the exteraGram helper of the same name. */
public class AppUtils {
    public static void log(Throwable t) {
        FileLog.e(t);
    }

    public static void log(String message) {
        FileLog.d(message);
    }

    public static void log(String message, Throwable t) {
        FileLog.e(message, t);
    }

    public static String stackTraceToString(Throwable t) {
        StringWriter sw = new StringWriter();
        t.printStackTrace(new PrintWriter(sw));
        return sw.toString();
    }

    public static boolean compareVersions(String operator, String a, String b) {
        int c = compare(a, b);
        if (operator == null) {
            return c == 0;
        }
        switch (operator.trim()) {
            case ">":
                return c > 0;
            case ">=":
                return c >= 0;
            case "<":
                return c < 0;
            case "<=":
                return c <= 0;
            case "!=":
                return c != 0;
            default:
                return c == 0;
        }
    }

    private static int compare(String a, String b) {
        int[] x = parse(a);
        int[] y = parse(b);
        int n = Math.max(x.length, y.length);
        for (int i = 0; i < n; i++) {
            int p = i < x.length ? x[i] : 0;
            int q = i < y.length ? y[i] : 0;
            if (p != q) {
                return p < q ? -1 : 1;
            }
        }
        return 0;
    }

    private static int[] parse(String v) {
        ArrayList<Integer> out = new ArrayList<>();
        if (v != null) {
            for (String s : v.trim().split("[^0-9]+")) {
                if (!s.isEmpty()) {
                    try {
                        out.add(Integer.parseInt(s));
                    } catch (NumberFormatException ignored) {
                    }
                }
            }
        }
        int[] r = new int[out.size()];
        for (int i = 0; i < r.length; i++) {
            r[i] = out.get(i);
        }
        return r;
    }

    public static int getBuildVersionCode() {
        try {
            android.content.Context c = org.telegram.messenger.ApplicationLoader.applicationContext;
            android.content.pm.PackageInfo info = c.getPackageManager().getPackageInfo(c.getPackageName(), 0);
            return (int) androidx.core.content.pm.PackageInfoCompat.getLongVersionCode(info);
        } catch (Throwable t) {
            return 0;
        }
    }

    public static boolean compareVersions(String operator, int a, int b) {
        return compareVersions(operator, String.valueOf(a), String.valueOf(b));
    }
}
