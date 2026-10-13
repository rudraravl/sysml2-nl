#!/usr/bin/env python3
"""Numbers and paper fill for the ECIR 2027 retrieval-utility study.

Every table shares this implementation: exact McNemar for rates, a percentile
bootstrap over 10,000 resamples of requirements (seed 0), and paired
randomization tests (10,000 sign flips) for pool comparisons. Selective
retrieval uses 10-fold cross-validation. The utility reranker uses 5-fold
cross-validation by requirement.

Commands
    template TEX JSON
    keys TEX
    set JSON KEY VALUE
    fill TEX JSON
    compare A.jsonl B.jsonl FIELD [--count]
    holm P1 P2 ...
    selective A0.jsonl A1.jsonl FIELD
    curve PDF "Name:A0.jsonl:A1.jsonl" ...
    pool LABELS.jsonl
    rerank-cv LABELS.jsonl FEAT,FEAT,...
    rerank-apply LABELS.jsonl CANDS.jsonl FEAT,FEAT,... OUT.jsonl
    errors A0.jsonl A1.jsonl ALT.jsonl RAND.jsonl
    a14 RESULTS.jsonl
    harm LABELS.jsonl
    self-test
    check-ladder A0.jsonl A1.jsonl
"""

from __future__ import annotations

import json
import math
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm
from scipy.stats import binomtest
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import cohen_kappa_score, ndcg_score  # kappa: agree; ndcg: pool and rerank
from sklearn.model_selection import GroupKFold

N_BOOT = 10_000
N_PERM = 10_000
SEED = 0
SELECTIVE_FOLDS = 10
RERANK_FOLDS = 5

KEY_RE = r"[A-Za-z][A-Za-z0-9_.]*"
TBD_RE = re.compile(r"\\tbd\{(" + KEY_RE + r")\}")
VERIFY_RE = re.compile(r"\\verify\{((?:[^{}]|\{[^{}]*\})*)\}\{(" + KEY_RE + r")\}")

CLASS_ORDER = ("imp", "ver", "und", "type", "parse", "other")
CLASS_WORDS = {
    "imp": "unresolved imports",
    "ver": "compiler version or pragma",
    "und": "undeclared identifiers",
    "type": "type errors",
    "parse": "parser errors",
    "other": "other errors",
}
HARM_FEATURES = [
    "cos_score", "bm25_score", "dense_score", "n_imports",
    "pragma_mismatch", "n_lines", "truncated",
]


def fmt_p_tex(p: float) -> str:
    """Three decimals at 0.01 and above; LaTeX scientific notation below."""
    if p >= 0.01 or math.isnan(p):
        return f"{p:.3f}"
    exp = math.floor(math.log10(p))
    mant = round(p / 10 ** exp, 1)
    if mant >= 10:
        mant = 1.0
        exp += 1
    return f"{mant:.1f}\\times10^{{{exp}}}"


def fmt_signed(value: float, decimals: int) -> str:
    return f"{value:+.{decimals}f}"


def fmt_ci(low: float, high: float, decimals: int) -> str:
    return f"{low:.{decimals}f}, {high:.{decimals}f}"


def cohens_h(p1: float, p2: float) -> float:
    """Signed arcsine distance, p1 minus p2."""
    p1 = min(1.0, max(0.0, p1))
    p2 = min(1.0, max(0.0, p2))
    return 2 * math.asin(math.sqrt(p1)) - 2 * math.asin(math.sqrt(p2))


def load_jsonl(path: str | Path) -> list[dict]:
    rows = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def _status(row: dict) -> str:
    return row.get("status") or "ok"


def _binary(row: dict, field: str) -> bool:
    """Empty output is a failure. A missing flag is a failure too."""
    if _status(row) == "empty_output":
        return False
    return bool(row.get(field))


def _number(row: dict, field: str) -> float:
    if _status(row) == "empty_output":
        return 0.0
    return float(row.get(field) or 0)


def align(path_a, path_b, field: str, *, count: bool) -> dict:
    """Pair on req_id. Drop a pair when either side is an infra error."""
    by_b = {row["req_id"]: row for row in load_jsonl(path_b)}
    ids, a_vals, b_vals = [], [], []
    for row in load_jsonl(path_a):
        other = by_b.get(row["req_id"])
        if other is None:
            continue
        if _status(row) == "infra_error" or _status(other) == "infra_error":
            continue
        ids.append(row["req_id"])
        if count:
            a_vals.append(_number(row, field))
            b_vals.append(_number(other, field))
        else:
            a_vals.append(_binary(row, field))
            b_vals.append(_binary(other, field))
    return {"ids": ids, "a": np.asarray(a_vals), "b": np.asarray(b_vals)}


def mcnemar_exact(a_flags, b_flags) -> dict:
    a = np.asarray(a_flags, dtype=bool)
    b = np.asarray(b_flags, dtype=bool)
    a_only = int(np.sum(a & ~b))
    b_only = int(np.sum(~a & b))
    discordant = a_only + b_only
    if discordant == 0:
        p = 1.0
    else:
        p = float(binomtest(a_only, discordant, 0.5, alternative="two-sided").pvalue)
    return {"a_only": a_only, "b_only": b_only, "p_raw": p, "p_tex": fmt_p_tex(p)}


def bootstrap_delta(a, b, *, scale: float, decimals: int) -> tuple[float, float]:
    """Percentile interval of mean(b) - mean(a), in `scale` units."""
    n = len(a)
    if n == 0:
        return 0.0, 0.0
    rng = np.random.default_rng(SEED)
    idx = rng.integers(0, n, size=(N_BOOT, n))
    deltas = (b[idx].mean(axis=1) - a[idx].mean(axis=1)) * scale
    low, high = np.quantile(deltas, [0.025, 0.975])
    return round(float(low), decimals), round(float(high), decimals)


def compare(path_a, path_b, field: str, *, count: bool = False) -> dict:
    """File A is the reference. Deltas are B minus A."""
    paired = align(path_a, path_b, field, count=count)
    a, b = paired["a"], paired["b"]
    n = int(len(a))
    if n == 0:
        raise SystemExit("compare: no paired requirements left after dropping infra errors")
    if count:
        a_stat, b_stat = float(a.mean()), float(b.mean())
        delta = b_stat - a_stat
        decimals = 2
        diffs = b - a
        sd = float(diffs.std(ddof=1)) if n > 1 else 0.0
        effect = float(diffs.mean() / sd) if sd else 0.0
        a_only = int(np.sum(a > b))
        b_only = int(np.sum(b > a))
        discordant = a_only + b_only
        p = 1.0 if discordant == 0 else float(
            binomtest(a_only, discordant, 0.5, alternative="two-sided").pvalue)
        test = {"a_only": a_only, "b_only": b_only, "p_raw": p, "p_tex": fmt_p_tex(p)}
    else:
        a_stat, b_stat = float(a.mean() * 100), float(b.mean() * 100)
        delta = b_stat - a_stat
        decimals = 1
        effect = cohens_h(b_stat / 100, a_stat / 100)
        test = mcnemar_exact(a, b)
    low, high = bootstrap_delta(a.astype(float), b.astype(float),
                                scale=1.0 if count else 100.0, decimals=decimals)
    return {
        "n": n,
        "a_pct": round(a_stat, decimals),
        "b_pct": round(b_stat, decimals),
        "delta_pp": fmt_signed(delta, decimals),
        "ci": fmt_ci(low, high, decimals),
        "h": round(effect, 3),
        "p_raw": test["p_raw"],
        "p_tex": test["p_tex"],
        "a_only": test["a_only"],
        "b_only": test["b_only"],
    }


def holm(pvals: list[float]) -> list[dict]:
    m = len(pvals)
    order = sorted(range(m), key=lambda i: pvals[i])
    adjusted = [0.0] * m
    running = 0.0
    for rank, index in enumerate(order):
        running = max(running, (m - rank) * pvals[index])
        adjusted[index] = min(1.0, running)
    return [{"p_raw": p, "p_adj": adj, "p_tex": fmt_p_tex(adj)}
            for p, adj in zip(pvals, adjusted)]


def _top1(row: dict) -> float:
    retrieval = row.get("retrieval") or {}
    scores = retrieval.get("scores") or []
    if not scores:
        raise SystemExit(f"selective: {row.get('req_id')} has no retrieval score")
    return float(scores[0])


def _best_threshold(scores, a, b) -> float:
    """Threshold with the highest training validity. Ties retrieve less often."""
    candidates = np.unique(scores)
    best_t, best_rate, best_n = float(np.max(scores) + 1.0), -1.0, 10 ** 9
    for threshold in list(candidates) + [float(np.max(scores) + 1.0)]:
        retrieve = scores >= threshold
        pred = np.where(retrieve, b, a)
        rate = float(pred.mean())
        n_retrieve = int(retrieve.sum())
        if rate > best_rate + 1e-12 or (abs(rate - best_rate) <= 1e-12 and n_retrieve < best_n):
            best_t, best_rate, best_n = float(threshold), rate, n_retrieve
    return best_t


def selective(path_a, path_b, field: str, *, folds: int = SELECTIVE_FOLDS) -> dict:
    paired = align(path_a, path_b, field, count=False)
    by_b = {row["req_id"]: row for row in load_jsonl(path_b)}
    scores = np.asarray([_top1(by_b[req_id]) for req_id in paired["ids"]], dtype=float)
    a = paired["a"].astype(float)
    b = paired["b"].astype(float)
    n = len(a)
    if n < folds:
        raise SystemExit(f"selective: {n} pairs is fewer than {folds} folds")
    order = np.random.default_rng(SEED).permutation(n)
    blocks = np.array_split(order, folds)
    chosen = np.zeros(n, dtype=bool)
    for fold, test in enumerate(blocks):
        train = np.concatenate([blocks[i] for i in range(folds) if i != fold])
        threshold = _best_threshold(scores[train], a[train], b[train])
        chosen[test] = scores[test] >= threshold
    selected = np.where(chosen, b, a)
    oracle = np.maximum(a, b)
    never, always = float(a.mean()), float(b.mean())
    best_is_always = always > never
    best = b if best_is_always else a
    best_name = "always" if best_is_always else "never"
    sel_rate = float(selected.mean())
    best_rate = float(best.mean())
    oracle_rate = float(oracle.mean())
    delta = (sel_rate - best_rate) * 100
    low, high = bootstrap_delta(best, selected, scale=100.0, decimals=1)
    gap = oracle_rate - best_rate
    recovery = 0.0 if abs(gap) < 1e-12 else (sel_rate - best_rate) / gap * 100
    versus_never = mcnemar_exact(a.astype(bool), selected.astype(bool))
    versus_always = mcnemar_exact(b.astype(bool), selected.astype(bool))
    return {
        "n": n,
        "selective_pct": round(sel_rate * 100, 1),
        "oracle_pct": round(oracle_rate * 100, 1),
        "never_pct": round(never * 100, 1),
        "always_pct": round(always * 100, 1),
        "best_fixed": best_name,
        "delta_vs_best_fixed_pp": fmt_signed(delta, 1),
        "ci_vs_best_fixed": fmt_ci(low, high, 1),
        "p_vs_never": versus_never["p_raw"],
        "p_vs_never_tex": versus_never["p_tex"],
        "p_vs_always": versus_always["p_raw"],
        "p_vs_always_tex": versus_always["p_tex"],
        "recovery_pct": round(recovery, 1),
        "oracle_minus_best_pp": round(gap * 100, 1),
    }


def _curve_y(a, b, scores) -> np.ndarray:
    order = np.argsort(-scores, kind="mergesort")
    a, b = a[order], b[order]
    n = len(a)
    out = np.empty(n + 1)
    out[0] = a.mean()
    running = a.astype(float).copy()
    for k in range(1, n + 1):
        running[k - 1] = b[k - 1]
        out[k] = running.mean()
    return out * 100


def curve(pdf_path: str, specs: list[str]) -> None:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    figure, axis = plt.subplots(figsize=(6.2, 3.4))
    for spec in specs:
        name, path_a, path_b = spec.split(":", 2)
        paired = align(path_a, path_b, "compile_valid", count=False)
        by_b = {row["req_id"]: row for row in load_jsonl(path_b)}
        scores = np.asarray([_top1(by_b[req_id]) for req_id in paired["ids"]])
        y = _curve_y(paired["a"], paired["b"], scores)
        x = np.linspace(0, 100, len(y))
        axis.plot(x, y, label=name)
        oracle = np.maximum(paired["a"], paired["b"]).mean() * 100
        axis.axhline(oracle, linestyle=":", linewidth=1)
    axis.set_xlabel("Requirements retrieving, highest top-1 score first (%)")
    axis.set_ylabel("Compile validity (%)")
    axis.legend(frameon=False)
    figure.tight_layout()
    figure.savefig(pdf_path)
    plt.close(figure)


def randomization_p(deltas: np.ndarray) -> float:
    deltas = np.asarray(deltas, dtype=float)
    if len(deltas) == 0:
        return 1.0
    observed = float(deltas.mean())
    rng = np.random.default_rng(SEED)
    signs = rng.choice(np.array([-1.0, 1.0]), size=(N_PERM, len(deltas)))
    null = (signs * deltas).mean(axis=1)
    return float((np.sum(np.abs(null) >= abs(observed) - 1e-15) + 1) / (N_PERM + 1))


def _grouped(labels: list[dict]) -> dict[str, list[dict]]:
    groups: dict[str, list[dict]] = {}
    for row in labels:
        groups.setdefault(row["req_id"], []).append(row)
    return groups


def _ndcg_at_5(gains: np.ndarray, scores: np.ndarray) -> float:
    if np.all(gains <= 0):
        return 0.0
    return float(ndcg_score(gains.reshape(1, -1), scores.reshape(1, -1), k=5))


def _block_metrics(groups: dict[str, list[dict]], members) -> dict:
    """members(rows) -> the exemplars in this block for one requirement."""
    gains, helps, hurts, ndcgs = [], [], [], []
    for rows in groups.values():
        chosen = members(rows)
        if not chosen:
            continue
        g0 = chosen[0]["g0"]
        gain = np.asarray([row["gain"] for row in chosen], dtype=float)
        gains.append(float(gain.mean()))
        helps.append(float(np.mean(gain > g0)))
        hurts.append(float(np.mean(gain < g0)))
    return {
        "gain": round(float(np.mean(gains)), 2) if gains else 0.0,
        "help": round(float(np.mean(helps) * 100), 1) if helps else 0.0,
        "hurt": round(float(np.mean(hurts) * 100), 1) if hurts else 0.0,
        "_per_req_gain": gains,
    }


def _retriever_members(name: str):
    def members(rows: list[dict]) -> list[dict]:
        ranked = [row for row in rows if (row.get("ranks") or {}).get(name)]
        ranked.sort(key=lambda row: row["ranks"][name])
        return [row for row in ranked if 1 <= row["ranks"][name] <= 5][:5]
    return members


def pool(path: str) -> dict:
    labels = load_jsonl(path)
    groups = _grouped(labels)
    out = {
        "n_req": len(groups),
        "n_labels": len(labels),
        "poolsize": round(float(np.mean([len(rows) for rows in groups.values()])), 1) if groups else 0.0,
        "a0_gain": round(float(np.mean([rows[0]["g0"] for rows in groups.values()])), 2) if groups else 0.0,
    }
    random_block = _block_metrics(groups, lambda rows: [row for row in rows if row.get("random")])
    out["rand"] = {key: random_block[key] for key in ("gain", "help", "hurt")}
    for name in ("cos", "bm25", "dense"):
        block = _block_metrics(groups, _retriever_members(name))
        ndcgs = []
        gain_deltas = []
        for rows in groups.values():
            gains = np.asarray([row["gain"] for row in rows], dtype=float)
            scores = np.asarray([
                float((row.get("features") or {}).get(f"{name}_score") or 0) for row in rows
            ])
            ndcgs.append(_ndcg_at_5(gains, scores))
        for rows in groups.values():
            chosen = _retriever_members(name)(rows)
            randoms = [row for row in rows if row.get("random")]
            if chosen and randoms:
                gain_deltas.append(
                    float(np.mean([row["gain"] for row in chosen]))
                    - float(np.mean([row["gain"] for row in randoms]))
                )
        p = randomization_p(np.asarray(gain_deltas))
        out[name] = {
            "gain": block["gain"],
            "help": block["help"],
            "hurt": block["hurt"],
            "ndcg": round(float(np.mean(ndcgs)), 2) if ndcgs else 0.0,
            "gain_minus_random": fmt_signed(float(np.mean(gain_deltas)) if gain_deltas else 0.0, 2),
            "p_gain_vs_random": p,
            "p_tex": fmt_p_tex(p),
        }
    return out


def _feature_frame(rows: list[dict], features: list[str]):
    frame = pd.DataFrame([{
        **{name: (row.get("features") or {}).get(name, np.nan) for name in features},
        "gain": row["gain"],
        "g0": row.get("g0", 0),
        "req_id": row["req_id"],
        "exemplar_id": row.get("exemplar_id"),
    } for row in rows])
    keep = []
    for name in features:
        values = pd.to_numeric(frame[name], errors="coerce")
        frame[name] = values.fillna(values.mean() if values.notna().any() else 0.0)
        if float(frame[name].std(ddof=0)) > 0:
            keep.append(name)
    return frame, keep


def _expected_gain(model: LogisticRegression, matrix: np.ndarray) -> np.ndarray:
    if not hasattr(model, "n_features_in_"):
        return np.full(len(matrix), float(model.classes_[0]))
    proba = model.predict_proba(matrix)
    classes = np.asarray(model.classes_, dtype=float)
    return proba @ classes


def rerank_cv(path: str, features: list[str], *, folds: int = RERANK_FOLDS) -> dict:
    rows = load_jsonl(path)
    frame, keep = _feature_frame(rows, features)
    if not keep:
        raise SystemExit("rerank-cv: every feature is constant")
    groups = frame["req_id"].to_numpy()
    n_groups = len(set(groups))
    if n_groups < folds:
        raise SystemExit(f"rerank-cv: {n_groups} requirements is fewer than {folds} folds")
    predicted = np.zeros(len(frame))
    y = frame["gain"].to_numpy()
    splitter = GroupKFold(n_splits=folds)
    for train, test in splitter.split(frame, y, groups):
        model = _fit_gain(frame.iloc[train], keep)
        predicted[test] = _expected_gain(model, _standardize(frame.iloc[train], frame.iloc[test], keep))
    scored = frame.copy()
    scored["pred"] = predicted
    return _score_predictions(scored, rows)


def _fit_gain(train: pd.DataFrame, features: list[str]) -> LogisticRegression:
    matrix = _standardize(train, train, features)
    target = train["gain"].to_numpy()
    model = LogisticRegression(max_iter=500)
    if len(set(target)) < 2:
        model.classes_ = np.array([target[0]])
        model.intercept_ = np.zeros(1)
        model.coef_ = np.zeros((1, matrix.shape[1]))
        return model
    model.fit(matrix, target)
    return model


def _standardize(train: pd.DataFrame, test: pd.DataFrame, features: list[str]) -> np.ndarray:
    mean = train[features].mean()
    std = train[features].std(ddof=0).replace(0, 1.0)
    return ((test[features] - mean) / std).to_numpy(dtype=float)


def _score_predictions(scored: pd.DataFrame, rows: list[dict]) -> dict:
    by_req: dict[str, pd.DataFrame] = {req: part for req, part in scored.groupby("req_id")}
    label_groups = _grouped(rows)
    gains, helps, hurts, ndcgs = [], [], [], []
    per_ndcg = {name: [] for name in ("cos", "bm25", "dense", "rr")}
    for req_id, part in by_req.items():
        labels = label_groups[req_id]
        g0 = labels[0]["g0"]
        top = part.sort_values(["pred", "exemplar_id"], ascending=[False, True]).head(5)
        gain = top["gain"].to_numpy(dtype=float)
        gains.append(float(gain.mean()))
        helps.append(float(np.mean(gain > g0)))
        hurts.append(float(np.mean(gain < g0)))
        all_gains = part["gain"].to_numpy(dtype=float)
        per_ndcg["rr"].append(_ndcg_at_5(all_gains, part["pred"].to_numpy(dtype=float)))
        for name in ("cos", "bm25", "dense"):
            column = f"{name}_score"
            scores = part[column].to_numpy(dtype=float) if column in part else np.zeros(len(part))
            per_ndcg[name].append(_ndcg_at_5(all_gains, scores))
        ndcgs.append(per_ndcg["rr"][-1])
    result = {
        "gain": round(float(np.mean(gains)), 2),
        "help": round(float(np.mean(helps) * 100), 1),
        "hurt": round(float(np.mean(hurts) * 100), 1),
        "ndcg": round(float(np.mean(ndcgs)), 2),
    }
    rr = np.asarray(per_ndcg["rr"])
    for name in ("cos", "bm25", "dense"):
        other = np.asarray(per_ndcg[name])
        p = randomization_p(rr - other)
        result[f"ndcg_minus_{name}"] = fmt_signed(float((rr - other).mean()), 2)
        result[f"p_vs_{name}"] = p
        result[f"p_vs_{name}_tex"] = fmt_p_tex(p)
    return result


def rerank_apply(labels_path, cands_path, features: list[str], out_path: str) -> None:
    labels = load_jsonl(labels_path)
    frame, keep = _feature_frame(labels, features)
    model = _fit_gain(frame, keep)
    by_req: dict[str, list[dict]] = {}
    for row in load_jsonl(cands_path):
        by_req.setdefault(row["req_id"], []).append(row)
    lines = []
    for req_id, cands in by_req.items():
        cand_frame, _ = _feature_frame([
            {"features": cand.get("features") or {}, "gain": 0, "g0": 0,
             "req_id": req_id, "exemplar_id": cand["exemplar_id"]}
            for cand in cands
        ], keep)
        scores = _expected_gain(model, _standardize(frame, cand_frame, keep))
        order = np.argsort(-scores, kind="mergesort")[:5]
        lines.append(json.dumps({
            "req_id": req_id,
            "exemplar_ids": [cands[i]["exemplar_id"] for i in order],
            "scores": [round(float(scores[i]), 4) for i in order],
        }))
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    Path(out_path).write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def classify_solc(message: str) -> str:
    low = (message or "").lower()
    if ("source \"" in low and "not found" in low) or "file import callback" in low:
        return "imp"
    if "pragma" in low or "compiler version" in low or "requires different compiler" in low:
        return "ver"
    if "undeclared identifier" in low or "declarationerror" in low:
        return "und"
    if "typeerror" in low or "type error" in low:
        return "type"
    if "parsererror" in low or "parser error" in low:
        return "parse"
    return "other"


def _classes_of(row: dict) -> list[str]:
    if _status(row) == "infra_error":
        return []
    if row.get("compiler_error_classes"):
        return [item if item in CLASS_ORDER else classify_solc(str(item))
                for item in row["compiler_error_classes"]]
    messages = row.get("compiler_errors") or []
    return [classify_solc(str(item)) for item in messages]


def errors(paths: dict[str, str]) -> dict:
    """paths maps arm name (a0, a1, alt, rand) to a results.jsonl."""
    rates = {}
    for arm, path in paths.items():
        rows = [row for row in load_jsonl(path) if _status(row) != "infra_error"]
        counts = {name: 0 for name in CLASS_ORDER}
        for row in rows:
            for name in _classes_of(row):
                counts[name] += 1
        n = max(len(rows), 1)
        rates[arm] = {name: counts[name] / n for name in CLASS_ORDER}
        rates[arm]["n"] = len(rows)
        rates[arm]["total"] = sum(counts.values()) / n
    increases = {name: rates["a1"][name] - rates["a0"][name] for name in CLASS_ORDER}
    positive = sum(value for value in increases.values() if value > 0)
    top = max(CLASS_ORDER, key=lambda name: increases[name])
    share = 0.0 if positive <= 0 else increases[top] / positive * 100
    flat = {}
    for name in CLASS_ORDER:
        for arm in paths:
            flat[f"A1.{name}.{arm}"] = f"{rates[arm][name]:.2f}"
    flat["A1.top.class"] = CLASS_WORDS[top]
    flat["A1.top.share"] = f"{share:.1f}"
    flat["totals"] = {arm: f"{rates[arm]['total']:.2f}" for arm in paths}
    return flat


def _logit_or(y, x, groups=None) -> dict:
    frame = pd.DataFrame(x)
    keep = [col for col in frame.columns if frame[col].std(ddof=1) > 0]
    if not keep:
        raise SystemExit("logit: every predictor is constant")
    standardized = (frame[keep] - frame[keep].mean()) / frame[keep].std(ddof=1)
    model = sm.Logit(np.asarray(y), sm.add_constant(standardized))
    if groups is None:
        fit = model.fit(disp=0)
    else:
        fit = model.fit(disp=0, cov_type="cluster",
                        cov_kwds={"groups": pd.factorize(groups)[0]})
    ci = np.exp(fit.conf_int())
    rows = {}
    for name in keep:
        rows[name] = {
            "or": round(float(np.exp(fit.params[name])), 2),
            "ci": fmt_ci(float(ci.loc[name, 0]), float(ci.loc[name, 1]), 2),
            "p": float(fit.pvalues[name]),
            "p_tex": fmt_p_tex(float(fit.pvalues[name])),
        }
    return rows


def a14(path: str) -> dict:
    rows = [row for row in load_jsonl(path) if _status(row) != "infra_error"]
    y, score = [], []
    for row in rows:
        retrieval = row.get("retrieval") or {}
        scores = retrieval.get("scores") or []
        if not scores or row.get("compile_valid") is None:
            continue
        y.append(int(bool(row["compile_valid"])))
        score.append(float(scores[0]))
    fitted = _logit_or(y, {"top1": score})
    item = fitted["top1"]
    return {"or": f"{item['or']:.2f}", "orci": item["ci"], "p": item["p"], "p_tex": item["p_tex"], "n": len(y)}


def agree(path_a: str, path_b: str) -> dict:
    """U2: percent identical gains and Cohen's kappa on paired label files."""
    by_b = {(row["req_id"], row["exemplar_id"]): row for row in load_jsonl(path_b)}
    first, second = [], []
    for row in load_jsonl(path_a):
        other = by_b.get((row["req_id"], row["exemplar_id"]))
        if other is None or _status(row) == "infra_error" or _status(other) == "infra_error":
            continue
        first.append(int(row["gain"]))
        second.append(int(other["gain"]))
    if not first:
        raise SystemExit("agree: no paired labels")
    identical = sum(a == b for a, b in zip(first, second)) / len(first) * 100
    return {
        "n": len(first),
        "agree": round(identical, 1),
        "kappa": round(float(cohen_kappa_score(first, second)), 2),
    }


def harm(path: str) -> dict:
    rows = load_jsonl(path)
    frame = pd.DataFrame([{
        **{name: (row.get("features") or {}).get(name, np.nan) for name in HARM_FEATURES},
        "hurts": int(row["gain"] < row["g0"]),
        "req_id": row["req_id"],
    } for row in rows])
    for name in HARM_FEATURES:
        frame[name] = pd.to_numeric(frame[name], errors="coerce").fillna(0.0)
    fitted = _logit_or(frame["hurts"], frame[HARM_FEATURES], groups=frame["req_id"])
    significant = {name: item for name, item in fitted.items() if item["p"] < 0.05}
    if not significant:
        return {"feat": "", "or": "", "orci": "", "fitted": fitted}
    feat = max(significant, key=lambda name: significant[name]["or"])
    return {
        "feat": feat.replace("_", " "),
        "or": f"{significant[feat]['or']:.2f}",
        "orci": significant[feat]["ci"],
        "p": significant[feat]["p"],
        "fitted": fitted,
    }


def _code_line(line: str) -> str:
    """Drop a full-line comment and an unescaped trailing comment."""
    if line.lstrip().startswith("%"):
        return ""
    return re.sub(r"(?<!\\)%.*", "", line)


def extract_keys(tex: str) -> list[tuple[str, int]]:
    found = []
    for lineno, line in enumerate(tex.splitlines(), 1):
        code = _code_line(line)
        for match in TBD_RE.finditer(code):
            found.append((match.group(1), lineno))
        for match in VERIFY_RE.finditer(code):
            found.append((match.group(2), lineno))
    return found


def template(tex_path: str, json_path: str) -> dict:
    tex = Path(tex_path).read_text(encoding="utf-8")
    values = {}
    for key, _lineno in extract_keys(tex):
        values.setdefault(key, "")
    Path(json_path).write_text(json.dumps(values, indent=2) + "\n", encoding="utf-8")
    return values


def keys(tex_path: str) -> list[tuple[str, list[int]]]:
    grouped: dict[str, list[int]] = {}
    for key, lineno in extract_keys(Path(tex_path).read_text(encoding="utf-8")):
        grouped.setdefault(key, []).append(lineno)
    return list(grouped.items())


def set_key(json_path: str, key: str, value: str) -> None:
    path = Path(json_path)
    values = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    values[key] = value
    path.write_text(json.dumps(values, indent=2) + "\n", encoding="utf-8")


def fill(tex_path: str, json_path: str) -> list[str]:
    tex = Path(tex_path).read_text(encoding="utf-8")
    values = json.loads(Path(json_path).read_text(encoding="utf-8"))
    missing = []

    def replace_tbd(match: re.Match) -> str:
        value = values.get(match.group(1), "")
        if value == "":
            missing.append(match.group(1))
            return match.group(0)
        return str(value)

    def replace_verify(match: re.Match) -> str:
        value = values.get(match.group(2), "")
        if value == "":
            missing.append(match.group(2))
            return match.group(0)
        return str(value)

    filled = VERIFY_RE.sub(replace_verify, TBD_RE.sub(replace_tbd, tex))
    out = Path(tex_path).with_name(Path(tex_path).stem + ".filled.tex")
    out.write_text(filled, encoding="utf-8")
    return sorted(set(missing))


def _print(obj) -> None:
    print(json.dumps(obj, indent=2))


def self_test() -> None:
    """Synthetic checks, including the 69.6 vs 58.2 ladder rates on 500 pairs."""
    import tempfile
    n = 500
    # 271 both, 77 A only, 20 B only, 132 neither -> 69.6% and 58.2%.
    a = np.array([True] * 348 + [False] * 152)
    b = np.array([True] * 271 + [False] * 77 + [True] * 20 + [False] * 132)
    assert a.sum() == 348 and b.sum() == 291
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        def dump(name, flags, scores=None):
            lines = []
            for i, flag in enumerate(flags):
                row = {"req_id": f"R{i}", "status": "ok", "compile_valid": bool(flag),
                       "n_compiler_errors": 0 if flag else 1}
                if scores is not None:
                    row["retrieval"] = {"scores": [float(scores[i])], "exemplar_ids": ["e"]}
                lines.append(json.dumps(row))
            (root / name).write_text("\n".join(lines) + "\n", encoding="utf-8")
        dump("a.jsonl", a, np.linspace(0, 1, n))
        dump("b.jsonl", b, np.linspace(1, 0, n))
        result = compare(root / "a.jsonl", root / "b.jsonl", "compile_valid")
        assert result["a_pct"] == 69.6, result
        assert result["b_pct"] == 58.2, result
        assert result["delta_pp"] == "-11.4", result
        assert result["n"] == 500
        assert result["a_only"] == 77 and result["b_only"] == 20
        # empty output counts as failure; infra error leaves the pair out
        (root / "empty.jsonl").write_text(json.dumps({
            "req_id": "R0", "status": "empty_output", "compile_valid": True}) + "\n", encoding="utf-8")
        (root / "one.jsonl").write_text(json.dumps({
            "req_id": "R0", "status": "ok", "compile_valid": True}) + "\n", encoding="utf-8")
        emptied = compare(root / "one.jsonl", root / "empty.jsonl", "compile_valid")
        assert emptied["b_pct"] == 0.0, emptied
        adjusted = holm([0.01, 0.04, 0.03])
        assert adjusted[0]["p_adj"] == 0.03
        assert abs(adjusted[1]["p_adj"] - 0.06) < 1e-12
        tiny = Path(tex_path_text(root))
        values = template(str(tiny), str(root / "ph.json"))
        assert values == {"R1.sol.cv": "", "V.p.sol": ""}
        set_key(str(root / "ph.json"), "R1.sol.cv", "71.2")
        missing = fill(str(tiny), str(root / "ph.json"))
        assert missing == ["V.p.sol"]
        filled = (root / "tiny.filled.tex").read_text(encoding="utf-8")
        assert "71.2" in filled and r"\verify" in filled
        # Pool: one requirement, cosine ranks the higher gain first.
        labels = [
            {"req_id": "Q", "exemplar_id": "c", "gain": 2, "g0": 1, "random": False,
             "ranks": {"cos": 1, "bm25": 2, "dense": None},
             "features": {"cos_score": 0.9, "bm25_score": 0.2, "dense_score": 0.1}},
            {"req_id": "Q", "exemplar_id": "d", "gain": 0, "g0": 1, "random": False,
             "ranks": {"cos": 2, "bm25": 1, "dense": None},
             "features": {"cos_score": 0.4, "bm25_score": 0.8, "dense_score": 0.1}},
            {"req_id": "Q", "exemplar_id": "r", "gain": 1, "g0": 1, "random": True,
             "ranks": {"cos": None, "bm25": None, "dense": None},
             "features": {"cos_score": 0.0, "bm25_score": 0.0, "dense_score": 0.0}},
        ]
        (root / "labels.jsonl").write_text(
            "\n".join(json.dumps(row) for row in labels) + "\n", encoding="utf-8")
        pooled = pool(str(root / "labels.jsonl"))
        assert pooled["cos"]["gain"] == 1.0, pooled
        assert pooled["a0_gain"] == 1.0
        assert classify_solc('Source "Foo.sol" not found') == "imp"
        assert classify_solc("ParserError: expected ';'") == "parse"
        assert fmt_p_tex(0.027) == "0.027"
        assert fmt_p_tex(0.0014) == "1.4\\times10^{-3}"
    print("self-test ok")


def tex_path_text(root: Path) -> Path:
    path = root / "tiny.tex"
    path.write_text("rate \\tbd{R1.sol.cv} p \\verify{0.014}{V.p.sol}\n", encoding="utf-8")
    return path


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv:
        print(__doc__)
        return 2
    cmd, rest = argv[0], argv[1:]
    if cmd == "template":
        values = template(rest[0], rest[1])
        print(f"{len(values)} keys -> {rest[1]}")
    elif cmd == "keys":
        for key, lines in keys(rest[0]):
            print(f"{key}\t{', '.join(map(str, lines))}")
    elif cmd == "set":
        set_key(rest[0], rest[1], rest[2])
    elif cmd == "fill":
        missing = fill(rest[0], rest[1])
        print(f"{len(missing)} unfilled")
        for key in missing:
            print(key)
    elif cmd == "compare":
        count = "--count" in rest
        args = [item for item in rest if item != "--count"]
        _print(compare(args[0], args[1], args[2], count=count))
    elif cmd == "holm":
        _print(holm([float(item) for item in rest]))
    elif cmd == "selective":
        _print(selective(rest[0], rest[1], rest[2]))
    elif cmd == "curve":
        curve(rest[0], rest[1:])
        print(rest[0])
    elif cmd == "pool":
        _print(pool(rest[0]))
    elif cmd == "rerank-cv":
        _print(rerank_cv(rest[0], rest[1].split(",")))
    elif cmd == "rerank-apply":
        rerank_apply(rest[0], rest[1], rest[2].split(","), rest[3])
        print(rest[3])
    elif cmd == "errors":
        arms = ("a0", "a1", "alt", "rand")
        _print(errors(dict(zip(arms, rest))))
    elif cmd == "a14":
        _print(a14(rest[0]))
    elif cmd == "harm":
        _print(harm(rest[0]))
    elif cmd == "agree":
        _print(agree(rest[0], rest[1]))
    elif cmd == "self-test":
        self_test()
    elif cmd == "check-ladder":
        result = compare(rest[0], rest[1], "compile_valid")
        _print(result)
        if result["a_pct"] != 69.6 or result["b_pct"] != 58.2 or result["delta_pp"] != "-11.4":
            print("STOP: Solidity A0 vs A1 is not 69.6% vs 58.2% (−11.4 pp). Tell SV.",
                  file=sys.stderr)
            return 1
        print("ladder check ok")
    else:
        print(f"unknown command {cmd}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
