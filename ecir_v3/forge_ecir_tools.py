#!/usr/bin/env python3
"""Helpers for the FORGE v3 ECIR paper (retrieval-utility study).

Reconstructed from the v3 runbook (the original forge_ecir_tools.py was not
delivered); extends paper_data/ecir_paper/feedback/forge_v2_tools.py.

  keys        TEX                          list every \\tbd / \\verify key with line numbers
  template    TEX OUT.json                 placeholders.json skeleton (all values null)
  set         JSON KEY VALUE               set one placeholder value
  fill        TEX JSON [OUT]               write OUT (default <tex>.filled.tex) with values
  compare     A.jsonl B.jsonl METRIC [--count] [--where M]
                                           paired comparison B - A, printed as JSON
  holm        P1 P2 ...                    Holm-adjusted p-values for one family
  selective   A0.jsonl A1.jsonl METRIC     cross-validated selective retrieval policy
  curve       OUT.pdf "Lang:A0:A1" ...     selective-retrieval curve figure
  pool        LABELS.jsonl                 pool evaluation (gain/help/hurt/nDCG@5 per retriever)
  rerank-cv   LABELS.jsonl FEATS           requirement-grouped CV of a feature reranker
  rerank-apply LABELS.jsonl CANDS.jsonl FEATS OUT.jsonl
                                           train on all labels, write top five per requirement

Set-level files (results.jsonl): one record per requirement,
  {"req_id", "status": ok|empty_output|infra_error, "compile_valid", "gain", ...,
   "retrieval": {"exemplar_ids": [...], "scores": [...], "spec_chunk_ids": [...]}}
Pairing: pairs where either side is infra_error are dropped; empty_output counts as
a failure (False / 0) for every metric of that record.

Pool label files (labels.jsonl): one record per requirement-exemplar pair,
  {"req_id", "exemplar_id", "gain", "g0", "ranks": {"cos": 1..5|null, ...},
   "random": bool, "features": {...}}
help = gain > g0, hurt = gain < g0.

Fixed conventions: percentile bootstrap over requirements, 10,000 resamples, seed 0;
exact McNemar for rates, Wilcoxon for counts; paired randomization (10,000 sign
flips, seed 0) for pool comparisons.
"""
import json
import math
import re
import sys
from collections import defaultdict

import numpy as np
from scipy import stats

TBD = re.compile(r"\\tbd\{([^}]*)\}")
# first argument may hold one level of braces, e.g. \verify{2.0\times10^{-6}}{V.p.mod}
VERIFY = re.compile(r"\\verify\{((?:[^{}]|\{[^{}]*\})*)\}\{([^}]*)\}")
REPS = 10000
RETRIEVERS = ("cos", "bm25", "dense")


# ---------------------------------------------------------------- keys / fill
def cmd_keys(tex, quiet=False):
    lines = open(tex, encoding="utf-8").read().splitlines()
    seen = {}
    for i, line in enumerate(lines, 1):
        if line.lstrip().startswith("%"):
            continue
        for k in TBD.findall(line):
            seen.setdefault(("tbd", k), []).append(i)
        for _, k in VERIFY.findall(line):
            seen.setdefault(("verify", k), []).append(i)
    if not quiet:
        for (kind, k), where in sorted(seen.items(), key=lambda x: (x[0][1], x[0][0])):
            print(f"{kind:6s} {k:28s} lines {','.join(map(str, where))}")
        print(f"# {len(seen)} keys", file=sys.stderr)
    return seen


def cmd_template(tex, out):
    seen = cmd_keys(tex)
    try:
        old = json.load(open(out))
    except FileNotFoundError:
        old = {}
    d = {k: old.get(k) for (_, k) in sorted(seen, key=lambda x: x[1])}
    json.dump(d, open(out, "w"), indent=1, sort_keys=True)


def cmd_set(path, key, value):
    try:
        d = json.load(open(path))
    except FileNotFoundError:
        d = {}
    d[key] = value
    json.dump(d, open(path, "w"), indent=1, sort_keys=True)


def cmd_fill(tex, path, out=None):
    src = open(tex, encoding="utf-8").read()
    vals = {k: v for k, v in json.load(open(path)).items() if v is not None}
    missing = set()

    def sub_tbd(m):
        k = m.group(1)
        if k in vals:
            return str(vals[k])
        missing.add(k)
        return m.group(0)

    def sub_verify(m):
        k = m.group(2)
        if k in vals:
            return str(vals[k])
        missing.add(k)
        return m.group(0)

    res = "\n".join(line if line.lstrip().startswith("%")
                    else VERIFY.sub(sub_verify, TBD.sub(sub_tbd, line))
                    for line in src.split("\n"))
    out = out or tex.replace(".tex", ".filled.tex")
    open(out, "w", encoding="utf-8").write(res)
    print(f"wrote {out}; {len(missing)} keys still unfilled")
    for k in sorted(missing):
        print("  unfilled:", k)
    return missing


# ---------------------------------------------------------------- formatting
def fmt_p(p):
    """Runbook format: three decimals at or above 0.01, LaTeX mantissa below."""
    if p >= 0.01:
        return f"{p:.3f}"
    if p <= 0:
        return "0"
    e = math.floor(math.log10(p))
    m = round(p / 10 ** e, 1)
    if m >= 10:
        m, e = 1.0, e + 1
    return f"{m:.1f}\\times10^{{{e}}}"


def fmt_n(n):
    """LaTeX thousands separator for counts >= 1000."""
    s = f"{int(n):,}"
    return s.replace(",", "{,}")


# ---------------------------------------------------------------- set-level stats
def load(path):
    recs = {}
    for line in open(path, encoding="utf-8"):
        if line.strip():
            r = json.loads(line)
            recs[str(r["req_id"])] = r
    return recs


def value(rec, metric):
    if rec.get("status") == "empty_output":
        return 0.0
    v = rec.get(metric)
    return None if v is None else float(v)


def pairs(a, b, metric, where=None):
    xa, xb, ids = [], [], []
    for rid in sorted(set(a) & set(b)):
        ra, rb = a[rid], b[rid]
        if "infra_error" in (ra.get("status"), rb.get("status")):
            continue
        if where and not (value(ra, where) and value(rb, where)):
            continue
        va, vb = value(ra, metric), value(rb, metric)
        if va is None or vb is None:
            continue
        xa.append(va); xb.append(vb); ids.append(rid)
    return np.array(xa), np.array(xb), ids


def mcnemar_exact(xa, xb):
    b = int(np.sum((xa == 1) & (xb == 0)))
    c = int(np.sum((xa == 0) & (xb == 1)))
    if b + c == 0:
        return 1.0, b, c
    return float(min(1.0, stats.binomtest(min(b, c), b + c, 0.5).pvalue)), b, c


def bootstrap_ci(d, reps=REPS, seed=0, scale=100.0):
    d = np.asarray(d, dtype=float)
    if len(d) == 0:
        return float("nan"), float("nan")
    rng = np.random.default_rng(seed)
    idx = rng.integers(0, len(d), size=(reps, len(d)))
    means = d[idx].mean(axis=1) * scale
    return float(np.percentile(means, 2.5)), float(np.percentile(means, 97.5))


def cohens_h(pa, pb):
    return 2 * math.asin(math.sqrt(pb)) - 2 * math.asin(math.sqrt(pa))


def rate_stats(xa, xb):
    pa, pb = xa.mean(), xb.mean()
    p, b, c = mcnemar_exact(xa, xb)
    lo, hi = bootstrap_ci(xb - xa)
    return {"n": len(xa), "a_pct": f"{100 * pa:.1f}", "b_pct": f"{100 * pb:.1f}",
            "delta_pp": f"{100 * (pb - pa):+.1f}", "ci": f"{lo:.1f}, {hi:.1f}",
            "h": f"{abs(cohens_h(pa, pb)):.2f}", "p_raw": p, "p_tex": fmt_p(p),
            "discordant_a_only": b, "discordant_b_only": c}


def compare(a_path, b_path, metric, kind="rate", where=None):
    xa, xb, ids = pairs(load(a_path), load(b_path), metric, where)
    out = {"metric": metric, "where": where}
    if not ids:
        out["n"] = 0
        return out
    if kind == "rate":
        out.update(rate_stats(xa, xb))
    else:
        p = float(stats.wilcoxon(xa, xb, zero_method="wilcox").pvalue) if np.any(xa != xb) else 1.0
        lo, hi = bootstrap_ci(xb - xa, scale=1.0)
        out.update({"n": len(ids), "a_mean": f"{xa.mean():.2f}", "b_mean": f"{xb.mean():.2f}",
                    "delta": f"{xb.mean() - xa.mean():+.2f}", "ci": f"{lo:.2f}, {hi:.2f}",
                    "p_raw": p, "p_tex": fmt_p(p)})
    return out


def holm(ps):
    order = sorted(range(len(ps)), key=lambda i: ps[i])
    adj, running = [0.0] * len(ps), 0.0
    for rank, i in enumerate(order):
        running = max(running, min(1.0, (len(ps) - rank) * ps[i]))
        adj[i] = running
    return adj


# ---------------------------------------------------------------- selective retrieval
def top1(rec):
    s = (rec.get("retrieval") or {}).get("scores") or []
    return float(s[0]) if s else 0.0


def selective_data(a0_path, a1_path, metric):
    a0, a1 = load(a0_path), load(a1_path)
    xa, xb, ids = pairs(a0, a1, metric)
    s = np.array([top1(a1[i]) for i in ids])
    return xa, xb, s, ids


def fit_threshold(xa, xb, s):
    """Best rule 'retrieve iff top-1 score s >= t' on training data (the paper: retrieve only when the
    top-1 score clears a threshold). t ranges over -inf, the observed scores and +inf, so always and
    never are special cases. Ties are broken toward the better fixed policy (fewest switches)."""
    best = None
    ts = np.concatenate([[-np.inf], np.unique(s), [np.inf]])
    target = 1.0 if xb.mean() >= xa.mean() else 0.0
    for t in ts:
        use = s >= t
        v = np.where(use, xb, xa).mean()
        key = (round(v, 12), -abs(use.mean() - target))
        if best is None or key > best[0]:
            best = (key, 1, t)
    return best[1], best[2]


def selective(a0_path, a1_path, metric, folds=10, seed=0):
    xa, xb, s, ids = selective_data(a0_path, a1_path, metric)
    n = len(ids)
    rng = np.random.default_rng(seed)
    fold = rng.permutation(np.arange(n) % folds)
    pol = np.zeros(n)
    use_all = np.zeros(n, dtype=bool)
    for k in range(folds):
        te, tr = fold == k, fold != k
        d, t = fit_threshold(xa[tr], xb[tr], s[tr])
        use = s[te] >= t if d == 1 else s[te] <= t
        use_all[te] = use
        pol[te] = np.where(use, xb[te], xa[te])
    orc = np.maximum(xa, xb)
    never, always = xa, xb
    best_name, best = ("always", always) if always.mean() >= never.mean() else ("never", never)
    st = rate_stats(best, pol)
    p_never, _, _ = mcnemar_exact(never, pol)
    p_always, _, _ = mcnemar_exact(always, pol)
    gap = orc.mean() - best.mean()
    d_full, t_full = fit_threshold(xa, xb, s)
    return {
        "n": n, "metric": metric,
        "never_pct": f"{100 * never.mean():.1f}", "always_pct": f"{100 * always.mean():.1f}",
        "selective_pct": f"{100 * pol.mean():.1f}", "oracle_pct": f"{100 * orc.mean():.1f}",
        "retrieve_share_pct": f"{100 * use_all.mean():.1f}",
        "best_fixed": best_name,
        "delta_vs_best_fixed_pp": st["delta_pp"], "ci_vs_best_fixed": st["ci"],
        "p_vs_best_fixed": st["p_raw"],
        "p_vs_never": p_never, "p_vs_always": p_always,
        "oracle_minus_best_fixed_pp": f"{100 * gap:+.1f}",
        "recovery_pct": f"{100 * (pol.mean() - best.mean()) / gap:.1f}" if gap > 0 else "0.0",
        "full_data_rule": {"direction": ">=",
                           "threshold": None if not np.isfinite(t_full) else float(t_full)},
        "folds": folds, "seed": seed,
    }


def curve(out, specs, metric="compile_valid"):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(3.4, 2.4))
    for spec in specs:
        name, a0, a1 = spec.split(":", 2)
        xa, xb, s, _ = selective_data(a0, a1, metric)
        n = len(s)
        # retrieve for the q highest-scoring requirements, q = 0..n
        order = np.argsort(-s, kind="stable")
        fr, val = [0.0], [xa.mean()]
        acc = xa.copy()
        for q, i in enumerate(order, 1):
            acc[i] = xb[i]
            fr.append(q / n); val.append(acc.mean())
        line, = ax.plot(np.array(fr) * 100, np.array(val) * 100, label=name, lw=1.2)
        ax.axhline(np.maximum(xa, xb).mean() * 100, ls=":", lw=0.8, color=line.get_color())
    ax.set_xlabel("Requirements given retrieval (%, highest top-1 score first)", fontsize=7)
    ax.set_ylabel("Compile-valid (%)", fontsize=7)
    ax.tick_params(labelsize=6)
    ax.legend(fontsize=6, frameon=False)
    fig.tight_layout()
    fig.savefig(out)
    print(f"wrote {out} (dotted lines: per-language oracle)")


# ---------------------------------------------------------------- pools
def load_labels(path):
    by = defaultdict(list)
    for line in open(path, encoding="utf-8"):
        if line.strip():
            r = json.loads(line)
            if r.get("status") == "infra_error":
                continue
            r["gain"] = float(r.get("gain") or 0)
            by[str(r["req_id"])].append(r)
    return by


def dcg(gains):
    return sum((2 ** g - 1) / math.log2(i + 2) for i, g in enumerate(gains))


def block_metrics(rows, g0, ranked, all_gains):
    """rows: the label records of one block (ranked = in rank order)."""
    gs = [r["gain"] for r in rows]
    if not gs:
        return None
    m = {"gain": float(np.mean(gs)),
         "help": float(np.mean([g > g0 for g in gs])),
         "hurt": float(np.mean([g < g0 for g in gs]))}
    if ranked:
        ideal = dcg(sorted(all_gains, reverse=True)[:5])
        m["ndcg"] = dcg(gs[:5]) / ideal if ideal > 0 else None
    return m


def retriever_block(rows, name):
    rk = [(r["ranks"].get(name), r) for r in rows if (r.get("ranks") or {}).get(name)]
    return [r for _, r in sorted(rk, key=lambda x: x[0])][:5]


def per_req(by, blocks):
    """{block: {req_id: metrics}} for named blocks (retriever names or 'rand' or callables)."""
    out = {b: {} for b in blocks}
    for rid, rows in by.items():
        g0 = float(rows[0].get("g0") or 0)
        allg = [r["gain"] for r in rows]
        for b, pick in blocks.items():
            sel = pick(rid, rows)
            m = block_metrics(sel, g0, b != "rand", allg)
            if m is not None:
                out[b][rid] = m
    return out


def randomization_p(d, reps=REPS, seed=0):
    d = np.asarray(d, dtype=float)
    d = d[~np.isnan(d)]
    if len(d) == 0 or np.all(d == 0):
        return 1.0
    rng = np.random.default_rng(seed)
    obs = abs(d.mean())
    signs = rng.choice([-1.0, 1.0], size=(reps, len(d)))
    null = np.abs((signs * d).mean(axis=1))
    return float((1 + np.sum(null >= obs - 1e-12)) / (reps + 1))


def paired_diff(pr, b1, b2, key):
    ids = sorted(set(pr[b1]) & set(pr[b2]))
    d = [pr[b1][i][key] - pr[b2][i][key] for i in ids
         if pr[b1][i].get(key) is not None and pr[b2][i].get(key) is not None]
    return np.array(d)


def summarize(pr, b):
    vals = list(pr[b].values())
    nd = [v["ndcg"] for v in vals if v.get("ndcg") is not None]
    out = {"n_req": len(vals),
           "gain": f"{np.mean([v['gain'] for v in vals]):.2f}",
           "help_pct": f"{100 * np.mean([v['help'] for v in vals]):.1f}",
           "hurt_pct": f"{100 * np.mean([v['hurt'] for v in vals]):.1f}"}
    if nd:
        out["ndcg"] = f"{np.mean(nd):.2f}"
        out["n_req_ndcg"] = len(nd)
    return out


def pool(path):
    by = load_labels(path)
    blocks = {name: (lambda rid, rows, n=name: retriever_block(rows, n)) for name in RETRIEVERS}
    blocks["rand"] = lambda rid, rows: [r for r in rows if r.get("random")]
    pr = per_req(by, blocks)
    res = {"n_req": len(by), "n_labels": sum(len(v) for v in by.values()),
           "mean_pool_size": f"{np.mean([len(v) for v in by.values()]):.1f}",
           "a0_gain": f"{np.mean([float(v[0].get('g0') or 0) for v in by.values()]):.2f}"}
    raw = []
    for b in list(RETRIEVERS) + ["rand"]:
        res[b] = summarize(pr, b)
        if b != "rand":
            d = paired_diff(pr, b, "rand", "gain")
            p = randomization_p(d)
            res[b]["gain_minus_random"] = f"{d.mean():+.2f}"
            res[b]["gain_minus_random_ci"] = "%.2f, %.2f" % bootstrap_ci(d, scale=1.0)
            res[b]["p_gain_vs_random"] = p
            raw.append(p)
    for b, q in zip(RETRIEVERS, holm(raw)):
        res[b]["p_gain_vs_random_holm_within_lang"] = q
    # retriever vs retriever (e.g. dense vs lexical), paired over requirements
    res["pairs"] = {}
    for i, b1 in enumerate(RETRIEVERS):
        for b2 in RETRIEVERS[i + 1:]:
            row = {}
            for key in ("ndcg", "gain"):
                d = paired_diff(pr, b1, b2, key)
                row[key] = {"delta": f"{d.mean():+.2f}" if len(d) else None, "p": randomization_p(d), "n": len(d)}
            res["pairs"][f"{b1}_minus_{b2}"] = row
    return res


# ---------------------------------------------------------------- reranker
def feat_matrix(rows, feats):
    X = np.array([[float((r.get("features") or {}).get(f) if (r.get("features") or {}).get(f) is not None else np.nan)
                   for f in feats] for r in rows], dtype=float)
    return X


def usable_feats(rows, feats):
    X = feat_matrix(rows, feats)
    keep = [i for i, f in enumerate(feats)
            if not np.all(np.isnan(X[:, i])) and np.nanstd(X[:, i]) > 0]
    return [feats[i] for i in keep]


def train(rows, feats):
    """Logistic-regression reranker (the paper: logistic regression over the three retrieval scores and
    exemplar features): multinomial over the graded gain {0,1,2} on standardized features; candidates are
    ranked by expected gain sum_k k * P(gain = k)."""
    from sklearn.linear_model import LogisticRegression
    X = feat_matrix(rows, feats)
    mu, sd = np.nanmean(X, axis=0), np.nanstd(X, axis=0)
    sd[sd == 0] = 1.0
    Xs = np.nan_to_num((X - mu) / sd)
    y = np.array([int(r["gain"]) for r in rows])
    if len(set(y)) < 2:                         # degenerate fold: every label equal
        c = float(y.mean())
        return (lambda rs: np.full(len(rs), c)), {f: 0.0 for f in feats}
    m = LogisticRegression(C=1.0, max_iter=5000).fit(Xs, y)
    cls = m.classes_.astype(float)

    def score(rs):
        return m.predict_proba(np.nan_to_num((feat_matrix(rs, feats) - mu) / sd)) @ cls
    # coefficients of the highest gain class (log-odds per SD), for reporting only
    return score, dict(zip(feats, map(float, m.coef_[-1])))


def rerank_top(score, rows, k=5):
    if not rows:
        return []
    p = score(rows)
    order = sorted(range(len(rows)), key=lambda i: (-p[i], str(rows[i]["exemplar_id"])))
    return [rows[i] for i in order[:k]]


def rerank_cv(path, feats, folds=5, seed=0):
    by = load_labels(path)
    rids = sorted(by)
    allrows = [r for rid in rids for r in by[rid]]
    feats = usable_feats(allrows, feats)
    rng = np.random.default_rng(seed)
    fold = dict(zip(rids, rng.permutation(np.arange(len(rids)) % folds)))
    picked = {}
    for k in range(folds):
        tr = [r for rid in rids if fold[rid] != k for r in by[rid]]
        score, _ = train(tr, feats)
        for rid in rids:
            if fold[rid] == k:
                # rank retrieved candidates only (R7 candidates never include random ones);
                # random exemplars still serve as training labels
                picked[rid] = rerank_top(score, [r for r in by[rid] if not r.get("random")])
    blocks = {name: (lambda rid, rows, n=name: retriever_block(rows, n)) for name in RETRIEVERS}
    blocks["rr"] = lambda rid, rows: picked[rid]
    blocks["rand"] = lambda rid, rows: [r for r in rows if r.get("random")]
    pr = per_req(by, blocks)
    _, coefs = train(allrows, feats)
    res = {"features_used": feats, "folds": folds, "seed": seed,
           "reranker_cv": summarize(pr, "rr"),
           "full_data_coefs": {f: round(c, 4) for f, c in coefs.items()}}
    for b in RETRIEVERS:
        res[b] = summarize(pr, b)
        d = paired_diff(pr, "rr", b, "ndcg")
        res[f"ndcg_minus_{b}"] = {"delta": f"{d.mean():+.2f}", "ci": "%.2f, %.2f" % bootstrap_ci(d, scale=1.0),
                                  "p": randomization_p(d), "n": len(d)}
        dg = paired_diff(pr, "rr", b, "gain")
        res[f"gain_minus_{b}"] = {"delta": f"{dg.mean():+.2f}", "p": randomization_p(dg), "n": len(dg)}
    best = max(RETRIEVERS, key=lambda b: float(res[b].get("ndcg", "nan")))
    res["best_single"] = best
    res["gate_pass"] = (float(res["ndcg_minus_" + best]["delta"]) > 0
                        and res["ndcg_minus_" + best]["p"] < 0.05)
    return res


def rerank_apply(labels, cands, feats, out):
    by = load_labels(labels)
    allrows = [r for v in by.values() for r in v]
    feats = usable_feats(allrows, feats)
    score, coefs = train(allrows, feats)
    cby = defaultdict(list)
    for line in open(cands, encoding="utf-8"):
        if line.strip():
            r = json.loads(line)
            cby[str(r["req_id"])].append(r)
    with open(out, "w", encoding="utf-8") as f:
        for rid in sorted(cby):
            rows = cby[rid]
            p = score(rows)
            order = sorted(range(len(rows)), key=lambda i: (-p[i], str(rows[i]["exemplar_id"])))[:5]
            f.write(json.dumps({"req_id": rid,
                                "exemplar_ids": [rows[i]["exemplar_id"] for i in order],
                                "scores": [round(float(p[i]), 6) for i in order]}) + "\n")
    print(json.dumps({"wrote": out, "n_req": len(cby), "features_used": feats,
                      "coefs": {k: round(v, 4) for k, v in coefs.items()}}, indent=1))


# ---------------------------------------------------------------- main
def jdump(x):
    print(json.dumps(x, indent=1, default=float))


def main(argv):
    if len(argv) < 2:
        print(__doc__); return 1
    cmd, args = argv[1], argv[2:]
    if cmd == "keys":
        cmd_keys(args[0])
    elif cmd == "template":
        cmd_template(args[0], args[1])
    elif cmd == "set":
        cmd_set(args[0], args[1], args[2])
    elif cmd == "fill":
        cmd_fill(args[0], args[1], args[2] if len(args) > 2 else None)
    elif cmd == "compare":
        kind = "count" if "--count" in args else "rate"
        where = args[args.index("--where") + 1] if "--where" in args else None
        jdump(compare(args[0], args[1], args[2], kind, where))
    elif cmd == "holm":
        ps = [float(x) for x in args]
        for p, q in zip(ps, holm(ps)):
            print(f"raw {p:.3g}  holm {q:.3g}  tex {fmt_p(q)}")
    elif cmd == "selective":
        jdump(selective(args[0], args[1], args[2] if len(args) > 2 else "compile_valid"))
    elif cmd == "curve":
        curve(args[0], args[1:])
    elif cmd == "pool":
        jdump(pool(args[0]))
    elif cmd == "rerank-cv":
        jdump(rerank_cv(args[0], args[1].split(",")))
    elif cmd == "rerank-apply":
        rerank_apply(args[0], args[1], args[2].split(","), args[3])
    else:
        print(__doc__); return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
