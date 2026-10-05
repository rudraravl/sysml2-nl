"""The three first-stage retrievers (binary cosine, BM25 + lineage diversity, dense) and pool features.

cos   = the deployed SysML v2 / Solidity scorer: binary cosine of token sets between the
        requirement and each exemplar description (nl2sysml/nl2solidity agent_rag_moe._similarity),
        stable sort so ties go to the lower exemplar ID, score > 0 only.
bm25  = nl2robotics.retrieval.DiverseBM25 over description + category + tags, at most one
        exemplar per semantic case and per source lineage. Modelica keeps the deployed
        family routing (4 of 5 from the family's categories, ExampleCorpus.retrieve); the
        other languages have no family routes and use plain diverse BM25.
dense = an off-the-shelf text-embedding model (D9), cosine over exemplar descriptions.
"""
from __future__ import annotations

import json
import os
import re
from functools import lru_cache

import numpy as np

from common import RETR
from corpora import Requirement, exemplars, mod_corpus

DENSE_MODEL = os.getenv("ECIR_DENSE_MODEL", "BAAI/bge-base-en-v1.5")
DENSE_QUERY_PREFIX = "Represent this sentence for searching relevant passages: "  # bge s2p instruction
TOPN = 10
RETRIEVER_NAMES = ("cos", "bm25", "dense")


# ---------------------------------------------------------------- binary cosine
def _tok(s: str) -> set[str]:
    return {t for t in re.split(r"[^A-Za-z0-9_]+", s.lower()) if t}


@lru_cache(None)
def _ex_tok(lang):
    return [_tok(e.desc) for e in exemplars(lang)]


def cos_scores(lang: str, query: str) -> np.ndarray:
    q = _tok(query)
    out = np.zeros(len(exemplars(lang)))
    if not q:
        return out
    for i, t in enumerate(_ex_tok(lang)):
        if t:
            out[i] = len(q & t) / (len(q) ** 0.5 * len(t) ** 0.5)
    return out


def cos_rank(lang: str, query: str, n: int = TOPN) -> list[tuple[int, float]]:
    s = cos_scores(lang, query)
    # Python's stable sort on (-score) == agent_rag_moe's sorted(..., reverse=True) on score
    order = sorted(range(len(s)), key=lambda i: -s[i])
    return [(i, float(s[i])) for i in order[:n] if s[i] > 0]


# ---------------------------------------------------------------- BM25 + diversity
@lru_cache(None)
def _bm25(lang):
    from nl2robotics.retrieval import DiverseBM25, RetrievalDocument
    if lang == "mod":
        return mod_corpus()._index
    return DiverseBM25([RetrievalDocument(e.bm25_text, e.semantic, e.lineage, e.category)
                        for e in exemplars(lang)])


def bm25_scores(lang: str, query: str) -> np.ndarray:
    from collections import Counter
    from nl2robotics.retrieval import tokens
    idx = _bm25(lang)
    q = Counter(tokens(query))
    return np.array([idx._score(q, d) for d in idx._tokens])


def bm25_rank(lang: str, req: Requirement, n: int = TOPN) -> list[tuple[int, float]]:
    if lang != "mod":
        return [(i, float(s)) for i, s in _bm25(lang).rank(req.text, k=n)]
    # Modelica: the first five are exactly the deployed list (ExampleCorpus.retrieve, k=5);
    # ranks 6..10 continue with the k=10 routed list, skipping exemplars already listed.
    corpus = mod_corpus()
    pos = {e.id: i for i, e in enumerate(corpus.examples)}
    route = tuple(req.meta.get("route", ()))
    top5 = corpus.retrieve(req.text, k=5, preferred_categories=route)
    out = [(pos[e.id], float(s)) for e, s in top5]
    seen = {i for i, _ in out}
    for e, s in corpus.retrieve(req.text, k=n, preferred_categories=route):
        if len(out) >= n:
            break
        if pos[e.id] not in seen:
            out.append((pos[e.id], float(s)))
            seen.add(pos[e.id])
    return out


# ---------------------------------------------------------------- dense
@lru_cache(None)
def _dense_model():
    from sentence_transformers import SentenceTransformer
    return SentenceTransformer(DENSE_MODEL, device="cpu")


def dense_info() -> dict:
    m = _dense_model()
    rev = None
    try:
        from huggingface_hub import model_info
        rev = model_info(DENSE_MODEL).sha
    except Exception:
        pass
    return {"name": DENSE_MODEL, "revision": rev, "query_prefix": DENSE_QUERY_PREFIX,
            "max_seq_length": m.max_seq_length, "normalize": True}


@lru_cache(None)
def _dense_ex(lang):
    cache = RETR / lang / f"dense_exemplars.{DENSE_MODEL.replace('/', '__')}.npy"
    if cache.exists():
        return np.load(cache)
    v = _dense_model().encode([e.desc for e in exemplars(lang)], batch_size=32,
                              normalize_embeddings=True, show_progress_bar=True)
    cache.parent.mkdir(parents=True, exist_ok=True)
    np.save(cache, v)
    return v


def dense_query_vecs(texts: list[str]) -> np.ndarray:
    return _dense_model().encode([DENSE_QUERY_PREFIX + t for t in texts], batch_size=16,
                                 normalize_embeddings=True, show_progress_bar=True)


def dense_scores_from_vec(lang: str, qv: np.ndarray) -> np.ndarray:
    return _dense_ex(lang) @ qv


def dense_rank_from_vec(lang: str, qv: np.ndarray, n: int = TOPN) -> list[tuple[int, float]]:
    s = dense_scores_from_vec(lang, qv)
    order = sorted(range(len(s)), key=lambda i: -s[i])
    return [(i, float(s[i])) for i in order[:n]]


# ---------------------------------------------------------------- SysML spec chunks (deployed scorer)
@lru_cache(None)
def _spec_chunks():
    from common import REPO
    rows = []
    for l in (REPO / "nl2sysml/spec_index/chunks.jsonl").read_text(encoding="utf-8").splitlines():
        try:
            rows.append(json.loads(l))
        except Exception:
            continue
    return rows


def spec_rank(query: str, n: int = 3) -> list[tuple[str, float]]:
    """nl2sysml.agent_rag_moe._rag_context's spec scorer, returning chunk IDs."""
    q = _tok(query)
    kws = {t for t in re.split(r"[^A-Za-z0-9_]+", query.lower()) if t and len(t) >= 4}
    hits = []
    for rec in _spec_chunks():
        txt, title = rec.get("text", ""), rec.get("title", "")
        t = _tok(txt)
        if not q or not t:
            continue
        base = len(q & t) / (len(q) ** 0.5 * len(t) ** 0.5)
        if base <= 0:
            continue
        low = txt.lower()
        bonus = min(sum(1 for k in kws if k in low) * 0.01, 0.08)
        tb = 0.05 if ("Textual Notation" in title or "Kernel_Modeling_Language" in title) else 0.0
        hits.append((rec, base + bonus + tb))
    hits.sort(key=lambda x: x[1], reverse=True)
    return [(r["id"], float(s)) for r, s in hits[:n]]


def spec_chunk(cid: str) -> dict:
    return next(r for r in _spec_chunks() if r["id"] == cid)


def spec_ids() -> list[str]:
    return [r["id"] for r in _spec_chunks()]


# ---------------------------------------------------------------- exemplar features
D2_SOLC = os.getenv("ECIR_D2_SOLC", "0.8.28")   # overwritten by stage0's D2 result when present


def _code_lines(code: str) -> list[str]:
    return [l for l in code.splitlines() if l.strip() and not l.strip().startswith("//")]


def _pragma_mismatch(code: str, version: str) -> int:
    m = re.search(r"pragma\s+solidity\s+([^;]+);", code)
    if not m:
        return 0
    from packaging.version import Version
    from solcx.install import select_pragma_version
    try:
        return int(select_pragma_version(m.group(1), [Version(version)]) is None)
    except Exception:
        return 1


@lru_cache(None)
def exemplar_static(lang: str, d2: str = D2_SOLC) -> dict[str, dict]:
    out = {}
    for e in exemplars(lang):
        lines = _code_lines(e.code)
        imports = sum(1 for l in lines if re.match(r"\s*((public|private)\s+)?import\b", l))
        trunc = len(e.code.splitlines()) > 100 if lang == "mod" else len(lines) > 80
        out[e.id] = {"n_imports": imports, "n_lines": len(lines), "truncated": int(trunc),
                     "pragma_mismatch": _pragma_mismatch(e.code, d2) if lang == "sol" else 0}
    return out


def pair_features(lang: str, req: Requirement, ex_ids: list[str], scores: dict[str, np.ndarray],
                  d2: str = D2_SOLC) -> dict[str, dict]:
    """Features for (req, exemplar) pairs; scores = {"cos": arr, "bm25": arr, "dense": arr} over the corpus."""
    pos = {e.id: i for i, e in enumerate(exemplars(lang))}
    ex = {e.id: e for e in exemplars(lang)}
    st = exemplar_static(lang, d2)
    route = set(req.meta.get("route", ()))
    out = {}
    for x in ex_ids:
        i = pos[x]
        f = {f"{k}_score": (round(float(v[i]), 6) if v is not None else None) for k, v in scores.items()}
        f.update(st[x])
        f["same_category"] = int(ex[x].category in route) if lang == "mod" else None
        out[x] = f
    return out
