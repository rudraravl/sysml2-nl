#!/usr/bin/env python3
"""Analyses with no model calls; each writes its placeholder keys into placeholders.json.

  python ecir_v3/analyze.py a10          leakage (A10.leak.proto, A10.leak.dup)
  python ecir_v3/analyze.py a14          retrieval score vs. final validity under repair (A14.*)
  python ecir_v3/analyze.py stage1       R1, R1b, R2, R4, V, A2 (+ fig-selective.pdf), Table 1 Holm family
  python ecir_v3/analyze.py a1           Solidity error classes and the import mechanism (A1.*)
  python ecir_v3/analyze.py res          Solidity Stage 1 + A1 with library imports resolved (RES.*)
  python ecir_v3/analyze.py u2           label reliability (U2.agree, U2.kappa)
  python ecir_v3/analyze.py a13          pool evaluation, reranker CV, harm model, R7 gate (U1.*, A13.*)
  python ecir_v3/analyze.py r7           reranked vs deployed A1 on the held-out IDs (R7.*)
  python ecir_v3/analyze.py d7           served providers across the v3 runs (D7.providers)
  python ecir_v3/analyze.py switches     suggested outcome switches (SV decides)
  python ecir_v3/analyze.py all          everything whose inputs exist
"""
from __future__ import annotations

import collections
import json
import os
import re
import sys
from pathlib import Path

import numpy as np

from common import (LADDER_SOL, REPO, RUNS, WORK, placeholders_set, read_ids, read_jsonl, write_json)
import forge_ecir_tools as T

OUT = WORK / "analysis"
PAPER = WORK          # fig-selective.pdf sits next to ecirv3.tex, where \includegraphics looks
LNAME = {"sys": "SysML~v2", "sol": "Solidity", "mod": "Modelica"}   # as the .tex writes them
A0 = {"sys": RUNS / "R4/sys/A0/results.jsonl", "sol": RUNS / "ladder/sol/A0/results.jsonl",
      "mod": RUNS / "ladder/mod/A0/results.jsonl"}
A1 = {l: RUNS / f"ladder/{l}/A1/results.jsonl" for l in ("sys", "sol", "mod")}
ALT = {"sol": RUNS / "R1/sol/A1bm25/results.jsonl", "mod": RUNS / "R1b/mod/A1cos/results.jsonl"}
RAND = {l: RUNS / f"R2/{l}/A1rand/results.jsonl" for l in ("sys", "sol", "mod")}
# Solidity compile validity is scored with library imports resolved (sol_imports.py, README deviation 18);
# ECIR_SOL_SCORING=single restores v1's single-file verdicts.
_SFX = "" if os.getenv("ECIR_SOL_SCORING", "resolved") == "single" else "_res"
CV = {"sys": "compile_valid", "sol": "compile_valid" + _SFX, "mod": "compile_valid"}
NERR, ECLS = "n_compiler_errors" + _SFX, "compiler_error_classes" + _SFX   # Solidity only


def have(*ps):
    """Inputs exist and every v3 run among them finished all its jobs (run_meta.json "complete");
    a pilot (--limit) or a run stopped by the spend guard is not analysed."""
    for p in ps:
        p = Path(p)
        if not p.exists():
            return False
        meta = p.parent / "run_meta.json"
        if meta.exists():
            m = json.loads(meta.read_text())
            if not m.get("complete", True) or "--limit" in (m.get("argv") or []):
                return False
    return True


def r1(x):
    return f"{float(x):.1f}"


def pct(x):
    return f"{100 * x:.1f}"


def save(name, obj):
    write_json(OUT / f"{name}.json", obj)


# ---------------------------------------------------------------- A10 leakage
def _sol_tokens(code):
    code = re.sub(r"/\*.*?\*/", " ", code, flags=re.S)
    code = re.sub(r"//[^\n]*", " ", code)
    return re.findall(r"[A-Za-z_][A-Za-z0-9_]*|\d+|[^\sA-Za-z0-9_]", code)


def _grams(code, n=5):
    t = _sol_tokens(code)
    return {hash(tuple(t[i:i + n])) for i in range(len(t) - n + 1)}


_STOP = {"proxy", "token", "vault", "oracle", "wrapped", "world", "swap", "bridge", "stake", "finance",
         "protocol", "money", "market", "lending", "yield", "astro", "unit", "based", "arch", "rain",
         "save", "sign", "ample", "safe", "base", "core", "governor", "wise", "loop", "moon"}
_PLATFORM = re.compile(r"^(code4rena|sherlock|cyfrin codehawks|smart contract sanctuary)\b", re.I)


def _toks(s):
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", s)
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1 \2", s)
    out = []
    for t in re.split(r"[^A-Za-z0-9]+", s.lower()):
        if t:
            out.append(t[:-1] if len(t) > 3 and t.endswith("s") else t)
    return out


def _source_name_tokens(e):
    """Token lists of the exemplar's repository, organization, contest and contract names
    (audit-platform labels and '*-audit' orgs excluded: they name the platform, not the protocol)."""
    names = []
    for n in e.source_names:
        if n.startswith("http"):
            n = "/".join(n.rstrip("/").split("/")[-2:])
        n = _PLATFORM.sub("", n).strip(" :")
        for part in re.split(r"[/:]", n):
            part = re.sub(r"^\d{4}-\d{2}-", "", part.strip())    # contest slug date prefix
            if part and not part.endswith("-audit") and not _PLATFORM.match(part):
                names.append(_toks(part))
    return names


def _contains(seq, sub):
    """sub's tokens as a consecutive run in seq, or its concatenation equal to a run of 1-3 tokens
    (so 'RedStone' matches 'Redstone')."""
    if any(seq[i:i + len(sub)] == sub for i in range(len(seq) - len(sub) + 1)):
        return True
    j = "".join(sub)
    return any("".join(seq[i:i + w]) == j for w in (1, 2, 3) for i in range(len(seq) - w + 1))


def a10():
    from corpora import exemplars
    ex = exemplars("sol")
    seeds = [json.loads(l) for l in (REPO / "nl2solidity/sol_seed.jsonl").read_text().splitlines() if l.strip()]
    ladder = set(read_ids("ladder500_sol.txt"))
    srcs = [(e.id, _source_name_tokens(e)) for e in ex]
    matches = []
    for s in seeds:
        if s.get("provenance") != "defillama-harvest":
            continue
        pt = [t for t in _toks(s.get("source_title") or "") if not re.fullmatch(r"v\d+", t)]
        if not pt or (len(pt) == 1 and (len(pt[0]) < 4 or pt[0] in _STOP)):
            continue
        hit = [eid for eid, names in srcs if any(_contains(n, pt) for n in names)]
        if hit:
            matches.append({"req_id": s["id"], "protocol": s["source_title"], "in_ladder": s["id"] in ladder,
                            "exemplars": hit[:10], "n_exemplars": len(hit)})
    protos = {m["protocol"] for m in matches}
    # (ii) near-duplicates: token 5-gram Jaccard of generated A0/A1 programs vs every exemplar
    eg = [(e.id, _grams(e.code)) for e in ex]
    post = collections.defaultdict(list)
    for i, (_, g) in enumerate(eg):
        for h in g:
            post[h].append(i)
    dups = []
    n_prog = 0
    for arm in ("A0", "A1"):
        for f in sorted((LADDER_SOL / arm).glob("U*/U*.sol")):
            g = _grams(f.read_text(encoding="utf-8"))
            if not g:
                continue
            n_prog += 1
            cnt = collections.Counter()
            for h in g:
                for i in post.get(h, ()):
                    cnt[i] += 1
            best = max(((c / (len(g) + len(eg[i][1]) - c), eg[i][0]) for i, c in cnt.items()), default=(0, None))
            if best[0] >= 0.8:
                dups.append({"arm": arm, "req_id": f.stem, "exemplar": best[1], "jaccard": round(best[0], 3)})
    progs = {(d["arm"], d["req_id"]) for d in dups}
    save("A10_leakage", {"protocol_matches": matches, "n_protocols_matched": len(protos),
                         "n_protocols_matched_ladder500": len({m["protocol"] for m in matches if m["in_ladder"]}),
                         "near_duplicates": dups, "n_programs": n_prog, "n_programs_dup": len(progs),
                         "method": "protocol: DefiLlama source_title tokens (camel/punctuation split, lowercase, plural s "
                                   "dropped, version tokens dropped) found as a consecutive token run in an exemplar "
                                   "repository, organization, contest or contract name; single-token names need >= 4 "
                                   "chars and must not be generic (_STOP); audit-platform labels excluded. "
                                   "dup: comment-stripped token "
                                   "5-gram Jaccard >= 0.8 against any of the 1,500 exemplars"})
    placeholders_set({"A10.leak.proto": str(len(protos)), "A10.leak.dup": str(len(progs))}, "analyze.py a10")
    print(f"A10: {len(protos)} protocols match exemplar sources; {len(progs)}/{n_prog} programs near-duplicate")


# ---------------------------------------------------------------- A14
def _logit_or(y, x, groups=None):
    import statsmodels.api as sm
    import pandas as pd
    z = (x - x.mean()) / x.std()
    X = sm.add_constant(pd.DataFrame({"z": z}))
    kw = {"cov_type": "cluster", "cov_kwds": {"groups": groups}} if groups is not None else {}
    m = sm.Logit(y, X).fit(disp=0, **kw)
    ci = np.exp(m.conf_int().loc["z"])
    return float(np.exp(m.params["z"])), float(ci[0]), float(ci[1]), float(m.pvalues["z"]), len(y)


def a14():
    vals, rep = {}, {}
    for lang in ("sol", "mod"):
        rows = [r for r in read_jsonl(RUNS / f"ladder/{lang}/A3/results.jsonl")
                if r["status"] != "infra_error" and r["retrieval"]["scores"]]
        y = np.array([int(r[CV[lang]]) for r in rows])
        x = np.array([float(r["retrieval"]["scores"][0]) for r in rows])
        o, lo, hi, p, n = _logit_or(y, x)
        rep[lang] = {"n": n, "or_per_sd": o, "ci": [lo, hi], "p": p, "final_valid_rate": y.mean()}
        vals[f"A14.{lang}.or"] = f"{o:.2f}"
        vals[f"A14.{lang}.orci"] = f"{lo:.2f}, {hi:.2f}"
    save("A14_repair", rep)
    placeholders_set(vals, "analyze.py a14")
    print("A14:", vals)


# ---------------------------------------------------------------- Stage 1
def stage1():
    vals, rep, fam = {}, {}, []      # fam: Table 1 Holm family entries (label, raw p)

    for lang in ("sys", "sol", "mod"):
        def cmp(a, b, m=CV[lang], kind="rate"):
            return T.compare(str(a), str(b), m, kind)
        if have(A0[lang], A1[lang]):
            c = cmp(A0[lang], A1[lang]); rep[f"{lang}.A1_vs_A0"] = c; fam.append((f"{lang}.A1_vs_A0", c["p_raw"]))
        if lang in ALT and have(A0[lang], ALT[lang]):
            c = cmp(A0[lang], ALT[lang]); rep[f"{lang}.alt_vs_A0"] = c; fam.append((f"{lang}.alt_vs_A0", c["p_raw"]))
        if have(A1[lang], RAND[lang]):
            c = cmp(A1[lang], RAND[lang]); rep[f"{lang}.rand_vs_A1"] = c; fam.append((f"{lang}.rand_vs_A1", c["p_raw"]))
        if have(A0[lang], A1[lang]):
            s = T.selective(str(A0[lang]), str(A1[lang]), CV[lang])
            rep[f"{lang}.selective"] = s
            fam.append((f"{lang}.sel_vs_best", s["p_vs_best_fixed"]))
    adj = dict(zip([k for k, _ in fam], T.holm([p for _, p in fam])))
    rep["holm_family"] = {k: {"raw": p, "holm": adj[k]} for k, p in fam}
    rep["holm_family_size"] = len(fam)
    if len(fam) != 11:
        print(f"note: Table 1 family has {len(fam)} of 11 tests so far; Holm p-values change as runs finish")

    def P(k):
        return T.fmt_p(adj[k])

    if "sol.alt_vs_A0" in rep:
        c = rep["sol.alt_vs_A0"]
        vals.update({"R1.sol.cv": c["b_pct"], "R1.sol.d": c["delta_pp"], "R1.sol.p": P("sol.alt_vs_A0")})
        alt = read_jsonl(ALT["sol"])
        vals["R1.sol.err"] = f"{np.mean([r[NERR] for r in alt if r['status'] != 'infra_error']):.2f}"
    if "mod.alt_vs_A0" in rep:
        vals["R1b.mod.cv"] = rep["mod.alt_vs_A0"]["b_pct"]
    gaps = {}
    for lang in ("sys", "sol", "mod"):
        if f"{lang}.rand_vs_A1" in rep:
            c = rep[f"{lang}.rand_vs_A1"]
            vals[f"R2.{lang}.cv"] = c["b_pct"]
            gaps[lang] = (-float(c["delta_pp"]), adj[f"{lang}.rand_vs_A1"])    # A1 minus random
    if "sol.rand_vs_A1" in rep:
        rr = read_jsonl(RAND["sol"])
        vals["R2.sol.err"] = f"{np.mean([r[NERR] for r in rr if r['status'] != 'infra_error']):.2f}"
    if gaps:
        sig = [g for g, p in gaps.values() if p < 0.05 and g > 0]
        if sig:
            vals["R2.mingap"] = f"{min(sig):.1f}"
        vals["R2.maxgap"] = f"{max(abs(g) for g, _ in gaps.values()):.1f}"
        rep["R2_gaps_A1_minus_random"] = gaps
    if "sys.A1_vs_A0" in rep:
        vals["R4.sys.a0"] = rep["sys.A1_vs_A0"]["a_pct"]
        vals["R4.sys.p"] = P("sys.A1_vs_A0")
    for lang in ("sol", "mod"):
        if f"{lang}.A1_vs_A0" in rep:
            vals[f"V.p.{lang}"] = P(f"{lang}.A1_vs_A0")
    # A2: selective retrieval
    sel_sig = {}
    for lang in ("sys", "sol", "mod"):
        s = rep.get(f"{lang}.selective")
        if not s:
            continue
        vals[f"A2.{lang}.sel"] = s["selective_pct"]
        vals[f"A2.{lang}.orc"] = s["oracle_pct"]
        if adj[f"{lang}.sel_vs_best"] < 0.05 and float(s["delta_vs_best_fixed_pp"]) > 0:
            sel_sig[lang] = float(s["delta_vs_best_fixed_pp"])
    if sel_sig:
        best = max(sel_sig, key=sel_sig.get)
        s = rep[f"{best}.selective"]
        vals.update({"A2.sel.dsl": LNAME[best], "A2.sel.d": s["delta_vs_best_fixed_pp"],
                     "A2.sel.ci": s["ci_vs_best_fixed"], "A2.sel.p": P(f"{best}.sel_vs_best"),
                     "A2.recov": s["recovery_pct"]})
    sels = [rep[f"{l}.selective"] for l in ("sys", "sol", "mod") if f"{l}.selective" in rep]
    if sels:
        vals["A2.orcgap"] = f"{max(float(s['oracle_minus_best_fixed_pp']) for s in sels):.1f}"
    rep["Sel"] = bool(sel_sig)
    if have(A0["sol"], A1["sol"], A0["mod"], A1["mod"]):
        PAPER.mkdir(parents=True, exist_ok=True)
        T.curve(str(PAPER / "fig-selective.pdf"),
                [f"Solidity:{A0['sol']}:{A1['sol']}:{CV['sol']}", f"Modelica:{A0['mod']}:{A1['mod']}"])
    rep["family_complete"] = len(fam) == 11
    if len(fam) != 11:
        # Holm-adjusted values depend on the whole family: keep them out of placeholders.json until it is complete.
        held = [k for k in vals if k.endswith(".p") or k.startswith("V.p") or k.startswith("R2.mingap")
                or k.startswith("A2.sel.") or k == "A2.recov"]
        rep["held_back_until_family_complete"] = {k: vals.pop(k) for k in held}
    save("stage1", rep)
    placeholders_set(vals, "analyze.py stage1")
    print(json.dumps(vals, indent=1))


# ---------------------------------------------------------------- A1 error classes
def a1():
    from langs import ERR_CLASSES, ERR_NAMES
    arms = {"a0": A0["sol"], "a1": A1["sol"], "alt": ALT["sol"], "rand": RAND["sol"]}
    per = {}
    for arm, p in arms.items():
        rows = [r for r in read_jsonl(p) if r["status"] != "infra_error"] if have(p) else []
        if not rows:
            continue
        c = collections.Counter(x for r in rows for x in r.get(ECLS) or [])
        per[arm] = {k: c[k] / len(rows) for k in ERR_CLASSES}
        per[arm]["_n"] = len(rows)
    vals = {f"A1.{k}.{arm}": f"{v[k]:.2f}" for arm, v in per.items() for k in ERR_CLASSES}
    if "a0" in per and "a1" in per:
        inc = {k: per["a1"][k] - per["a0"][k] for k in ERR_CLASSES}
        tot = sum(inc.values())
        top = max(inc, key=inc.get)
        vals["A1.top.class"] = ERR_NAMES[top]
        vals["A1.top.share"] = f"{100 * inc[top] / tot:.1f}" if tot > 0 else "0.0"
        per["increase_a0_to_a1"] = inc
    save("A1_error_classes", per)
    placeholders_set(vals, "analyze.py a1")
    print(json.dumps(vals, indent=1))
    a1_imports(arms)


_IMPORT = re.compile(r"""^\s*import\s+[^;]*?["']([^"']+)["']""", re.M)


def _sol_program(path, rid):
    """Generated Solidity program behind a results.jsonl row (v1 ladder dir or a v3 run's outputs/)."""
    if path.parent.parent.parent.name == "ladder":          # runs/ladder/sol/<arm>/results.jsonl
        f = LADDER_SOL / path.parent.name / rid / f"{rid}.sol"
    else:
        f = path.parent / "outputs" / f"{rid}.sol"
    return f.read_text(encoding="utf-8") if f.exists() else ""


def a1_imports(arms):
    """Mechanism behind the Solidity A0->A1 loss: generated contracts copy a retrieved exemplar's import,
    and an import never compiles as a single file. Keys (no sentence is written; the TODO stays manual):
      A1.impshare.<arm>   % of contracts with an import statement
      A1.impvalid.<arm>   % of those that compile
      A1.impcopied.<arm>  % of importing contracts whose import path (or file name) is in a retrieved exemplar
      A1.impexset.<arm>   % of requirements whose retrieved set contains an importing exemplar"""
    from corpora import exemplar_index
    ix = exemplar_index("sol")
    vals, rep = {}, {}
    for arm, p in arms.items():
        p = Path(p)
        rows = [r for r in read_jsonl(p) if r["status"] != "infra_error"] if have(p) else []
        if not rows:
            continue
        n = len(rows)
        imp = valid = copied = exset = 0
        for r in rows:
            paths = _IMPORT.findall(_sol_program(p, r["req_id"]))
            ex = r["retrieval"]["exemplar_ids"]
            ex_paths = {q for x in ex for q in _IMPORT.findall(ix[x].code)}
            exset += bool(ex_paths)
            if paths:
                imp += 1
                valid += bool(r[CV["sol"]])
                names = {q.split("/")[-1] for q in ex_paths}
                copied += any(q in ex_paths or q.split("/")[-1] in names for q in paths)
        rep[arm] = {"n": n, "with_import": imp, "with_import_valid": valid, "copied": copied, "importing_exemplar_in_set": exset}
        vals[f"A1.impshare.{arm}"] = pct(imp / n)
        vals[f"A1.impvalid.{arm}"] = pct(valid / imp) if imp else "0.0"
        if arm != "a0":
            vals[f"A1.impcopied.{arm}"] = pct(copied / imp) if imp else "0.0"
            vals[f"A1.impexset.{arm}"] = pct(exset / n)
    save("A1_import_mechanism", rep)
    placeholders_set(vals, "analyze.py a1 (imports)")
    print(json.dumps(vals, indent=1))


# ---------------------------------------------------------------- import-resolved Solidity (sensitivity)
def res():
    """Solidity Stage 1 + A1 under import-resolved scoring (sol_imports.py; fields added by
    rescore_sol_imports.py). Keys RES.*; p values are raw and Holm-adjusted within this 4-test family
    (A1 vs A0, alt vs A0, random vs A1, selective vs best fixed), separate from the Table 1 family."""
    from langs import ERR_CLASSES
    m = "compile_valid_res"
    arms = {"a0": A0["sol"], "a1": A1["sol"], "alt": ALT["sol"], "rand": RAND["sol"],
            "a3": RUNS / "ladder/sol/A3/results.jsonl"}
    data = {k: [r for r in read_jsonl(p) if r["status"] != "infra_error"] for k, p in arms.items()}
    if any(m not in r for rows in data.values() for r in rows):
        raise FileNotFoundError("compile_valid_res missing; run ecir_v3/rescore_sol_imports.py")
    rep, vals = {"arms": {}}, {}
    for k, rows in data.items():
        n = len(rows)
        imp = [r for r in rows if r.get("res_profile")]
        rep["arms"][k] = {"n": n, "cv_single_pct": pct(sum(bool(r["compile_valid"]) for r in rows) / n),
                          "cv_res_pct": pct(sum(bool(r[m]) for r in rows) / n),
                          "with_resolvable_import": len(imp),
                          "with_resolvable_import_valid": sum(bool(r[m]) for r in imp),
                          "err_per_sample_res": f"{np.mean([r['n_compiler_errors_res'] for r in rows]):.2f}"}
        vals[f"RES.sol.{k}.cv"] = rep["arms"][k]["cv_res_pct"]
        vals[f"RES.sol.{k}.err"] = rep["arms"][k]["err_per_sample_res"]
        if imp:
            vals[f"RES.sol.{k}.impvalid"] = pct(rep["arms"][k]["with_resolvable_import_valid"] / len(imp))
    fam = {"a1_vs_a0": T.compare(str(A0["sol"]), str(A1["sol"]), m),
           "alt_vs_a0": T.compare(str(A0["sol"]), str(ALT["sol"]), m),
           "rand_vs_a1": T.compare(str(A1["sol"]), str(RAND["sol"]), m)}
    sel = T.selective(str(A0["sol"]), str(A1["sol"]), m)
    raw = [fam[k]["p_raw"] for k in fam] + [sel["p_vs_best_fixed"]]
    adj = T.holm(raw)
    for (k, c), p in zip(fam.items(), adj):
        c["p_holm4"] = p
        vals.update({f"RES.sol.{k}.d": c["delta_pp"], f"RES.sol.{k}.ci": c["ci"], f"RES.sol.{k}.p": T.fmt_p(p)})
    sel["p_holm4"] = adj[-1]
    vals.update({"RES.sol.sel": sel["selective_pct"], "RES.sol.orc": sel["oracle_pct"],
                 "RES.sol.sel.d": sel["delta_vs_best_fixed_pp"], "RES.sol.sel.p": T.fmt_p(adj[-1])})
    rep.update(fam)
    rep["selective"] = sel
    # error classes per sample (first attempt), as Table 2
    cls = {}
    for k in ("a0", "a1", "alt", "rand"):
        c = collections.Counter(x for r in data[k] for x in r.get("compiler_error_classes_res") or [])
        cls[k] = {e: c[e] / len(data[k]) for e in ERR_CLASSES}
        vals.update({f"RES.A1.{e}.{k}": f"{cls[k][e]:.2f}" for e in ERR_CLASSES})
    inc = {e: cls["a1"][e] - cls["a0"][e] for e in ERR_CLASSES}
    rep["error_classes"], rep["increase_a0_to_a1"] = cls, inc
    rep["n_compiler_errors_a1_vs_a0"] = T.compare(str(A0["sol"]), str(A1["sol"]), "n_compiler_errors_res", "count")
    save("RES_sol_imports", rep)
    placeholders_set(vals, "analyze.py res (import-resolved Solidity)")
    print(json.dumps(vals, indent=1))


# ---------------------------------------------------------------- U2
def u2():
    from sklearn.metrics import cohen_kappa_score
    vals, rep = {}, {}
    a, b = [], []
    for lang in ("sol", "mod"):
        first = {(r["req_id"], r["exemplar_id"]): r for r in read_jsonl(RUNS / f"U1/{lang}/k1/results.jsonl")}
        for r in read_jsonl(RUNS / f"U2/{lang}/k1/results.jsonl"):
            k = (r["req_id"], r["exemplar_id"])
            if r["status"] == "infra_error" or k not in first or first[k]["status"] == "infra_error":
                continue
            gk = "gain_res" if lang == "sol" and _SFX else "gain"      # same label metric as generate.py labels
            a.append(int(first[k][gk])); b.append(int(r[gk]))
            rep.setdefault(lang, []).append([first[k][gk], r[gk]])
    if not a:
        print("U2: no paired labels yet"); return
    agree = float(np.mean(np.array(a) == np.array(b)))
    kappa = float(cohen_kappa_score(a, b))
    vals = {"U2.agree": pct(agree), "U2.kappa": f"{kappa:.2f}"}
    save("U2_reliability", {"n_pairs": len(a), "agree": agree, "kappa": kappa, "pairs": rep})
    placeholders_set(vals, "analyze.py u2")
    print(vals, "n =", len(a), "(kappa < 0.6: SV decides on a second label sample)" if kappa < 0.6 else "")


# ---------------------------------------------------------------- A13
FEATS = "cos_score,bm25_score,dense_score,n_imports,pragma_mismatch,n_lines,truncated,same_category"
FEAT_WORDS = {"cos_score": "binary-cosine score", "bm25_score": "BM25 score", "dense_score": "dense score",
              "n_imports": "number of imports", "pragma_mismatch": "a pragma our compiler cannot satisfy",
              "n_lines": "exemplar length", "truncated": "truncation of the exemplar",
              "same_category": "same category"}


def a13():
    vals, rep = {}, {}
    pools, raw = {}, []
    langs = [l for l in ("sol", "mod") if (RUNS / f"U1/{l}/labels.jsonl").exists()]
    if not langs:
        print("A13: no labels.jsonl yet"); return
    for lang in langs:
        lab = str(RUNS / f"U1/{lang}/labels.jsonl")
        p = T.pool(lab)
        pools[lang] = p
        for b in ("cos", "bm25", "dense"):
            for m, k in (("gain", "gain"), ("help", "help_pct"), ("hurt", "hurt_pct"), ("ndcg", "ndcg")):
                if k in p[b]:
                    vals[f"U1.{lang}.{b}.{m}"] = p[b][k]
            raw.append((f"{lang}.{b}", p[b]["p_gain_vs_random"]))
        for m, k in (("gain", "gain"), ("help", "help_pct"), ("hurt", "hurt_pct")):
            vals[f"U1.{lang}.rand.{m}"] = p["rand"][k]
        vals[f"U1.{lang}.a0.gain"] = p["a0_gain"]
    adj = dict(zip([k for k, _ in raw], T.holm([p for _, p in raw])))
    rep["holm_gain_vs_random"] = {k: {"raw": p, "holm": adj[k]} for k, p in raw}
    lex_p, urel = [], {}
    for lang in langs:
        p = pools[lang]
        lex = max(("cos", "bm25"), key=lambda b: float(p[b]["gain"]))
        rep[f"{lang}.better_lexical"] = lex
        vals[f"U1.{lang}.lexgap"] = p[lex]["gain_minus_random"]
        lex_p.append(adj[f"{lang}.{lex}"])
        urel[lang] = adj[f"{lang}.{lex}"] < 0.05 and float(p[lex]["gain_minus_random"]) > 0
        if lang == "sol":
            vals["U1.sol.hurt.lex"] = p[lex]["hurt_pct"]
    vals["U1.p"] = T.fmt_p(max(lex_p))
    vals["U1.nlabels"] = T.fmt_n(sum(pools[l]["n_labels"] for l in langs))
    vals["U1.poolsize"] = f"{np.mean([float(pools[l]['mean_pool_size']) for l in langs]):.1f}"
    rep["Urel"] = all(urel.get(l, False) for l in ("sol", "mod"))
    rep["pools"] = pools
    # reranker CV + gate
    gate, rr_raw = {}, []
    for lang in langs:
        cv = T.rerank_cv(str(RUNS / f"U1/{lang}/labels.jsonl"), FEATS.split(","))
        rep[f"{lang}.rerank_cv"] = cv
        for m, k in (("gain", "gain"), ("help", "help_pct"), ("hurt", "hurt_pct"), ("ndcg", "ndcg")):
            vals[f"A13.{lang}.rr.{m}"] = cv["reranker_cv"][k]
        best = cv["best_single"]
        d = cv[f"ndcg_minus_{best}"]
        rr_raw.append((lang, d["p"]))
        gate[lang] = {"reranker_ndcg": cv["reranker_cv"]["ndcg"], "best_single": best,
                      "best_single_ndcg": cv[best]["ndcg"], "delta": d["delta"], "p_randomization": d["p"],
                      "pass": cv["gate_pass"]}
    for (lang, p), q in zip(rr_raw, T.holm([p for _, p in rr_raw])):
        gate[lang]["p_holm_table3_family2"] = q
    write_json(RUNS / "R7" / "gate_decision.json", gate)
    rep["gate"] = gate
    # harm model (Solidity pairs)
    if "sol" in langs:
        h = harm_model(RUNS / "U1/sol/labels.jsonl")
        rep["harm"] = h
        if h.get("feature"):
            vals.update({"A13.harm.feat": FEAT_WORDS[h["feature"]], "A13.harm.or": f"{h['or']:.2f}",
                         "A13.harm.orci": f"{h['ci'][0]:.2f}, {h['ci'][1]:.2f}"})
    save("A13_pools", rep)
    placeholders_set(vals, "analyze.py a13")
    print(json.dumps(vals, indent=1))
    print("R7 gate:", json.dumps(gate, indent=1))


def harm_model(path):
    import pandas as pd
    import statsmodels.api as sm
    rows = read_jsonl(path)
    df = pd.DataFrame([{**r["features"], "hurts": int(r["gain"] < r["g0"]), "req_id": r["req_id"],
                        "exemplar_id": r["exemplar_id"], "top1": (r["ranks"] or {}).get("cos") == 1}
                       for r in rows])
    feats = [f for f in ["cos_score", "bm25_score", "dense_score", "n_imports", "pragma_mismatch",
                         "n_lines", "truncated"] if f in df and df[f].notna().all() and df[f].std() > 0]
    X = (df[feats] - df[feats].mean()) / df[feats].std()
    m = sm.Logit(df.hurts, sm.add_constant(X)).fit(
        disp=0, cov_type="cluster", cov_kwds={"groups": pd.factorize(df.req_id)[0]})
    ci = np.exp(m.conf_int())
    table = {f: {"or": float(np.exp(m.params[f])), "ci": [float(ci.loc[f, 0]), float(ci.loc[f, 1])],
                 "p": float(m.pvalues[f])} for f in feats}
    sig = {f: t for f, t in table.items() if t["p"] < 0.05 and t["or"] > 1}
    out = {"n_pairs": len(df), "hurt_rate": float(df.hurts.mean()), "table": table}
    if sig:
        f = max(sig, key=lambda k: sig[k]["or"])
        out.update({"feature": f, **sig[f]})
        ex = df[(df.hurts == 1) & df.top1].sort_values(f, ascending=False).head(10)
        out["harmful_top1_examples"] = ex[["req_id", "exemplar_id", f]].to_dict("records")
    return out


# ---------------------------------------------------------------- R7
def r7():
    vals, rep, raw = {}, {}, []
    for lang in ("sol", "mod"):
        p = RUNS / f"R7/{lang}/A1rerank/results.jsonl"
        if not p.exists():
            continue
        held = set(read_ids(f"heldout400_{lang}.txt"))
        base = OUT / f"_r7_base_{lang}.jsonl"
        base.parent.mkdir(parents=True, exist_ok=True)
        base.write_text("".join(json.dumps(r) + "\n" for r in read_jsonl(A1[lang]) if r["req_id"] in held))
        c = T.compare(str(base), str(p), CV[lang])
        rep[lang] = c
        vals[f"R7.{lang}.cv"] = c["b_pct"]
        vals[f"R7.{lang}.base"] = c["a_pct"]
        raw.append((lang, c["p_raw"], float(c["delta_pp"])))
    if not raw:
        print("R7: not run"); return
    adj = T.holm([p for _, p, _ in raw])
    vals["R7.p"] = T.fmt_p(min(adj))
    vals["R7.best.d"] = f"{max(d for _, _, d in raw):+.1f}"
    rep["holm"] = dict(zip([l for l, _, _ in raw], adj))
    rep["Rrk"] = any(q < 0.05 and d > 0 for q, (_, _, d) in zip(adj, raw))
    for lang in ("sol", "mod"):
        if lang not in rep:
            vals[f"R7.{lang}.cv"] = "--"; vals[f"R7.{lang}.base"] = "--"
    save("R7", rep)
    placeholders_set(vals, "analyze.py r7")
    print(vals)


# ---------------------------------------------------------------- D7, switches
def d7():
    served = collections.Counter()
    for m in RUNS.glob("*/*/*/run_meta.json"):
        for k, v in json.loads(m.read_text()).get("providers_served", {}).items():
            served[k or "unknown"] += v
    if not served:
        print("D7: no v3 runs yet; v1 never logged the served provider"); return
    placeholders_set({"D7.providers": ", ".join(sorted(served))}, "analyze.py d7")
    print("D7 providers served:", dict(served))


def switches():
    s = {}
    st = OUT / "stage1.json"
    if st.exists():
        r = json.loads(st.read_text())
        h = r["holm_family"]
        if "sol.alt_vs_A0" in h:
            d = float(r["sol.alt_vs_A0"]["delta_pp"])
            s["Rone"] = h["sol.alt_vs_A0"]["holm"] >= 0.05 or d >= 0
        wins = [l for l in ("sys", "sol", "mod") if f"{l}.rand_vs_A1" in h
                and h[f"{l}.rand_vs_A1"]["holm"] < 0.05 and float(r[f"{l}.rand_vs_A1"]["delta_pp"]) < 0]
        if all(f"{l}.rand_vs_A1" in h for l in ("sys", "sol", "mod")):
            s["Rtwo"] = len(wins) >= 2
        s["Sel"] = r.get("Sel")
    a13p = OUT / "A13_pools.json"
    if a13p.exists():
        s["Urel"] = json.loads(a13p.read_text()).get("Urel")
    r7p = OUT / "R7.json"
    s["Rrk"] = json.loads(r7p.read_text()).get("Rrk", False) if r7p.exists() else False
    save("switches_suggested", s)
    print("suggested switches (SV decides; mixed outcomes get rewritten by hand):", s)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "all"
    fns = {"a10": a10, "a14": a14, "stage1": stage1, "a1": a1, "u2": u2, "a13": a13, "r7": r7,
           "d7": d7, "switches": switches, "res": res}
    if cmd == "all":
        for k, f in fns.items():
            try:
                f()
            except FileNotFoundError as e:
                print(f"{k}: skipped ({e})")
    else:
        fns[cmd]()


if __name__ == "__main__":
    main()
