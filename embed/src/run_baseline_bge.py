from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

import numpy as np
from sentence_transformers import SentenceTransformer
from sklearn.metrics import pairwise_distances
from tqdm import tqdm


def load_pairs(dataset_dir: Path) -> list[dict[str, str]]:
    manifest_path = dataset_dir / "index" / "manifest.jsonl"
    pairs: list[dict[str, str]] = []
    with manifest_path.open() as f:
        for line in f:
            rec = json.loads(line)
            sysml_path = dataset_dir / rec["paths"]["sysml"]
            nl_path = dataset_dir / rec["paths"]["text"]
            nl_text = nl_path.read_text(encoding="utf-8").strip()
            sysml_text = sysml_path.read_text(encoding="utf-8").strip()
            pairs.append({"nl": nl_text, "sysml": sysml_text})
    return pairs


def make_query(text: str) -> str:
    return f"Represent this sentence for searching relevant passages: {text}"


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parents[2]
    dataset_dir = repo_root / "dataset"

    print("Loading model...")
    model = SentenceTransformer("BAAI/bge-large-en-v1.5")

    print("Loading data...")
    data = load_pairs(dataset_dir)

    nl_texts = [x["nl"] for x in data]
    sysml_texts = [x["sysml"] for x in data]

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
    sims = 1 - pairwise_distances(nl_emb, sysml_emb, metric="cosine")

    print("Evaluating recall@K ...")
    recalls: list[tuple[int, float]] = []
    for k in [1, 5, 10]:
        hits = 0
        for i in tqdm(range(len(data)), desc=f"Recall@{k}"):
            topk = np.argsort(-sims[i])[:k]
            if i in topk:
                hits += 1
        score = hits / len(data)
        recalls.append((k, score))
        print(f"Recall@{k}: {score:.4f}")

    log_path = Path(__file__).resolve().parent / "log_run_baseline_bge.txt"
    with log_path.open("w", encoding="utf-8") as f:
        f.write(f"{datetime.utcnow().isoformat()}Z\n")
        for k, score in recalls:
            f.write(f"Recall@{k}: {score:.4f}\n")
        f.write("\n")
