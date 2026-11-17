#!/bin/bash
echo "=== ПРОВЕРКА 5 НАЧАЛО ==="
F="TMessagesProj/src/main/java/org/telegram/ui/LauncherIconController.java"
grep -n "enum\|LauncherIcon(\|DEFAULT\|VINTAGE\|AQUA\|PREMIUM\|TURBO\|NOX\|isPremium" "$F" | head -40 || true
sed -n '114,126p' TMessagesProj/src/main/AndroidManifest.xml || true
echo "=== ПРОВЕРКА 5 КОНЕЦ ==="
