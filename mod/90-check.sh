#!/bin/bash
echo "=== ПРОВЕРКА ИКОНОК НАЧАЛО ==="
grep -n "activity-alias" TMessagesProj*/src/main/AndroidManifest.xml | head -20 || true
grep -rln "LauncherIconController" TMessagesProj/src/main/java | head -5 || true
ls TMessagesProj*/src/*/res/mipmap-xxxhdpi 2>/dev/null | head -40 || true
echo "=== ПРОВЕРКА ИКОНОК КОНЕЦ ==="
