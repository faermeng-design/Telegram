#!/usr/bin/env python3
# Анализ: что нужно из exteraGram для переноса ядра плагинов. Ничего не меняет в проекте.
import os, re, sys
from pathlib import Path
from collections import Counter, defaultdict

EX = Path("extera")
OUR_JAVA = Path("TMessagesProj/src/main/java")
OUR_RES = sorted(Path("TMessagesProj/src").glob("main/res*"))
PLUG = "com/exteragram/messenger/plugins/"
OPTIONAL = [PLUG + d + "/" for d in ("analyzer", "catalog", "pip", "updates")]
SKIP = ("android.", "androidx.", "java.", "javax.", "kotlin.", "kotlinx.", "dalvik.",
        "org.json", "com.exteragram.", "org.w3c", "org.xml", "libcore.", "sun.")

out = []
def P(*a):
    s = " ".join(str(x) for x in a)
    out.append(s)
    print(s)

files = {}
_text = {}
def text(rel):
    if rel not in _text:
        _text[rel] = Path(files[rel]).read_text(encoding="utf-8", errors="ignore")
    return _text[rel]
def L(rel):
    return text(rel).count("\n") + 1

roots = [p for p in (EX / "TMessagesProj/src").glob("*/java") if p.is_dir()]
roots.sort(key=lambda r: {"full": 0, "main": 1}.get(r.parent.name, 2))
for root in roots:
    for p in root.rglob("*"):
        if p.is_file() and p.suffix in (".kt", ".java"):
            rel = p.relative_to(root).as_posix()
            if rel.startswith("com/exteragram/"):
                files.setdefault(rel, p)
if not files:
    print("ОШИБКА: исходники exteraGram не найдены")
    sys.exit(1)
siblings = defaultdict(list)
for rel in files:
    siblings[os.path.dirname(rel)].append(rel)

IMPORT = re.compile(r'^\s*import\s+(?:static\s+)?([\w.]+?)(?:\.\*)?(?:\s+as\s+\w+)?\s*;?\s*$', re.M)
WILD = re.compile(r'^\s*import\s+(com\.exteragram[\w.]*)\.\*', re.M)
RES_REF = re.compile(r'\bR\.(drawable|string|layout|raw|xml|color|dimen|style|id|attr|plurals|mipmap|anim|font|menu|array)\.([A-Za-z0-9_]+)')

def resolve(fqn):
    parts = fqn.split(".")
    for k in range(len(parts), 2, -1):
        base = "/".join(parts[:k])
        for ext in (".kt", ".java"):
            if base + ext in files:
                return [base + ext]
    pkg = "/".join(parts[:-1])
    name = parts[-1]
    pat = re.compile(r'\b(?:val|var|fun|class|object|interface|typealias|enum)\s+(?:<[^>]*>\s*)?(?:[\w.<>?, ]*\.)?' + re.escape(name) + r'\b')
    return [r for r in siblings.get(pkg, []) if pat.search(text(r))]

def closure(pred, skip):
    seeds = {r for r in files if pred(r)}
    seen = set(seeds)
    stack = list(seeds)
    unresolved, wild = set(), set()
    direct = defaultdict(set)
    while stack:
        rel = stack.pop()
        t = text(rel)
        deps = []
        for m in IMPORT.finditer(t):
            fqn = m.group(1)
            if fqn.startswith("com.exteragram."):
                r = resolve(fqn)
                if not r:
                    unresolved.add(fqn)
                deps += r
        for m in WILD.finditer(t):
            wild.add(m.group(1))
        for other in siblings[os.path.dirname(rel)]:
            if other != rel and re.search(r'\b' + re.escape(Path(other).stem) + r'\b', t):
                deps.append(other)
        for r in deps:
            if any(r.startswith(s) for s in skip):
                continue
            if rel in seeds and r not in seeds:
                direct[r].add(rel)
            if r not in seen:
                seen.add(r)
                stack.append(r)
    return seeds, seen, unresolved, wild, direct

def exists_ours(fqn):
    parts = fqn.split(".")
    for k in range(len(parts), 1, -1):
        base = OUR_JAVA / "/".join(parts[:k])
        if base.with_suffix(".java").exists() or base.with_suffix(".kt").exists():
            return True
    return False

seeds_min, seen_min, unres, wild, direct = closure(
    lambda r: r.startswith(PLUG) and not any(r.startswith(o) for o in OPTIONAL), OPTIONAL)
seeds_all, seen_all, _, _, _ = closure(lambda r: r.startswith(PLUG), [])

P("===== ИТОГ =====")
for label, seen in (("ЯДРО+UI (без analyzer/catalog/pip/updates)", seen_min), ("ВСЯ папка plugins", seen_all)):
    pl = [r for r in seen if r.startswith(PLUG)]
    ex = [r for r in seen if not r.startswith(PLUG)]
    P(label + ":")
    P("   файлов plugins =", len(pl), ", строк =", sum(L(r) for r in pl))
    P("   нужно внешних файлов из exteraGram =", len(ex), ", строк =", sum(L(r) for r in ex))

ext_min = [r for r in seen_min if not r.startswith(PLUG)]
P("\n===== Прямые зависимости ядра/UI (строк, файл, сколько файлов используют) =====")
for l, r, n in sorted(((L(r), r, len(i)) for r, i in direct.items()), reverse=True):
    P("%6d  %s  x%d" % (l, r, n))

by_dir, by_loc = Counter(), Counter()
for r in ext_min:
    d = os.path.dirname(r)
    by_dir[d] += 1
    by_loc[d] += L(r)
P("\n===== Весь внешний набор по папкам (файлов, строк) =====")
for d, c in by_dir.most_common(45):
    P("%4d %6d  %s" % (c, by_loc[d], d))

P("\n===== Не найдены в исходниках exteraGram =====")
for u in sorted(unres):
    P(u)
P("\n===== Импорты со звёздочкой =====")
for w in sorted(wild):
    P(w + ".*")

tp, miss_tg, res_refs, bc = Counter(), Counter(), Counter(), Counter()
for r in seen_min:
    t = text(r)
    for m in IMPORT.finditer(t):
        fqn = m.group(1)
        if fqn.startswith("org.telegram.") or fqn.startswith("me.vkryl."):
            if not exists_ours(fqn):
                miss_tg[fqn] += 1
        elif not fqn.startswith(SKIP):
            tp[".".join(fqn.split(".")[:3])] += 1
    for m in RES_REF.finditer(t):
        res_refs[(m.group(1), m.group(2))] += 1
    for m in re.finditer(r'BuildConfig\.(\w+)', t):
        bc[m.group(1)] += 1

P("\n===== Сторонние библиотеки (пакет, импортов) =====")
for k, c in tp.most_common(40):
    P("%4d  %s" % (c, k))

P("\n===== Классов Telegram нет в вашем проекте: %d =====" % len(miss_tg))
for k, c in miss_tg.most_common(120):
    P("%3d  %s" % (c, k))

have = set()
for rd in OUR_RES:
    for p in rd.rglob("*"):
        if p.is_file():
            have.add(p.name.split(".")[0])
            if p.suffix == ".xml" and p.parent.name.startswith("values"):
                for m in re.finditer(r'name="([^"]+)"', p.read_text(encoding="utf-8", errors="ignore")):
                    have.add(m.group(1).replace(".", "_"))
miss_res = sorted(k for k in res_refs if k[1] not in have)
bytype = Counter(k[0] for k in miss_res)
P("\n===== Ресурсов нет в вашем проекте: %d из %d =====" % (len(miss_res), len(res_refs)))
P("по типам:", dict(bytype))
for t_, n in miss_res[:150]:
    P("R.%s.%s" % (t_, n))

P("\n===== BuildConfig =====")
for k, c in bc.most_common():
    P("%3d  %s" % (c, k))

Path("analysis-report.txt").write_text("\n".join(out), encoding="utf-8")
