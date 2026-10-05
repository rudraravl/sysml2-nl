"""Paths, ID lists, JSONL I/O and run provenance shared by the v3 scripts."""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))

IDS = HERE / "ids"
RETR = HERE / "retrieval"
# ECIR_WORKDIR redirects every *output* (runs, analysis, paper, placeholders) for dry tests.
WORK = Path(os.getenv("ECIR_WORKDIR", HERE))
RUNS = WORK / "runs"
PLACEHOLDERS = WORK / "placeholders.json"

LANGS = ("sys", "sol", "mod")
EXT = {"sys": "sysml", "sol": "sol", "mod": "mo"}
DEPLOYED = {"sys": "cos", "sol": "cos", "mod": "bm25"}   # v1 A1 retriever per language
MODEL = "z-ai/glm-5.2"
TEMPERATURE = 0.2

# v1 ladder outputs (read-only)
LADDER_SOL = REPO / "nl2solidity/ablation/solidity_ablation/ablation"
LADDER_SYS = REPO / "dataset/sysml-ablation/outputs/sysml-ablation-rich500-20260922-0acc72e0"
LADDER_MOD = REPO / "nl2robotics/glm52-ablation-corpus-v2"


def req_seed(req_id: str, salt: str = "") -> int:
    """Deterministic per-requirement seed (runbook: seed = hash of the requirement ID)."""
    return int(hashlib.sha256((salt + req_id).encode()).hexdigest()[:8], 16)


def sha256_text(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def read_ids(name: str) -> list[str]:
    return [l.strip() for l in (IDS / name).read_text().splitlines() if l.strip()]


def write_ids(name: str, ids) -> None:
    IDS.mkdir(parents=True, exist_ok=True)
    (IDS / name).write_text("".join(f"{i}\n" for i in ids))


def read_jsonl(path) -> list[dict]:
    p = Path(path)
    if not p.exists():
        return []
    return [json.loads(l) for l in p.read_text(encoding="utf-8").splitlines() if l.strip()]


def write_jsonl(path, rows) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(p.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, sort_keys=True) + "\n")
    tmp.replace(p)


def write_json(path, obj) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(p.suffix + ".tmp")
    tmp.write_text(json.dumps(obj, indent=1, sort_keys=True, default=str) + "\n", encoding="utf-8")
    tmp.replace(p)


def retrieval_lists(lang: str, name: str) -> dict[str, dict]:
    """{req_id: {"exemplar_ids": [...], "scores": [...], ...}} from retrieval/<lang>/<name>.jsonl."""
    return {r["req_id"]: r for r in read_jsonl(RETR / lang / f"{name}.jsonl")}


def git_commit() -> str:
    try:
        sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True,
                             text=True, check=True).stdout.strip()
        dirty = subprocess.run(["git", "status", "--porcelain", "--", "ecir_v3", "nl2solidity",
                                "nl2sysml", "nl2robotics"], cwd=REPO, capture_output=True,
                               text=True).stdout.strip()
        return sha + ("-dirty" if dirty else "")
    except Exception:
        return "unknown"


def load_env() -> None:
    try:
        from dotenv import load_dotenv
        load_dotenv(REPO / ".env")
    except Exception:
        pass


def placeholders_set(values: dict, source: str) -> None:
    """Merge values into placeholders.json; keeps a per-key provenance sidecar."""
    d = json.loads(PLACEHOLDERS.read_text()) if PLACEHOLDERS.exists() else {}
    prov_p = WORK / "placeholders.provenance.json"
    prov = json.loads(prov_p.read_text()) if prov_p.exists() else {}
    for k, v in values.items():
        d[k] = v
        prov[k] = source
    PLACEHOLDERS.write_text(json.dumps(d, indent=1, sort_keys=True) + "\n")
    prov_p.write_text(json.dumps(prov, indent=1, sort_keys=True) + "\n")


def env_flag(name: str, default: bool = False) -> bool:
    v = os.getenv(name)
    return default if v is None else v.strip().lower() in ("1", "true", "yes", "on")
