"""Text-first checks for SysML 2 Executable modeling rules.

These checks intentionally avoid a full SysML parser. They extract enough
structure from textual SysML to score the executable rules in bulk datasets and
return explicit statuses when a concept is absent or parser fidelity is limited.
"""

from __future__ import annotations

import re
from dataclasses import asdict, dataclass
from typing import Iterable, Literal

RuleStatus = Literal["pass", "fail", "not_applicable", "unsupported"]


@dataclass
class RuleEvaluation:
    rule_id: str
    ruleset: str
    status: RuleStatus
    score: float
    support_mode: str
    checked_elements: int
    failing_elements: list[str]
    rationale: str
    citations: list[str]

    def to_dict(self) -> dict:
        return asdict(self)


EXECUTABLE_RULE_IDS = [
    "ACCEPTEVENTOUTPUT",
    "MESSAGEFLOWNEEDED",
    "MESSAGESIGNATURE",
    "STMINTEGRITY",
    "SUBMACHINESTR",
]


def status_to_score(status: RuleStatus) -> float:
    if status == "pass":
        return 1.0
    if status == "fail":
        return 0.0
    if status == "not_applicable":
        return 1.0
    return 0.5


def _result(
    rule_id: str,
    status: RuleStatus,
    checked_elements: int,
    failing_elements: list[str],
    rationale: str,
    *,
    support_mode: str,
    citations: list[str],
) -> RuleEvaluation:
    return RuleEvaluation(
        rule_id=rule_id,
        ruleset="Executable",
        status=status,
        score=status_to_score(status),
        support_mode=support_mode,
        checked_elements=checked_elements,
        failing_elements=failing_elements,
        rationale=rationale,
        citations=citations,
    )


def _strip_comments(code: str) -> str:
    without_blocks = re.sub(r"/\*.*?\*/", "", code, flags=re.DOTALL)
    return re.sub(r"//.*", "", without_blocks)


def _meaningful_lines(code: str) -> list[tuple[int, str]]:
    clean = _strip_comments(code)
    return [
        (i, line.strip())
        for i, line in enumerate(clean.splitlines(), 1)
        if line.strip()
    ]


def _names(pattern: str, code: str) -> set[str]:
    return {m.group(1) for m in re.finditer(pattern, code, flags=re.IGNORECASE)}


def _has_any(code: str, words: Iterable[str]) -> bool:
    low = code.lower()
    return any(w.lower() in low for w in words)


def _line_label(line_no: int, text: str) -> str:
    return f"L{line_no}: {text[:140]}"


def _message_lines(lines: list[tuple[int, str]]) -> list[tuple[int, str]]:
    message_decl = re.compile(
        r"^(?:then\s+)?(?:in\s+|out\s+)?message\b|\bmessage\s*:>>|\bmessage\s*:|\bmessage\s+def\b",
        re.IGNORECASE,
    )
    return [(n, t) for n, t in lines if message_decl.search(t)]


def _flow_exchange_lines(lines: list[tuple[int, str]]) -> list[tuple[int, str]]:
    exchange = re.compile(
        r"\bflow\b|\bconnect\b|\bconnection\b",
        re.IGNORECASE,
    )
    return [(n, t) for n, t in lines if exchange.search(t)]


def _has_executable_context(code: str) -> bool:
    return bool(
        re.search(
            r"\b(action|perform|state|transition|accept|send|flow|connect|connection|message)\b",
            code,
            re.IGNORECASE,
        )
    )


def _balanced_block_from(code: str, brace_pos: int) -> str:
    depth = 0
    for idx in range(brace_pos, len(code)):
        if code[idx] == "{":
            depth += 1
        elif code[idx] == "}":
            depth -= 1
            if depth == 0:
                return code[brace_pos : idx + 1]
    return code[brace_pos:]


def _state_machine_blocks(code: str) -> list[str]:
    blocks: list[str] = []
    pattern = re.compile(
        r"\b(?:state\s+machine(?:\s+def)?|state\s+def|state)\s+([A-Za-z_][\w]*)?",
        re.IGNORECASE,
    )
    for match in pattern.finditer(code):
        name = match.group(1) or ""
        if (
            match.group(0).lower().startswith("state ")
            and "machine" not in match.group(0).lower()
            and "def" not in match.group(0).lower()
            and not re.search(r"(statemachine|states)$", name, re.IGNORECASE)
        ):
            continue
        brace = code.find("{", match.end())
        if brace == -1:
            blocks.append(code[match.start() : match.end()])
        else:
            blocks.append(code[match.start() : brace] + _balanced_block_from(code, brace))
    return blocks


def _defined_behavior_names(code: str) -> set[str]:
    patterns = [
        r"\baction\s+def\s+([A-Za-z_][\w]*)",
        r"\baction\s+([A-Za-z_][\w]*)\s*:",
        r"\baction\s+([A-Za-z_][\w]*)\s*[;{]",
        r"\boperation\s+(?:def\s+)?([A-Za-z_][\w]*)",
        r"\bperform\s+action\s+([A-Za-z_][\w]*)\s*:",
    ]
    names: set[str] = set()
    for pattern in patterns:
        names.update(_names(pattern, code))
    return names


def check_accept_event_output(code: str) -> RuleEvaluation:
    lines = _meaningful_lines(code)
    accept_lines = [(n, t) for n, t in lines if re.search(r"\baccept\b", t, re.I)]
    if not accept_lines:
        clean = _strip_comments(code)
        if _has_executable_context(clean):
            return _result(
                "ACCEPTEVENTOUTPUT",
                "pass",
                0,
                [],
                "Executable behavior was found, but no signal accept events require output pins.",
                support_mode="approximate",
                citations=["S1", "S2", "S3", "S5"],
            )
        return _result(
            "ACCEPTEVENTOUTPUT",
            "not_applicable",
            0,
            [],
            "No accept actions or accept-triggered transitions were found.",
            support_mode="approximate",
            citations=["S1", "S2", "S3", "S5"],
        )

    failing: list[str] = []
    for line_no, text in accept_lines:
        low = text.lower()
        event_is_signal_like = not any(
            token in low for token in ("completion", "timeout", "after ", "when ")
        )
        if not event_is_signal_like:
            continue
        has_output = bool(
            re.search(r"\baccept\s+\w+\s*:\s*[\w:]+", text, re.I)
            or re.search(r"\baccept\s+\w+\s+via\s+\w+", text, re.I)
            or re.search(r"\bout\s+(?:item\s+)?\w+\s*:\s*[\w:]+", text, re.I)
            or re.search(r"\boutput\s+\w+\s*:\s*[\w:]+", text, re.I)
        )
        quoted_literal = bool(re.search(r"\baccept\s+['\"]", text, re.I))
        if not has_output and not quoted_literal:
            failing.append(_line_label(line_no, text))

    return _result(
        "ACCEPTEVENTOUTPUT",
        "fail" if failing else "pass",
        len(accept_lines),
        failing,
        (
            "Signal-like accept events should expose a typed output pin or payload parameter."
            if failing
            else "All signal-like accept events carry a typed output/payload or are literal control triggers."
        ),
        support_mode="approximate",
        citations=["S1", "S2", "S3", "S5"],
    )


def check_message_signature(code: str) -> RuleEvaluation:
    lines = _meaningful_lines(code)
    messages = _message_lines(lines)
    if not messages:
        flows = _flow_exchange_lines(lines)
        if flows:
            return _result(
                "MESSAGESIGNATURE",
                "pass",
                len(flows),
                [],
                "No explicit sequence messages were found; derived exchanges are expressed as flows/connectors with endpoint signatures.",
                support_mode="legacy-derived",
                citations=["S1", "S2", "S3", "S5"],
            )
        clean = _strip_comments(code)
        if _has_executable_context(clean):
            return _result(
                "MESSAGESIGNATURE",
                "pass",
                0,
                [],
                "Executable behavior was found, but no sequence messages require signatures.",
                support_mode="legacy-derived",
                citations=["S1", "S2", "S3", "S5"],
            )
        return _result(
            "MESSAGESIGNATURE",
            "not_applicable",
            0,
            [],
            "No sequence/message records were found.",
            support_mode="legacy-derived",
            citations=["S1", "S2", "S3", "S5"],
        )

    failing: list[str] = []
    for line_no, text in messages:
        if re.search(r"\bmessage\s+def\s+[A-Za-z_][\w]*", text, re.I):
            continue
        if re.search(r"\b(reply|create|delete)\b", text, re.I):
            continue
        has_signature = bool(
            re.search(r"\bmessage\b.*(?:=|:|of|:>>)\s*[\w:.\[\]]+", text, re.I)
            or re.search(r"\b(?:in|out)\s+message\s*:\s*[\w:.\[\]]+", text, re.I)
        )
        if not has_signature:
            failing.append(_line_label(line_no, text))

    return _result(
        "MESSAGESIGNATURE",
        "fail" if failing else "pass",
        len(messages),
        failing,
        "Ordinary messages must have a resolvable operation/action/signal/item/event signature.",
        support_mode="legacy-derived",
        citations=["S1", "S2", "S3", "S5"],
    )


def check_message_flow_needed(code: str) -> RuleEvaluation:
    clean = _strip_comments(code)
    lines = _meaningful_lines(clean)
    messages = _message_lines(lines)
    flows = _flow_exchange_lines(lines)
    if not messages:
        if flows:
            return _result(
                "MESSAGEFLOWNEEDED",
                "pass",
                len(flows),
                [],
                "No explicit signal messages were found; exchanges are already realized by flows/connectors.",
                support_mode="legacy-derived",
                citations=["S1", "S2", "S3", "S4", "S5"],
            )
        if _has_executable_context(clean):
            return _result(
                "MESSAGEFLOWNEEDED",
                "pass",
                0,
                [],
                "Executable behavior was found, but no signal messages require realization by flows.",
                support_mode="legacy-derived",
                citations=["S1", "S2", "S3", "S4", "S5"],
            )
        return _result(
            "MESSAGEFLOWNEEDED",
            "not_applicable",
            0,
            [],
            "No signal message signatures were found.",
            support_mode="legacy-derived",
            citations=["S1", "S2", "S3", "S4", "S5"],
        )

    flowish = _has_any(clean, ["flow", "connect", "interface", "port", "binding connector"])
    signal_defs = _names(r"\b(?:item|signal)\s+def\s+([A-Za-z_][\w]*)", clean)
    failing: list[str] = []
    for line_no, text in messages:
        if re.search(r"\bmessage\s+def\b", text, re.I):
            continue
        if re.search(r"\b(reply|create|delete)\b", text, re.I):
            continue
        sig_match = re.search(r"(?:=|:|of|:>>)\s*([A-Za-z_][\w:]*)", text)
        signature = sig_match.group(1).split("::")[-1] if sig_match else ""
        signal_like = (not signature) or signature in signal_defs or "signal" in text.lower()
        if signal_like and not flowish:
            failing.append(_line_label(line_no, text))

    return _result(
        "MESSAGEFLOWNEEDED",
        "fail" if failing else "pass",
        len(messages),
        failing,
        "Signal-like messages should be realized by item flows, object flows, connectors, or interface features.",
        support_mode="legacy-derived",
        citations=["S1", "S2", "S3", "S4", "S5"],
    )


def check_state_machine_integrity(code: str) -> RuleEvaluation:
    clean = _strip_comments(code)
    machines = _state_machine_blocks(clean)
    if not machines:
        if _has_executable_context(clean):
            return _result(
                "STMINTEGRITY",
                "pass",
                0,
                [],
                "Executable behavior was found, but no state machine calls require ownership checks.",
                support_mode="approximate",
                citations=["S1", "S2", "S3", "S5"],
            )
        return _result(
            "STMINTEGRITY",
            "not_applicable",
            0,
            [],
            "No state-machine-like behavior was found.",
            support_mode="approximate",
            citations=["S1", "S2", "S3", "S5"],
        )

    known = _defined_behavior_names(clean)
    checked = 0
    failing: list[str] = []
    call_pattern = re.compile(
        r"\b(?:perform|do|entry|exit|effect)\s+(?:action\s+)?([A-Za-z_][\w]*)",
        re.IGNORECASE,
    )
    ignored = {
        "then",
        "first",
        "start",
        "done",
        "entry",
        "exit",
        "action",
        "accept",
        "assign",
        "send",
    }
    for block in machines:
        for call in call_pattern.finditer(block):
            name = call.group(1)
            if name.lower() in ignored:
                continue
            checked += 1
            if known and name not in known:
                failing.append(name)

    if checked == 0:
        return _result(
            "STMINTEGRITY",
            "pass",
            0,
            [],
            "State machines were found, but no operation/action calls requiring ownership resolution were found.",
            support_mode="approximate",
            citations=["S1", "S2", "S3", "S5"],
        )
    if not known:
        return _result(
            "STMINTEGRITY",
            "unsupported",
            checked,
            [],
            "State-machine calls were found, but action/operation definitions could not be resolved textually.",
            support_mode="approximate",
            citations=["S1", "S2", "S3", "S5"],
        )
    return _result(
        "STMINTEGRITY",
        "fail" if failing else "pass",
        checked,
        sorted(set(failing)),
        "State-machine calls should resolve to locally defined or structurally reachable actions/operations.",
        support_mode="approximate",
        citations=["S1", "S2", "S3", "S5"],
    )


def check_submachine_structure(code: str) -> RuleEvaluation:
    clean = _strip_comments(code)
    machine_defs = _names(r"\bstate\s+machine(?:\s+def)?\s+([A-Za-z_][\w]*)", clean)
    machine_defs.update(_names(r"\bstate\s+def\s+([A-Za-z_][\w]*)", clean))
    machine_defs.update(
        name
        for name in _names(r"\bstate\s+([A-Za-z_][\w]*)\s*\{", clean)
        if re.search(r"(statemachine|states)$", name, re.IGNORECASE)
    )
    refs: list[tuple[str, str]] = []
    for match in re.finditer(
        r"\bsubmachine\s+([A-Za-z_][\w]*)\s*:\s*([A-Za-z_][\w:]*)",
        clean,
        re.IGNORECASE,
    ):
        refs.append((match.group(1), match.group(2).split("::")[-1]))
    for match in re.finditer(
        r"\bstate\s+([A-Za-z_][\w]*)\s*:\s*([A-Za-z_][\w:]*)",
        clean,
        re.IGNORECASE,
    ):
        refs.append((match.group(1), match.group(2).split("::")[-1]))

    if not refs:
        if machine_defs or _has_executable_context(clean):
            return _result(
                "SUBMACHINESTR",
                "pass",
                0,
                [],
                "Executable behavior was found, but no submachine states were referenced.",
                support_mode="approximate",
                citations=["S1", "S2", "S3", "S5"],
            )
        return _result(
            "SUBMACHINESTR",
            "not_applicable",
            0,
            [],
            "No submachine-state references were found.",
            support_mode="approximate",
            citations=["S1", "S2", "S3", "S5"],
        )
    if not machine_defs:
        return _result(
            "SUBMACHINESTR",
            "unsupported",
            len(refs),
            [],
            "Submachine references were found, but no state machine definitions were resolvable textually.",
            support_mode="approximate",
            citations=["S1", "S2", "S3", "S5"],
        )

    failing = [f"{state}:{ref}" for state, ref in refs if ref not in machine_defs]
    return _result(
        "SUBMACHINESTR",
        "fail" if failing else "pass",
        len(refs),
        failing,
        "Submachine references should resolve to state machines in the owning or typed-part structure.",
        support_mode="approximate",
        citations=["S1", "S2", "S3", "S5"],
    )


def evaluate_executable_rules(code: str) -> list[RuleEvaluation]:
    return [
        check_accept_event_output(code),
        check_message_flow_needed(code),
        check_message_signature(code),
        check_state_machine_integrity(code),
        check_submachine_structure(code),
    ]
