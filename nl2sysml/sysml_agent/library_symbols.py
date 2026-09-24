#!/usr/bin/env python3
"""Standard-library symbol table for the unresolved-reference check (DEVIATIONS.md D2).

Parses the Pilot Implementation's sysml.library with the same ANTLR grammar the validator uses and
records, for every named namespace, its qualified name, the names it declares directly (regular
and short names, aliases) and the imports it re-exports. `.sysml` files are parsed from
`rootNamespace`. `.kerml` files use KerML syntax, which the grammar only reaches below a KerML
`namespace`, so for them `library package` is read as `namespace` and the file is parsed as a
sequence of `namespaceBodyElement`s. Only the symbol table does this; models are always validated
from `rootNamespace`.

Where the grammar cannot be trusted to find a file's declarations, every namespace declared in
that file also exports every word token of the file (identifiers and keywords, since KerML declares
names such as `frame` and `accept` that the SysML lexer reserves). That is every file with syntax
errors and every `.kerml` file: in KerML type bodies the grammar accepts `feature x : T;` without
error but as three elements (bare `feature`, bare `x`, anonymous `: T`), so `x` is never seen as
declared. Over-approximating exports can only silence the unresolved-reference check, never make
it fire.

The table is cached in library_symbols.json (committed), so PACE nodes need no Pilot checkout:
    python nl2sysml/sysml_agent/library_symbols.py [--library DIR]    # rebuild
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

import antlr_validator as av  # noqa: E402
from antlr4 import CommonTokenStream, InputStream, ParseTreeWalker, Token  # noqa: E402

CACHE = _HERE / "library_symbols.json"
DEFAULT_LIBRARY = Path(os.getenv("SYSML_LIBRARY_DIR",
                                 Path.home() / "College/SysML-v2-Pilot-Implementation/sysml.library"))
P = av.P
_ITEM_PARENTS = (P.CalculationBodyPartContext, P.FunctionBodyPartContext)


# --------------------------------------------------------------------------- parsing
def _parse_kerml(src: str):
    """Parse KerML text as a sequence of namespaceBodyElements, `library package` -> `namespace`."""
    src = re.sub(r"\b(?:standard\s+)?library\s+package\b|\bpackage\b", "namespace", src)
    errs = av._Errors()
    lexer = av.SysMLv2Lexer(InputStream(src))
    lexer.removeErrorListeners()
    lexer.addErrorListener(errs)
    tokens = CommonTokenStream(lexer)
    parser = av.SysMLv2Parser(tokens)
    parser.removeErrorListeners()
    parser.addErrorListener(errs)
    trees = []
    while tokens.LA(1) != Token.EOF:
        i = tokens.index
        trees.append(parser.namespaceBodyElement())
        if tokens.index == i:
            tokens.consume()
    return trees, errs.errors


def _identifiers(src: str) -> set[str]:
    """Every word token (identifier or keyword) and every unrestricted name, unquoted."""
    lexer = av.SysMLv2Lexer(InputStream(src))
    lexer.removeErrorListeners()
    out = set()
    for t in lexer.getAllTokens():
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", t.text):
            out.add(t.text)
        elif t.type == av.SysMLv2Lexer.STRING:
            out.add(t.text[1:-1])
    return out


class _Table(av.SysMLv2ParserListener):
    """Qualified-name bookkeeping: an item of a body is one member; the first declaring
    identification inside an item names it; a body opened inside that item belongs to it."""

    def __init__(self, ns: dict):
        self.ns = ns             # qn -> {"members": set, "imports": [(segs, kind)], "file": str}
        self.stack = [None]      # qn of the namespace owning the current scope (None = root)
        self.item = [None]       # name of the member currently being declared, per scope level

    def enterEveryRule(self, ctx):
        parent = ctx.parentCtx
        if parent is not None and (av.is_scope(parent) or
                                   (isinstance(parent, _ITEM_PARENTS) and av.is_scope(parent.parentCtx))):
            self.item[-1] = None  # a new member of the current scope starts here
        if av.is_scope(ctx) and not isinstance(ctx, P.RootNamespaceContext):
            owner, name = self.stack[-1], self.item[-1]
            qn = None if (name is None or (owner is None and len(self.stack) > 1)) \
                else (name if owner is None else f"{owner}::{name}")
            self.stack.append(qn)
            self.item.append(None)
            if qn is not None:
                self.ns.setdefault(qn, {"members": set(), "imports": [], "file": self.file})

    def exitEveryRule(self, ctx):
        if av.is_scope(ctx) and not isinstance(ctx, P.RootNamespaceContext):
            self.stack.pop()
            self.item.pop()

    def _declare(self, names, primary):
        owner = self.stack[-1]
        if owner is not None:
            self.ns[owner]["members"].update(names)
        elif len(self.stack) == 1:
            self.top.update(names)
        if self.item[-1] is None:
            self.item[-1] = primary

    def enterIdentification(self, ctx):
        if type(ctx.parentCtx) in av._DECL_RULES:
            self._declare({av.name_text(n) for n in ctx.name()}, av.declared_name(ctx))

    def enterFeatureIdentification(self, ctx):
        self._declare({av.name_text(n) for n in ctx.name()}, av.name_text(ctx.name()[-1]))

    def _alias(self, ctx):
        names = {av.name_text(n) for n in ctx.name()}
        if names and self.stack[-1] is not None:
            self.ns[self.stack[-1]]["members"].update(names)

    enterAliasMember = _alias

    def enterDefinitionBodyItemContent(self, ctx):
        if ctx.ALIAS():
            self._alias(ctx)

    def enterImportRule(self, ctx):
        vis = ctx.visibilityIndicator()
        if self.stack[-1] is not None and not (vis and vis.getText() == "private"):
            self.ns[self.stack[-1]]["imports"].append(av.import_spec(ctx))


def build(lib_dir: Path) -> dict:
    ns, top, uncertain = {}, set(), {}
    files = sorted(p for p in lib_dir.rglob("*") if p.suffix in (".sysml", ".kerml"))
    n_err = {}
    for f in files:
        src = f.read_text(encoding="utf-8")
        rel = str(f.relative_to(lib_dir))
        if f.suffix == ".kerml":
            trees, errs = _parse_kerml(src)
        else:
            tree, errs = av.parse(src)
            trees = [tree]
        t = _Table(ns)
        t.file, t.top = rel, top
        for tree in trees:
            ParseTreeWalker.DEFAULT.walk(t, tree)
        if errs:
            n_err[rel] = len(errs)
        if errs or f.suffix == ".kerml":
            uncertain[rel] = sorted(_identifiers(src))
        print(f"  {rel}: {len(errs)} syntax errors", flush=True)
    try:
        commit = subprocess.run(["git", "-C", str(lib_dir), "describe", "--tags", "--always"],
                                capture_output=True, text=True).stdout.strip()
    except OSError:
        commit = ""
    return {
        "library": str(lib_dir), "pilot_version": commit, "grammar": av.GRAMMAR_TAG,
        "n_files": len(files), "files_with_parse_errors": n_err,
        "top": sorted(top),
        "namespaces": {k: {"members": sorted(v["members"]),
                           "imports": [list(i) for i in v["imports"]], "file": v["file"]}
                       for k, v in sorted(ns.items())},
        "uncertain_files": uncertain,
    }


# --------------------------------------------------------------------------- lookup
_LOADED = None


def load(path: Path = CACHE) -> dict:
    """Cached table plus derived sets: `global` (top-level package names, visible everywhere as
    the first segment of a qualified name) and `all` (every name the library declares)."""
    global _LOADED
    if _LOADED is None:
        t = json.loads(path.read_text(encoding="utf-8"))
        t["global"] = set(t["top"])
        t["all"] = set(t["top"]).union(*(v["members"] for v in t["namespaces"].values()),
                                       *t["uncertain_files"].values())
        _LOADED = t
    return _LOADED


def exports(lib: dict, segs: list[str], kind: str, _seen=None) -> set[str] | None:
    """Names an import makes visible; None if the imported namespace is not a library namespace."""
    if not segs:
        return None
    if kind == "member":
        return {segs[-1]}
    qn = "::".join(segs)
    ns = lib["namespaces"].get(qn)
    if ns is None:
        return None
    seen = _seen if _seen is not None else set()
    if qn in seen:
        return set()
    seen.add(qn)
    out = set(ns["members"]) | set(lib["uncertain_files"].get(ns["file"], []))
    if kind == "recursive":
        for k in lib["namespaces"]:
            if k.startswith(qn + "::"):
                out |= exports(lib, k.split("::"), "members", seen) or set()
    for isegs, ikind in ns["imports"]:  # re-exported (non-private) imports, resolved from the
        for n in range(len(segs), -1, -1):  # importing namespace outwards to the root
            got = exports(lib, segs[:n] + isegs, ikind, seen)
            if got is not None:
                out |= got
                break
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--library", type=Path, default=DEFAULT_LIBRARY)
    a = ap.parse_args()
    t0 = time.time()
    table = build(a.library)
    CACHE.write_text(json.dumps(table, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{len(table['namespaces'])} namespaces, {len(table['top'])} top-level, "
          f"{len(table['files_with_parse_errors'])}/{table['n_files']} files with parse errors, "
          f"{time.time() - t0:.0f}s -> {CACHE}")
