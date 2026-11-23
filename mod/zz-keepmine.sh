#!/bin/bash
python3 - <<'PY'
import re
B = "TMessagesProj/src/main/java/org/telegram/"

# 1) GhostMode: флаг "оставить у меня" на одно удаление
g = B + "messenger/GhostMode.java"
s = open(g, encoding="ascii").read()
if "takeKeepMine" in s:
    print("Оставить у меня: GhostMode уже готов")
else:
    add = """
    private static boolean keepMineFlag = false;

    public static synchronized void setKeepMine(boolean value) {
        keepMineFlag = value;
    }

    public static synchronized boolean takeKeepMine() {
        boolean r = keepMineFlag;
        keepMineFlag = false;
        return r;
    }
"""
    i = s.rindex("}")
    open(g, "w", encoding="ascii").write(s[:i] + add + "}\n")
    print("Оставить у меня: GhostMode дополнен")

# 2) MessagesController: удаляем у собеседника, у себя оставляем с пометкой
m = B + "messenger/MessagesController.java"
t = open(m, encoding="utf-8").read()
sig = "public void deleteMessages(ArrayList<Integer> messages, ArrayList<Long> randoms, TLRPC.EncryptedChat encryptedChat, long dialogId, boolean forAll, int mode, boolean cacheOnly, long taskId, TLObject taskRequest, int topicId, boolean movedToScheduled, int movedToScheduledMessageId) {"
if "keepmine:delete" in t:
    print("Оставить у меня: MessagesController уже готов")
elif sig not in t:
    print("WARNING: оставить у меня: главная deleteMessages не найдена")
else:
    code = r'''
        boolean telegyouKeep = GhostMode.takeKeepMine(); // keepmine:delete
        if (telegyouKeep && taskId == 0 && forAll && !cacheOnly && encryptedChat == null && messages != null && !messages.isEmpty()
                && mode != ChatActivity.MODE_SCHEDULED && mode != ChatActivity.MODE_QUICK_REPLIES && mode != ChatActivity.MODE_WELCOME_MESSAGES) {
            long telegyouChannelId = 0;
            TLRPC.Chat telegyouChat = null;
            if (dialogId != 0 && DialogObject.isChatDialog(dialogId)) {
                telegyouChat = getChat(-dialogId);
                telegyouChannelId = ChatObject.isChannel(telegyouChat) ? telegyouChat.id : 0;
            }
            ArrayList<Integer> telegyouIds = new ArrayList<>();
            for (int gi = 0; gi < messages.size(); gi++) {
                Integer gm = messages.get(gi);
                if (gm != null && gm > 0) {
                    telegyouIds.add(gm);
                    GhostMode.markDeleted(telegyouChannelId, gm);
                }
            }
            if (!telegyouIds.isEmpty()) {
                if (telegyouChannelId != 0) {
                    TLRPC.TL_channels_deleteMessages telegyouReq = new TLRPC.TL_channels_deleteMessages();
                    telegyouReq.channel = getInputChannel(telegyouChat);
                    telegyouReq.id = telegyouIds;
                    getConnectionsManager().sendRequest(telegyouReq, (response, error) -> {
                    });
                } else {
                    TLRPC.TL_messages_deleteMessages telegyouReq = new TLRPC.TL_messages_deleteMessages();
                    telegyouReq.id = telegyouIds;
                    telegyouReq.revoke = true;
                    getConnectionsManager().sendRequest(telegyouReq, (response, error) -> {
                        if (error == null) {
                            TLRPC.TL_messages_affectedMessages res = (TLRPC.TL_messages_affectedMessages) response;
                            processNewDifferenceParams(-1, res.pts, -1, res.pts_count);
                        }
                    });
                }
            }
            return;
        }'''
    t = t.replace(sig, sig + code, 1)
    open(m, "w", encoding="utf-8").write(t)
    print("Оставить у меня: MessagesController подключён")

# 3) AlertsCreator: галочка "Оставить у меня" в окне удаления
a = B + "ui/Components/AlertsCreator.java"
u = open(a, encoding="utf-8").read()
if "keepMine" in u:
    print("Оставить у меня: окно удаления уже готово")
else:
    pat = re.compile(r'final boolean\[\] deleteForAll = new boolean\[1\];(\s+)boolean canRevokeInbox')
    mm = pat.search(u)
    if not mm:
        print("WARNING: оставить у меня: окно удаления не найдено")
    else:
        u = u[:mm.start()] + "final boolean[] deleteForAll = new boolean[1];\n        final boolean[] keepMine = new boolean[1];" + mm.group(1) + "boolean canRevokeInbox" + u[mm.end():]
        end = u.find("AlertDialog.OnButtonClickListener deleteAction", mm.start())
        head, region, tail = u[:mm.start()], u[mm.start():end], u[end:]
        cell_code = r'''final CheckBoxCell keepCell = new CheckBoxCell(activity, 1, resourcesProvider);
                keepCell.setBackgroundDrawable(Theme.getSelectorDrawable(false));
                keepCell.setText("\u041e\u0441\u0442\u0430\u0432\u0438\u0442\u044c \u0443 \u043c\u0435\u043d\u044f", "", false, false);
                keepCell.setPadding(LocaleController.isRTL ? dp(16) : dp(8), 0, LocaleController.isRTL ? dp(8) : dp(16), 0);
                frameLayout.addView(keepCell, LayoutHelper.createFrame(LayoutHelper.MATCH_PARENT, 48, Gravity.TOP | Gravity.LEFT, 0, 48, 0, 0));
                keepCell.setOnClickListener(v -> {
                    CheckBoxCell keepBox = (CheckBoxCell) v;
                    keepMine[0] = !keepMine[0];
                    keepBox.setChecked(keepMine[0], true);
                });
                '''
        region, n = re.subn(r'builder\.setView\(frameLayout\);(\s*)builder\.setCustomViewOffset\(9\);',
                            lambda x: cell_code + "builder.setView(frameLayout);" + x.group(1) + "builder.setCustomViewOffset(9);", region)
        call1 = "MessagesController.getInstance(currentAccount).deleteMessages(ids, random_ids, encryptedChat, thisDialogId, topicId, deleteForAll[0], mode);"
        call2 = "MessagesController.getInstance(currentAccount).deleteMessages(ids, random_ids, encryptedChat, (a == 1 && mergeDialogId != 0) ? mergeDialogId : thisDialogId, topicId, deleteForAll[0], mode);"
        flag = "org.telegram.messenger.GhostMode.setKeepMine(keepMine[0] && deleteForAll[0]);\n                    "
        c = 0
        for call in (call1, call2):
            if call in tail:
                tail = tail.replace(call, flag + call)
                c += 1
        u = head + region + tail
        open(a, "w", encoding="utf-8").write(u)
        print("Оставить у меня: галочек добавлено =", n, ", вызовов удаления =", c)
PY
