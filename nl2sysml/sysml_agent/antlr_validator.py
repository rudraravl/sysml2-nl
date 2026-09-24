#!/usr/bin/env python3
"""SysMLAgent's Validation Engine (Cibrian et al. 2025, Sec. 3.4), reimplemented.

Two phases, as the paper describes them:
  1. syntax:   OMG spec grammar (ANTLR4, see grammar/PATCHES.md and DEVIATIONS.md D1) with a
               custom error listener that records every error with its line and column;
  2. semantic: a parse-tree listener with exactly the two checks the paper names (D2):
               (a) duplicate names among the owned members of one namespace body,
               (b) unresolved references: an unqualified name (or the first segment of a
                   qualified one) used as a typing / specialization / subsetting / redefinition
                   target that is declared nowhere in the file and not exported by any
                   standard-library package the file imports.
The semantic phase runs only on syntactically valid input (an error-recovered tree would produce
phantom duplicates and phantom unresolved names). Both checks are conservative: when in doubt they
stay silent. False negatives are acceptable, false positives are not.

    validate(code) -> {"valid": bool, "errors": [{"line", "column", "kind", "message"}]}

CLI: python nl2sysml/sysml_agent/antlr_validator.py FILE.sysml [...]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE / "grammar"))
sys.path.insert(0, str(_HERE))
sys.setrecursionlimit(20000)  # deep expression trees recurse in the generated parser

from antlr4 import CommonTokenStream, InputStream, ParseTreeWalker  # noqa: E402
from antlr4.error.ErrorListener import ErrorListener  # noqa: E402
from antlr4.tree.Tree import TerminalNode  # noqa: E402

from SysMLv2Lexer import SysMLv2Lexer  # noqa: E402
from SysMLv2Parser import SysMLv2Parser  # noqa: E402
from SysMLv2ParserListener import SysMLv2ParserListener  # noqa: E402

GRAMMAR_TAG = "daltskin/sysml-v2-grammar generator v2026.05.0 (7292dc3) @ OMG SysML-v2-Release 2025-12"
# Semantic checks in force. The pre-registered conformance rule (DEVIATIONS.md, gate 7.1) removes a
# check from this tuple if it flags more than 2% of the curated reference models.
CHECKS = ("duplicates", "unresolved")
P = SysMLv2Parser

# Rules whose `identification` declares a member of the enclosing namespace. The other rules that
# use `identification` (specialization, featureTyping, subsetting, comment, ...) name a
# relationship or annotation, not a namespace member.
_DECL_RULES = {
    P.PackageDeclarationContext, P.NamespaceDeclarationContext, P.TypeDeclarationContext,
    P.ClassifierDeclarationContext, P.DefinitionDeclarationContext, P.UsageDeclarationContext,
    P.MetadataFeatureDeclarationContext, P.DependencyDeclarationContext, P.DependencyContext,
}
# Reference kinds checked by (b), see _Collect.enterOwned*: `:` / `defined by` (typing, incl.
# `~Port`), `:>` / `specializes` on definitions, `:>` / `subsets`, `:>>` / `redefines`.
# Not `::>` / `references` and not `crosses`.


# --------------------------------------------------------------------------- helpers
def name_text(ctx) -> str:
    """Text of a `name` node, with unrestricted-name quotes removed."""
    s = ctx.getText()
    if len(s) >= 2 and s[0] == "'" and s[-1] == "'":
        s = s[1:-1].replace("\\'", "'").replace("\\\\", "\\")
    return s


def qn_parts(ctx) -> list[str]:
    """Segments of a `qualifiedName`; [] for a `$::`-rooted (global) name."""
    if ctx.DOLLAR():
        return []
    return [name_text(n) for n in ctx.name()]


def declared_name(ident) -> str:
    """The name an `identification` declares: the regular name, else the short name."""
    return name_text(ident.name()[-1])


def is_scope(ctx) -> bool:
    """A namespace: `rootNamespace`, any rule that opens a brace itself (bodies, expression bodies
    `{ in x; ... }`, transition action bodies), or a transition, whose trigger and effect are its
    own members although it has no braces."""
    if isinstance(ctx, (P.RootNamespaceContext, P.TransitionUsageContext, P.TargetTransitionUsageContext)):
        return True
    return any(isinstance(c, TerminalNode) and c.symbol.type == P.LBRACE
               for c in (ctx.children or []))


def owning_scope(ctx):
    p = ctx.parentCtx
    while p is not None and not is_scope(p):
        p = p.parentCtx
    return p


def import_spec(ctx) -> tuple[list[str], str]:
    """(target segments, kind) of an `importRule`. kind: 'member' (X::Y), 'members' (X::*),
    'recursive' (X::** or X::*::**). Filter conditions are ignored: filtering only removes names."""
    decl = ctx.importDeclaration()
    fp = decl.namespaceImport() and decl.namespaceImport().filterPackage()
    if fp:  # `import X::*[@F];` -> the import inside the filter
        decl = fp.filterPackageImportDeclaration()
    qn = _find(decl, P.QualifiedNameContext)[0]
    text = decl.getText()
    kind = "recursive" if text.endswith("**") else "members" if text.endswith("*") else "member"
    return qn_parts(qn), kind


def _find(ctx, cls):
    """All descendants (preorder, including ctx) of rule class `cls`."""
    out, stack = [], [ctx]
    while stack:
        n = stack.pop()
        if isinstance(n, cls):
            out.append(n)
        if not isinstance(n, TerminalNode):
            stack.extend(reversed(list(n.getChildren())))
    return out


# --------------------------------------------------------------------------- parsing
class _Errors(ErrorListener):
    def __init__(self):
        self.errors = []

    def syntaxError(self, recognizer, offending, line, column, msg, e):
        # token length for the caret underline (lexer errors have no token: one caret)
        n = offending.stop - offending.start + 1 if offending is not None and offending.start >= 0 else 1
        self.errors.append({"line": line, "column": column, "kind": "syntax", "message": msg,
                            "length": max(n, 1)})


def parse(code: str):
    """(tree, syntax errors). Lexer and parser report through the same listener."""
    listener = _Errors()
    lexer = SysMLv2Lexer(InputStream(code))
    lexer.removeErrorListeners()
    lexer.addErrorListener(listener)
    parser = SysMLv2Parser(CommonTokenStream(lexer))
    parser.removeErrorListeners()
    parser.addErrorListener(listener)
    tree = parser.rootNamespace()
    return tree, listener.errors


# --------------------------------------------------------------------------- semantic phase
class _Collect(SysMLv2ParserListener):
    """One walk: declarations per scope, every declared name, imports, reference targets."""

    def __init__(self):
        self.members = {}      # id(scope) -> {name: first line}
        self.dups = []         # (line, col, length, name, first line)
        self.declared = set()  # every name declared anywhere in the file (any depth)
        self.imports = []      # (segments, kind)
        self.refs = []         # (line, col, length, first segment, is_feature_ref)

    def enterIdentification(self, ctx):
        for n in ctx.name():
            self.declared.add(name_text(n))
        if type(ctx.parentCtx) not in _DECL_RULES:
            return
        self._member(ctx, declared_name(ctx))

    def enterFeatureIdentification(self, ctx):  # KerML features
        for n in ctx.name():
            self.declared.add(name_text(n))
        self._member(ctx, name_text(ctx.name()[-1]))

    def _member(self, ctx, name):
        scope = owning_scope(ctx)
        seen = self.members.setdefault(id(scope), {})
        tok = ctx.name()[-1].start  # the declared name's token
        if name in seen:
            self.dups.append((tok.line, tok.column, len(tok.text), name, seen[name]))
        else:
            seen[name] = tok.line

    # names declared outside `identification`: aliases, `end` names, connector-end names
    def _names(self, ctx):
        ns = ctx.name()  # a list where the rule mentions `name` twice, else one node or None
        for n in (ns if isinstance(ns, list) else [ns] if ns is not None else []):
            self.declared.add(name_text(n))

    enterAliasMember = _names
    enterEndOccurrenceUsageElement = _names
    enterConnectorEnd = _names
    enterInterfaceEnd = _names

    def enterDefinitionBodyItemContent(self, ctx):
        if ctx.ALIAS():
            self._names(ctx)

    def enterImportRule(self, ctx):
        self.imports.append(import_spec(ctx))

    def _ref(self, ctx, feature):
        qn = _find(ctx, P.QualifiedNameContext)[0]  # feature chain `a.b`: only the head `a`
        segs = qn_parts(qn)
        if segs:
            self.refs.append((qn.start.line, qn.start.column, len(qn.start.text), segs[0], feature))

    def enterOwnedFeatureTyping(self, ctx):
        self._ref(ctx, False)

    def enterConjugatedPortTyping(self, ctx):
        self._ref(ctx, False)

    def enterOwnedSubclassification(self, ctx):
        self._ref(ctx, False)

    def enterOwnedSubsetting(self, ctx):
        self._ref(ctx, True)

    def enterOwnedRedefinition(self, ctx):
        self._ref(ctx, True)


def semantic_errors(tree, checks=None, lib=None) -> list[dict]:
    import library_symbols

    checks = CHECKS if checks is None else checks
    lib = lib or library_symbols.load()
    c = _Collect()
    ParseTreeWalker.DEFAULT.walk(c, tree)
    errs = [{"line": ln, "column": col, "kind": "semantic", "length": w,
             "message": f"duplicate name '{n}' in the same namespace (first declared at line {first})"}
            for ln, col, w, n, first in c.dups] if "duplicates" in checks else []
    if "unresolved" not in checks:
        return sorted(errs, key=_pos)

    visible = set(c.declared) | lib["global"]
    for segs, kind in c.imports:
        got = library_symbols.exports(lib, segs, kind)
        if got is None and not (segs and segs[0] in c.declared):
            return sorted(errs, key=_pos)  # import of an unknown namespace: (b) is ambiguous, skip
        visible |= got or set()
    for ln, col, w, n, feature in c.refs:
        # subsetting/redefinition targets may be features inherited from implicit library
        # supertypes (Parts::Part etc.), which no import brings in: accept any library name
        if n in visible or (feature and n in lib["all"]):
            continue
        errs.append({"line": ln, "column": col, "kind": "semantic", "length": w,
                     "message": f"unresolved reference '{n}': not declared in this model or in "
                                f"any imported standard library package"})
    return sorted(errs, key=_pos)


def _pos(e):
    return (e["line"], e["column"])


# --------------------------------------------------------------------------- API
def validate(code: str, checks=None) -> dict:
    """{valid, errors[]}; errors are syntax errors, or (only if there are none) semantic ones.
    `checks` overrides CHECKS (() = syntax only)."""
    tree, errs = parse(code or "")
    if not errs:
        errs = semantic_errors(tree, checks)
    return {"valid": not errs, "errors": errs}


def underline(code: str, e: dict) -> list[str]:
    """Parr's `underlineError` (Definitive ANTLR 4 Reference, Sec. 9.2): the offending source line,
    then carets under the offending token. Tabs are kept in the prefix so the carets line up."""
    src = code.splitlines()
    if not 1 <= e["line"] <= len(src):
        return []
    text = src[e["line"] - 1]
    pad = "".join(ch if ch == "\t" else " " for ch in text[:e["column"]])
    return ["    " + text, "    " + pad + "^" * e.get("length", 1)]


def format_errors(errors: list[dict], cap: int = 40, code: str | None = None) -> str:
    """One line per error, `line L:C <syntax|semantic> <message>`, capped (DEVIATIONS.md D4). With
    `code`, each error is followed by its underlined source line (amendment A1)."""
    lines = []
    for e in errors[:cap]:
        lines.append(f"line {e['line']}:{e['column']} {e['kind']} {e['message']}")
        if code is not None:
            lines += underline(code, e)
    if len(errors) > cap:
        lines.append(f"... ({len(errors) - cap} more)")
    return "\n".join(lines)


if __name__ == "__main__":
    for f in sys.argv[1:]:
        r = validate(Path(f).read_text(encoding="utf-8"))
        print(json.dumps({"file": f, **r}, indent=1) if r["errors"] else f"{f}: valid")
