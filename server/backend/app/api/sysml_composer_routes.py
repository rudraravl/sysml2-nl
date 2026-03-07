"""SysML Composer API routes – deterministic DSL generation and diagram rendering."""

import io
import json
import uuid
from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from fastapi.responses import Response, StreamingResponse

from app.sysml_composer.model import (
    build_model_from_form,
    SysMLModelBuilder,
    render_diagram,
    ctx_from_sysml,
    ctx_from_json,
    ctx_to_json,
)
from app.sysml_composer.dot_check import DOT_AVAILABLE

router = APIRouter(prefix="/api/sysml-composer", tags=["sysml-composer"])

_DIAGRAM_CACHE: dict[str, bytes] = {}


def _form_ctx(
    app_name: str = "",
    actors_lines: str = "",
    requirements_lines: str = "",
    blocks_lines: str = "",
    usecases_lines: str = "",
    elements_filename: str = "",
) -> dict:
    return {
        "app_name": app_name or "",
        "actors_lines": actors_lines or "",
        "requirements_lines": requirements_lines or "",
        "blocks_lines": blocks_lines or "",
        "usecases_lines": usecases_lines or "",
        "elements_filename": elements_filename or "",
    }


@router.post("/preview")
async def preview(
    app_name: str = Form(""),
    actors_lines: str = Form(""),
    requirements_lines: str = Form(""),
    blocks_lines: str = Form(""),
    usecases_lines: str = Form(""),
):
    """Generate SysML preview text from form data."""
    ctx = _form_ctx(app_name, actors_lines, requirements_lines, blocks_lines, usecases_lines)
    model = build_model_from_form(
        ctx["app_name"],
        ctx["actors_lines"],
        ctx["requirements_lines"],
        ctx["blocks_lines"],
        ctx["usecases_lines"],
    )
    sysml_text = SysMLModelBuilder(model).render()
    return {"sysml_text": sysml_text, "ctx": ctx}


@router.post("/diagram-png")
async def diagram_png(
    app_name: str = Form(""),
    actors_lines: str = Form(""),
    requirements_lines: str = Form(""),
    blocks_lines: str = Form(""),
    usecases_lines: str = Form(""),
):
    """Generate diagram PNG and return diagram_id for fetching."""
    if not DOT_AVAILABLE:
        raise HTTPException(
            status_code=503,
            detail="Graphviz 'dot' is not available on this system. Cannot generate diagram.",
        )
    ctx = _form_ctx(app_name, actors_lines, requirements_lines, blocks_lines, usecases_lines)
    model = build_model_from_form(
        ctx["app_name"],
        ctx["actors_lines"],
        ctx["requirements_lines"],
        ctx["blocks_lines"],
        ctx["usecases_lines"],
    )
    try:
        png_bytes = render_diagram(model, fmt="png")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Diagram error: {e}")
    did = uuid.uuid4().hex[:12]
    _DIAGRAM_CACHE[did] = png_bytes
    return {"diagram_id": did, "ctx": ctx}


@router.get("/diagram/{diagram_id}")
async def serve_diagram(diagram_id: str):
    """Serve cached diagram PNG."""
    data = _DIAGRAM_CACHE.get(diagram_id)
    if not data:
        raise HTTPException(status_code=404, detail="Diagram not found")
    return Response(content=data, media_type="image/png")


@router.post("/diagram-pdf")
async def diagram_pdf(
    app_name: str = Form(""),
    actors_lines: str = Form(""),
    requirements_lines: str = Form(""),
    blocks_lines: str = Form(""),
    usecases_lines: str = Form(""),
):
    """Generate and download diagram as PDF."""
    if not DOT_AVAILABLE:
        raise HTTPException(
            status_code=503,
            detail="Graphviz 'dot' is not available on this system. Cannot generate diagram.",
        )
    ctx = _form_ctx(app_name, actors_lines, requirements_lines, blocks_lines, usecases_lines)
    model = build_model_from_form(
        ctx["app_name"],
        ctx["actors_lines"],
        ctx["requirements_lines"],
        ctx["blocks_lines"],
        ctx["usecases_lines"],
    )
    try:
        pdf_bytes = render_diagram(model, fmt="pdf")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Diagram error: {e}")
    fname = f"{ctx['app_name'] or 'diagram'}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{fname}"'},
    )


@router.post("/download-sysml")
async def download_sysml(
    app_name: str = Form(""),
    actors_lines: str = Form(""),
    requirements_lines: str = Form(""),
    blocks_lines: str = Form(""),
    usecases_lines: str = Form(""),
):
    """Download .sysml file."""
    ctx = _form_ctx(app_name, actors_lines, requirements_lines, blocks_lines, usecases_lines)
    model = build_model_from_form(
        ctx["app_name"],
        ctx["actors_lines"],
        ctx["requirements_lines"],
        ctx["blocks_lines"],
        ctx["usecases_lines"],
    )
    text = SysMLModelBuilder(model).render()
    fname = f"{ctx['app_name'] or 'model'}.sysml"
    return Response(
        content=text.encode("utf-8"),
        media_type="text/plain",
        headers={"Content-Disposition": f'attachment; filename="{fname}"'},
    )


@router.post("/download-json")
async def download_json(
    app_name: str = Form(""),
    actors_lines: str = Form(""),
    requirements_lines: str = Form(""),
    blocks_lines: str = Form(""),
    usecases_lines: str = Form(""),
    elements_filename: str = Form(""),
):
    """Download All Elements as JSON with optional filename."""
    ctx = _form_ctx(
        app_name, actors_lines, requirements_lines, blocks_lines, usecases_lines, elements_filename
    )
    model = build_model_from_form(
        ctx["app_name"],
        ctx["actors_lines"],
        ctx["requirements_lines"],
        ctx["blocks_lines"],
        ctx["usecases_lines"],
    )
    sysml_t = SysMLModelBuilder(model).render()
    payload = ctx_to_json(ctx, sysml_text=sysml_t)
    fname = (ctx.get("elements_filename") or "").strip()
    if not fname:
        fname = f"{ctx['app_name'] or 'elements'}.json"
    if not fname.endswith(".json"):
        fname += ".json"
    return Response(
        content=json.dumps(payload, indent=2).encode("utf-8"),
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="{fname}"'},
    )


@router.post("/load-sysml")
async def load_sysml(file: UploadFile = File(...)):
    """Load SysML from uploaded file and return form context."""
    if not file.filename:
        raise HTTPException(status_code=400, detail="No .sysml file selected.")
    try:
        text = (await file.read()).decode("utf-8")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error reading file: {e}")
    ctx = ctx_from_sysml(text)
    return {"ctx": ctx, "message": "SysML file loaded successfully."}


@router.post("/load-json")
async def load_json(file: UploadFile = File(...)):
    """Load All Elements from uploaded JSON and return form context."""
    if not file.filename:
        raise HTTPException(status_code=400, detail="No JSON file selected.")
    try:
        data = json.loads((await file.read()).decode("utf-8"))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid JSON: {e}")
    ctx = ctx_from_json(data)
    return {"ctx": ctx, "message": "All elements loaded from JSON."}


@router.get("/dot-available")
async def dot_available():
    """Check if Graphviz dot is available."""
    return {"available": DOT_AVAILABLE}
