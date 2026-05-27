"""Approximate executable-rule checks for SysML 2 textual models.

The checks are intentionally conservative: they distinguish missing concepts
from unsupported parser fidelity, and they keep enough rationale for repair.
They can be replaced by AST-backed checks later without changing result.csv.
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


def _strip_line_comments(code: str) -> str:
    lines = []
    for line in code.splitlines():
        if "//" in line:
            line = line.split("//", 1)[0]
        lines.append(line)
    return "\n".join(lines)


def _meaningful_lines(code: str) -> list[tuple[int, str]]:
    clean = _strip_line_comments(code)
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
    return f"L{line_no}: {text[:120]}"


def _message_lines(lines: list[tuple[int, str]]) -> list[tuple[int, str]]:
    return [
        (n, t)
        for n, t in lines
        if re.search(r"^(?:\w+\s+)?message\b|\bmessage\s*:>>", t, re.I)
    ]


def _accept_event_output(code: str) -> RuleEvaluation:
    lines = _meaningful_lines(code)
    accept_lines = [(n, t) for n, t in lines if re.search(r"\baccept\b", t, re.I)]
    if not accept_lines:
        return RuleEvaluation(
            "ACCEPTEVENTOUTPUT",
            "Executable",
            "not_applicable",
            "approximate",
            0,
            [],
            "No accept actions or accept-triggered transitions were found.",
            ["S1", "S2", "S3", "S5"],
        )

    failing: list[str] = []
    for line_no, text in accept_lines:
        low = text.lower()
        if any(token in low for token in ("completion", "timeout", '"')):
            continue
        has_payload_pin = bool(
            re.search(r"\baccept\s+\w+\s*:\s*[\w:]+", text, re.I)
            or re.search(r"\bout\s+(item\s+)?\w+\s*:\s*[\w:]+", text, re.I)
            or re.search(r"\boutput\s+\w+\s*:\s*[\w:]+", text, re.I)
        )
        if not has_payload_pin:
            failing.append(_line_label(line_no, text))

    status: RuleStatus = "fail" if failing else "pass"
    rationale = (
        "Signal-like accept events should expose a typed output pin or payload parameter."
        if failing
        else "Every signal-like accept event found carries an inline typed payload/output."
    )
    return RuleEvaluation(
        "ACCEPTEVENTOUTPUT",
        "Executable",
        status,
        "approximate",
        len(accept_lines),
        failing,
        rationale,
        ["S1", "S2", "S3", "S5"],
    )


def _message_signature(code: str) -> RuleEvaluation:
    lines = _meaningful_lines(code)
    message_lines = _message_lines(lines)
    if not message_lines:
        return RuleEvaluation(
            "MESSAGESIGNATURE",
            "Executable",
            "not_applicable",
            "legacy-derived",
            0,
            [],
            "No sequence/message records were found.",
            ["S1", "S2", "S3", "S5"],
        )

    failing: list[str] = []
    for line_no, text in message_lines:
        if re.search(r"\b(reply|create|delete)\b", text, re.I):
            continue
        has_signature = bool(
            re.search(r"\bmessage\b.*(:|=|of|:>>)\s*[\w:.\[\]]+", text, re.I)
        )
        if not has_signature:
            failing.append(_line_label(line_no, text))

    return RuleEvaluation(
        "MESSAGESIGNATURE",
        "Executable",
        "fail" if failing else "pass",
        "legacy-derived",
        len(message_lines),
        failing,
        "Ordinary messages must resolve to an operation, action, signal, item, or event signature.",
        ["S1", "S2", "S3", "S5"],
    )


def _message_flow_needed(code: str) -> RuleEvaluation:
    clean = _strip_line_comments(code)
    lines = _meaningful_lines(clean)
    message_lines = _message_lines(lines)
    if not message_lines:
        return RuleEvaluation(
            "MESSAGEFLOWNEEDED",
            "Executable",
            "not_applicable",
            "legacy-derived",
            0,
            [],
            "No signal message signatures were found.",
            ["S1", "S2", "S3", "S4", "S5"],
        )

    flowish = _has_any(clean, ["flow", "connect", "interface", "port"])
    item_defs = _names(r"\bitem\s+def\s+([A-Za-z_][\w]*)", clean)
    failing: list[str] = []
    for line_no, text in message_lines:
        if re.search(r"\b(reply|create|delete)\b", text, re.I):
            continue
        sig_match = re.search(r"(?:=|:|of|:>>)\s*([A-Za-z_][\w:]*)", text)
        signature = sig_match.group(1).split("::")[-1] if sig_match else ""
        signal_like = (not signature) or signature in item_defs or "signal" in text.lower()
        if signal_like and not flowish:
            failing.append(_line_label(line_no, text))

    return RuleEvaluation(
        "MESSAGEFLOWNEEDED",
        "Executable",
        "fail" if failing else "pass",
        "legacy-derived",
        len(message_lines),
        failing,
        "Signal-like messages should be realized by item flows, object flows, connectors, or interface features.",
        ["S1", "S2", "S3", "S4", "S5"],
    )


def _state_machine_blocks(code: str) -> list[str]:
    blocks: list[str] = []
    for match in re.finditer(r"\bstate\s+machine(?:\s+def)?\s+([A-Za-z_][\w]*)?", code, re.I):
        start = match.start()
        brace = code.find("{", match.end())
        if brace == -1:
            blocks.append(code[start : match.end()])
            continue
        depth = 0
        for idx in range(brace, len(code)):
            if code[idx] == "{":
                depth += 1
            elif code[idx] == "}":
                depth -= 1
                if depth == 0:
                    blocks.append(code[start : idx + 1])
                    break
    return blocks


def _state_machine_integrity(code: str) -> RuleEvaluation:
    clean = _strip_line_comments(code)
    blocks = _state_machine_blocks(clean)
    if not blocks:
        return RuleEvaluation(
            "STMINTEGRITY",
            "Executable",
            "not_applicable",
            "approximate",
            0,
            [],
            "No state-machine-like behavior was found.",
            ["S1", "S2", "S3", "S5"],
        )

    action_defs = _names(r"\baction\s+def\s+([A-Za-z_][\w]*)", clean)
    part_defs = _names(r"\bpart\s+def\s+([A-Za-z_][\w]*)", clean)
    known = action_defs | part_defs
    failing: list[str] = []
    checked_calls = 0
    for block in blocks:
        for call in re.finditer(r"\b(?:perform|do|entry|exit|effect)\s+(?:action\s+)?([A-Za-z_][\w]*)", block, re.I):
            name = call.group(1)
            if name in {"then", "first", "start", "done"}:
                continue
            checked_calls += 1
            if known and name not in known:
                failing.append(name)

    if checked_calls == 0:
        status: RuleStatus = "pass"
        rationale = "State machines were found, but no operation/action calls requiring ownership resolution were found."
    elif not known:
        status = "unsupported"
        rationale = "State-machine calls were found, but the checker could not resolve action or part definitions."
    else:
        status = "fail" if failing else "pass"
        rationale = "Called actions should be owned by or reachable from the state machine's owning structural context."

    return RuleEvaluation(
        "STMINTEGRITY",
        "Executable",
        status,
        "approximate",
        checked_calls,
        sorted(set(failing)),
        rationale,
        ["S1", "S2", "S3", "S5"],
    )


def _submachine_structure(code: str) -> RuleEvaluation:
    clean = _strip_line_comments(code)
    machine_defs = _names(r"\bstate\s+machine(?:\s+def)?\s+([A-Za-z_][\w]*)", clean)
    refs: list[tuple[str, str]] = []
    for match in re.finditer(r"\bsubmachine\s+([A-Za-z_][\w]*)\s*:\s*([A-Za-z_][\w:]*)", clean, re.I):
        refs.append((match.group(1), match.group(2).split("::")[-1]))
    for match in re.finditer(r"\bstate\s+([A-Za-z_][\w]*)\s*:\s*([A-Za-z_][\w:]*)", clean, re.I):
        refs.append((match.group(1), match.group(2).split("::")[-1]))

    if not refs:
        return RuleEvaluation(
            "SUBMACHINESTR",
            "Executable",
            "not_applicable",
            "approximate",
            0,
            [],
            "No submachine-state references were found.",
            ["S1", "S2", "S3", "S5"],
        )

    failing = [f"{state}:{ref}" for state, ref in refs if ref not in machine_defs]
    status: RuleStatus
    if not machine_defs:
        status = "unsupported"
    else:
        status = "fail" if failing else "pass"
    return RuleEvaluation(
        "SUBMACHINESTR",
        "Executable",
        status,
        "approximate",
        len(refs),
        failing,
        "Submachine references should resolve to state machines in the owning block structure or typed part structure.",
        ["S1", "S2", "S3", "S5"],
    )


def evaluate_executable_rules(code: str) -> list[RuleEvaluation]:
    """Evaluate all active Executable rules against SysML 2 text."""

    return [
        _accept_event_output(code),
        _message_flow_needed(code),
        _message_signature(code),
        _state_machine_integrity(code),
        _submachine_structure(code),
    ]
