"""Generate yes/no presence questions from dataset SysML models via regex topology extract.

Uses the same ``extract_topology`` parser as the execution harness. Questions are
meant for LLM cross-checking: answer from the NL spec vs the generated SysML and
compare for mismatch.

From repo root::

    python nl2sysml/sysml_execution/generate_questions.py
    python nl2sysml/sysml_execution/generate_questions.py --limit 100
    python nl2sysml/sysml_execution/generate_questions.py -o nl2sysml/sysml_execution/questions.txt
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Iterable, List, Optional, Set, Tuple

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from nl2sysml.sysml_execution.extractor import extract_topology  # noqa: E402
from nl2sysml.sysml_execution.models import ExtractedTopology  # noqa: E402

_DATA = _REPO_ROOT / "dataset" / "data"
_DEFAULT_OUT = Path(__file__).resolve().parent / "generated_questions.txt"

# Boilerplate / non-domain names the extractor often surfaces.
_SKIP_NAMES = {
    "definitions",
    "usages",
    "analysis",
    "requirements",
    "verification",
    "views",
    "viewpoints",
    "parts",
    "items",
    "actions",
    "states",
    "attributes",
    "constraints",
    "interfaces",
    "ports",
    "connections",
    "calculation",
    "calculations",
    "domain",
    "model",
    "system",
    "systems",
    "package",
    "example",
    "examples",
}

_AUTO_CONSTRAINT_RE = re.compile(r"^(constraint_|assert_constraint_)\d+$")
_CAMEL_SPLIT_RE = re.compile(r"(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])")


def _display_name(name: str) -> str:
    """Strip SysML quoted-id quotes and normalize whitespace."""
    name = (name or "").strip()
    if len(name) >= 2 and name[0] == "'" and name[-1] == "'":
        name = name[1:-1]
    return " ".join(name.split())


def _is_useful_name(name: str) -> bool:
    label = _display_name(name)
    if not label or len(label) < 2:
        return False
    if label.lower() in _SKIP_NAMES:
        return False
    if _AUTO_CONSTRAINT_RE.match(label):
        return False
    # Pure numeric / single-letter ids are rarely useful for NL checks.
    if label.isdigit() or (len(label) == 1 and label.isalpha()):
        return False
    return True


def _phrase(name: str) -> str:
    """Readable phrase for questions; keep original casing of multi-word names."""
    label = _display_name(name)
    if " " in label or "-" in label or "_" in label:
        return label.replace("_", " ")
    # CamelCase -> spaced words for NL readability.
    spaced = _CAMEL_SPLIT_RE.sub(" ", label)
    return spaced if spaced != label else label


def _q(template: str, **kwargs: str) -> str:
    return template.format(**{k: _phrase(v) for k, v in kwargs.items()})


def questions_from_topology(topo: ExtractedTopology) -> List[str]:
    """Build yes/no presence / structure questions from one extracted model."""
    qs: List[str] = []

    for part in topo.formal_part_defs:
        if _is_useful_name(part):
            qs.append(_q("Does this specification require a '{name}' part?", name=part))

    # Shorthand part usages (instances) not already covered as formal defs.
    formal = set(topo.formal_part_defs)
    for part in topo.part_defs:
        if part in formal or not _is_useful_name(part):
            continue
        qs.append(_q("Does this specification include a '{name}' part?", name=part))

    for attr_def in topo.attribute_defs:
        if _is_useful_name(attr_def.name):
            qs.append(
                _q(
                    "Does this specification define a '{name}' attribute or signal type?",
                    name=attr_def.name,
                )
            )

    for item in topo.item_defs:
        if _is_useful_name(item.name):
            qs.append(_q("Does this specification define a '{name}' item?", name=item.name))

    for enum in topo.enum_defs:
        if _is_useful_name(enum.name):
            qs.append(
                _q("Does this specification define a '{name}' enumeration?", name=enum.name)
            )
            for lit in enum.literals:
                if _is_useful_name(lit):
                    qs.append(
                        _q(
                            "Does the '{enum}' enumeration include a '{lit}' value?",
                            enum=enum.name,
                            lit=lit,
                        )
                    )

    for action in topo.action_defs:
        if not _is_useful_name(action.name):
            continue
        qs.append(_q("Does this specification include a '{name}' action?", name=action.name))
        for pin, typ in action.input_types.items():
            if _is_useful_name(pin) and _is_useful_name(typ):
                qs.append(
                    _q(
                        "Does the '{action}' action take a '{pin}' input of type '{typ}'?",
                        action=action.name,
                        pin=pin,
                        typ=typ,
                    )
                )
        for out in action.outputs:
            if _is_useful_name(out):
                qs.append(
                    _q(
                        "Does the '{action}' action produce a '{out}' output?",
                        action=action.name,
                        out=out,
                    )
                )

    for usage in topo.action_usages:
        if not _is_useful_name(usage.name):
            continue
        if usage.type_ref and _is_useful_name(usage.type_ref):
            qs.append(
                _q(
                    "Does this specification use a '{name}' action of type '{typ}'?",
                    name=usage.name,
                    typ=usage.type_ref,
                )
            )
        else:
            qs.append(
                _q("Does this specification include a '{name}' action usage?", name=usage.name)
            )

    for sm in topo.state_machines:
        if not _is_useful_name(sm.name):
            continue
        qs.append(
            _q("Does this specification include a '{name}' state machine?", name=sm.name)
        )
        if sm.entry_state and _is_useful_name(sm.entry_state):
            qs.append(
                _q(
                    "Does the '{sm}' state machine start in a '{state}' state?",
                    sm=sm.name,
                    state=sm.entry_state,
                )
            )
        for tr in sm.transitions:
            if tr.trigger_kind == "accept" and tr.trigger and _is_useful_name(tr.trigger):
                qs.append(
                    _q(
                        "Does the '{sm}' state machine accept a '{signal}' signal?",
                        sm=sm.name,
                        signal=tr.trigger,
                    )
                )
            if (
                tr.source
                and tr.target
                and _is_useful_name(tr.source)
                and _is_useful_name(tr.target)
            ):
                qs.append(
                    _q(
                        "Does the '{sm}' state machine transition from '{src}' to '{tgt}'?",
                        sm=sm.name,
                        src=tr.source,
                        tgt=tr.target,
                    )
                )

    for acc in topo.accept_actions:
        if _is_useful_name(acc.signal_type):
            qs.append(
                _q(
                    "Does this specification accept an incoming '{signal}' signal?",
                    signal=acc.signal_type,
                )
            )

    for send in topo.send_actions:
        if _is_useful_name(send.signal_type):
            qs.append(
                _q(
                    "Does this specification send an outgoing '{signal}' signal?",
                    signal=send.signal_type,
                )
            )

    for attr in topo.attributes:
        if not _is_useful_name(attr.name):
            continue
        if attr.owner and _is_useful_name(attr.owner) and attr.owner.lower() not in _SKIP_NAMES:
            qs.append(
                _q(
                    "Does the '{owner}' element have a '{name}' attribute?",
                    owner=attr.owner,
                    name=attr.name,
                )
            )
        else:
            qs.append(
                _q("Does this specification include a '{name}' attribute?", name=attr.name)
            )

    for c in topo.constraints:
        if _is_useful_name(c.name):
            qs.append(
                _q("Does this specification include a '{name}' constraint?", name=c.name)
            )

    for pb in topo.part_behaviors:
        if not (_is_useful_name(pb.part_def) and _is_useful_name(pb.usage_name)):
            continue
        if pb.kind == "perform_action":
            qs.append(
                _q(
                    "Does the '{part}' part perform a '{usage}' action?",
                    part=pb.part_def,
                    usage=pb.usage_name,
                )
            )
        elif pb.kind == "exhibit_state":
            qs.append(
                _q(
                    "Does the '{part}' part exhibit a '{usage}' state machine?",
                    part=pb.part_def,
                    usage=pb.usage_name,
                )
            )

    return qs


def _list_samples(
    *,
    start: Optional[str] = None,
    limit: Optional[int] = None,
) -> List[Path]:
    samples: List[Path] = []
    for child in sorted(_DATA.iterdir()):
        if not child.is_dir():
            continue
        sysml = child / f"{child.name}.sysml"
        if sysml.is_file():
            samples.append(sysml)
    if start:
        start_id = start.strip("/")
        samples = [p for p in samples if p.parent.name >= start_id]
    if limit is not None:
        samples = samples[:limit]
    return samples


def _dedupe_preserve(items: Iterable[str]) -> List[str]:
    seen: Set[str] = set()
    out: List[str] = []
    for item in items:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out


def generate_questions(
    *,
    start: Optional[str] = None,
    limit: Optional[int] = None,
    min_count: int = 1,
) -> Tuple[List[str], Counter]:
    """Scan dataset models and return (sorted questions, frequency counter)."""
    counts: Counter = Counter()
    samples = _list_samples(start=start, limit=limit)
    for path in samples:
        text = path.read_text(encoding="utf-8", errors="replace")
        topo = extract_topology(text)
        for q in _dedupe_preserve(questions_from_topology(topo)):
            counts[q] += 1

    questions = [q for q, n in counts.most_common() if n >= min_count]
    return questions, counts


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate yes/no SysML/NL mismatch questions from dataset models",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=_DEFAULT_OUT,
        help=f"output path (default: {_DEFAULT_OUT})",
    )
    parser.add_argument("--start", default=None, help="start at sample id (inclusive)")
    parser.add_argument("--limit", type=int, default=None, help="process at most N samples")
    parser.add_argument(
        "--min-count",
        type=int,
        default=1,
        help="keep questions that appear in at least N models (default: 1)",
    )
    args = parser.parse_args(argv)

    if not _DATA.is_dir():
        print(f"dataset not found: {_DATA}", file=sys.stderr)
        return 1

    questions, counts = generate_questions(
        start=args.start,
        limit=args.limit,
        min_count=args.min_count,
    )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(questions) + ("\n" if questions else ""), encoding="utf-8")

    n_samples = len(_list_samples(start=args.start, limit=args.limit))
    print(f"scanned {n_samples} sample(s)")
    print(f"unique questions: {len(questions)} (min_count={args.min_count})")
    if counts:
        top = counts.most_common(5)
        print("top by frequency:")
        for q, n in top:
            print(f"  [{n}] {q}")
    print(f"wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
