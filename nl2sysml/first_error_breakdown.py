#!/usr/bin/env python3
"""Why do the naive SysML outputs fail? First-error breakdown of the 0% compile rate.

For each naive output paired with a full-pipeline output (default: seeds present in both
`dataset/naive_glm` and `dataset/with_kernel_spec`), take the *first* compiler diagnostic
(earliest line/column) and classify it, so "0% compiled" can be read as either trivial
syntax slips or deep semantic failures.

Two modes:
  default      reads only the cached meta.json / .sysml the generator wrote (seconds, no JVM).
  --recompile  also recompiles every output with bare `import` rewritten to `private import`
               (the visibility keyword the SysML v2 grammar requires) and reports what is
               left. This is a counterfactual that shows how much of the failure is that one
               keyword; it does NOT replace the 0% headline, which is the unmodified output.

Diagnostics are de-duplicated first: the parser jar emits every syntax error twice (once
uncoded from ANTLR, once as Xtext `Diagnostic.Syntax`), so raw `error_count` double-counts
them. Validity is unaffected (any diagnostic => invalid).

    python nl2sysml/first_error_breakdown.py
    python nl2sysml/first_error_breakdown.py --recompile --workers 6
"""

import argparse
import collections
import json
import os
import re
import statistics
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

_NL2 = Path(__file__).resolve().parent
_ROOT = _NL2.parent
sys.path.insert(0, str(_NL2))

DEFAULT_OUT = _ROOT / "dataset" / "analysis_results" / "sysml_first_error"
BARE_IMPORT = re.compile(r"^(\s*)import\b", re.M)


def dedupe(errors):
    seen, out = set(), []
    for e in sorted(errors, key=lambda e: (e["line"], e["column"])):
        key = (e["line"], e["column"], e["message"])
        if key not in seen:
            seen.add(key)
            out.append(e)
    return out


def layer(e):
    """parser = lexical/grammar (ANTLR, Xtext Syntax); linking = unresolved reference."""
    code = e.get("code") or ""
    return "linking" if "Linking" in code else "parser"


def template(msg):
    """Collapse the offending/expected tokens so messages group by parser rule."""
    m = re.match(r"(mismatched input|extraneous input|missing EOF at|no viable alternative at input)"
                 r"(?: .*? (expecting) (RULE_\w+|'.*'|\{.*\}))?", msg)
    if not m:
        return re.sub(r"(?<!\w)'[^']*'(?=[.\s]|$)", "'_'", msg)
    head, exp, what = m.groups()
    if not exp:
        return f"{head} '_'"
    return f"{head} '_' expecting " + (what if what.startswith("RULE_") else "'_'")


def offending_token(msg):
    m = re.search(r"input '([^']*)'|at '([^']*)'", msg)
    return next((g for g in m.groups() if g is not None), None) if m else None


def first_error_type(e, line_text=""):
    """A named, human-readable first-error class (line_text = source line of the error)."""
    msg = e["message"]
    if layer(e) == "linking":
        kind = re.match(r"Couldn't resolve reference to (\w+)", msg)
        return f"unresolved reference ({kind.group(1) if kind else 'other'})"
    tok = offending_token(msg)
    if msg.startswith("mismatched input") and tok == "import":
        return "bare `import` (visibility keyword missing)"
    if re.match(r"\s*imports\b", line_text):
        return "`imports` (plural) instead of `import`"
    if re.search(r"\b(scalar )?value type\b", line_text):
        return "SysML v1-style `value type` declaration"
    if re.search(r"\bunit\b", line_text):
        return "`unit` declaration (`unit def` / `unit 'm'`) has no SysML v2 form"
    return template(msg)


def classify(meta, src):
    if meta.get("empty_output"):
        return {"status": "empty_output"}
    errs = dedupe(meta.get("errors", []))
    if meta.get("compiler_timeout"):
        return {"status": "compiler_timeout"}
    if not errs:
        return {"status": "valid" if meta["validation"]["is_valid"] else "no_diagnostics"}
    first = errs[0]
    listed_first = meta["errors"][0]
    src_lines = src.splitlines()
    line_text = src_lines[first["line"] - 1] if 0 < first["line"] <= len(src_lines) else ""
    return {
        "status": "invalid",
        "first": first,
        "type": first_error_type(first, line_text),
        "layer": layer(first),
        "template": template(first["message"]),
        "token": offending_token(first["message"]),
        "line": first["line"],
        "n_lines": src.count("\n") + 1 if src else None,
        "list_first_differs": (listed_first["line"], listed_first["column"]) != (first["line"], first["column"]),
        "n_unique": len(errs),
        "n_parser": sum(layer(e) == "parser" for e in errs),
        "n_linking": sum(layer(e) == "linking" for e in errs),
        "has_bare_import": bool(BARE_IMPORT.search(src)),
    }


def load_pairs(naive_dir, full_dir):
    naive = {p.parent.name for p in naive_dir.glob("*/meta.json")}
    full = {p.parent.name for p in full_dir.glob("*/meta.json")}
    ids = sorted(naive & full, key=lambda s: int(re.sub(r"\D", "", s) or 0))
    return ids, sorted(naive - full), sorted(full - naive)


def summarize(rows):
    inv = [r for r in rows if r["status"] == "invalid"]
    n = len(rows)
    pct = lambda k, d=n: round(100 * k / d, 1) if d else None
    c_type = collections.Counter(r["type"] for r in inv)
    c_tmpl = collections.Counter(r["template"] for r in inv)
    c_layer = collections.Counter(r["layer"] for r in inv)
    lines = [r["line"] for r in inv]
    return {
        "n": n,
        "status": dict(collections.Counter(r["status"] for r in rows)),
        "n_invalid_with_diagnostics": len(inv),
        "first_error_layer": {k: {"n": v, "pct_of_invalid": pct(v, len(inv))} for k, v in c_layer.items()},
        "top_types": [{"type": k, "n": v, "pct_of_invalid": pct(v, len(inv)), "pct_of_all": pct(v)}
                      for k, v in c_type.most_common(10)],
        "top_templates": [{"template": k, "n": v, "pct_of_invalid": pct(v, len(inv))}
                          for k, v in c_tmpl.most_common(10)],
        "first_error_line": {
            "line_1": pct(sum(l == 1 for l in lines), len(inv)),
            "le_3": pct(sum(l <= 3 for l in lines), len(inv)),
            "le_10": pct(sum(l <= 10 for l in lines), len(inv)),
            "median": statistics.median(lines) if lines else None,
        },
        "first_error_relative_position_median_pct": round(100 * statistics.median(
            r["line"] / r["n_lines"] for r in inv if r.get("n_lines")), 1) if inv else None,
        "list_order_vs_position_disagree": sum(r["list_first_differs"] for r in inv),
        "unique_diagnostics_per_output": {
            "mean": round(statistics.mean(r["n_unique"] for r in inv), 1) if inv else None,
            "median": statistics.median(r["n_unique"] for r in inv) if inv else None,
            "outputs_with_parser_error": sum(r["n_parser"] > 0 for r in inv),
            "outputs_with_linking_error": sum(r["n_linking"] > 0 for r in inv),
            "outputs_with_only_linking_errors": sum(r["n_parser"] == 0 and r["n_linking"] > 0 for r in inv),
        },
        "outputs_containing_bare_import": sum(r["has_bare_import"] for r in inv),
    }


def recompile_patched(ids, naive_dir, workers):
    os.environ.setdefault("SYSML_COMPILER_MAX_CONCURRENCY", str(workers))
    from compiler_interface import check_code, is_compiler_available
    from naive_glm_generate import _postprocess
    if not is_compiler_available():
        sys.exit("SysML compiler unavailable; cannot --recompile.")

    def one(sid):
        raw = (naive_dir / sid / f"{sid}.sysml").read_text(encoding="utf-8")
        code = _postprocess(BARE_IMPORT.sub(r"\1private import", raw))
        if not code:
            return {"status": "empty_output"}
        res = check_code(code)
        errs = dedupe([{"line": e.line, "column": e.column, "message": e.message,
                        "severity": e.severity, "code": e.code} for e in res.errors])
        if not errs:
            return {"status": "valid", "changed": code != _postprocess(raw)}
        first = errs[0]
        code_lines = code.splitlines()
        line_text = code_lines[first["line"] - 1] if 0 < first["line"] <= len(code_lines) else ""
        return {"status": "invalid", "first": first, "type": first_error_type(first, line_text),
                "layer": layer(first), "template": template(first["message"]),
                "token": offending_token(first["message"]), "line": first["line"],
                "n_lines": code.count("\n") + 1, "list_first_differs": False,
                "n_unique": len(errs), "n_parser": sum(layer(e) == "parser" for e in errs),
                "n_linking": sum(layer(e) == "linking" for e in errs),
                "has_bare_import": False}

    with ThreadPoolExecutor(workers) as pool:
        return list(pool.map(one, ids))


def md_table(rows, head):
    return ["| " + " | ".join(head) + " |", "|" + "|".join("---" for _ in head) + "|"] + \
           ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]


def render(rep):
    s = rep["as_generated"]
    inv = s["n_invalid_with_diagnostics"]
    L = ["# SysML naive arm: first-error breakdown", "",
         f"Population: {s['n']} naive outputs paired with a full-pipeline output "
         f"(naive-only: {rep['naive_only']}, full-only: {rep['full_only']}). "
         f"Status: {s['status']}.", "",
         "First error = earliest line/column diagnostic after removing the parser's duplicate "
         "ANTLR/Xtext copies.", ""]
    L += ["## Layer of the first error", ""] + md_table(
        [[k, v["n"], f"{v['pct_of_invalid']}%"] for k, v in s["first_error_layer"].items()],
        ["layer", "n", "% of failing outputs"])
    fl = s["first_error_line"]
    L += ["", f"Position: first error on line 1 for {fl['line_1']}% of failing outputs, within the first "
              f"3 lines for {fl['le_3']}%, within 10 lines for {fl['le_10']}% (median line {fl['median']}; "
              f"median position {s['first_error_relative_position_median_pct']}% of the way through the file).", ""]
    L += ["## Top five first-error types", ""] + md_table(
        [[i + 1, t["type"], t["n"], f"{t['pct_of_invalid']}%", f"{t['pct_of_all']}%"]
         for i, t in enumerate(s["top_types"][:5])],
        ["#", "first-error type", "n", "% of failing", "% of all"])
    L += ["", "### Diagnostic message templates (top 5)", ""] + md_table(
        [[t["template"], t["n"], f"{t['pct_of_invalid']}%"] for t in s["top_templates"][:5]],
        ["template", "n", "% of failing"])
    u = s["unique_diagnostics_per_output"]
    L += ["", "## Whole-file view", "",
          f"Unique diagnostics per failing output: mean {u['mean']}, median {u['median']}. "
          f"Outputs with at least one parser error: {u['outputs_with_parser_error']}/{inv}; with at least one "
          f"unresolved-reference (linking) error: {u['outputs_with_linking_error']}/{inv}; "
          f"linking errors only: {u['outputs_with_only_linking_errors']}/{inv}. "
          f"Outputs containing a bare `import`: {s['outputs_containing_bare_import']}/{inv}."]
    p = rep.get("patched_imports")
    if p:
        n = p["n"]
        v = p["status"].get("valid", 0)
        L += ["", "## Counterfactual: bare `import` rewritten to `private import`", "",
              f"Recompiled all {n} outputs after only that rewrite: **{v} / {n} valid "
              f"({100*v/n:.1f}%)**. Status: {p['status']}.", "",
              "First-error layer after the rewrite:", ""] + md_table(
            [[k, d["n"], f"{d['pct_of_invalid']}%"] for k, d in p["first_error_layer"].items()],
            ["layer", "n", "% of still-failing"])
        L += ["", "Top five first-error types after the rewrite:", ""] + md_table(
            [[i + 1, t["type"], t["n"], f"{t['pct_of_invalid']}%"] for i, t in enumerate(p["top_types"][:5])],
            ["#", "first-error type", "n", "% of still-failing"])
        pu = p["unique_diagnostics_per_output"]
        L += ["", f"Unique diagnostics per still-failing output: mean {pu['mean']}, median {pu['median']}; "
                  f"linking-only failures: {pu['outputs_with_only_linking_errors']}."]
    return "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--naive-dir", type=Path, default=_ROOT / "dataset" / "naive_glm")
    ap.add_argument("--full-dir", type=Path, default=_ROOT / "dataset" / "with_kernel_spec")
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--recompile", action="store_true")
    ap.add_argument("--workers", type=int, default=6)
    args = ap.parse_args()

    ids, naive_only, full_only = load_pairs(args.naive_dir, args.full_dir)
    rows = []
    for sid in ids:
        d = args.naive_dir / sid
        meta = json.loads((d / "meta.json").read_text())
        src_path = d / f"{sid}.sysml"
        src = src_path.read_text(encoding="utf-8") if src_path.exists() else ""
        rows.append({"id": sid, **classify(meta, src)})

    rep = {"naive_only": naive_only, "full_only": full_only, "as_generated": summarize(rows)}
    if args.recompile:
        rows_p = recompile_patched(ids, args.naive_dir, args.workers)
        rep["patched_imports"] = summarize(rows_p)
        rep["patched_rows"] = [{"id": i, **{k: v for k, v in r.items() if k != "first"}}
                               for i, r in zip(ids, rows_p)]

    args.out_dir.mkdir(parents=True, exist_ok=True)
    rep["rows"] = [{"id": r["id"], **{k: v for k, v in r.items() if k not in ("id", "first")}} for r in rows]
    (args.out_dir / "first_error_breakdown.json").write_text(json.dumps(rep, indent=2) + "\n")
    md = render(rep)
    (args.out_dir / "first_error_breakdown.md").write_text(md)
    print(md)


if __name__ == "__main__":
    main()
