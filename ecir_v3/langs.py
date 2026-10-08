"""Per-language prompts, output post-processing and scoring, reusing the v1 ladder code.

Prompts (exactly the ladder's A0 / A1 messages; only the exemplar list changes):
  sys  A0  nl2sysml.naive_glm_generate SYSTEM_PROMPT / HUMAN_TEMPLATE (= ladder A1 prompt minus context)
       A1  agent_rag_moe._default_system_prompt + PROMPT_HUMAN_TEMPLATE(context=_rag_context format)
  sol  A0  agent_rag_moe prompt with _rag_context() == ""   (ladder A0 ran RAG_ENABLED=false)
       A1  agent_rag_moe prompt with the five exemplars (no spec index existed)
  mod  A0  system TEXT_PREFIX, user ModelicaPipeline.build_baseline_messages joined by "\\n\\n"
       A1  system TEXT_PREFIX, user ModelicaPipeline._prompt(requirement, hits)
Truncation follows each pipeline: 80 non-blank, non-// lines (sys, sol); first 100 lines (mod).

Scoring:
  compile_valid  sys: nl2sysml.compiler_interface.check_code (zero diagnostics)
                 sol: nl2solidity.compiler_interface.check_code (no error-severity diagnostic;
                      solc picked per pragma from the PACE-installed set, ECIR_SOLC_VERSIONS)
                 mod: OpenModelicaRunner.compile -> build.success (checkModel + buildModel)
  gain           0 fail / 1 compiles / 2 also passes Tier A (sol: forge build + no contract
                 defect on the programmatic fuzz/boundary suite, 64 runs) or builds and runs an
                 FMU over the task clock (mod: run_compiler_execution_baseline). sys stops at 1.
"""
from __future__ import annotations

import os
import re
import tempfile
from functools import lru_cache
from pathlib import Path
from types import SimpleNamespace

from corpora import Requirement, exemplar_index, mod_corpus

PACE_SOLC = os.getenv("ECIR_SOLC_VERSIONS", "0.7.6,0.8.26,0.8.28")
# v1's SysML evaluator ran without the standard library (the parser CLI only searches fixed home-directory
# paths, none of which existed on the v1 machine). Loading this machine's library changes 85/497 v1 verdicts,
# so match v1 unless explicitly overridden (README deviation 16).
os.environ.setdefault("SYSML_COMPILER_LOAD_LIBRARY", "false")
FUZZ_RUNS = int(os.getenv("ECIR_FUZZ_RUNS", "64"))
MOD_BACKEND = os.getenv("ECIR_MODELICA_BACKEND", "auto")


# ---------------------------------------------------------------- prompts
def _snip80(code: str) -> str:
    lines = []
    for ln in code.splitlines():
        t = ln.strip()
        if not t or t.startswith("//"):
            continue
        lines.append(ln)
        if len(lines) >= 80:
            break
    return "\n".join(lines)


def _context(lang: str, ex_ids: list[str], spec_ids: list[str] | None) -> str:
    idx = exemplar_index(lang)
    label = "SysML" if lang == "sys" else "Solidity"
    blocks = [f"Example {i} NL:\n{idx[x].desc.strip()}\n\nExample {i} {label}:\n{_snip80(idx[x].code)}\n---"
              for i, x in enumerate(ex_ids, 1)]
    if lang == "sys" and spec_ids:
        from retrievers import spec_chunk
        for j, cid in enumerate(spec_ids, 1):
            r = spec_chunk(cid)
            blocks.append(f"Spec {j} [{r.get('title', 'Spec')}]:\n{r.get('text', '')}\n---")
    if not blocks:
        return ""
    if lang == "sys":
        head = ("Use the following examples and specification excerpts as guidance. "
                "Follow grammar; prefer simple, correct constructs.\n")
    else:
        head = ("Use the following examples and documentation excerpts as guidance. "
                "Follow the language grammar; prefer simple, correct, secure constructs.\n")
    return head + "\n".join(blocks)


def messages(lang: str, req: Requirement, ex_ids: list[str] | None,
             spec_ids: list[str] | None = None) -> tuple[str, str]:
    """(system, user). ex_ids None/[] and no spec_ids -> the A0 prompt."""
    a0 = not ex_ids and not spec_ids
    if lang == "sys":
        if a0:
            from nl2sysml.naive_glm_generate import HUMAN_TEMPLATE, SYSTEM_PROMPT
            return SYSTEM_PROMPT, HUMAN_TEMPLATE.format(input=req.text)
        from nl2sysml import agent_rag_moe as A
        return A._default_system_prompt(None), A.PROMPT_HUMAN_TEMPLATE.format(
            context=_context("sys", ex_ids or [], spec_ids), input=req.text)
    if lang == "sol":
        from nl2solidity import agent_rag_moe as A
        ctx = "" if a0 else _context("sol", ex_ids, None)
        return A._default_system_prompt(None), A.PROMPT_HUMAN_TEMPLATE.format(context=ctx, input=req.text)
    from nl2robotics.modelica.pipeline import ModelicaPipeline
    from spec_aligner.llm import TEXT_PREFIX
    pipe = _mod_pipe()
    if a0:
        s, h = pipe.build_baseline_messages(req.text)
        return TEXT_PREFIX, f"{s}\n\n{h}"
    corpus = mod_corpus()
    by = {e.id: e for e in corpus.examples}
    hits = [(by[x], 0.0) for x in ex_ids]
    return TEXT_PREFIX, ModelicaPipeline._prompt(pipe, req.text, hits)


@lru_cache(None)
def _mod_pipe():
    from nl2robotics.modelica.pipeline import ModelicaPipeline
    return ModelicaPipeline(corpus=mod_corpus(), runner=_omc())


# ---------------------------------------------------------------- generation with ladder post-processing
STRONG = {"sys": " No markdown, no fences, no prose. Output SysML v2 code only.",
          "sol": " No markdown, no fences, no prose. Output Solidity code only."}


def generate(lang: str, system: str, user: str, call) -> tuple[str, list[dict]]:
    """Ladder invoke semantics. call(system, user) -> llm.chat dict. Returns (code, calls).
    code == "" means an empty/degenerate output (status empty_output)."""
    calls = []
    if lang == "mod":
        from nl2robotics.modelica.pipeline import clean_code
        r = call(system, user); calls.append(r)
        try:
            return clean_code(r["text"] or ""), calls
        except ValueError:
            return "", calls
    A = _agent(lang)
    r = call(system, user); calls.append(r)
    out = A._postprocess(r["text"] or "")
    if (not out) or ("```" in out) or A._is_degenerate(out):
        r = call(system + STRONG[lang], user); calls.append(r)
        out = A._postprocess(r["text"] or "")
    if not out.strip() or A._is_degenerate(out):
        return "", calls
    return out, calls


def _agent(lang):
    if lang == "sys":
        from nl2sysml import agent_rag_moe as A
    else:
        from nl2solidity import agent_rag_moe as A
    return A


# ---------------------------------------------------------------- scoring
def _restrict_solcx():
    import solcx
    from packaging.version import Version
    if getattr(solcx, "_ecir_restricted", False):
        return
    keep = {Version(v) for v in PACE_SOLC.split(",") if v}
    orig = solcx.get_installed_solc_versions

    def only_pace(*a, **k):
        return [v for v in orig(*a, **k) if v in keep]
    solcx.get_installed_solc_versions = only_pace
    solcx._ecir_restricted = True
    os.environ.setdefault("SOLC_AUTO_INSTALL", "false")


def solc_version_for(code: str) -> str | None:
    _restrict_solcx()
    import solcx
    from solcx.install import select_pragma_version
    m = re.search(r"pragma\s+solidity\s+([^;]+);", code)
    inst = solcx.get_installed_solc_versions()
    try:
        v = select_pragma_version(m.group(1), inst) if m else None
    except Exception:
        v = None
    if v is None and not m:
        v = next((x for x in inst if str(x) == os.getenv("SOLC_DEFAULT_VERSION", "0.8.26")), None)
    if v is None and inst:
        v = max(inst)
    return str(v) if v else None


@lru_cache(None)
def _omc():
    from nl2robotics.modelica.openmodelica import OpenModelicaRunner
    return OpenModelicaRunner(backend=MOD_BACKEND)


def compile_check(lang: str, code: str, workdir: Path | None = None) -> dict:
    """{"compile_valid", "n_compiler_errors", "errors": [{"code", "message"}], "infra": str|None}"""
    if lang == "sys":
        from nl2sysml.compiler_interface import check_code
        r = check_code(code, syntax_only=False)
        errs = [{"code": e.code, "message": e.message, "severity": e.severity} for e in r.errors]
        return {"compile_valid": bool(r.is_valid), "n_compiler_errors": len(errs), "errors": errs, "infra": None}
    if lang == "sol":
        _restrict_solcx()
        from nl2solidity.compiler_interface import check_code
        r = check_code(code)
        errs = [{"code": e.code, "message": e.message, "severity": e.severity} for e in r.errors
                if (e.severity or "").lower() == "error"]
        infra = None
        if any((e["code"] or "") in ("SolcNotFound", "Timeout") for e in errs):
            infra = "solc unavailable or timed out"
        return {"compile_valid": bool(r.is_valid), "n_compiler_errors": len(errs), "errors": errs,
                "infra": infra, "solc": solc_version_for(code)}
    b = _omc().compile(code, output_dir=workdir)
    if not b.available:
        return {"compile_valid": False, "n_compiler_errors": 0, "errors": [], "infra": "OpenModelica unavailable"}
    d = b.to_dict()
    errs = [{"code": x.get("stage"), "message": x.get("message"), "severity": x.get("severity")}
            for x in (d.get("diagnostics") or []) if (x.get("severity") or "").lower() == "error"]
    return {"compile_valid": bool(b.success), "n_compiler_errors": int(b.error_count), "errors": errs,
            "infra": None, "check_message": b.check_message}


def tier2(lang: str, code: str, req: Requirement, workdir: Path) -> dict:
    """Gain level 2 check for a program that already compiles."""
    if lang == "sol":
        from nl2solidity.solidity_execution import ExecutionRequest, run_solidity_execution
        r = run_solidity_execution(ExecutionRequest(candidate_solidity=code, fuzz_runs=FUZZ_RUNS,
                                                    numeric_bound="1e30", property_tests=None))
        diag = r.diagnostics or {}
        ok = bool(r.compiled) and int(diag.get("contract_defects") or 0) == 0
        return {"passed": ok, "compiled": bool(r.compiled), "tier_status": r.tier_status,
                "contract_defects": diag.get("contract_defects"), "harness_defects": diag.get("harness_defects"),
                "infra": None if r.kernel_available else (r.bridge_error or "Foundry unavailable")}
    if lang == "mod":
        from nl2robotics.experiments.executor import _baseline_execution_clock
        from nl2robotics.hybrid.capability_execution import CapabilityExecutionPipeline
        from nl2robotics.modelica.fmu_runtime import FMIContainerRunner
        from nl2robotics.modelica.openmodelica import find_model_name
        task = SimpleNamespace(id=req.id, oracle={"design_axes": req.meta.get("design_axes", {})})
        clock = _baseline_execution_clock(task, req.text)
        name = find_model_name(code)
        rep = CapabilityExecutionPipeline(modelica_runner=_omc(), fmi_runner=FMIContainerRunner()) \
            .run_compiler_execution_baseline(
                code, {"task_id": req.id, "properties": []},
                {"contract_kind": "baseline_compiler_execution", "model_name": name, "clock": clock},
                output_dir=workdir)
        infra = None
        ex = rep.get("execution") or {}
        if ex and ex.get("available") is False:
            infra = "FMI runtime unavailable"
        return {"passed": bool(rep.get("passed")), "failure_stage": rep.get("failure_stage"),
                "model_name": name, "infra": infra}
    return {"passed": False, "infra": None}


def score(lang: str, code: str, req: Requirement, *, gain2: bool, workdir: Path | None = None) -> dict:
    workdir = workdir or Path(tempfile.mkdtemp(prefix=f"ecir-{lang}-"))
    c = compile_check(lang, code, workdir / "compile")
    out = {**c, "gain": int(c["compile_valid"])}
    if gain2 and lang != "sys" and c["compile_valid"] and not c["infra"]:
        t = tier2(lang, code, req, workdir / "tier2")
        out["tier2"] = t
        out["infra"] = t.get("infra")
        out["gain"] = 2 if t["passed"] else 1
    if lang == "sol" and not out.get("infra"):
        out.update(resolved_fields(code, out["gain"]))
    return out


def resolved_fields(code: str, gain_single: int) -> dict:
    """Import-resolved Solidity verdict (sol_imports.py, README deviation 18) next to the single-file one.
    gain_res: 0 = fails resolved compilation, 1 = compiles resolved, 2 = also passed Tier A, which runs on
    single-file-valid programs only (forge keeps fixed remappings), so an importing program tops out at 1."""
    import sol_imports as S
    x = S.compile_resolved(code)
    if x["infra"]:
        return {"infra": f"resolved scoring: {x['infra']}"}
    return {"compile_valid_res": x["compile_valid"], "n_compiler_errors_res": x["n_compiler_errors"],
            "errors_res": x["errors"], "res_profile": x["profile"], "res_resolved": x["resolved_imports"],
            "res_unresolved": x["unresolved_imports"], "res_lib_errors": x["lib_errors"],
            "gain_res": 2 if gain_single == 2 else int(x["compile_valid"])}


# ---------------------------------------------------------------- solc error classes (A1)
ERR_CLASSES = ("imp", "ver", "und", "type", "parse", "other")
ERR_NAMES = {"imp": "unresolved imports", "ver": "compiler version or pragma errors",
             "und": "undeclared identifiers", "type": "type errors", "parse": "parser errors",
             "other": "other errors"}


def solc_class(err: dict) -> str:
    code, msg = (err.get("code") or ""), (err.get("message") or "")
    low = msg.lower()
    if ("source \"" in low and "not found" in low) or "file import callback" in low or \
            ("not found" in low and "import" in low):
        return "imp"
    if "compiler version" in low or "pragma" in low:
        return "ver"
    if "undeclared identifier" in low or ("identifier not found" in low) or \
            ("DeclarationError" in code and "not found" in low):
        return "und"
    if "TypeError" in code:
        return "type"
    if "ParserError" in code or "SyntaxError" in code:
        return "parse"
    return "other"
