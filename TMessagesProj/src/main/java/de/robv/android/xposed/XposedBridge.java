package de.robv.android.xposed;

import java.lang.reflect.Constructor;
import java.lang.reflect.Member;
import java.lang.reflect.Method;

/** Temporary compile-time stub (not exteraGram code). */
public final class XposedBridge {
    private XposedBridge() {
    }

    public static void disableProfileSaver() {
    }

    public static Object invokeOriginalMethod(Member method, Object thisObject, Object[] args) throws Throwable {
        if (method instanceof Method) {
            ((Method) method).setAccessible(true);
            return ((Method) method).invoke(thisObject, args);
        }
        if (method instanceof Constructor) {
            ((Constructor<?>) method).setAccessible(true);
            return ((Constructor<?>) method).newInstance(args);
        }
        throw new IllegalArgumentException("Unsupported member: " + method);
    }
}
