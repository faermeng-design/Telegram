#!/bin/bash
python3 - <<'PY'
import os, re, json, copy

NEW = "com.telegyou.app"

# 1) APP_PACKAGE в gradle.properties
done = False
for p in ["gradle.properties", "TMessagesProj_App/gradle.properties", "TMessagesProj/gradle.properties"]:
    if not os.path.exists(p):
        continue
    s = open(p, encoding="utf-8").read()
    if re.search(r'^APP_PACKAGE\s*=', s, re.M):
        s2 = re.sub(r'^APP_PACKAGE\s*=.*$', "APP_PACKAGE=" + NEW, s, count=1, flags=re.M)
        open(p, "w", encoding="utf-8").write(s2)
        print("zz-zzzzpkg: APP_PACKAGE =", NEW, "в", p)
        done = True
        break
if not done:
    print("WARNING zz-zzzzpkg: APP_PACKAGE не найден в gradle.properties")

# 2) google-services.json: добавляем клиентов с новым именем
found = False
for root, dirs, files in os.walk("."):
    dirs[:] = [d for d in dirs if d not in (".git", "build", "node_modules", ".gradle")]
    if "google-services.json" not in files:
        continue
    p = os.path.join(root, "google-services.json")
    found = True
    try:
        data = json.load(open(p, encoding="utf-8"))
        clients = data.get("client", [])
        have = set()
        for c in clients:
            have.add(c.get("client_info", {}).get("android_client_info", {}).get("package_name"))
        if not clients:
            print("WARNING zz-zzzzpkg: пустой список client в", p)
            continue
        added = 0
        for suf in ["", ".beta", ".web"]:
            name = NEW + suf
            if name in have:
                continue
            c = copy.deepcopy(clients[0])
            c["client_info"]["android_client_info"]["package_name"] = name
            clients.append(c)
            added += 1
        data["client"] = clients
        json.dump(data, open(p, "w", encoding="utf-8"), indent=2)
        print("zz-zzzzpkg: google-services.json обновлён:", p, ", добавлено =", added)
    except Exception as e:
        print("WARNING zz-zzzzpkg: не удалось обработать", p, e)
if not found:
    print("WARNING zz-zzzzpkg: google-services.json не найден")
PY
