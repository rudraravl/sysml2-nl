#!/usr/bin/env python3
"""SysMLAgent's Context Engine (Cibrian et al. 2025, Sec. 3.3), reimplemented.

Database (DEVIATIONS.md D7): FORGE's retrieval pool (agent_rag_moe._collect_examples: the first 300
dataset/data samples, all disjoint from the evaluation seeds, which derive from 000387+) restricted
to the official OMG Release split, IDs 000001-000250. Each entry's natural-language description
(<ID>.txt) is what gets embedded; its <ID>.sysml is what gets inserted into the prompt.

Embeddings (D8): sentence-transformers/all-MiniLM-L6-v2 (384-d), normalized, cosine similarity,
top k = 2, ties broken by dataset ID. Database embeddings are precomputed (as in the paper) under
index/. Query embeddings are cached there too (`--precompute` fills the cache for every evaluation
and paper prompt), so generation nodes need neither torch nor the Hugging Face hub.

    python nl2sysml/sysml_agent/context_engine.py --precompute
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent.parent
DATA = _ROOT / "dataset" / "data"
INDEX = _HERE / "index"
MODEL_ID = "sentence-transformers/all-MiniLM-L6-v2"
POOL_IDS = [f"{i:06d}" for i in range(1, 251)]  # official OMG Release split
K = 2

_model = None
_pool = None
_qcache = None


def _embed(texts: list[str]) -> np.ndarray:
    global _model
    if _model is None:
        from sentence_transformers import SentenceTransformer
        _model = SentenceTransformer(MODEL_ID, device="cpu")
    return _model.encode(texts, normalize_embeddings=True, convert_to_numpy=True,
                         show_progress_bar=False).astype(np.float32)


def _key(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def pool() -> dict:
    """{ids, descs, codes, emb}; builds and caches the database embeddings on first use."""
    global _pool
    if _pool is not None:
        return _pool
    ids = [i for i in POOL_IDS if (DATA / i / f"{i}.txt").exists() and (DATA / i / f"{i}.sysml").exists()]
    descs = [(DATA / i / f"{i}.txt").read_text(encoding="utf-8").strip() for i in ids]
    codes = [(DATA / i / f"{i}.sysml").read_text(encoding="utf-8").strip() for i in ids]
    f = INDEX / "pool_emb.npy"
    meta = INDEX / "pool.json"
    sig = _key("\n\0".join(descs))
    if f.exists() and meta.exists() and json.loads(meta.read_text())["sha256"] == sig:
        emb = np.load(f)
    else:
        INDEX.mkdir(exist_ok=True)
        emb = _embed(descs)
        np.save(f, emb)
        meta.write_text(json.dumps({"model": MODEL_ID, "ids": ids, "n": len(ids), "sha256": sig},
                                   indent=1) + "\n")
    _pool = {"ids": ids, "descs": descs, "codes": codes, "emb": emb}
    return _pool


def _queries() -> dict:
    global _qcache
    if _qcache is None:
        f = INDEX / "query_emb.npz"
        _qcache = dict(np.load(f)) if f.exists() else {}
    return _qcache


def embed_query(text: str) -> np.ndarray:
    q = _queries().get(_key(text))
    return q if q is not None else _embed([text])[0]


def retrieve(text: str, k: int = K) -> list[dict]:
    """The k nearest database entries: [{id, description, code, similarity}], best first."""
    p = pool()
    sims = p["emb"] @ embed_query(text)
    order = sorted(range(len(sims)), key=lambda j: (-float(sims[j]), p["ids"][j]))[:k]
    return [{"id": p["ids"][j], "description": p["descs"][j], "code": p["codes"][j],
             "similarity": round(float(sims[j]), 6)} for j in order]


def precompute(texts: list[str]) -> int:
    """Embed and cache queries not yet cached; returns how many were added."""
    cache = _queries()
    todo = sorted({t for t in texts if _key(t) not in cache})
    if todo:
        for t, v in zip(todo, _embed(todo)):
            cache[_key(t)] = v
        INDEX.mkdir(exist_ok=True)
        np.savez_compressed(INDEX / "query_emb.npz", **cache)
    return len(todo)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--precompute", action="store_true",
                    help="cache query embeddings for every evaluation prompt and paper prompt")
    ap.add_argument("--query", help="print the top-k hits for one query")
    a = ap.parse_args()
    sys.path.insert(0, str(_HERE))
    print(f"database: {len(pool()['ids'])} entries ({MODEL_ID})")
    if a.precompute:
        import run_sysml_agent as run
        texts = [run.read_prompt(s) for s in run.eval_ids()]
        texts += [p["description"] for p in run.paper_prompts()]
        print(f"cached {precompute([t for t in texts if t])} new query embeddings")
    if a.query:
        for h in retrieve(a.query):
            print(f"{h['id']}  {h['similarity']:.4f}  {h['description'][:100]}")
