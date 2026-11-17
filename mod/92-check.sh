#!/bin/bash
echo "=== ПРОВЕРКА 6 НАЧАЛО ==="
F="TMessagesProj/src/main/java/org/telegram/ui/SettingsActivity.java"
grep -n "7777\|Telegyou" "$F" || echo "ВКЛАДКИ В ФАЙЛЕ НЕТ"
N=$(grep -n "7777" "$F" | head -1 | cut -d: -f1)
if [ -n "$N" ]; then sed -n "$((N-6)),$((N+4))p" "$F"; fi
echo "=== ПРОВЕРКА 6 КОНЕЦ ==="
