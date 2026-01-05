from __future__ import annotations
from datetime import datetime
from pathlib import Path

import numpy as np
from sentence_transformers import SentenceTransformer
from retrieval_eval import eval_bidirectional_recalls_by_source, format_paper_row, load_records


MODEL_ID = "BAAI/bge-large-en-v1.5"
MODEL_CLASS = "E"  # encoder-only


def make_query(text: str) -> str:
    return f"Represent this sentence for searching relevant passages: {text}"


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parents[2]
    dataset_dir = repo_root / "dataset"

    print("Loading model...")
    model = SentenceTransformer(MODEL_ID)

    print("Loading data...")
    records = load_records(dataset_dir)
    nl_texts = [r.nl for r in records]
    sysml_texts = [r.sysml for r in records]
    splits = [r.split for r in records]

    nl_queries = [make_query(t) for t in nl_texts]

    print("Encoding NL queries...")
    nl_emb = model.encode(
        nl_queries,
        normalize_embeddings=True,
        batch_size=64,
        show_progress_bar=True,
    )

    print("Encoding SysML docs...")
    sysml_emb = model.encode(
        sysml_texts,
        normalize_embeddings=True,
        batch_size=64,
        show_progress_bar=True,
    )

    print("Computing similarity matrix...")
    sims = (nl_emb @ sysml_emb.T).astype(np.float32, copy=False)

    print("Evaluating recall@K (avg over both directions) ...")
    by_k = eval_bidirectional_recalls_by_source(sims, splits, ks=(1, 5, 10))
    for k, scores in by_k.items():
        print(f"R@{k} (All): {scores['All']:.4f}")
        if k == 5:
            print("Paper row (R@5):", format_paper_row(MODEL_ID, MODEL_CLASS, scores))

    log_path = Path(__file__).resolve().parent / "log_run_baseline_bge.txt"
    with log_path.open("w", encoding="utf-8") as f:
        f.write(f"{datetime.utcnow().isoformat()}Z\n")
        f.write(f"Model: {MODEL_ID}\n")
        f.write(f"Class: {MODEL_CLASS}\n")
        for k in [1, 5, 10]:
            scores = by_k[k]
            f.write(f"R@{k} Off/Com/Pilot/ESA/Agent/All (%): ")
            f.write(
                ", ".join(
                    [f"{col}={100.0 * scores[col]:.1f}" for col in ["Off", "Com", "Pilot", "ESA", "Agent", "All"]]
                )
                + "\n"
            )
        f.write("Paper row (R@5): " + format_paper_row(MODEL_ID, MODEL_CLASS, by_k[5]) + "\n")
