#!/bin/bash
echo "=== ПРОВЕРКА 7 НАЧАЛО ==="
J="TMessagesProj/src/main/java/org/telegram/ui"
R="TMessagesProj/src/main/res"
echo "--- картинки intro ---"
ls $R/drawable-nodpi 2>/dev/null | grep -i "intro\|plane" | head -20 || true
ls $R/drawable-xxhdpi 2>/dev/null | grep -i "intro" | head -10 || true
echo "--- IntroActivity ---"
grep -n "R.drawable\|R.raw\|loadTexture" $J/IntroActivity.java | head -30 || true
echo "--- LoginActivity ---"
grep -n "R.drawable.ic_\|R.raw\|RLottieImageView\|setImageResource" $J/LoginActivity.java | head -20 || true
echo "=== ПРОВЕРКА 7 КОНЕЦ ==="
