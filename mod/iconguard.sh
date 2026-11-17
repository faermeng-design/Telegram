#!/bin/bash
ROOT="TMessagesProj/src/main/java/org/telegram/messenger"

cat > "$ROOT/IconGuard.java" <<'JAVA'
package org.telegram.messenger;

import android.content.ComponentName;
import android.content.Context;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;

/** Telegyou: если все иконки Telegram выключены, включает стандартную. */
public class IconGuard {
    public static void ensureDefault(Context ctx) {
        try {
            PackageManager pm = ctx.getPackageManager();
            String pkg = ctx.getPackageName();
            PackageInfo pi = pm.getPackageInfo(pkg,
                    PackageManager.GET_ACTIVITIES | PackageManager.MATCH_DISABLED_COMPONENTS);
            boolean anyEnabled = false;
            if (pi.activities != null) {
                for (ActivityInfo ai : pi.activities) {
                    if (ai.targetActivity == null || !ai.targetActivity.endsWith("LaunchActivity")) {
                        continue;
                    }
                    int st = pm.getComponentEnabledSetting(new ComponentName(pkg, ai.name));
                    if (st == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                            || (st == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && ai.enabled)) {
                        anyEnabled = true;
                    }
                }
            }
            if (!anyEnabled) {
                pm.setComponentEnabledSetting(
                        new ComponentName(pkg, "org.telegram.messenger.DefaultIcon"),
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        PackageManager.DONT_KILL_APP);
            }
        } catch (Throwable ignored) {
        }
    }
}
JAVA

G="$ROOT/GhostMode.java"
if [ -f "$G" ]; then
  python3 - <<'PY'
p = "TMessagesProj/src/main/java/org/telegram/messenger/GhostMode.java"
s = open(p, encoding="ascii").read()
if "IconGuard" in s:
    print("IconGuard: уже подключён")
elif "appContext = context;" in s:
    s = s.replace("appContext = context;", "appContext = context;\n        IconGuard.ensureDefault(context);", 1)
    open(p, "w", encoding="ascii").write(s)
    print("IconGuard: подключён")
else:
    print("WARNING: не нашёл место в GhostMode.java")
PY
else
  echo "WARNING: GhostMode.java ещё нет, IconGuard не подключён (скрипт iconguard.sh запускается слишком рано)"
fi
