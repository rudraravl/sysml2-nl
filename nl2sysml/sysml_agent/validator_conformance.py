#!/usr/bin/env python3
"""Run the ANTLR validator over many files: gate 7.1 conformance, and the ANTLR-valid column.

Conformance (default): the 386 curated reference models dataset/data/000001-000386, all accepted by
our Xtext compiler. Reports the syntax-accept rate, each semantic check's flag rate (pre-registered
rule: a check that flags > 2% of the references is disabled in antlr_validator.CHECKS, logged in
DEVIATIONS.md, and this is re-run) and the top syntax-rejection causes.

Corpus mode: `--corpus dataset/naive_glm` scores <ID>/<ID>.sysml for every seed with SysMLAgent's
own metric (ANTLR-valid) and writes one record per ID.

    python nl2sysml/sysml_agent/validator_conformance.py [--workers 8]
    python nl2sysml/sysml_agent/validator_conformance.py --corpus dataset/best_of_6
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent.parent
sys.path.insert(0, str(_HERE))

REPORTS = _HERE / "reports"
FLAG_LIMIT = 0.02
ALL_CHECKS = ("duplicates", "unresolved")


def check_file(path: str) -> dict:
    """Syntax, then every semantic check separately (so each one's flag rate is measurable)."""
    import antlr_validator as av
    import signal

    def _alarm(signum, frame):
        raise TimeoutError()

    code = Path(path).read_text(encoding="utf-8") if Path(path).exists() else ""
    t0 = time.time()
    signal.signal(signal.SIGALRM, _alarm)
    signal.alarm(600)
    try:
        tree, syn = av.parse(code)
        info = {"unresolved_abstained": False}
        sem = {c: ([] if syn else av.semantic_errors(tree, (c,), info=info)) for c in ALL_CHECKS}
        out = {"path": path, "empty": not code.strip(), "syntax": syn, "semantic": sem,
               "timeout": False, **info}
    except TimeoutError:
        out = {"path": path, "empty": False, "syntax": [], "semantic": {}, "timeout": True,
               "unresolved_abstained": False}
    finally:
        signal.alarm(0)
    out["valid"] = (not out["empty"] and not out["timeout"] and not out["syntax"]
                    and not any(out["semantic"].get(c) for c in av.CHECKS))
    out["sec"] = round(time.time() - t0, 2)
    return out


def run(paths: list[str], workers: int) -> list[dict]:
    with ProcessPoolExecutor(max_workers=workers) as pool:
        return list(pool.map(check_file, paths, chunksize=1))


def _cause(msg: str) -> str:
    """Group ANTLR messages: keep the shape, drop the offending text and the expected-set."""
    msg = re.sub(r" expecting .*$", "", msg)
    return re.sub(r"'[^']*'", "'…'", msg)


def conformance(workers: int) -> dict:
    import antlr_validator as av
    ids = [f"{i:06d}" for i in range(1, 387)]
    paths = [str(_ROOT / "dataset" / "data" / i / f"{i}.sysml") for i in ids]
    res = run(paths, workers)
    n = len(res)
    syn_ok = [r for r in res if not r["syntax"] and not r["timeout"]]
    flags = {c: [Path(r["path"]).stem for r in syn_ok if r["semantic"].get(c)] for c in ALL_CHECKS}
    first = Counter(_cause(r["syntax"][0]["message"]) for r in res if r["syntax"])
    allmsg = Counter(_cause(e["message"]) for r in res for e in r["syntax"])
    split = lambda i: ("official" if i <= 250 else "community" if i <= 286 else  # noqa: E731
                       "pilot" if i <= 376 else "esa")
    by_split = Counter()
    acc_split = Counter()
    for r in res:
        s = split(int(Path(r["path"]).stem))
        by_split[s] += 1
        acc_split[s] += not r["syntax"] and not r["timeout"]
    return {
        "grammar": av.GRAMMAR_TAG,
        "checks_in_force": list(av.CHECKS),
        "n": n,
        "syntax_accept": len(syn_ok),
        "syntax_accept_rate": round(len(syn_ok) / n, 4),
        "syntax_accept_by_split": {s: f"{acc_split[s]}/{by_split[s]}" for s in by_split},
        "timeouts": sum(r["timeout"] for r in res),
        "semantic_flag_rate": {c: round(len(v) / n, 4) for c, v in flags.items()},
        "semantic_flag_rate_among_syntax_valid": {c: round(len(v) / max(len(syn_ok), 1), 4)
                                                  for c, v in flags.items()},
        "semantic_flagged_ids": flags,
        "semantic_examples": {c: [(Path(r["path"]).stem, r["semantic"][c][:3]) for r in syn_ok
                                  if r["semantic"].get(c)][:15] for c in ALL_CHECKS},
        "over_limit": [c for c, v in flags.items() if len(v) / n > FLAG_LIMIT],
        "fully_valid_with_checks_in_force": sum(r["valid"] for r in res),
        "top_first_syntax_error": first.most_common(15),
        "top_syntax_error": allmsg.most_common(15),
        "rejected": [(Path(r["path"]).stem, r["syntax"][0]) for r in res if r["syntax"]],
        "sec_mean": round(sum(r["sec"] for r in res) / n, 2),
        "sec_max": max(r["sec"] for r in res),
    }


def corpus(d: Path, workers: int, ids: list[str] | None = None) -> dict:
    sids = sorted(p.parent.name for p in d.glob("*/meta.json"))
    if ids:
        sids = [s for s in sids if s in set(ids)]
    res = run([str(d / s / f"{s}.sysml") for s in sids], workers)
    per = {s: {"antlr_valid": r["valid"], "empty": r["empty"], "timeout": r["timeout"],
               "unresolved_abstained": r["unresolved_abstained"],
               "n_syntax": len(r["syntax"]),
               **{f"n_{c}": len(r["semantic"].get(c, [])) for c in ALL_CHECKS}}
           for s, r in zip(sids, res)}
    return {"corpus": str(d), "n": len(per), "antlr_valid": sum(v["antlr_valid"] for v in per.values()),
            "unresolved_abstained": sum(v["unresolved_abstained"] for v in per.values()),
            "per_id": per}


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--corpus", type=Path, default=None)
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--out", type=Path, default=None)
    ap.add_argument("--ids", default=None, help="@file with one id per line: score only these seeds")
    a = ap.parse_args()
    REPORTS.mkdir(exist_ok=True)
    t0 = time.time()
    if a.corpus:
        ids = Path(a.ids[1:]).read_text().split() if a.ids else None
        r = corpus(a.corpus, a.workers, ids)
        out = a.out or REPORTS / f"antlr_valid_{a.corpus.name}{'_subset' if ids else ''}.json"
        print(f"{a.corpus}: ANTLR-valid {r['antlr_valid']}/{r['n']} "
              f"({r['antlr_valid'] / max(r['n'], 1):.1%}) | unresolved check abstained on "
              f"{r['unresolved_abstained']}")
    else:
        r = conformance(a.workers)
        out = a.out or REPORTS / "conformance.json"
        print(json.dumps({k: v for k, v in r.items()
                          if k not in ("rejected", "semantic_flagged_ids", "semantic_examples")},
                         indent=1, ensure_ascii=False))
        if r["over_limit"]:
            print(f"OVER THE {FLAG_LIMIT:.0%} LIMIT: {r['over_limit']} -> disable in "
                  f"antlr_validator.CHECKS, log in DEVIATIONS.md, re-run")
    out.write_text(json.dumps(r, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"-> {out} ({time.time() - t0:.0f}s)")
