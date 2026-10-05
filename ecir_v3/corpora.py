"""Requirements and exemplar corpora for the three ladder languages, as the v1 ladder saw them."""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

from common import LADDER_MOD, LADDER_SOL, LADDER_SYS, REPO, sha256_text


@dataclass
class Exemplar:
    id: str
    desc: str            # NL side scored by binary cosine / dense
    bm25_text: str       # NL side + category + tags
    code: str
    category: str
    lineage: str
    semantic: str
    source_names: list = field(default_factory=list)   # repo / org / contest / contract names (A10)


@dataclass
class Requirement:
    id: str
    text: str
    meta: dict = field(default_factory=dict)


# ---------------------------------------------------------------- exemplars
@lru_cache(None)
def exemplars(lang: str) -> list[Exemplar]:
    return {"sys": _ex_sys, "sol": _ex_sol, "mod": _ex_mod}[lang]()


@lru_cache(None)
def exemplar_index(lang: str) -> dict[str, Exemplar]:
    return {e.id: e for e in exemplars(lang)}


def _ex_sys() -> list[Exemplar]:
    # Same order and limit as nl2sysml.agent_rag_moe._collect_examples (first 300 .txt/.sysml pairs).
    out = []
    for p in sorted((REPO / "dataset/data").glob("*/*")):
        if p.suffix != ".txt" or not p.with_suffix(".sysml").exists():
            continue
        m = json.loads((p.parent / "meta.json").read_text())
        src = m.get("source_path", "")
        txt = p.read_text(encoding="utf-8")
        cat = m.get("category", "")
        out.append(Exemplar(p.stem, txt, f"{txt} {cat}", p.with_suffix(".sysml").read_text(encoding="utf-8"),
                            cat, str(Path(src).parent), p.stem, [Path(src).stem]))
        if len(out) >= 300:
            break
    return out


def _sol_lineage(m: dict) -> str:
    src = m.get("source_path", "")
    if "/sanctuary/" in src:        # independent Etherscan-verified contracts: one lineage each
        return src
    return str(Path(src).parent)


def _ex_sol() -> list[Exemplar]:
    # Same order and limit as nl2solidity.agent_rag_moe._collect_examples (all 1,500 pairs).
    out = []
    for p in sorted((REPO / "nl2solidity/dataset/data").glob("*/*")):
        if p.suffix != ".txt" or not p.with_suffix(".sol").exists():
            continue
        m = json.loads((p.parent / "meta.json").read_text())
        txt = p.read_text(encoding="utf-8")
        cat = m.get("category", "")
        tags = [m.get("labels", {}).get("domain", ""), m.get("labels", {}).get("difficulty", "")]
        src = m.get("source_path", "")
        stem = Path(src).stem
        contract = stem.split("_", 1)[1] if "/sanctuary/" in src and "_" in stem else stem
        attr = m.get("source", {}).get("attribution", "")
        names = [contract, attr, m.get("source", {}).get("provenance", "")]
        names += attr.replace(":", "/").split("/")
        out.append(Exemplar(p.stem, txt, " ".join([txt, cat, *tags]),
                            p.with_suffix(".sol").read_text(encoding="utf-8"),
                            cat, _sol_lineage(m), p.stem, [n.strip() for n in names if n.strip()]))
    return out


@lru_cache(None)
def mod_corpus():
    from nl2robotics.modelica.corpus import ExampleCorpus
    return ExampleCorpus(subset="full1500")


def _ex_mod() -> list[Exemplar]:
    out = []
    for e in mod_corpus().examples:
        out.append(Exemplar(e.id, e.requirement, " ".join((e.requirement, e.category, *e.tags)),
                            e.code, e.category, e.lineage_id, e.semantic_case_id, [e.source]))
    return out


# ---------------------------------------------------------------- requirements
@lru_cache(None)
def requirements(lang: str) -> dict[str, Requirement]:
    return {"sys": _req_sys, "sol": _req_sol, "mod": _req_mod}[lang]()


def _req_sys() -> dict[str, Requirement]:
    # The ladder's own request.txt (run_study strips the manifest description).
    out = {}
    for d in sorted((LADDER_SYS / "A1/tasks").iterdir()):
        t = (d / "artifacts/request.txt").read_text(encoding="utf-8").strip()
        out[d.name] = Requirement(d.name, t)
    return out


def _req_sol() -> dict[str, Requirement]:
    seeds = {}
    for l in (REPO / "nl2solidity/sol_seed.jsonl").read_text().splitlines():
        if l.strip():
            r = json.loads(l)
            seeds[r["id"]] = r
    out = {}
    for d in sorted((LADDER_SOL / "A1").iterdir()):
        if d.is_dir() and d.name.startswith("U"):
            s = seeds[d.name]
            out[d.name] = Requirement(d.name, s["description_long"],
                                      {"protocol": s.get("source_title"), "domain": s.get("domain")})
    return out


@lru_cache(None)
def mod_manifest() -> dict:
    return json.loads((REPO / "nl2robotics/corpus/pipeline_prompt_manifest.json").read_text())


def mod_run(task: str, arm: str) -> dict:
    return json.loads((LADDER_MOD / task / "rich" / arm / "repeat-00" / "run.json").read_text())


def _req_mod() -> dict[str, Requirement]:
    m = mod_manifest()
    cases = {c["id"]: c for c in m["cases"]}
    routes = m["rag_family_routes"]
    out = {}
    for d in sorted(LADDER_MOD.iterdir()):
        if not (d / "rich").is_dir():
            continue
        c = cases[d.name]
        a1 = mod_run(d.name, "A1")
        norm_ok = bool(((a1.get("result") or {}).get("normalization") or {}).get("success"))
        if sha256_text(c["request"].strip()) != (a1.get("result") or {}).get("source_text_sha256"):
            raise SystemExit(f"{d.name}: manifest request does not match the ladder's source_text_sha256")
        out[d.name] = Requirement(d.name, c["request"], {
            "family": c["family"], "route": tuple(routes[c["family"]]["modelica"]),
            "design_axes": c.get("design_axes", {}), "normalization_ok": norm_ok})
    return out


def mod_ladder_ids() -> list[str]:
    """Tasks common to all five Modelica arms after infrastructure exclusion (498)."""
    keep = []
    for t in requirements("mod"):
        ok = True
        for arm in ("A0", "A1", "A2", "A3", "A4"):
            r = mod_run(t, arm)
            if r.get("infrastructure_error") or (r.get("metrics") or {}).get("infrastructure_available") is False:
                ok = False
        if ok:
            keep.append(t)
    return keep
