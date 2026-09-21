#!/usr/bin/env python3
"""Toolchain sanity check for the naive arm's 0% compile rate.

Question: is "0 / 1,543 naive outputs compile" a finding about the LLM, or an artifact
of our compiler wrapper? Three checks, all through the *same* code path the naive
generator uses (`naive_glm_generate._postprocess` -> `compiler_interface.check_code`):

  1. Known-good corpus. Every human-authored model in the RAG corpus (`dataset/data`,
     ids 000001-000386: OMG Release / Pilot / community / ESA; the `agent` split is
     LLM-generated and is excluded) goes through the wrapper unchanged. A spotlight model
     (default 000086, OMG's SimpleVehicleModel, ~1.6k lines) is reported on its own.
  2. Negative controls. Small deliberate mutations of the spotlight model must flip
     valid -> invalid, so the pipeline is shown to discriminate rather than always pass.
  3. Reproducibility. A seeded sample of stored naive outputs is recompiled and compared
     with the diagnostics cached in their meta.json.

Calls the JVM checker (~4 s/file), so this is minutes, not seconds. Writes
`dataset/analysis_results/sysml_sanity/sanity_check.{json,md}`.

    python nl2sysml/handwritten_sanity_check.py
    python nl2sysml/handwritten_sanity_check.py --skip-corpus --repro-n 40
"""

import argparse
import collections
import json
import os
import random
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

_NL2 = Path(__file__).resolve().parent
_ROOT = _NL2.parent
sys.path.insert(0, str(_NL2))

from compiler_interface import check_code, is_compiler_available  # noqa: E402
from naive_glm_generate import _postprocess  # noqa: E402

DEFAULT_OUT = _ROOT / "dataset" / "analysis_results" / "sysml_sanity"


def check_like_naive(raw):
    """Mirror generate_one(): postprocess, compile, count as meta.json does."""
    code = _postprocess(raw)
    if not code:  # generate_one() never compiles empty output; it is recorded invalid
        return {"is_valid": False, "error_count": 0, "syntax_error_count": 0,
                "semantic_error_count": 0, "errors": []}
    result = check_code(code)
    return {
        "is_valid": result.is_valid,
        "error_count": len(result.errors),
        "syntax_error_count": sum(1 for e in result.errors if e.is_syntax_error()),
        "semantic_error_count": sum(1 for e in result.errors if e.is_semantic_error()),
        "errors": [{"line": e.line, "column": e.column, "message": e.message,
                    "severity": e.severity, "code": e.code} for e in result.errors],
    }


def real_corpus_ids():
    ids = []
    with (_ROOT / "dataset" / "index" / "manifest.jsonl").open() as fh:
        for line in fh:
            r = json.loads(line)
            if r["split"] != "agent":
                ids.append((r["id"], r["split"]))
    return ids


def run_corpus(workers, limit):
    entries = real_corpus_ids()[:limit]

    def one(entry):
        sid, split = entry
        raw = (_ROOT / "dataset" / "data" / sid / f"{sid}.sysml").read_text(encoding="utf-8")
        out = check_like_naive(raw)
        out.update(id=sid, split=split, lines=raw.count("\n") + 1,
                   bare_import=bool(re.search(r"^\s*import\b", raw, re.M)))
        return out

    with ThreadPoolExecutor(workers) as pool:
        return list(pool.map(one, entries))


def mutations(raw):
    """Deliberate defects; each must be rejected. Only mutates if the pattern exists."""
    out = {"unmodified": raw}
    if re.search(r"^\s*(private|public) import\b", raw, re.M):
        out["drop_import_visibility (naive arm's dominant defect)"] = re.sub(
            r"^(\s*)(?:private|public) import\b", r"\1import", raw, count=1, flags=re.M)
    idx = raw.rfind("}")
    if idx != -1:
        out["delete_final_closing_brace"] = raw[:idx] + raw[idx + 1:]
    m = re.search(r"\bpart def (\w+)", raw)
    if m:
        out["misspell_type_reference (semantic)"] = re.sub(
            r"(:\s*)" + re.escape(m.group(1)) + r"\b", r"\1" + m.group(1) + "Xyz", raw, count=1)
    return out


def run_negative_controls(spotlight_raw):
    res = {}
    for name, code in mutations(spotlight_raw).items():
        r = check_like_naive(code)
        res[name] = {k: r[k] for k in ("is_valid", "error_count", "syntax_error_count",
                                        "semantic_error_count")}
        res[name]["first_error"] = r["errors"][0]["message"] if r["errors"] else None
    return res


def run_repro(n, seed, workers, naive_dir):
    metas = sorted(naive_dir.glob("*/meta.json"))
    rng = random.Random(seed)
    sample = rng.sample(metas, min(n, len(metas)))

    def one(p):
        meta = json.loads(p.read_text())
        sid = p.parent.name
        raw = (p.parent / f"{sid}.sysml").read_text(encoding="utf-8")
        r = check_like_naive(raw)
        v = meta["validation"]
        return {"id": sid,
                "stored_errors": v["error_count"], "fresh_errors": r["error_count"],
                "stored_valid": v["is_valid"], "fresh_valid": r["is_valid"],
                "same_count": v["error_count"] == r["error_count"],
                "same_first_error": bool(meta["errors"]) == bool(r["errors"]) and (
                    not r["errors"] or meta["errors"][0]["message"] == r["errors"][0]["message"])}

    with ThreadPoolExecutor(workers) as pool:
        return list(pool.map(one, sample))


def _cause(r):
    errs = r["errors"]
    if errs and all("Linking" in (e["code"] or "") for e in errs):
        return "only unresolved references (multi-file fragment: sibling package not in this file)"
    first = errs[0]["message"] if errs else ""
    if "mismatched input 'import'" in first:
        return "bare `import` (no visibility keyword) rejected by the checker"
    return "other parser/checker error"


def render_md(rep):
    L = ["# SysML naive-arm toolchain sanity check", ""]
    c = rep.get("corpus")
    if c:
        s = c["summary"]
        L += ["## 1. Known-good, human-authored corpus models through the naive-arm wrapper", "",
              "Same path as `naive_glm_generate.generate_one` (`_postprocess` -> `check_code`), files unmodified.", "",
              f"**{s['valid']} / {s['n']} valid ({100*s['valid']/s['n']:.1f}%)**", "",
              "| Split | n | valid | rate |", "|---|---:|---:|---:|"]
        for sp, d in sorted(s["by_split"].items()):
            L.append(f"| {sp} | {d['n']} | {d['valid']} | {100*d['valid']/d['n']:.1f}% |")
        sp = c.get("spotlight")
        if sp:
            L += ["", f"Spotlight `{sp['id']}` ({sp['lines']} lines, {sp['split']}): "
                      f"valid={sp['is_valid']}, errors={sp['error_count']}."]
        if s["invalid_ids"]:
            causes = collections.Counter(_cause(r) for r in c["invalid"])
            L += ["", "Why the invalid ones fail:", ""] + [f"- {k}: {v}" for k, v in causes.most_common()]
            L += ["", "Invalid corpus models (id: errors, first error):", ""]
            for r in c["invalid"]:
                fe = r["errors"][0]["message"] if r["errors"] else "-"
                L.append(f"- `{r['id']}` ({r['split']}, bare import={r['bare_import']}): "
                         f"{r['error_count']} errors; {fe}")
    nc = rep.get("negative_controls")
    if nc:
        L += ["", "## 2. Negative controls (spotlight model, deliberately broken)", "",
              "| Variant | valid | errors | first error |", "|---|---|---:|---|"]
        for k, v in nc.items():
            L.append(f"| {k} | {v['is_valid']} | {v['error_count']} | {v['first_error'] or '-'} |")
    rp = rep.get("reproducibility")
    if rp:
        L += ["", "## 3. Recompiling stored naive outputs", "",
              f"n = {rp['n']}; identical error count {rp['same_count']} / {rp['n']}; "
              f"identical first error {rp['same_first_error']} / {rp['n']}; "
              f"valid flag agrees {rp['same_valid']} / {rp['n']}."]
    return "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--spotlight", default="000086")
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--limit", type=int, default=None, help="only first N real corpus models")
    ap.add_argument("--skip-corpus", action="store_true")
    ap.add_argument("--repro-n", type=int, default=40)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--naive-dir", type=Path, default=_ROOT / "dataset" / "naive_glm")
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    args = ap.parse_args()

    os.environ.setdefault("SYSML_COMPILER_MAX_CONCURRENCY", str(args.workers))
    if not is_compiler_available():
        sys.exit("SysML compiler unavailable (java / parser jar not found); nothing to sanity-check.")

    out_json = args.out_dir / "sanity_check.json"
    rep = {"spotlight_id": args.spotlight}
    if args.skip_corpus and out_json.exists():  # keep the earlier corpus run
        rep["corpus"] = json.loads(out_json.read_text()).get("corpus")
    spot_raw = (_ROOT / "dataset" / "data" / args.spotlight / f"{args.spotlight}.sysml").read_text(encoding="utf-8")

    if not args.skip_corpus:
        rows = run_corpus(args.workers, args.limit)
        by = collections.defaultdict(lambda: {"n": 0, "valid": 0})
        for r in rows:
            by[r["split"]]["n"] += 1
            by[r["split"]]["valid"] += r["is_valid"]
        invalid = [r for r in rows if not r["is_valid"]]
        rep["corpus"] = {
            "summary": {"n": len(rows), "valid": len(rows) - len(invalid), "by_split": dict(by),
                        "invalid_ids": [r["id"] for r in invalid]},
            "spotlight": next(({k: r[k] for k in ("id", "split", "lines", "is_valid", "error_count")}
                               for r in rows if r["id"] == args.spotlight), None),
            "invalid": invalid,
            "all": [{k: r[k] for k in ("id", "split", "lines", "is_valid", "error_count", "bare_import")}
                    for r in rows],
        }
    rep["negative_controls"] = run_negative_controls(spot_raw)

    if args.repro_n:
        rows = run_repro(args.repro_n, args.seed, args.workers, args.naive_dir)
        rep["reproducibility"] = {
            "n": len(rows),
            "same_count": sum(r["same_count"] for r in rows),
            "same_first_error": sum(r["same_first_error"] for r in rows),
            "same_valid": sum(r["stored_valid"] == r["fresh_valid"] for r in rows),
            "rows": rows,
        }

    args.out_dir.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(rep, indent=2) + "\n")
    md = render_md(rep)
    (args.out_dir / "sanity_check.md").write_text(md)
    print(md)


if __name__ == "__main__":
    main()
