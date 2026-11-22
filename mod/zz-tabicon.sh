#!/bin/bash
mkdir -p TMessagesProj/src/main/res/drawable
cat > TMessagesProj/src/main/res/drawable/settings_telegyou.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M2.75,11.75 L21.5,4.25 L18.5,19.75 L13,16.75 L10,19.25 L10.4,15 L17.5,7.5 L8,13.75 Z" />
</vector>
XML
python3 - <<'PY'
import re
p = "TMessagesProj/src/main/java/org/telegram/ui/SettingsActivity.java"
s = open(p, encoding="utf-8").read()
pat = re.compile(r'(SettingCell\.Factory\.of\(7777,[^;]*?)R\.drawable\.settings_language')
if "R.drawable.settings_telegyou" in s:
    print("Иконка вкладки: уже заменена")
elif pat.search(s):
    s = pat.sub(r'\1R.drawable.settings_telegyou', s, count=1)
    open(p, "w", encoding="utf-8").write(s)
    print("Иконка вкладки Telegyou: заменена на самолётик")
else:
    print("WARNING: иконка вкладки: строка не найдена")
PY
