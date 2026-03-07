#!/usr/bin/env python3
"""
SysML Architecture Composer – Flask Web Application
====================================================
Deterministic SysML-like DSL generator, parser, and Graphviz diagram renderer.
No LLM usage; all transformations are purely rule-based.
"""

from __future__ import annotations

import io
import json
import os
import re
import shutil
import subprocess
import textwrap
import uuid
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional

from flask import (
    Flask,
    request,
    redirect,
    url_for,
    render_template_string,
    send_file,
    flash,
    session,
)

# ---------------------------------------------------------------------------
# Graphviz / dot availability
# ---------------------------------------------------------------------------
_EXTRA_PATHS = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin"]
for p in _EXTRA_PATHS:
    if p not in os.environ.get("PATH", ""):
        os.environ["PATH"] = p + os.pathsep + os.environ.get("PATH", "")

DOT_AVAILABLE = False
try:
    subprocess.run(["dot", "-V"], capture_output=True, check=True)
    DOT_AVAILABLE = True
except Exception:
    DOT_AVAILABLE = False

# ---------------------------------------------------------------------------
# Internal Model
# ---------------------------------------------------------------------------

@dataclass
class BlockDef:
    name: str
    attributes: list[tuple[str, str]] = field(default_factory=list)   # (name, type)
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


# ---------------------------------------------------------------------------
# DSL Builder  (SysMLModelBuilder.render)
# ---------------------------------------------------------------------------

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

        # Actors
        for a in m.actors:
            lines.append(f"  actor {a};")
        if m.actors:
            lines.append("")

        # Blocks
        for b in m.blocks:
            lines.append(f"  block {b.name} {{")
            for aname, atype in b.attributes:
                lines.append(f"    attribute {aname}: {atype};")
            for part in b.parts:
                lines.append(f"    part {part}: Block;")
            lines.append("  }")
            lines.append("")

        # Use cases
        for uc in m.usecases:
            lines.append(f"  usecase {uc.name} {{")
            if uc.subject:
                lines.append(f"    subject {uc.subject};")
            for a in uc.actors:
                lines.append(f"    actor {a};")
            lines.append("  }")
            lines.append("")

        # Requirements
        for r in m.requirements:
            escaped = r.text.replace('"', '\\"')
            lines.append(f'  requirement {r.req_id} "{escaped}";')
        if m.requirements:
            lines.append("")

        lines.append("}")
        return "\n".join(lines)


# ---------------------------------------------------------------------------
# DSL Parser  (parse_sysml_to_model)
# ---------------------------------------------------------------------------

def parse_sysml_to_model(text: str) -> SysMLModel:
    """Parse a SysML-like DSL string back into an internal SysMLModel."""
    model = SysMLModel()

    # Package name
    pkg_m = re.search(r"package\s+(\S+)\s*\{", text)
    if pkg_m:
        model.package = pkg_m.group(1)

    # Actors – only top-level (not inside usecase { } blocks)
    # Strip all block/usecase bodies first, then scan for actor declarations
    stripped = re.sub(r"(block|usecase)\s+\S+\s*\{[^}]*\}", "", text, flags=re.DOTALL)
    for m in re.finditer(r"^\s*actor\s+(\S+)\s*;", stripped, re.MULTILINE):
        model.actors.append(m.group(1))

    # Blocks  (multiline)
    block_pat = re.compile(
        r"block\s+(\S+)\s*\{(.*?)\}", re.DOTALL
    )
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

    # Use cases (multiline)
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

    # Requirements
    req_pat = re.compile(r'requirement\s+(\S+)\s+"((?:[^"\\]|\\.)*)"\s*;')
    for rm in req_pat.finditer(text):
        model.requirements.append(
            RequirementDef(req_id=rm.group(1), text=rm.group(2).replace('\\"', '"'))
        )

    return model


# ---------------------------------------------------------------------------
# Form line parsers (raw text areas → internal model)
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Graphviz Diagram Renderer  (render_diagram)
# ---------------------------------------------------------------------------

def render_diagram(model: SysMLModel, fmt: str = "png") -> bytes:
    """Render a merged BDD + Use Case + Requirements diagram via Graphviz.
    Returns raw bytes in the requested format (png or pdf).
    """
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

    # ---- BDD Cluster ----
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
            # Composition edges for parts
            for p in b.parts:
                # Try to find the target block
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

    # ---- Actor nodes (shared) ----
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

    # ---- Use Case Cluster ----
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
        # Edges: actor -> usecase
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

    # ---- Requirements Cluster ----
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

    # ---- satisfy edges (requirement → first block if exists) ----
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


# ---------------------------------------------------------------------------
# Cache for generated images
# ---------------------------------------------------------------------------
_DIAGRAM_CACHE: dict[str, bytes] = {}


# ---------------------------------------------------------------------------
# Flask App
# ---------------------------------------------------------------------------

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET", "sysml-composer-dev-key")

# ---------------------------------------------------------------------------
# HTML Template
# ---------------------------------------------------------------------------

MAIN_TEMPLATE = r"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>SysML Architecture Composer</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,wght@0,400;0,500;0,600;0,700&family=JetBrains+Mono:wght@400;500&display=swap');

  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --bg: #F9FAFB; --surface: #FFFFFF; --surface-alt: #F3F4F6;
    --border: #E5E7EB; --border-focus: #6366F1;
    --text: #111827; --text-muted: #6B7280; --text-inv: #FFFFFF;
    --primary: #4F46E5; --primary-hover: #4338CA;
    --success: #059669; --danger: #DC2626;
    --radius: 10px; --shadow: 0 1px 3px rgba(0,0,0,.06), 0 1px 2px rgba(0,0,0,.04);
    --shadow-md: 0 4px 12px rgba(0,0,0,.08);
  }

  body {
    font-family: 'DM Sans', system-ui, sans-serif;
    background: var(--bg); color: var(--text);
    line-height: 1.55; padding: 0 0 3rem 0;
  }

  header {
    background: var(--surface); border-bottom: 1px solid var(--border);
    padding: 1.25rem 2rem; margin-bottom: 1.75rem;
    box-shadow: var(--shadow);
  }
  header h1 { font-size: 1.5rem; font-weight: 700; letter-spacing: -.02em; }
  header p  { color: var(--text-muted); font-size: .875rem; margin-top: .25rem; }

  .container { max-width: 1440px; margin: 0 auto; padding: 0 1.5rem; }

  /* Cards */
  .card {
    background: var(--surface); border: 1px solid var(--border);
    border-radius: var(--radius); padding: 1.25rem 1.5rem;
    box-shadow: var(--shadow);
  }
  .card h2 {
    font-size: .8rem; font-weight: 600; text-transform: uppercase;
    letter-spacing: .04em; color: var(--text-muted); margin-bottom: .75rem;
  }

  /* Grid layouts */
  .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 1.25rem; }
  @media (max-width: 900px) { .grid-2 { grid-template-columns: 1fr; } }

  /* Inputs */
  input[type=text], textarea {
    width: 100%; font-family: 'JetBrains Mono', monospace;
    font-size: .82rem; padding: .6rem .75rem;
    border: 1px solid var(--border); border-radius: 6px;
    background: var(--surface-alt); color: var(--text);
    transition: border-color .15s, box-shadow .15s;
    resize: vertical;
  }
  input[type=text]:focus, textarea:focus {
    outline: none; border-color: var(--border-focus);
    box-shadow: 0 0 0 3px rgba(99,102,241,.15);
  }
  textarea { min-height: 160px; }

  .example {
    margin-top: .5rem; background: var(--surface-alt);
    border-radius: 6px; padding: .5rem .75rem;
    font-family: 'JetBrains Mono', monospace; font-size: .72rem;
    color: var(--text-muted); white-space: pre-wrap; line-height: 1.6;
  }
  .example-label { font-family: 'DM Sans', sans-serif; font-size: .7rem; color: var(--text-muted); margin-top: .5rem; }

  /* Buttons */
  .btn {
    display: inline-flex; align-items: center; gap: .4rem;
    font-family: 'DM Sans', sans-serif;
    font-weight: 600; font-size: .82rem;
    padding: .55rem 1.1rem; border-radius: 7px; border: none;
    cursor: pointer; transition: background .15s, transform .1s;
    text-decoration: none; color: var(--text-inv);
  }
  .btn:active { transform: scale(.97); }
  .btn-primary   { background: var(--primary); }
  .btn-primary:hover { background: var(--primary-hover); }
  .btn-success   { background: var(--success); }
  .btn-success:hover { background: #047857; }
  .btn-danger    { background: var(--danger); }
  .btn-danger:hover  { background: #B91C1C; }
  .btn-outline   {
    background: var(--surface); color: var(--text);
    border: 1px solid var(--border);
  }
  .btn-outline:hover { background: var(--surface-alt); }

  .btn-bar {
    display: flex; flex-wrap: wrap; gap: .6rem; margin-top: 1.5rem;
    align-items: center;
  }
  .btn-bar .sep { width: 1px; height: 1.5rem; background: var(--border); }

  /* Flash messages */
  .flash { padding: .75rem 1rem; border-radius: 6px; margin-bottom: 1rem; font-size: .85rem; }
  .flash-error { background: #FEF2F2; color: #991B1B; border: 1px solid #FECACA; }
  .flash-info  { background: #EFF6FF; color: #1E40AF; border: 1px solid #BFDBFE; }

  /* Preview area */
  .preview-block {
    background: #1E1E2E; color: #CDD6F4; border-radius: var(--radius);
    padding: 1.25rem 1.5rem; font-family: 'JetBrains Mono', monospace;
    font-size: .78rem; white-space: pre-wrap; line-height: 1.65;
    overflow-x: auto; margin-top: 1.25rem; box-shadow: var(--shadow-md);
  }

  /* Diagram display */
  .diagram-wrapper {
    margin-top: 1.25rem; text-align: center;
    background: var(--surface); border: 1px solid var(--border);
    border-radius: var(--radius); padding: 1.5rem;
    box-shadow: var(--shadow);
  }
  .diagram-wrapper img { max-width: 100%; height: auto; }

  /* File inputs */
  .file-row {
    display: flex; align-items: center; gap: .5rem; flex-wrap: wrap;
  }
  input[type=file] {
    font-family: 'DM Sans', sans-serif; font-size: .8rem;
  }

  /* Utility */
  .mt-1 { margin-top: .75rem; }
  .mt-2 { margin-top: 1.25rem; }
  .mb-1 { margin-bottom: .75rem; }
  label.field-label { font-size: .78rem; font-weight: 600; display: block; margin-bottom: .3rem; color: var(--text-muted); }
</style>
</head>
<body>

<header>
  <h1>SysML Architecture Composer</h1>
  <p>Enter your app name and elements below. Use the examples as guidance. Lines starting with # are ignored.</p>
</header>

<div class="container">
  {% with messages = get_flashed_messages(with_categories=true) %}
    {% for cat, msg in messages %}
      <div class="flash flash-{{ cat }}">{{ msg }}</div>
    {% endfor %}
  {% endwith %}

  <form method="post" action="{{ url_for('index') }}" enctype="multipart/form-data" id="mainForm">

    <!-- App name -->
    <div class="card mb-1">
      <h2>App name</h2>
      <input type="text" name="app_name" value="{{ ctx.app_name }}" placeholder="MySystem"/>
    </div>

    <div class="grid-2 mt-1">
      <!-- Actors -->
      <div class="card">
        <h2>Actors (one per line)</h2>
        <textarea name="actors_lines" placeholder="Operator&#10;Sensor">{{ ctx.actors_lines }}</textarea>
        <div class="example-label">Example:</div>
        <div class="example">Operator
Sensor</div>
      </div>

      <!-- Requirements -->
      <div class="card">
        <h2>Requirements (ID | text)</h2>
        <textarea name="requirements_lines" placeholder="R-001 | The system shall start within 5 seconds.">{{ ctx.requirements_lines }}</textarea>
        <div class="example-label">Example:</div>
        <div class="example">R-001 | The system shall start within 5 seconds.
R-002 | The operator shall be notified on fault.</div>
      </div>
    </div>

    <div class="grid-2 mt-1">
      <!-- Blocks -->
      <div class="card">
        <h2>Blocks (Name | attr1:type, attr2:type | part1, part2)</h2>
        <textarea name="blocks_lines" placeholder="Controller | state:string, version:int | cpu, memory">{{ ctx.blocks_lines }}</textarea>
        <div class="example-label">Example:</div>
        <div class="example">Controller | state:string, version:int | cpu, memory
Sensor | reading:float |</div>
      </div>

      <!-- Use Cases -->
      <div class="card">
        <h2>Use Cases (Name | SubjectBlock | actor1, actor2)</h2>
        <textarea name="usecases_lines" placeholder="StartSystem | Controller | Operator">{{ ctx.usecases_lines }}</textarea>
        <div class="example-label">Example:</div>
        <div class="example">StartSystem | Controller | Operator
ReadSensor | Sensor | Operator</div>
      </div>
    </div>

    <!-- Action buttons -->
    <div class="btn-bar">
      <button type="submit" name="action" value="preview" class="btn btn-primary">Generate SysML Preview</button>
      <button type="submit" name="action" value="diagram_png" class="btn btn-primary">Generate Diagram PNG</button>
      <button type="submit" name="action" value="diagram_pdf" class="btn btn-primary">Generate Diagram PDF</button>
      <button type="submit" name="action" value="download_sysml" class="btn btn-success">Download .sysml</button>
      <div class="sep"></div>
      <button type="submit" name="action" value="download_json" class="btn btn-success">Download All Elements JSON</button>
      <label class="field-label" style="display:inline; margin-left: .3rem;">Filename:</label>
      <input type="text" name="elements_filename" value="{{ ctx.elements_filename or '' }}" placeholder="elements.json" style="width:160px;"/>
      <div class="sep"></div>
    </div>

    <div class="btn-bar">
      <div class="file-row">
        <label class="field-label" style="display:inline;">Load .sysml file:</label>
        <input type="file" name="sysml_file" accept=".sysml,.txt"/>
        <button type="submit" name="action" value="load_sysml" class="btn btn-outline">Load SysML</button>
      </div>
      <div class="file-row" style="margin-left:1rem;">
        <label class="field-label" style="display:inline;">Load JSON:</label>
        <input type="file" name="json_file" accept=".json"/>
        <button type="submit" name="action" value="load_json" class="btn btn-outline">Load All Elements</button>
      </div>
    </div>

    <!-- Hidden fields to carry state for Back button -->
    <input type="hidden" name="_has_state" value="1"/>
  </form>

  {% if sysml_text %}
    <div class="preview-block">{{ sysml_text }}</div>
    <form method="post" action="{{ url_for('index') }}">
      <input type="hidden" name="app_name" value="{{ ctx.app_name }}"/>
      <input type="hidden" name="actors_lines" value="{{ ctx.actors_lines }}"/>
      <input type="hidden" name="requirements_lines" value="{{ ctx.requirements_lines }}"/>
      <input type="hidden" name="blocks_lines" value="{{ ctx.blocks_lines }}"/>
      <input type="hidden" name="usecases_lines" value="{{ ctx.usecases_lines }}"/>
      <input type="hidden" name="action" value="back"/>
      <button type="submit" class="btn btn-outline mt-1">&#8592; Back</button>
    </form>
  {% endif %}

  {% if diagram_id %}
    <div class="diagram-wrapper">
      <img src="{{ url_for('serve_diagram', diagram_id=diagram_id) }}" alt="SysML Diagram"/>
    </div>
    <div class="btn-bar">
      <a href="{{ url_for('serve_diagram', diagram_id=diagram_id) }}" download="diagram.png" class="btn btn-success">Download PNG</a>
      <form method="post" action="{{ url_for('index') }}" style="display:inline;">
        <input type="hidden" name="app_name" value="{{ ctx.app_name }}"/>
        <input type="hidden" name="actors_lines" value="{{ ctx.actors_lines }}"/>
        <input type="hidden" name="requirements_lines" value="{{ ctx.requirements_lines }}"/>
        <input type="hidden" name="blocks_lines" value="{{ ctx.blocks_lines }}"/>
        <input type="hidden" name="usecases_lines" value="{{ ctx.usecases_lines }}"/>
        <input type="hidden" name="action" value="back"/>
        <button type="submit" class="btn btn-outline">&#8592; Back</button>
      </form>
    </div>
  {% endif %}

</div>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _form_ctx(form=None) -> dict:
    """Build context dict from form data or defaults."""
    f = form or {}
    return {
        "app_name": f.get("app_name", ""),
        "actors_lines": f.get("actors_lines", ""),
        "requirements_lines": f.get("requirements_lines", ""),
        "blocks_lines": f.get("blocks_lines", ""),
        "usecases_lines": f.get("usecases_lines", ""),
        "elements_filename": f.get("elements_filename", ""),
    }


def _model_from_form(ctx: dict) -> SysMLModel:
    return build_model_from_form(
        ctx["app_name"],
        ctx["actors_lines"],
        ctx["requirements_lines"],
        ctx["blocks_lines"],
        ctx["usecases_lines"],
    )


def _ctx_to_json(ctx: dict, sysml_text: str = "") -> dict:
    """Build the All Elements JSON export payload."""
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


def _ctx_from_json(data: dict) -> dict:
    return {
        "app_name": data.get("app_name", ""),
        "actors_lines": data.get("actors_lines", ""),
        "requirements_lines": data.get("requirements_lines", ""),
        "blocks_lines": data.get("blocks_lines", ""),
        "usecases_lines": data.get("usecases_lines", ""),
        "elements_filename": "",
    }


def _ctx_from_sysml(text: str) -> dict:
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
    ucs = []
    for u in model.usecases:
        ucs.append(f"{u.name} | {u.subject} | {', '.join(u.actors)}")
    uc_str = "\n".join(ucs)
    return {
        "app_name": model.package,
        "actors_lines": actors_lines,
        "requirements_lines": reqs,
        "blocks_lines": blocks_str,
        "usecases_lines": uc_str,
        "elements_filename": "",
    }


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.route("/", methods=["GET", "POST"])
def index():
    ctx = _form_ctx()
    sysml_text = ""
    diagram_id = None

    if request.method == "GET":
        return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text="", diagram_id=None)

    # ---- POST ----
    action = request.form.get("action", "")
    ctx = _form_ctx(request.form)

    # ---- Back ----
    if action == "back":
        return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text="", diagram_id=None)

    # ---- Generate SysML Preview ----
    if action == "preview":
        model = _model_from_form(ctx)
        sysml_text = SysMLModelBuilder(model).render()
        return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text=sysml_text, diagram_id=None)

    # ---- Diagram PNG ----
    if action == "diagram_png":
        if not DOT_AVAILABLE:
            flash("Graphviz 'dot' is not available on this system. Cannot generate diagram.", "error")
            return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text="", diagram_id=None)
        model = _model_from_form(ctx)
        try:
            png_bytes = render_diagram(model, fmt="png")
        except Exception as e:
            flash(f"Diagram error: {e}", "error")
            return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text="", diagram_id=None)
        did = uuid.uuid4().hex[:12]
        _DIAGRAM_CACHE[did] = png_bytes
        return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text="", diagram_id=did)

    # ---- Diagram PDF ----
    if action == "diagram_pdf":
        if not DOT_AVAILABLE:
            flash("Graphviz 'dot' is not available on this system. Cannot generate diagram.", "error")
            return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text="", diagram_id=None)
        model = _model_from_form(ctx)
        try:
            pdf_bytes = render_diagram(model, fmt="pdf")
        except Exception as e:
            flash(f"Diagram error: {e}", "error")
            return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text="", diagram_id=None)
        return send_file(
            io.BytesIO(pdf_bytes),
            mimetype="application/pdf",
            as_attachment=True,
            download_name=f"{ctx['app_name'] or 'diagram'}.pdf",
        )

    # ---- Download .sysml ----
    if action == "download_sysml":
        model = _model_from_form(ctx)
        text = SysMLModelBuilder(model).render()
        return send_file(
            io.BytesIO(text.encode("utf-8")),
            mimetype="text/plain",
            as_attachment=True,
            download_name=f"{ctx['app_name'] or 'model'}.sysml",
        )

    # ---- Download All Elements JSON ----
    if action == "download_json":
        model = _model_from_form(ctx)
        sysml_t = SysMLModelBuilder(model).render()
        payload = _ctx_to_json(ctx, sysml_text=sysml_t)
        fname = (ctx.get("elements_filename") or "").strip()
        if not fname:
            fname = f"{ctx['app_name'] or 'elements'}.json"
        if not fname.endswith(".json"):
            fname += ".json"
        return send_file(
            io.BytesIO(json.dumps(payload, indent=2).encode("utf-8")),
            mimetype="application/json",
            as_attachment=True,
            download_name=fname,
        )

    # ---- Load SysML from file ----
    if action == "load_sysml":
        f = request.files.get("sysml_file")
        if not f or not f.filename:
            flash("No .sysml file selected.", "error")
            return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text="", diagram_id=None)
        try:
            text = f.read().decode("utf-8")
        except Exception as e:
            flash(f"Error reading file: {e}", "error")
            return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text="", diagram_id=None)
        ctx = _ctx_from_sysml(text)
        flash("SysML file loaded successfully.", "info")
        return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text="", diagram_id=None)

    # ---- Load All Elements from JSON ----
    if action == "load_json":
        f = request.files.get("json_file")
        if not f or not f.filename:
            flash("No JSON file selected.", "error")
            return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text="", diagram_id=None)
        try:
            data = json.loads(f.read().decode("utf-8"))
        except Exception as e:
            flash(f"Invalid JSON: {e}", "error")
            return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text="", diagram_id=None)
        ctx = _ctx_from_json(data)
        flash("All elements loaded from JSON.", "info")
        return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text="", diagram_id=None)

    # Fallback
    return render_template_string(MAIN_TEMPLATE, ctx=ctx, sysml_text="", diagram_id=None)


@app.route("/diagram/<diagram_id>")
def serve_diagram(diagram_id: str):
    data = _DIAGRAM_CACHE.get(diagram_id)
    if not data:
        return "Diagram not found", 404
    return send_file(io.BytesIO(data), mimetype="image/png")


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    host = os.environ.get("HOST", "0.0.0.0")
    port = int(os.environ.get("PORT", "5000"))
    print(f"[SysML Composer] Starting on {host}:{port}  (dot available: {DOT_AVAILABLE})")
    app.run(host=host, port=port, debug=False)
