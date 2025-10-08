from __future__ import annotations
from typing import List, Dict, Tuple
from .ir_schema import IR, Block, Connector, Requirement

def _render_block_def(b: Block) -> str:
    lines = []
    lines.append(f"part def {b.name};")
    lines.append(f"{b.name} {{")
    for p in b.parts:
        agg = "" if p.aggregation != "composite" else ""  # v2 doesn't use keyword here in text form
        lines.append(f"  part {p.name}: {p.type};")
    for vp in b.valueProperties:
        lines.append(f"  attribute {vp.name}: {vp.type};")
        for c in vp.constraints:
            lines.append(f"  // constraint: {c}")
    for port in b.ports:
        direction = port.direction or ""
        if direction:
            lines.append(f"  port {port.name}: {direction}; // {port.kind} {port.interface or ''}".rstrip())
        else:
            lines.append(f"  port {port.name}; // {port.kind} {port.interface or ''}".rstrip())
    lines.append("}")
    return "\n".join(lines)

def _render_connectors(conns: List[Connector]) -> List[str]:
    res = []
    for c in conns:
        items = (" using item " + ", ".join(c.items)) if c.items else ""
        res.append(f"connection {c.from_} -> {c.to}{items};")
    return res

def _render_requirement(r: Requirement) -> str:
    sid = f" <{r.id}>" if r.id else ""
    lines = [f"requirement{sid} {r.name} {{",
             f'  doc "{r.text.replace(chr(34), chr(39))}";',
             "}"]
    return "\n".join(lines)

def ir_to_v2_text(ir: IR) -> Dict[str, str]:
    """Return a dict {filename_without_ext: text} for a single monolithic draft.
    You will shard later."""
    units_pkg = "package Libraries::Units;\n// define units/quantity kinds here\n"
    files : Dict[str, str] = {"Libraries/Units": units_pkg}

    # Basic structure file
    body = ["package Structure::Core;",
            "import Libraries::Units;",
            ""]
    for b in ir.blocks:
        body.append(_render_block_def(b))
        body.append("")
    for s in _render_connectors(ir.connectors):
        body.append(s)
    files["Structure/Core"] = "\n".join(body)

    # Requirements file
    if ir.requirements:
        rbody = ["package Requirements::Core;", ""]
        for r in ir.requirements:
            rbody.append(_render_requirement(r))
            rbody.append("")
        files["Requirements/Core"] = "\n".join(rbody)

    return files
