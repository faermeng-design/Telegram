#!/bin/bash
python3 - <<'PY'
p = "TMessagesProj/src/main/java/org/telegram/ui/Cells/ChatMessageCell.java"
s = open(p, encoding="utf-8").read()
anchor = "timeTextWidth = timeWidth = (int) Math.ceil(Theme.chat_timePaint.measureText(currentTimeString, 0, currentTimeString == null ? 0 : currentTimeString.length()));"
if "GhostMode.isDeleted" in s:
    print("Удалённые (дизайн): уже подключено")
elif s.count(anchor) != 1:
    print("WARNING: удалённые (дизайн): место найдено раз:", s.count(anchor))
else:
    add = r'''try {
            if (currentMessageObject != null && org.telegram.messenger.GhostMode.isDeleted(currentMessageObject.getChannelId(), currentMessageObject.getId())) {
                currentTimeString = TextUtils.concat("\uD83D\uDDD1 \u0443\u0434\u0430\u043b\u0435\u043d\u043e  ", currentTimeString == null ? "" : currentTimeString);
            }
        } catch (Throwable ignored) {
        }
        '''
    s = s.replace(anchor, add + anchor, 1)
    open(p, "w", encoding="utf-8").write(s)
    print("Удалённые (дизайн): пометка добавлена")
PY
