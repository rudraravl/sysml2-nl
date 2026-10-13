#!/usr/bin/env python3
"""Stage 0 of the ECIR 2027 runbook: ids, retrieval, features, leakage.

No model calls. Solidity uses the first 500 rows of nl2solidity/sol_seed.csv,
which is the ablation evaluation set (the jsonl twin is not in this checkout).
SysML v2 and Modelica ladder ids are not frozen anywhere in this checkout, so
this script does not draw a fresh 500 or 498: those lists have to be the ones
the v1 A1 logs used.

    python ecir2027/stage0.py ids
    python ecir2027/stage0.py retrieval
    python ecir2027/stage0.py features
    python ecir2027/stage0.py leakage
    python ecir2027/stage0.py versions
    python ecir2027/stage0.py all
"""

from __future__ import annotations

import csv
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
sys.path.insert(0, str(REPO))

from nl2robotics.retrieval import DiverseBM25, RetrievalDocument  # noqa: E402

SOL_SEED = REPO / "nl2solidity" / "sol_seed.csv"
SOL_EXEMPLARS = REPO / "nl2solidity" / "dataset" / "data"
IDS = HERE / "ids"
RETRIEVAL = HERE / "retrieval"
RUNS = HERE / "runs"

# Same tokenizer and binary cosine as nl2solidity/agent_rag_moe.py.
_TOKEN = re.compile(r"[^A-Za-z0-9_]+")


def tokenize(text: str) -> list[str]:
    return [tok for tok in _TOKEN.split(text.lower()) if tok]


def binary_cosine(left: set[str], right: set[str]) -> float:
    if not left or not right:
        return 0.0
    return len(left & right) / (len(left) ** 0.5 * len(right) ** 0.5)


def stable_rng(key: str) -> np.random.Generator:
    digest = hashlib.sha256(key.encode("utf-8")).digest()
    return np.random.default_rng(int.from_bytes(digest[:8], "little"))


def read_lines(path: Path) -> list[str]:
    return [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def write_lines(path: Path, rows: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(rows) + "\n", encoding="utf-8")


def solidity_seed_rows() -> list[dict]:
    with SOL_SEED.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def cmd_ids() -> None:
    if not SOL_SEED.exists():
        raise SystemExit(f"missing {SOL_SEED}")
    rows = solidity_seed_rows()
    ladder = [row["id"] for row in rows[:500]]
    if len(ladder) != 500:
        raise SystemExit(f"sol_seed.csv has {len(rows)} rows, need at least 500")
    write_lines(IDS / "ladder500_sol.txt", ladder)
    rng = np.random.default_rng(0)
    chosen = set(rng.choice(len(ladder), size=100, replace=False).tolist())
    pool = [req for i, req in enumerate(ladder) if i in chosen]
    heldout = [req for i, req in enumerate(ladder) if i not in chosen]
    write_lines(IDS / "pool100_sol.txt", pool)
    write_lines(IDS / "heldout400_sol.txt", heldout)
    print(f"solidity ids: ladder {len(ladder)}, pool {len(pool)}, held-out {len(heldout)}")


def load_sol_exemplars() -> list[dict]:
    exemplars = []
    for meta_path in sorted(SOL_EXEMPLARS.glob("*/meta.json")):
        folder = meta_path.parent
        code_path = folder / f"{folder.name}.sol"
        text_path = folder / f"{folder.name}.txt"
        if not code_path.exists() or not text_path.exists():
            continue
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        source = meta.get("source") or {}
        attribution = source.get("attribution") or ""
        source_path = meta.get("source_path") or ""
        parts = source_path.split("/")
        lineage = attribution or (parts[2] if len(parts) >= 3 else folder.name)
        category = meta.get("category") or ""
        tags = " ".join(str(v) for v in (meta.get("labels") or {}).values())
        description = text_path.read_text(encoding="utf-8", errors="replace")
        exemplars.append({
            "id": folder.name,
            "description": description,
            "category": category,
            "tags": tags,
            "lineage": lineage or folder.name,
            "attribution": attribution,
            "source_path": source_path,
            "code_path": str(code_path),
            "tokens": set(tokenize(description)),
        })
    if not exemplars:
        raise SystemExit(f"no Solidity exemplars under {SOL_EXEMPLARS}")
    return exemplars


MODELICA_RESULTS = Path(
    "/Users/siveshkannan/Downloads/glm52-ablation-exact-500x5-results.tar.gz"
)
MODELICA_MANIFEST = REPO / "nl2robotics" / "corpus" / "pipeline_prompt_manifest.json"


def modelica_ladder_ids() -> list[str]:
    """The 500 requirements in the Modelica A0–A4 results archive."""
    import tarfile
    if not MODELICA_RESULTS.is_file():
        raise SystemExit(f"missing {MODELICA_RESULTS}")
    ids = set()
    with tarfile.open(MODELICA_RESULTS) as archive:
        for name in archive.getnames():
            for part in name.split("/"):
                if part.startswith("RPI"):
                    ids.add(part)
    if len(ids) != 500:
        raise SystemExit(f"expected 500 Modelica ladder ids, found {len(ids)}")
    return sorted(ids)


def modelica_requests() -> dict[str, str]:
    manifest = json.loads(MODELICA_MANIFEST.read_text(encoding="utf-8"))
    return {row["id"]: row["request"] for row in manifest["cases"]}


def cmd_modelica_ids() -> None:
    ladder = modelica_ladder_ids()
    requests = modelica_requests()
    missing = [req_id for req_id in ladder if req_id not in requests]
    if missing:
        raise SystemExit(f"{len(missing)} ladder ids are not in the manifest, e.g. {missing[:3]}")
    write_lines(IDS / "ladder500_mod.txt", ladder)
    rng = np.random.default_rng(0)
    chosen = set(rng.choice(len(ladder), size=100, replace=False).tolist())
    pool = [req for i, req in enumerate(ladder) if i in chosen]
    heldout = [req for i, req in enumerate(ladder) if i not in chosen]
    write_lines(IDS / "pool100_mod.txt", pool)
    write_lines(IDS / "heldout400_mod.txt", heldout)
    print(f"modelica ids: ladder {len(ladder)}, pool {len(pool)}, held-out {len(heldout)}")


def cmd_modelica_retrieval() -> None:
    from nl2robotics.modelica.corpus import ExampleCorpus
    ladder_path = IDS / "ladder500_mod.txt"
    if not ladder_path.exists():
        cmd_modelica_ids()
    requests = modelica_requests()
    corpus = ExampleCorpus()
    exemplars = corpus.examples
    cos_docs = []
    for item in exemplars:
        cos_docs.append((item.id, set(tokenize(item.requirement))))
    cos_lines, bm25_lines = [], []
    for req_id in read_lines(ladder_path):
        text = requests[req_id]
        query = set(tokenize(text))
        scored = sorted(
            ((item_id, binary_cosine(query, tokenset)) for item_id, tokenset in cos_docs),
            key=lambda pair: (-pair[1], pair[0]),
        )[:10]
        cos_lines.append(json.dumps({
            "req_id": req_id,
            "exemplar_ids": [item[0] for item in scored],
            "scores": [round(item[1], 6) for item in scored],
        }))
        ranked = corpus.retrieve(text, k=10)
        bm25_lines.append(json.dumps({
            "req_id": req_id,
            "exemplar_ids": [item.id for item, _score in ranked],
            "scores": [round(score, 6) for _item, score in ranked],
        }))
    out = RETRIEVAL / "mod"
    out.mkdir(parents=True, exist_ok=True)
    (out / "cos.jsonl").write_text("\n".join(cos_lines) + "\n", encoding="utf-8")
    (out / "bm25.jsonl").write_text("\n".join(bm25_lines) + "\n", encoding="utf-8")
    print(f"retrieval: {len(cos_lines)} modelica requirements, cosine and BM25 top 10")
    _draw_modelica_pool_random([item.id for item in exemplars])
    _check_modelica_bm25_against_archive()


def _draw_modelica_pool_random(corpus_ids: list[str]) -> None:
    pool_ids = read_lines(IDS / "pool100_mod.txt")
    by_req = {}
    for name in ("cos", "bm25", "dense"):
        path = RETRIEVAL / "mod" / f"{name}.jsonl"
        if not path.exists():
            continue
        for row in (json.loads(line) for line in path.read_text().splitlines()):
            by_req.setdefault(row["req_id"], set()).update(row["exemplar_ids"][:5])
    lines = []
    for req_id in pool_ids:
        banned = by_req.get(req_id, set())
        eligible = [item for item in corpus_ids if item not in banned]
        draw = stable_rng(req_id).choice(eligible, size=2, replace=False)
        lines.append(json.dumps({"req_id": req_id, "exemplar_ids": list(draw)}))
    (RETRIEVAL / "mod" / "random.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"pool random exemplars: {len(lines)} modelica requirements")


def _check_modelica_bm25_against_archive() -> None:
    import tarfile
    ours = {
        row["req_id"]: row["exemplar_ids"][:5]
        for row in (json.loads(line) for line in (RETRIEVAL / "mod" / "bm25.jsonl").read_text().splitlines())
    }
    compared = differ = 0
    with tarfile.open(MODELICA_RESULTS) as archive:
        for member in archive.getmembers():
            if not member.name.endswith("/A1/repeat-00/run.json"):
                continue
            record = json.load(archive.extractfile(member))
            logged = ((record.get("result") or {}).get("modelica") or {}).get("retrieved_examples") or []
            if not logged:
                continue
            req_id = record["task_id"]
            logged_ids = [item["id"] for item in logged]
            compared += 1
            if ours.get(req_id) != logged_ids:
                differ += 1
    print(f"BM25 top-5 vs archived A1 logs: {differ} of {compared} differ")


def cmd_modelica_dense() -> None:
    """Top 10 dense cosine, then the pool the paper labels."""
    from sentence_transformers import SentenceTransformer
    ladder_path = IDS / "ladder500_mod.txt"
    if not (RETRIEVAL / "mod" / "bm25.jsonl").exists():
        cmd_modelica_retrieval()
    from nl2robotics.modelica.corpus import ExampleCorpus
    requests = modelica_requests()
    families = {
        row["id"]: row.get("family", "")
        for row in json.loads(MODELICA_MANIFEST.read_text(encoding="utf-8"))["cases"]
    }
    exemplars = ExampleCorpus().examples
    model = SentenceTransformer("BAAI/bge-base-en-v1.5")
    revision = getattr(getattr(model, "model_card_data", None), "base_model", None)
    doc_matrix = model.encode(
        [item.requirement for item in exemplars],
        normalize_embeddings=True,
        show_progress_bar=False,
    )
    ladder = read_lines(ladder_path)
    query_matrix = model.encode(
        ["Represent this sentence for searching relevant passages: " + requests[req_id] for req_id in ladder],
        normalize_embeddings=True,
        show_progress_bar=False,
    )
    scores = query_matrix @ doc_matrix.T
    lines = []
    for row_index, req_id in enumerate(ladder):
        order = sorted(range(len(exemplars)), key=lambda index: (-float(scores[row_index, index]), exemplars[index].id))
        top = order[:10]
        lines.append(json.dumps({
            "req_id": req_id,
            "exemplar_ids": [exemplars[index].id for index in top],
            "scores": [round(float(scores[row_index, index]), 6) for index in top],
        }))
    out = RETRIEVAL / "mod"
    (out / "dense.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"dense: {len(lines)} modelica requirements, top 10")
    _record_dense_revision(revision)
    _draw_modelica_pool_random([item.id for item in exemplars])
    _write_modelica_pool(exemplars, families)


def _record_dense_revision(revision) -> None:
    path = RUNS / "versions.json"
    if not path.exists():
        return
    versions = json.loads(path.read_text(encoding="utf-8"))
    versions.setdefault("dense", {})["revision"] = revision
    path.write_text(json.dumps(versions, indent=2) + "\n", encoding="utf-8")


def _write_modelica_pool(exemplars, families: dict[str, str]) -> None:
    by_id = {item.id: item for item in exemplars}
    lists = {}
    for name in ("cos", "bm25", "dense"):
        lists[name] = {
            row["req_id"]: row
            for row in (json.loads(line) for line in (RETRIEVAL / "mod" / f"{name}.jsonl").read_text().splitlines())
        }
    random_rows = {
        row["req_id"]: row["exemplar_ids"]
        for row in (json.loads(line) for line in (RETRIEVAL / "mod" / "random.jsonl").read_text().splitlines())
    }
    feature_lines = []
    pool_lines = []
    pool_ids = set(read_lines(IDS / "pool100_mod.txt"))
    for req_id in read_lines(IDS / "ladder500_mod.txt"):
        chosen = {}
        for name in ("cos", "bm25", "dense"):
            row = lists[name][req_id]
            for rank, (exemplar_id, score) in enumerate(zip(row["exemplar_ids"], row["scores"]), 1):
                slot = chosen.setdefault(exemplar_id, {"ranks": {}, "scores": {}})
                slot["scores"][name] = score
                if rank <= 5:
                    slot["ranks"][name] = rank
        for exemplar_id, slot in chosen.items():
            feature_lines.append(json.dumps(_pool_row(req_id, exemplar_id, slot, by_id, families, random=False)))
        if req_id not in pool_ids:
            continue
        labeled = {}
        for name in ("cos", "bm25", "dense"):
            row = lists[name][req_id]
            for rank, (exemplar_id, score) in enumerate(zip(row["exemplar_ids"][:5], row["scores"][:5]), 1):
                slot = labeled.setdefault(exemplar_id, {"ranks": {}, "scores": {}, "random": False})
                slot["ranks"][name] = rank
                slot["scores"][name] = score
        for exemplar_id in random_rows[req_id]:
            slot = labeled.setdefault(exemplar_id, {"ranks": {}, "scores": {}, "random": True})
            slot["random"] = True
            for name in ("cos", "bm25", "dense"):
                row = lists[name][req_id]
                if exemplar_id in row["exemplar_ids"]:
                    slot["scores"][name] = row["scores"][row["exemplar_ids"].index(exemplar_id)]
        for exemplar_id in sorted(labeled):
            pool_lines.append(json.dumps(
                _pool_row(req_id, exemplar_id, labeled[exemplar_id], by_id, families, random=labeled[exemplar_id]["random"])
            ))
    (RETRIEVAL / "mod" / "features.jsonl").write_text("\n".join(feature_lines) + "\n", encoding="utf-8")
    (RETRIEVAL / "mod" / "pool.jsonl").write_text("\n".join(pool_lines) + "\n", encoding="utf-8")
    print(f"pool: {len(pool_lines)} modelica requirement-exemplar pairs over {len(pool_ids)} requirements")


def _pool_row(req_id, exemplar_id, slot, by_id, families, *, random: bool) -> dict:
    example = by_id[exemplar_id]
    lines = _noncomment_lines(example.code)
    ranks = {name: slot["ranks"].get(name) for name in ("cos", "bm25", "dense")}
    scores = slot["scores"]
    return {
        "req_id": req_id,
        "exemplar_id": exemplar_id,
        "ranks": ranks,
        "random": random,
        "features": {
            "cos_score": scores.get("cos", 0.0),
            "bm25_score": scores.get("bm25", 0.0),
            "dense_score": scores.get("dense", 0.0),
            "n_imports": sum(1 for line in lines if line.strip().startswith("import ")),
            "pragma_mismatch": 0,
            "n_lines": len(lines),
            "truncated": int(len(lines) > 80),
            "same_category": int(example.category == families.get(req_id, "")),
        },
    }


def cmd_retrieval() -> None:
    ladder_path = IDS / "ladder500_sol.txt"
    if not ladder_path.exists():
        cmd_ids()
    requirements = {row["id"]: row for row in solidity_seed_rows()}
    exemplars = load_sol_exemplars()
    documents = [
        RetrievalDocument(
            " ".join((item["description"], item["category"], item["tags"])),
            item["id"],
            item["lineage"],
            item["category"] or "unknown",
        )
        for item in exemplars
    ]
    bm25 = DiverseBM25(documents)
    cos_lines, bm25_lines = [], []
    for req_id in read_lines(ladder_path):
        text = requirements[req_id]["description"]
        query = set(tokenize(text))
        scored = sorted(
            ((item["id"], binary_cosine(query, item["tokens"])) for item in exemplars),
            key=lambda pair: (-pair[1], pair[0]),
        )[:10]
        cos_lines.append(json.dumps({
            "req_id": req_id,
            "exemplar_ids": [item[0] for item in scored],
            "scores": [round(item[1], 6) for item in scored],
        }))
        ranked = bm25.rank(text, k=10)
        bm25_lines.append(json.dumps({
            "req_id": req_id,
            "exemplar_ids": [exemplars[index]["id"] for index, _score in ranked],
            "scores": [round(score, 6) for _index, score in ranked],
        }))
    out = RETRIEVAL / "sol"
    out.mkdir(parents=True, exist_ok=True)
    (out / "cos.jsonl").write_text("\n".join(cos_lines) + "\n", encoding="utf-8")
    (out / "bm25.jsonl").write_text("\n".join(bm25_lines) + "\n", encoding="utf-8")
    print(f"retrieval: {len(cos_lines)} solidity requirements, cosine and BM25 top 10")
    print("dense lists are not built: sentence-transformers is not installed, and D9 has no revision yet")
    print("v1 A1 logs are not in this checkout, so the deployed top-five sanity check cannot be run")
    _draw_pool_random(exemplars)


def _draw_pool_random(exemplars: list[dict]) -> None:
    pool_ids = read_lines(IDS / "pool100_sol.txt")
    by_req = {}
    for name in ("cos", "bm25", "dense"):
        path = RETRIEVAL / "sol" / f"{name}.jsonl"
        if not path.exists():
            continue
        for row in (json.loads(line) for line in path.read_text().splitlines()):
            by_req.setdefault(row["req_id"], set()).update(row["exemplar_ids"][:5])
    corpus = [item["id"] for item in exemplars]
    lines = []
    for req_id in pool_ids:
        banned = by_req.get(req_id, set())
        eligible = [item for item in corpus if item not in banned]
        draw = stable_rng(req_id).choice(eligible, size=2, replace=False)
        lines.append(json.dumps({"req_id": req_id, "exemplar_ids": list(draw)}))
    (RETRIEVAL / "sol" / "random.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"pool random exemplars: {len(lines)} solidity requirements")


def _noncomment_lines(code: str) -> list[str]:
    kept = []
    in_block = False
    for line in code.splitlines():
        stripped = line.strip()
        if in_block:
            if "*/" in stripped:
                in_block = False
            continue
        if stripped.startswith("/*"):
            in_block = "*/" not in stripped
            continue
        if not stripped or stripped.startswith("//"):
            continue
        kept.append(line)
    return kept


def _pragma(code: str) -> str:
    match = re.search(r"pragma\s+solidity\s+([^;]+);", code)
    return match.group(1).strip() if match else ""


def cmd_solidity_dense() -> None:
    """Top 10 dense cosine for Solidity, then the pool the paper labels."""
    from sentence_transformers import SentenceTransformer
    if not (RETRIEVAL / "sol" / "bm25.jsonl").exists():
        cmd_retrieval()
    requirements = {row["id"]: row for row in solidity_seed_rows()}
    exemplars = load_sol_exemplars()
    model = SentenceTransformer("BAAI/bge-base-en-v1.5")
    doc_matrix = model.encode(
        [item["description"] for item in exemplars],
        normalize_embeddings=True,
        show_progress_bar=False,
    )
    ladder = read_lines(IDS / "ladder500_sol.txt")
    query_matrix = model.encode(
        ["Represent this sentence for searching relevant passages: " + requirements[req_id]["description"] for req_id in ladder],
        normalize_embeddings=True,
        show_progress_bar=False,
    )
    matrix = query_matrix @ doc_matrix.T
    lines = []
    for row_index, req_id in enumerate(ladder):
        order = sorted(range(len(exemplars)), key=lambda index: (-float(matrix[row_index, index]), exemplars[index]["id"]))
        top = order[:10]
        lines.append(json.dumps({
            "req_id": req_id,
            "exemplar_ids": [exemplars[index]["id"] for index in top],
            "scores": [round(float(matrix[row_index, index]), 6) for index in top],
        }))
    (RETRIEVAL / "sol" / "dense.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"dense: {len(lines)} solidity requirements, top 10")
    _draw_pool_random(exemplars)
    _write_solidity_pool(exemplars, requirements)


def _write_solidity_pool(exemplars, requirements) -> None:
    by_id = {item["id"]: item for item in exemplars}
    lists = {}
    for name in ("cos", "bm25", "dense"):
        lists[name] = {
            row["req_id"]: row
            for row in (json.loads(line) for line in (RETRIEVAL / "sol" / f"{name}.jsonl").read_text().splitlines())
        }
    random_rows = {
        row["req_id"]: row["exemplar_ids"]
        for row in (json.loads(line) for line in (RETRIEVAL / "sol" / "random.jsonl").read_text().splitlines())
    }
    solc = _solc_version() or "0.8.26"
    pool_ids = set(read_lines(IDS / "pool100_sol.txt"))
    pool_lines = []
    feature_lines = []
    for req_id in read_lines(IDS / "ladder500_sol.txt"):
        chosen = {}
        for name in ("cos", "bm25", "dense"):
            row = lists[name][req_id]
            for rank, (exemplar_id, score) in enumerate(zip(row["exemplar_ids"], row["scores"]), 1):
                slot = chosen.setdefault(exemplar_id, {"ranks": {}, "scores": {}})
                slot["scores"][name] = score
                if rank <= 5:
                    slot["ranks"][name] = rank
        for exemplar_id, slot in chosen.items():
            feature_lines.append(json.dumps(
                _sol_pool_row(req_id, exemplar_id, slot, by_id, requirements, solc, random=False)
            ))
        if req_id not in pool_ids:
            continue
        labeled = {}
        for name in ("cos", "bm25", "dense"):
            row = lists[name][req_id]
            for rank, (exemplar_id, score) in enumerate(zip(row["exemplar_ids"][:5], row["scores"][:5]), 1):
                slot = labeled.setdefault(exemplar_id, {"ranks": {}, "scores": {}, "random": False})
                slot["ranks"][name] = rank
                slot["scores"][name] = score
        for exemplar_id in random_rows[req_id]:
            slot = labeled.setdefault(exemplar_id, {"ranks": {}, "scores": {}, "random": True})
            slot["random"] = True
            for name in ("cos", "bm25", "dense"):
                row = lists[name][req_id]
                if exemplar_id in row["exemplar_ids"]:
                    slot["scores"][name] = row["scores"][row["exemplar_ids"].index(exemplar_id)]
        for exemplar_id in sorted(labeled):
            pool_lines.append(json.dumps(
                _sol_pool_row(req_id, exemplar_id, labeled[exemplar_id], by_id, requirements, solc, random=labeled[exemplar_id]["random"])
            ))
    (RETRIEVAL / "sol" / "features.jsonl").write_text("\n".join(feature_lines) + "\n", encoding="utf-8")
    (RETRIEVAL / "sol" / "pool.jsonl").write_text("\n".join(pool_lines) + "\n", encoding="utf-8")
    print(f"pool: {len(pool_lines)} solidity requirement-exemplar pairs over {len(pool_ids)} requirements")


def _sol_pool_row(req_id, exemplar_id, slot, by_id, requirements, solc, *, random: bool) -> dict:
    item = by_id[exemplar_id]
    code = Path(item["code_path"]).read_text(encoding="utf-8", errors="replace")
    body = _noncomment_lines(code)
    pragma = _pragma(code)
    mismatch = 0
    if solc and pragma:
        mismatch = int(solc.split(".")[1] not in pragma and not pragma.startswith("^0.8") and "0.8" not in pragma)
    ranks = {name: slot["ranks"].get(name) for name in ("cos", "bm25", "dense")}
    scores = slot["scores"]
    return {
        "req_id": req_id,
        "exemplar_id": exemplar_id,
        "ranks": ranks,
        "random": random,
        "features": {
            "cos_score": scores.get("cos", 0.0),
            "bm25_score": scores.get("bm25", 0.0),
            "dense_score": scores.get("dense", 0.0),
            "n_imports": len(re.findall(r"(?m)^\s*import\s", code)),
            "pragma_mismatch": mismatch,
            "n_lines": len(body),
            "truncated": int(len(body) > 80),
            "same_category": int(item["category"] == requirements[req_id].get("domain", "")),
        },
    }


def cmd_features() -> None:
    exemplars = load_sol_exemplars()
    solc = _solc_version()
    lines = []
    for item in exemplars:
        code = Path(item["code_path"]).read_text(encoding="utf-8", errors="replace")
        body = _noncomment_lines(code)
        pragma = _pragma(code)
        mismatch = None
        if solc and pragma:
            mismatch = int(solc.split(".")[1] not in pragma and not pragma.startswith("^0.8") and "0.8" not in pragma)
        lines.append(json.dumps({
            "exemplar_id": item["id"],
            "n_imports": len(re.findall(r"(?m)^\s*import\s", code)),
            "pragma": pragma,
            "pragma_mismatch": mismatch,
            "n_lines": len(body),
            "truncated": int(len(body) > 80),
            "category": item["category"],
            "lineage": item["lineage"],
        }))
    out = RETRIEVAL / "sol" / "features.jsonl"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"features: {len(lines)} solidity exemplars (pragma_mismatch needs solc; currently {solc or 'unavailable'})")


def _normalize(text: str) -> str:
    return " ".join(re.sub(r"[^a-z0-9]+", " ", text.lower()).split())


def cmd_leakage() -> None:
    rows = solidity_seed_rows()
    protocols = sorted({
        row["source_title"] for row in rows
        if row.get("provenance") == "defillama-harvest" and row.get("source_title")
    })
    exemplars = load_sol_exemplars()
    # Organization, repository, contest, and contract file name. Intermediate
    # directories such as contracts/proxy or token/common are not source names.
    named = []
    for item in exemplars:
        parts = Path(item["source_path"]).parts
        bucket = ""
        if "sol_sources" in parts:
            bucket = parts[parts.index("sol_sources") + 1]
        attribution = _normalize(item["attribution"])
        bucket_name = _normalize(bucket.replace("_", " ").replace("-", " "))
        contract = _normalize(Path(item["code_path"]).stem)
        named.append((item["id"], attribution, bucket_name, contract))
    matches = []
    for protocol in protocols:
        needle = _normalize(protocol)
        if len(needle) < 3:
            continue
        hits = []
        for exemplar_id, attribution, bucket_name, contract in named:
            source = f" {attribution} {bucket_name} "
            if f" {needle} " in source or needle == contract:
                hits.append(exemplar_id)
        if hits:
            matches.append({"protocol": protocol, "exemplar_ids": hits[:20], "n": len(hits)})
    dest = HERE / "leakage"
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "proto_matches.jsonl").write_text(
        "\n".join(json.dumps(row) for row in matches) + ("\n" if matches else ""),
        encoding="utf-8",
    )
    print(f"A10.leak.proto = {len(matches)} (of {len(protocols)} DefiLlama protocol names)")
    print("A10.leak.dup needs the ladder A0 and A1 Solidity programs; those outputs are not in this checkout")
    _set_placeholder("A10.leak.proto", str(len(matches)))


def _set_placeholder(key: str, value: str) -> None:
    sys.path.insert(0, str(HERE))
    import forge_ecir_tools as tools
    path = HERE / "placeholders.json"
    if not path.exists():
        return
    tools.set_key(str(path), key, value)


def _solc_version() -> str:
    try:
        out = subprocess.run(["solc", "--version"], capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return ""
    match = re.search(r"Version:\s*([0-9][^\s+]*)", out.stdout + out.stderr)
    return match.group(1) if match else ""


def cmd_versions() -> None:
    import platform
    versions = {
        "python": platform.python_version(),
        "solc": _solc_version() or None,
        "foundry": _which_version("forge", "--version"),
        "openmodelica": _which_version("omc", "--version"),
        "dense": {
            "model": "BAAI/bge-base-en-v1.5",
            "revision": None,
            "note": "chosen off the shelf, not fine-tuned; revision recorded when the model is loaded",
        },
        "packages": {},
    }
    for name in ("numpy", "scipy", "pandas", "statsmodels", "sklearn", "matplotlib"):
        try:
            module = __import__(name)
            versions["packages"][name] = getattr(module, "__version__", "unknown")
        except ImportError:
            versions["packages"][name] = None
    RUNS.mkdir(parents=True, exist_ok=True)
    (RUNS / "versions.json").write_text(json.dumps(versions, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {RUNS / 'versions.json'}")
    if versions["solc"]:
        _set_placeholder("D2.solc", versions["solc"])


def _which_version(binary: str, flag: str) -> str | None:
    try:
        out = subprocess.run([binary, flag], capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return None
    text = (out.stdout or out.stderr).strip().splitlines()
    return text[0] if text else None


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    cmd = argv[0] if argv else "all"
    steps = {
        "ids": cmd_ids,
        "retrieval": cmd_retrieval,
        "features": cmd_features,
        "leakage": cmd_leakage,
        "versions": cmd_versions,
        "modelica-ids": cmd_modelica_ids,
        "modelica-retrieval": cmd_modelica_retrieval,
        "modelica-dense": cmd_modelica_dense,
        "solidity-dense": cmd_solidity_dense,
    }
    if cmd == "all":
        for name in ("ids", "retrieval", "features", "leakage", "versions"):
            steps[name]()
        return 0
    if cmd not in steps:
        print(__doc__)
        return 2
    steps[cmd]()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
