"""Paired naive-vs-full statistics shared by the per-domain analysis scripts.

The tests are the ones used in nl2sysml/comparison_results.ipynb (power analysis
section), lifted out of the notebook so the Solidity and Modelica scripts run
the identical procedure:

    proportions  -> McNemar (exact binomial on discordant pairs), Cohen's h
    continuous   -> Wilcoxon signed-rank, rank-biserial r, Cohen's d_z
    all          -> Holm-Bonferroni across the whole metric family, power, and
                    the n needed for 80% power

Conventions
    * Every metric is PAIRED: entry i of `naive` and `full` is the same prompt.
    * `delta` is always `full - naive` in the metric's own units.
    * `effect` is signed so that POSITIVE = the full pipeline is better,
      regardless of whether the metric is lower-is-better.

numpy + stdlib only (no scipy), so it runs on a bare PACE venv.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from math import asin, comb, erfc, sqrt
from statistics import NormalDist
from typing import Any, Optional, Sequence

import numpy as np

ALPHA = 0.05
_N = NormalDist()


@dataclass
class PairedMetric:
    name: str
    kind: str                       # "proportion" | "continuous"
    naive: list                     # bool/0-1 flags, or floats
    full: list
    ids: list = field(default_factory=list)
    lower_is_better: bool = False
    unit: str = ""
    note: str = ""

    @classmethod
    def from_pairs(cls, name: str, kind: str, pairs: Sequence[tuple],
                   **kw) -> "PairedMetric":
        """Build from (id, naive_value, full_value); drop pairs where either
        side is None (metric unavailable for that sample)."""
        kept = [(i, a, b) for i, a, b in pairs if a is not None and b is not None]
        return cls(name=name, kind=kind, ids=[k[0] for k in kept],
                   naive=[k[1] for k in kept], full=[k[2] for k in kept], **kw)


# ---- primitives -------------------------------------------------------------
def p_from_z(z: float) -> float:
    """Two-sided normal p-value via erfc. NormalDist.cdf computes 0.5*(1+erf(x)),
    which cancels to exactly 0 for |z| >~ 8 and would floor every large effect."""
    return max(erfc(abs(z) / sqrt(2)), 1e-300)


def fmt_p(p: Optional[float]) -> str:
    if p is None:
        return "n/a"
    return "< 1e-300" if p <= 1e-300 else (f"{p:.3g}" if p >= 1e-4 else f"{p:.2e}")


def cohens_h(p1: float, p2: float) -> float:
    """Arcsine-transformed distance between two proportions (p1 - p2)."""
    return 2 * asin(sqrt(p1)) - 2 * asin(sqrt(p2))


def cohens_dz(diffs) -> float:
    d = np.asarray(diffs, dtype=float)
    if len(d) < 2:
        return 0.0
    sd = d.std(ddof=1)
    return float(d.mean() / sd) if sd > 0 else 0.0


def wilson_ci(k: int, n: int, alpha: float = ALPHA) -> tuple[float, float]:
    """Wilson score interval for a proportion, as percentages. Unlike the Wald
    interval it stays inside [0, 100] and behaves at rates near 0% or 100%."""
    if n == 0:
        return (0.0, 0.0)
    z = _N.inv_cdf(1 - alpha / 2)
    p = k / n
    denom = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / denom
    half = z * sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denom
    return (max(0.0, centre - half) * 100, min(1.0, centre + half) * 100)


def bootstrap_mean_ci(values, *, samples: int = 5000, seed: int = 20260920,
                      alpha: float = ALPHA) -> tuple[float, float]:
    """Percentile bootstrap CI of the mean (skew-safe; no normality assumed)."""
    v = np.asarray(values, dtype=float)
    if len(v) < 2:
        return (float(v.mean()) if len(v) else 0.0,) * 2
    rng = np.random.default_rng(seed)
    # Chunked so n=~1500 x 5000 resamples stays a few MB, not a few hundred.
    means = np.empty(samples)
    chunk = 500
    for s in range(0, samples, chunk):
        m = min(chunk, samples - s)
        idx = rng.integers(0, len(v), size=(m, len(v)))
        means[s:s + m] = v[idx].mean(axis=1)
    return (float(np.quantile(means, alpha / 2)), float(np.quantile(means, 1 - alpha / 2)))


def mcnemar(naive_flags, full_flags) -> dict:
    """Paired nominal test on DISCORDANT pairs only.

    b = naive passed / full failed, c = naive failed / full passed. Exact
    binomial up to 1000 discordants, continuity-corrected normal above.
    """
    b = sum(1 for x, y in zip(naive_flags, full_flags) if x and not y)
    c = sum(1 for x, y in zip(naive_flags, full_flags) if y and not x)
    nd = b + c
    if nd == 0:
        return {"b": b, "c": c, "n_discordant": 0, "p": 1.0, "z": 0.0, "exact": True}
    z = (abs(c - b) - 1) / sqrt(nd)
    if nd <= 1000:
        tail = sum(comb(nd, i) for i in range(min(b, c) + 1)) / (2 ** nd)
        return {"b": b, "c": c, "n_discordant": nd, "p": min(1.0, 2 * tail),
                "z": z, "exact": True}
    return {"b": b, "c": c, "n_discordant": nd, "p": p_from_z(z), "z": z, "exact": False}


def _ranks(vals: np.ndarray) -> np.ndarray:
    """Average ranks (ties share their mean rank)."""
    order = np.argsort(vals, kind="mergesort")
    r = np.empty(len(vals), dtype=float)
    i = 0
    while i < len(order):
        j = i
        while j + 1 < len(order) and vals[order[j + 1]] == vals[order[i]]:
            j += 1
        r[order[i:j + 1]] = (i + j) / 2 + 1
        i = j + 1
    return r


def wilcoxon(diffs) -> dict:
    """Signed-rank test on paired differences (+ = improvement) with the
    matched-pairs rank-biserial r. Zero differences are dropped."""
    d = np.asarray([x for x in diffs if x != 0], dtype=float)
    nr = len(d)
    if nr == 0:
        return {"n_nonzero": 0, "p": 1.0, "z": 0.0, "rb": 0.0, "w_plus": 0.0, "w_minus": 0.0}
    r = _ranks(np.abs(d))
    w_plus, w_minus = float(r[d > 0].sum()), float(r[d < 0].sum())
    mu = nr * (nr + 1) / 4
    _, counts = np.unique(np.abs(d), return_counts=True)
    tie_corr = float(sum(t ** 3 - t for t in counts))
    var = nr * (nr + 1) * (2 * nr + 1) / 24 - tie_corr / 48
    z = (w_plus - mu - np.sign(w_plus - mu) * 0.5) / sqrt(var) if var > 0 else 0.0
    rb = (w_plus - w_minus) / (w_plus + w_minus) if (w_plus + w_minus) else 0.0
    return {"n_nonzero": nr, "p": p_from_z(float(z)), "z": float(z), "rb": float(rb),
            "w_plus": w_plus, "w_minus": w_minus}


def _power_from_lambda(lam: float, alpha: float) -> float:
    zc = _N.inv_cdf(1 - alpha / 2)
    return _N.cdf(lam - zc) + _N.cdf(-lam - zc)


def power_two_proportions(h: float, n_per_group: int, alpha: float = ALPHA) -> float:
    return _power_from_lambda(abs(h) * sqrt(n_per_group / 2), alpha)


def power_mcnemar(b: int, c: int, alpha: float = ALPHA) -> float:
    """Observed power of McNemar from its own discordants (post hoc)."""
    nd = b + c
    return _power_from_lambda(sqrt(nd) * abs(2 * c / nd - 1), alpha) if nd else 0.0


def power_paired(dz: float, n_pairs: int, alpha: float = ALPHA) -> float:
    """Paired-t power at d_z; conservative (lower bound) for Wilcoxon on skewed data."""
    return _power_from_lambda(abs(dz) * sqrt(n_pairs), alpha)


def n_for_power(effect: float, target: float = 0.80, alpha: float = ALPHA,
                paired: bool = True) -> float:
    if not effect:
        return float("inf")
    zc, zb = _N.inv_cdf(1 - alpha / 2), _N.inv_cdf(target)
    return int(np.ceil((1 if paired else 2) * ((zc + zb) / effect) ** 2))


def min_detectable_effect(n: int, target: float = 0.80, alpha: float = ALPHA,
                          paired: bool = True) -> float:
    """Effect size (h or d_z) detectable with `target` power at this n."""
    if n <= 0:
        return float("inf")
    zc, zb = _N.inv_cdf(1 - alpha / 2), _N.inv_cdf(target)
    return (zc + zb) / sqrt(n if paired else n / 2)


def effect_label(x: float, kind: str = "d") -> str:
    a = abs(x)
    if kind == "rb":
        return "large" if a >= 0.5 else "medium" if a >= 0.3 else "small" if a >= 0.1 else "negligible"
    return "large" if a >= 0.8 else "medium" if a >= 0.5 else "small" if a >= 0.2 else "negligible"


def holm(pvals: Sequence[float]) -> list[float]:
    """Holm-Bonferroni adjusted p-values."""
    m = len(pvals)
    order = sorted(range(m), key=lambda i: pvals[i])
    adj, running = [0.0] * m, 0.0
    for rank, i in enumerate(order):
        running = max(running, (m - rank) * pvals[i])
        adj[i] = min(1.0, running)
    return adj


# ---- driver -----------------------------------------------------------------
def analyze_metric(m: PairedMetric, alpha: float = ALPHA) -> dict[str, Any]:
    n = len(m.naive)
    base = {"metric": m.name, "kind": m.kind, "n": n, "unit": m.unit,
            "lower_is_better": m.lower_is_better, "note": m.note}
    if n == 0:
        return {**base, "skipped": True, "p": None}

    if m.kind == "proportion":
        a = [bool(x) for x in m.naive]
        b = [bool(x) for x in m.full]
        ka, kb = sum(a), sum(b)
        p_naive, p_full = ka / n, kb / n
        h = cohens_h(p_full, p_naive)
        mc = mcnemar(a, b)
        return {
            **base, "skipped": False,
            "naive": p_naive * 100, "full": p_full * 100, "delta": (p_full - p_naive) * 100,
            "naive_ci": wilson_ci(ka, n, alpha), "full_ci": wilson_ci(kb, n, alpha),
            "effect_name": "Cohen's h", "effect": h, "effect_label": effect_label(h),
            "test": "McNemar (exact)" if mc["exact"] else "McNemar (normal approx.)",
            "p": mc["p"], "naive_only": mc["b"], "full_only": mc["c"],
            "n_discordant": mc["n_discordant"],
            "power": power_mcnemar(mc["b"], mc["c"]),
            "power_unpaired": power_two_proportions(h, n, alpha),
            "n_needed": n_for_power(h, alpha=alpha, paired=False),
            "mde": min_detectable_effect(n, alpha=alpha, paired=False),
        }

    a = np.asarray(m.naive, dtype=float)
    b = np.asarray(m.full, dtype=float)
    diffs = b - a
    signed = -diffs if m.lower_is_better else diffs
    wc = wilcoxon(signed)
    dz = cohens_dz(signed)
    return {
        **base, "skipped": False,
        "naive": float(a.mean()), "full": float(b.mean()), "delta": float(diffs.mean()),
        "median_delta": float(np.median(b) - np.median(a)),
        "naive_ci": bootstrap_mean_ci(a), "full_ci": bootstrap_mean_ci(b),
        "delta_ci": bootstrap_mean_ci(diffs),
        "effect_name": "Cohen's d_z", "effect": dz, "effect_label": effect_label(dz),
        "rb": wc["rb"], "rb_label": effect_label(wc["rb"], "rb"),
        "test": "Wilcoxon signed-rank", "p": wc["p"],
        "n_nonzero": wc["n_nonzero"],
        "full_better": int((signed > 0).sum()), "full_worse": int((signed < 0).sum()),
        "tied": int((signed == 0).sum()),
        "power": power_paired(dz, n, alpha),
        "n_needed": n_for_power(dz, alpha=alpha, paired=True),
        "mde": min_detectable_effect(n, alpha=alpha, paired=True),
    }


def analyze(metrics: Sequence[PairedMetric], alpha: float = ALPHA) -> list[dict]:
    """Run every metric, then Holm-adjust across the (non-skipped) family."""
    results = [analyze_metric(m, alpha) for m in metrics]
    live = [r for r in results if not r["skipped"]]
    for r, adj in zip(live, holm([r["p"] for r in live])):
        r["p_holm"] = adj
    return results
