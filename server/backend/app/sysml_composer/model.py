"""
SysML-like DSL model, builder, parser, and Graphviz renderer.
Deterministic; no LLM usage.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field


@dataclass
class BlockDef:
    name: str
    attributes: list[tuple[str, str]] = field(default_factory=list)
    parts: list[str] = field(default_factory=list)


@dataclass
class UseCaseDef:
    name: str
    subject: str = ""
    actors: list[str] = field(default_factory=list)


@dataclass
class RequirementDef:
    req_id: str
    text: str


@dataclass
class RenderHints:
    layout: dict = field(default_factory=lambda: {"rankdir": "LR"})
    style: dict = field(default_factory=lambda: {"fontname": "Helvetica"})


@dataclass
class SysMLModel:
    package: str = ""
    actors: list[str] = field(default_factory=list)
    blocks: list[BlockDef] = field(default_factory=list)
    usecases: list[UseCaseDef] = field(default_factory=list)
    requirements: list[RequirementDef] = field(default_factory=list)
    render_hints: RenderHints = field(default_factory=RenderHints)


class SysMLModelBuilder:
    """Build a SysML-like textual representation from an internal model."""

    def __init__(self, model: SysMLModel):
        self.model = model

    def render(self) -> str:
        lines: list[str] = []
        m = self.model
        lines.append(f"package {m.package} {{")
        lines.append("  import sysml;")
        lines.append("")

        for a in m.actors:
            lines.append(f"  actor {a};")
        if m.actors:
            lines.append("")

        for b in m.blocks:
            lines.append(f"  block {b.name} {{")
            for aname, atype in b.attributes:
                lines.append(f"    attribute {aname}: {atype};")
            for part in b.parts:
                lines.append(f"    part {part}: Block;")
            lines.append("  }")
            lines.append("")

        for uc in m.usecases:
            lines.append(f"  usecase {uc.name} {{")
            if uc.subject:
                lines.append(f"    subject {uc.subject};")
            for a in uc.actors:
                lines.append(f"    actor {a};")
            lines.append("  }")
            lines.append("")

        for r in m.requirements:
            escaped = r.text.replace('"', '\\"')
            lines.append(f'  requirement {r.req_id} "{escaped}";')
        if m.requirements:
            lines.append("")

        lines.append("}")
        return "\n".join(lines)


def parse_sysml_to_model(text: str) -> SysMLModel:
    """Parse a SysML-like DSL string back into an internal SysMLModel."""
    model = SysMLModel()

    pkg_m = re.search(r"package\s+(\S+)\s*\{", text)
    if pkg_m:
        model.package = pkg_m.group(1)

    stripped = re.sub(r"(block|usecase)\s+\S+\s*\{[^}]*\}", "", text, flags=re.DOTALL)
    for m in re.finditer(r"^\s*actor\s+(\S+)\s*;", stripped, re.MULTILINE):
        model.actors.append(m.group(1))

    block_pat = re.compile(r"block\s+(\S+)\s*\{(.*?)\}", re.DOTALL)
    for bm in block_pat.finditer(text):
        bname = bm.group(1)
        body = bm.group(2)
        attrs: list[tuple[str, str]] = []
        parts: list[str] = []
        for am in re.finditer(r"attribute\s+(\S+)\s*:\s*(\S+)\s*;", body):
            attrs.append((am.group(1), am.group(2)))
        for pm in re.finditer(r"part\s+(\S+)\s*:", body):
            parts.append(pm.group(1))
        model.blocks.append(BlockDef(name=bname, attributes=attrs, parts=parts))

    uc_pat = re.compile(r"usecase\s+(\S+)\s*\{(.*?)\}", re.DOTALL)
    for um in uc_pat.finditer(text):
        ucname = um.group(1)
        body = um.group(2)
        subject = ""
        actors: list[str] = []
        sm = re.search(r"subject\s+(\S+)\s*;", body)
        if sm:
            subject = sm.group(1)
        for am in re.finditer(r"actor\s+(\S+)\s*;", body):
            actors.append(am.group(1))
        model.usecases.append(UseCaseDef(name=ucname, subject=subject, actors=actors))

    req_pat = re.compile(r'requirement\s+(\S+)\s+"((?:[^"\\]|\\.)*)"\s*;')
    for rm in req_pat.finditer(text):
        model.requirements.append(
            RequirementDef(req_id=rm.group(1), text=rm.group(2).replace('\\"', '"'))
        )

    return model


def parse_actors_lines(raw: str) -> list[str]:
    return [l.strip() for l in raw.splitlines() if l.strip() and not l.strip().startswith("#")]


def parse_requirements_lines(raw: str) -> list[RequirementDef]:
    results = []
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "|" in line:
            parts = line.split("|", 1)
            results.append(RequirementDef(req_id=parts[0].strip(), text=parts[1].strip()))
    return results


def parse_blocks_lines(raw: str) -> list[BlockDef]:
    results = []
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        segments = [s.strip() for s in line.split("|")]
        name = segments[0] if segments else ""
        attrs: list[tuple[str, str]] = []
        parts: list[str] = []
        if len(segments) > 1 and segments[1]:
            for tok in segments[1].split(","):
                tok = tok.strip()
                if ":" in tok:
                    aname, atype = tok.split(":", 1)
                    attrs.append((aname.strip(), atype.strip()))
        if len(segments) > 2 and segments[2]:
            parts = [p.strip() for p in segments[2].split(",") if p.strip()]
        results.append(BlockDef(name=name, attributes=attrs, parts=parts))
    return results


def parse_usecases_lines(raw: str) -> list[UseCaseDef]:
    results = []
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        segments = [s.strip() for s in line.split("|")]
        name = segments[0] if segments else ""
        subject = segments[1] if len(segments) > 1 else ""
        actors: list[str] = []
        if len(segments) > 2 and segments[2]:
            actors = [a.strip() for a in segments[2].split(",") if a.strip()]
        results.append(UseCaseDef(name=name, subject=subject, actors=actors))
    return results


def build_model_from_form(
    app_name: str,
    actors_raw: str,
    requirements_raw: str,
    blocks_raw: str,
    usecases_raw: str,
) -> SysMLModel:
    model = SysMLModel()
    model.package = app_name or "Unnamed"
    model.actors = parse_actors_lines(actors_raw)
    model.requirements = parse_requirements_lines(requirements_raw)
    model.blocks = parse_blocks_lines(blocks_raw)
    model.usecases = parse_usecases_lines(usecases_raw)
    return model


def render_diagram(model: SysMLModel, fmt: str = "png") -> bytes:
    """Render a merged BDD + Use Case + Requirements diagram via Graphviz."""
    import graphviz

    fontname = model.render_hints.style.get("fontname", "Helvetica")
    rankdir = model.render_hints.layout.get("rankdir", "LR")

    g = graphviz.Digraph(
        name="SysML",
        format=fmt,
        graph_attr={
            "rankdir": rankdir,
            "fontname": fontname,
            "fontsize": "11",
            "label": f"<<B>{model.package} – SysML Architecture</B>>",
            "labelloc": "t",
            "compound": "true",
            "nodesep": "0.6",
            "ranksep": "0.8",
            "bgcolor": "white",
        },
        node_attr={"fontname": fontname, "fontsize": "10"},
        edge_attr={"fontname": fontname, "fontsize": "9"},
    )

    with g.subgraph(name="cluster_bdd") as bdd:
        bdd.attr(label="«bdd» Block Definition Diagram", style="dashed", color="#2563EB", fontcolor="#2563EB")
        for b in model.blocks:
            attr_rows = "".join(
                f'<TR><TD ALIGN="LEFT">  {aname}: {atype}</TD></TR>' for aname, atype in b.attributes
            )
            part_rows = "".join(
                f'<TR><TD ALIGN="LEFT">  part {p}: Block</TD></TR>' for p in b.parts
            )
            sep1 = '<HR/>' if b.attributes else ''
            sep2 = '<HR/>' if b.parts and b.attributes else ('<HR/>' if b.parts else '')
            label = (
                f'<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0">'
                f'<TR><TD><B>«block»</B></TD></TR>'
                f'<TR><TD><B>{b.name}</B></TD></TR>'
                f'{sep1}{attr_rows}'
                f'{sep2}{part_rows}'
                f'</TABLE>>'
            )
            bdd.node(
                f"block_{b.name}",
                label=label,
                shape="record" if not b.attributes and not b.parts else "none",
                style="rounded" if not b.attributes and not b.parts else "",
                penwidth="1.2",
            )
            for p in b.parts:
                target = f"block_{p}"
                found = any(bl.name == p for bl in model.blocks)
                if found:
                    bdd.edge(
                        f"block_{b.name}",
                        target,
                        label=f"  {p}",
                        arrowhead="diamond",
                        style="solid",
                        color="#374151",
                    )

    for a in model.actors:
        g.node(
            f"actor_{a}",
            label=f"<<B>«actor»</B><BR/>{a}>",
            shape="box",
            style="rounded,filled",
            fillcolor="#F3F4F6",
            color="#6B7280",
            penwidth="1.2",
        )

    with g.subgraph(name="cluster_uc") as uc:
        uc.attr(label="«uc» Use Case Diagram", style="dashed", color="#059669", fontcolor="#059669")
        for u in model.usecases:
            uc.node(
                f"uc_{u.name}",
                label=f"{u.name}",
                shape="ellipse",
                style="filled",
                fillcolor="#ECFDF5",
                color="#059669",
                penwidth="1.2",
            )
        for u in model.usecases:
            if u.subject:
                target_block = f"block_{u.subject}"
                found_block = any(bl.name == u.subject for bl in model.blocks)
                if found_block:
                    uc.edge(
                        f"uc_{u.name}",
                        target_block,
                        label="  «subject»",
                        style="dashed",
                        color="#6B7280",
                    )
            for a in u.actors:
                g.edge(
                    f"actor_{a}",
                    f"uc_{u.name}",
                    style="solid",
                    color="#374151",
                )

    with g.subgraph(name="cluster_req") as req:
        req.attr(label="«req» Requirements", style="dashed", color="#DC2626", fontcolor="#DC2626")
        for r in model.requirements:
            truncated = (r.text[:60] + "...") if len(r.text) > 63 else r.text
            label = (
                f'<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0">'
                f'<TR><TD><B>«requirement»</B></TD></TR>'
                f'<TR><TD><B>{r.req_id}</B></TD></TR>'
                f'<TR><TD ALIGN="LEFT"><FONT POINT-SIZE="8">{truncated}</FONT></TD></TR>'
                f'</TABLE>>'
            )
            req.node(
                f"req_{r.req_id}",
                label=label,
                shape="none",
                penwidth="1.2",
            )

    if model.blocks and model.requirements:
        first_block = model.blocks[0].name
        for r in model.requirements:
            g.edge(
                f"block_{first_block}",
                f"req_{r.req_id}",
                label="  «satisfy»",
                style="dashed",
                color="#DC2626",
                arrowhead="open",
            )

    return g.pipe()


def ctx_from_sysml(text: str) -> dict:
    """Parse SysML text and reconstruct form field values."""
    model = parse_sysml_to_model(text)
    actors_lines = "\n".join(model.actors)
    reqs = "\n".join(f"{r.req_id} | {r.text}" for r in model.requirements)
    blocks_parts = []
    for b in model.blocks:
        attrs_str = ", ".join(f"{n}:{t}" for n, t in b.attributes)
        parts_str = ", ".join(b.parts)
        blocks_parts.append(f"{b.name} | {attrs_str} | {parts_str}")
    blocks_str = "\n".join(blocks_parts)
    ucs = [f"{u.name} | {u.subject} | {', '.join(u.actors)}" for u in model.usecases]
    uc_str = "\n".join(ucs)
    return {
        "app_name": model.package,
        "actors_lines": actors_lines,
        "requirements_lines": reqs,
        "blocks_lines": blocks_str,
        "usecases_lines": uc_str,
        "elements_filename": "",
    }


def ctx_from_json(data: dict) -> dict:
    return {
        "app_name": data.get("app_name", ""),
        "actors_lines": data.get("actors_lines", ""),
        "requirements_lines": data.get("requirements_lines", ""),
        "blocks_lines": data.get("blocks_lines", ""),
        "usecases_lines": data.get("usecases_lines", ""),
        "elements_filename": data.get("elements_filename", ""),
    }


def ctx_to_json(ctx: dict, sysml_text: str = "") -> dict:
    payload = {
        "app_name": ctx["app_name"],
        "actors_lines": ctx["actors_lines"],
        "requirements_lines": ctx["requirements_lines"],
        "blocks_lines": ctx["blocks_lines"],
        "usecases_lines": ctx["usecases_lines"],
    }
    if sysml_text:
        payload["sysml_text"] = sysml_text
    return payload
