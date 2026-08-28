#!/usr/bin/env python3
"""24 Standard Modeling Rules checked statically over SysML v2 text.

Each rule returns "pass", "fail", or "n_a" (not applicable when the model owns
no element the rule targets). Static parse only — no kernel. Brutally simple:
regex + brace scanning, one function per rule, short names, fail fast.

Usage:
    from std_rules import check, RULES
    res = check(open("x.sysml").read())   # {rule: "pass"|"fail"|"n_a"}
"""

import re

# ---- text prep -------------------------------------------------------------

def strip_comments(t):
    """Drop // line comments and /* */ blocks but keep doc bodies intact."""
    t = re.sub(r"/\*.*?\*/", " ", t, flags=re.DOTALL)
    t = re.sub(r"//[^\n]*", " ", t)
    return t


def _named(t, kw):
    """Yield the declaration tail after each `kw` (up to { ; or =).

    Keeps redefinition markers (`:>>`, `:>`, `:`) so _name_ok can resolve the
    named feature. Stops at block/stmt/binding boundaries."""
    pat = re.compile(r"\b" + kw + r"\b[ \t]*([^\n{;=]*)")
    for m in pat.finditer(t):
        yield m.group(1).strip()


def _has(t, kw):
    return re.search(r"\b" + kw + r"\b", t) is not None


def _name_ok(s):
    """A declared name is present if some ident/quoted name is declared.

    Handles redefinition/subset/typing markers: `:>> foo`, `:> foo`, `: Foo`
    all name a feature (the redefined/typed identifier counts as the name)."""
    if not s:
        return False
    s = s.strip()
    # a leading redefine/subset marker still names the feature after it
    s = re.sub(r"^(:>>|:>|:)\s*", "", s)
    m = re.match(r"^(<[^>]+>|'[^']+'|[A-Za-z_]\w*)", s)
    return m is not None


def _all_named(t, kw):
    """True if every `kw` decl has a name; None if there are none (n_a)."""
    names = list(_named(t, kw))
    if not names:
        return None
    return all(_name_ok(n) for n in names)


def _pf(ok):
    """Map True/False/None -> pass/fail/n_a."""
    if ok is None:
        return "n_a"
    return "pass" if ok else "fail"


# ---- naming rules ----------------------------------------------------------

def activityname(t):
    return _pf(_all_named(t, r"action\s+def"))


def actorname(t):
    # actors ~ named parts/part defs marked as actor or external via metadata
    if not re.search(r"\bactor\b", t, re.I):
        return "n_a"
    ok = True
    for m in re.finditer(r"\bactor\b[ \t]*([^\n{;:]*)", t, re.I):
        if not _name_ok(m.group(1)):
            ok = False
    return _pf(ok)


def blockname(t):
    return _pf(_all_named(t, r"part\s+def"))


def operationname(t):
    # operations ~ action defs / interface features; reuse action def coverage
    if _has(t, r"operation"):
        return _pf(_all_named(t, "operation"))
    return _pf(_all_named(t, r"action\s+def"))


def packagename(t):
    return _pf(_all_named(t, "package"))


def signalname(t):
    # signals ~ item defs used as payloads; fall back to n_a if no items
    if _has(t, "attribute def"):  # models exist; check item def names
        pass
    return _pf(_all_named(t, r"item\s+def"))


def stmachinename(t):
    return _pf(_all_named(t, r"state\s+def"))


def valuename(t):
    return _pf(_all_named(t, "attribute"))


def artifactname(t):
    if not _has(t, "artifact"):
        return "n_a"
    return _pf(_all_named(t, "artifact"))


def usecasename(t):
    if not re.search(r"\buse\s*case\b", t, re.I):
        return "n_a"
    return _pf(_all_named(t, r"use\s*case"))


def termname(t):
    if not re.search(r"\b(glossary|term)\b", t, re.I):
        return "n_a"
    return _pf(_all_named(t, "term"))


def diagramname(t):
    # SysML 2 text has no diagram elements; n_a unless a view is declared
    if not _has(t, r"view"):
        return "n_a"
    return _pf(_all_named(t, "view"))


def decisionnodename(t):
    # decision nodes: `decide` steps. SysML often names them by the step label.
    if not _has(t, "decide"):
        return "n_a"
    # `action foo decide` or `then decide` — accept named or labeled succession
    ok = True
    for m in re.finditer(r"\bdecide\b[ \t]*([^\n{;]*)", t):
        tail = m.group(1).strip()
        # named if it carries an identifier after decide OR is a named action step
        if tail and not _name_ok(tail):
            ok = False
    return _pf(ok)


# ---- body / content rules --------------------------------------------------

def commentbody(t):
    bodies = re.findall(r"/\*(.*?)\*/", t, flags=re.DOTALL)
    docs = re.findall(r"\bdoc\b[ \t]*(?:<[^>]*>)?[ \t]*(?:\"([^\"]*)\")", t)
    all_b = bodies + docs
    if not all_b:
        return "n_a"
    return _pf(all(b.strip() for b in all_b))


def constraintspecification(t):
    # each constraint/assert constraint must own a non-empty { body }
    if not _has(t, "constraint"):
        return "n_a"
    ok = True
    for m in re.finditer(r"constraint\b[^\n{;]*\{([^{}]*)\}", t):
        if not m.group(1).strip():
            ok = False
    # constraint decls that end with ; and no body are usage refs -> ignore
    return _pf(ok)


def enumerationliteral(t):
    if not _has(t, r"enum\s+def"):
        return "n_a"
    ok = True
    for m in re.finditer(r"enum\s+def\b[^\n{]*\{([^{}]*)\}", t):
        body = m.group(1)
        lits = [x for x in re.split(r"[;\n]", body) if x.strip()]
        if not lits:
            ok = False
    return _pf(ok)


def annotatedelements(t):
    # problem/rationale should annotate something (have about/for/subject/target)
    if not re.search(r"\b(problem|rationale)\b", t):
        return "n_a"
    ok = True
    for m in re.finditer(r"\b(problem|rationale)\b[^{;]*(\{([^{}]*)\}|;)", t):
        blk = m.group(3) or ""
        if not re.search(r"\b(about|for|subject|annotates)\b", blk + m.group(0)):
            ok = False
    return _pf(ok)


def classprohibited(t):
    # raw UML `class` (not part/item/action def) is prohibited
    if re.search(r"\bclass\s+def\b|\bclass\s+\w", t):
        return "fail"
    return "pass"


# ---- signal / event rules --------------------------------------------------

def signaleventsignal(t):
    # accept actions must reference a signal/type: `accept x : Sig` or `accept Sig`
    if not _has(t, "accept"):
        return "n_a"
    ok = True
    for m in re.finditer(r"\baccept\b[ \t]+([^\n;{]*)", t):
        seg = m.group(1).strip()
        ref = seg.split(":", 1)[1] if ":" in seg else seg  # after colon, else whole
        # a signal ref is the leading identifier/qualified path before `then`/`if`
        ref = re.split(r"\b(then|if|first)\b", ref)[0].strip()
        if not _name_ok(ref):
            ok = False
    return _pf(ok)


# ---- activity graph rules --------------------------------------------------
# Derived from `first`/`then`/`transition`/`succession`/`decide`/`merge`/`fork`.

def _has_activity(t):
    return bool(re.search(r"\b(first|then|transition|succession|action\s+def)\b", t))


def activityedgeincoming(t):
    """Control nodes (non-initial) need >=1 incoming edge.

    Approx: if there are `then`/`transition ... then` steps, an activity graph
    exists and edges connect steps. Fail only if `then` appears with no prior
    `first`/`entry`/`start` anchor (dangling target)."""
    if not _has_activity(t):
        return "n_a"
    # every succession block that uses `then` should also have an anchor
    ok = True
    for blk in _behavior_blocks(t):
        if "then" in blk and not re.search(r"\b(first|entry|start|transition)\b", blk):
            ok = False
    return _pf(ok)


def controlnodeincoming(t):
    """Joins/merges need >=2 incoming flows."""
    if not re.search(r"\b(merge|join)\b", t):
        return "n_a"
    ok = True
    for blk in _behavior_blocks(t):
        for kind in ("merge", "join"):
            for label in _step_labels(blk, kind):
                if _incoming(blk, label) < 2:
                    ok = False
    return _pf(ok)


def controlnodeoutgoing(t):
    """Forks/decisions need >=2 outgoing flows."""
    if not re.search(r"\b(fork|decide|decision)\b", t):
        return "n_a"
    ok = True
    for blk in _behavior_blocks(t):
        # a decide is followed by >=2 `if ... then` branches
        for m in re.finditer(r"\bdecide\b", blk):
            after = blk[m.end():]
            nxt = re.split(r"\b(decide|merge|join|fork)\b", after, maxsplit=1)[0]
            if len(re.findall(r"\bif\b|\bthen\b", nxt)) < 2:
                ok = False
        for label in _step_labels(blk, "fork"):
            if _outgoing(blk, label) < 2:
                ok = False
    return _pf(ok)


def mergejoinoutgoing(t):
    """Merge/join must have exactly one outgoing flow."""
    if not re.search(r"\b(merge|join)\b", t):
        return "n_a"
    ok = True
    for blk in _behavior_blocks(t):
        for kind in ("merge", "join"):
            for label in _step_labels(blk, kind):
                if _outgoing(blk, label) != 1:
                    ok = False
    return _pf(ok)


def flowfinalincoming(t):
    """Flow-final nodes need >=1 incoming and no outgoing."""
    if not re.search(r"\b(done|flow\s*final|final)\b", t):
        return "n_a"
    ok = True
    for blk in _behavior_blocks(t):
        for label in ("done", "final"):
            if label in blk:
                if _incoming(blk, label) < 1:
                    ok = False
                if _outgoing(blk, label) > 0:
                    ok = False
    return _pf(ok)


def ibdowner(t):
    """Internal structure (parts nesting parts) must live inside a part def."""
    # If there are nested `part x : Y { part ... }`, they are owned by def -> ok.
    if not _has(t, r"part\s+def"):
        return "n_a"
    # free-floating `part` at package top level without a def owner is the fail
    # case; approximate by checking every `part ` sits inside some `{ }`.
    ok = True
    depth = 0
    for tok in re.finditer(r"[{}]|part\s+def|\bpart\b", t):
        s = tok.group(0)
        if s == "{":
            depth += 1
        elif s == "}":
            depth = max(0, depth - 1)
        elif s == "part" and depth == 0:
            ok = False
    return _pf(ok)


# ---- behavior-block helpers ------------------------------------------------

def _behavior_blocks(t):
    """Return brace-balanced bodies of action/state/def blocks."""
    out = []
    for m in re.finditer(r"\b(action|state)\b[^\n{;]*\{", t):
        start = m.end() - 1
        depth = 0
        for i in range(start, len(t)):
            if t[i] == "{":
                depth += 1
            elif t[i] == "}":
                depth -= 1
                if depth == 0:
                    out.append(t[start + 1:i])
                    break
    return out or [t]


def _step_labels(blk, kind):
    """Labels of steps of a given control kind, e.g. `merge cont` -> cont."""
    labels = []
    for m in re.finditer(r"\b" + kind + r"\b[ \t]+(\w+)", blk):
        labels.append(m.group(1))
    return labels


def _incoming(blk, label):
    """Incoming edges to a labeled step = explicit `then <label>` references
    elsewhere + 1 if it also sits positionally after a `then`/`first`."""
    explicit = len(re.findall(r"\b(?:then|first)\b[ \t]+" + re.escape(label) + r"\b", blk))
    # positional: `then merge label` / `first join label` — the step itself
    positional = len(re.findall(
        r"\b(?:then|first)\b[ \t]+(?:merge|join|fork|decide)?\s*" + re.escape(label) + r"\b", blk))
    return max(explicit, positional)


def _outgoing(blk, label):
    """Outgoing edges from a labeled step. In `first/then` succession a step
    has one positional successor (the next `then`) unless it is re-targeted.
    Count `<label> then` adjacency plus the positional successor."""
    n = len(re.findall(r"\b" + re.escape(label) + r"\b[ \t]*;?[ \t\n]*then\b", blk))
    return n


# ---- registry --------------------------------------------------------------

RULES = {
    "ACTIVITYEDGEINCOMING": activityedgeincoming,
    "ACTIVITYNAME": activityname,
    "ACTORNAME": actorname,
    "ANNOTATEDELEMENTS": annotatedelements,
    "ARTIFACTNAME": artifactname,
    "BLOCKNAME": blockname,
    "CLASSPROHIBITED": classprohibited,
    "COMMENTBODY": commentbody,
    "CONSTRAINTSPECIFICATION": constraintspecification,
    "CONTROLNODEINCOMING": controlnodeincoming,
    "CONTROLNODEOUTGOING": controlnodeoutgoing,
    "DECISIONNODENAME": decisionnodename,
    "DIAGRAMNAME": diagramname,
    "ENUMERATIONLITERAL": enumerationliteral,
    "FLOWFINALINCOMING": flowfinalincoming,
    "IBDOWNER": ibdowner,
    "MERGEJOINOUTGOING": mergejoinoutgoing,
    "OPERATIONNAME": operationname,
    "PACKAGENAME": packagename,
    "SIGNALEVENTSIGNAL": signaleventsignal,
    "SIGNALNAME": signalname,
    "STMACHINENAME": stmachinename,
    "TERMNAME": termname,
    "USECASENAME": usecasename,
    "VALUENAME": valuename,
}


def check(code):
    """Run all rules on SysML v2 source; return {RULE: pass|fail|n_a}."""
    t = strip_comments(code)
    out = {}
    for name, fn in RULES.items():
        try:
            out[name] = fn(t)
        except Exception:
            out[name] = "fail"  # fail fast: a crashing check is a failed model
    return out


if __name__ == "__main__":
    import sys
    for p in sys.argv[1:]:
        r = check(open(p, encoding="utf-8").read())
        print(p)
        for k, v in r.items():
            print(f"  {k:<24} {v}")
