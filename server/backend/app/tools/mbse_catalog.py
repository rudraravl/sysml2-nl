"""MBSE/SysML v2 tool catalog utilities exposed as callable tools."""

from typing import Any


_TOOL_CATALOG: list[dict[str, str]] = [
    {"tool": "BAAM", "vendor": "Belcan (Cognizant)", "compatibility": "Unverified", "availability": "Development", "role": "legacy/internal candidate"},
    {"tool": "BusbySim", "vendor": "Busby Ventures Limited", "compatibility": "Unverified", "availability": "Development", "role": "legacy/internal candidate"},
    {"tool": "CATIA / Cameo SysML v2", "vendor": "Dassault Systemes", "compatibility": "High", "availability": "Development", "role": "authoring validation transformation management integration version-control"},
    {"tool": "Connector", "vendor": "Maple", "compatibility": "Unverified", "availability": "Development", "role": "connector candidate"},
    {"tool": "Davinci", "vendor": "Celedon Systems", "compatibility": "High", "availability": "Available", "role": "authoring transformation visualization management validation integration version-control"},
    {"tool": "Dragonfly", "vendor": "MITRE", "compatibility": "Unverified", "availability": "Development", "role": "internal prototype"},
    {"tool": "Enterprise Architect / Trechoro", "vendor": "Sparx Systems", "compatibility": "High", "availability": "Development", "role": "authoring validation integration management"},
    {"tool": "Genesys", "vendor": "Vitech / Zuken", "compatibility": "Unverified", "availability": "Development", "role": "requirements mbse workflow candidate"},
    {"tool": "Imandra Transpiler", "vendor": "Imandra", "compatibility": "Unverified", "availability": "Development", "role": "transpiler formal analysis candidate"},
    {"tool": "Innoslate", "vendor": "Spec Innovations", "compatibility": "Unverified", "availability": "Development", "role": "requirements mbse workflow candidate"},
    {"tool": "LemonTree", "vendor": "LieberLieber", "compatibility": "Low", "availability": "Available", "role": "versioning comparison merge"},
    {"tool": "MeTRA", "vendor": "Tenet3", "compatibility": "Unverified", "availability": "Available", "role": "candidate"},
    {"tool": "Mg", "vendor": "Mgnite", "compatibility": "High", "availability": "Available", "role": "integration automation jupyter python external-tool-access"},
    {"tool": "MMS 5 / Flexo", "vendor": "OpenMBEE", "compatibility": "Listed-not-scored", "availability": "Development", "role": "repository api services collaboration"},
    {"tool": "Modeler", "vendor": "PTC", "compatibility": "High", "availability": "Available", "role": "authoring textual graphical validation integration"},
    {"tool": "MontiCore SysML v2 Parser", "vendor": "Nico Jansen", "compatibility": "Unverified", "availability": "Available", "role": "parser research"},
    {"tool": "Pilot Implementation", "vendor": "OMG", "compatibility": "Listed-not-scored", "availability": "Available", "role": "reference parser textual notation visualization api validation"},
    {"tool": "PySysML2", "vendor": "Keith Lucas", "compatibility": "Unverified", "availability": "Available", "role": "python notebook candidate"},
    {"tool": "Rhapsody SE", "vendor": "IBM", "compatibility": "High", "availability": "Available", "role": "authoring validation systems engineering"},
    {"tool": "SAM", "vendor": "Ansys", "compatibility": "High", "availability": "Available", "role": "cloud authoring api validation"},
    {"tool": "Stitch", "vendor": "AFIT / AFRL", "compatibility": "Unverified", "availability": "Development", "role": "research prototype"},
    {"tool": "Syndeia", "vendor": "Intercax", "compatibility": "High", "availability": "Available", "role": "digital-thread integration requirements verification manufacturing"},
    {"tool": "SysIDE Editor", "vendor": "Sensmetry", "compatibility": "Medium", "availability": "Available", "role": "textual editor kerML sysml"},
    {"tool": "SysIDE Pro", "vendor": "Sensmetry", "compatibility": "Medium", "availability": "Available", "role": "textual editor suite"},
    {"tool": "SysMD Notebook", "vendor": "University of Kaiserslautern-Landau", "compatibility": "Unverified", "availability": "Available", "role": "notebook academic"},
    {"tool": "SysML Extension", "vendor": "Ellidiss Technologies", "compatibility": "Listed-not-scored", "availability": "Available", "role": "textual editor analysis"},
    {"tool": "SysML v2 codeGEN", "vendor": "YESCAT AI", "compatibility": "Unverified", "availability": "Development", "role": "generator candidate"},
    {"tool": "SysML V2 Co-Pilot", "vendor": "Joshua Butt", "compatibility": "Unverified", "availability": "Available", "role": "assistant candidate"},
    {"tool": "SysML v2 Editor", "vendor": "Astah / Change Vision", "compatibility": "Unverified", "availability": "Available", "role": "editor candidate"},
    {"tool": "SysML v2 Generator", "vendor": "HOOD Group", "compatibility": "Unverified", "availability": "Development", "role": "generator candidate"},
    {"tool": "SysML v2 Model Generator", "vendor": "YESCAT AI", "compatibility": "Unverified", "availability": "Development", "role": "generator candidate"},
    {"tool": "SysML v2 Viewer", "vendor": "Tom Sawyer", "compatibility": "Low", "availability": "Available", "role": "viewer visualization navigation"},
    {"tool": "SysON", "vendor": "Eclipse / Obeo", "compatibility": "High", "availability": "Available", "role": "open-source web graphical authoring"},
    {"tool": "System Composer", "vendor": "MathWorks", "compatibility": "Medium", "availability": "Development", "role": "architecture modeling matlab integration"},
    {"tool": "TEAMS Translator", "vendor": "Qualtech Systems", "compatibility": "Listed-not-scored", "availability": "Available", "role": "import analysis reliability sustainment"},
    {"tool": "Validator for SysML v2 / Ingecovy", "vendor": "IncQuery", "compatibility": "Low", "availability": "Development", "role": "validation"},
    {"tool": "vim Plugin", "vendor": "Ethan James Lew", "compatibility": "Unverified", "availability": "Available", "role": "editor plugin"},
    {"tool": "Xcelerator / Siemens Systems Modeler", "vendor": "Siemens", "compatibility": "High", "availability": "Available", "role": "web modeling rest oslc api access"},
    {"tool": "Dalus", "vendor": "Dalus", "compatibility": "Medium", "availability": "Available", "role": "ai-native mbse requirements hazard test trade mission-planning"},
    {"tool": "SBE", "vendor": "SBE vision", "compatibility": "High", "availability": "Available", "role": "authoring validation integration"},
    {"tool": "Simcenter Architect / Studio", "vendor": "Siemens", "compatibility": "High", "availability": "Available", "role": "architecture generation evaluation python automation analysis simulation"},
    {"tool": "SECollab", "vendor": "SodiusWillert", "compatibility": "Medium", "availability": "Available", "role": "collaboration integration"},
    {"tool": "SysGit", "vendor": "SysGit", "compatibility": "Medium", "availability": "Available", "role": "git collaboration textual graphical editing"},
    {"tool": "Violet", "vendor": "Violet Labs", "compatibility": "High", "availability": "Available", "role": "digital-thread integration hardware-development"},
]

_COMPATIBILITY_ORDER = {
    "High": 5,
    "Medium": 4,
    "Listed-not-scored": 3,
    "Low": 2,
    "Unverified": 1,
}


def list_mbse_tools_tool(arguments: dict[str, Any]) -> dict[str, Any]:
    """Return MBSE/SysML v2 tool candidates from the verified compatibility catalog."""

    min_compatibility = str(arguments.get("min_compatibility", "") or "")
    availability = str(arguments.get("availability", "") or "")
    include_unverified = bool(arguments.get("include_unverified", True))
    limit = int(arguments.get("limit", 50) or 50)

    min_score = _COMPATIBILITY_ORDER.get(min_compatibility, 0)
    tools = []
    for tool in _TOOL_CATALOG:
        if not include_unverified and tool["compatibility"] == "Unverified":
            continue
        if availability and tool["availability"].lower() != availability.lower():
            continue
        if _COMPATIBILITY_ORDER.get(tool["compatibility"], 0) < min_score:
            continue
        tools.append(tool)

    tools.sort(key=lambda item: _COMPATIBILITY_ORDER.get(item["compatibility"], 0), reverse=True)
    return {
        "ok": True,
        "count": len(tools[:limit]),
        "total_matches": len(tools),
        "tools": tools[:limit],
    }


def recommend_mbse_tools_tool(arguments: dict[str, Any]) -> dict[str, Any]:
    """Recommend MBSE tool candidates for a validation, authoring, visualization, or integration task."""

    task = str(arguments.get("task", "") or "").lower()
    limit = int(arguments.get("limit", 5) or 5)
    include_unverified = bool(arguments.get("include_unverified", False))
    keywords = [token for token in task.replace("/", " ").replace("-", " ").split() if token]

    ranked = []
    for tool in _TOOL_CATALOG:
        if not include_unverified and tool["compatibility"] == "Unverified":
            continue
        searchable = " ".join([tool["tool"], tool["vendor"], tool["role"], tool["compatibility"]]).lower()
        keyword_score = sum(1 for keyword in keywords if keyword in searchable)
        compatibility_score = _COMPATIBILITY_ORDER.get(tool["compatibility"], 0)
        score = keyword_score * 10 + compatibility_score
        if keyword_score or not keywords:
            ranked.append({"score": score, **tool})

    ranked.sort(key=lambda item: item["score"], reverse=True)
    return {
        "ok": True,
        "task": task,
        "recommendations": ranked[:limit],
        "note": "Catalog recommendations identify candidate MBSE backends; they do not execute commercial tools directly.",
    }
