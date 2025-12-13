from __future__ import annotations

import importlib
import json
from datetime import datetime
from pathlib import Path

import numpy as np
import torch
from sentence_transformers import SentenceTransformer
from tqdm import tqdm


MODEL_ID = "Qwen/Qwen3-Embedding-8B"


def load_pairs(dataset_dir: Path) -> list[dict[str, str]]:
    """Load NL/SysML pairs following the dataset manifest."""
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


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parents[2]
    dataset_dir = repo_root / "dataset"

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print("Using device:", device)

    dtype = torch.bfloat16 if torch.cuda.is_available() else torch.float32
    model_kwargs: dict[str, object] = {"dtype": dtype}
    if torch.cuda.is_available():
        has_flash_attn = bool(
            importlib.util.find_spec("flash_attn") or importlib.util.find_spec("flash_attn_2")
        )
        if has_flash_attn:
            model_kwargs["attn_implementation"] = "flash_attention_2"
        else:
            print("flash_attn not installed; using default attention.")

    print(f"Loading model {MODEL_ID} ...")
    model = SentenceTransformer(
        MODEL_ID,
        trust_remote_code=True,
        device=device,
        model_kwargs=model_kwargs,
    )
    model.max_seq_length = 512

    print("Loading data...")
    data = load_pairs(dataset_dir)

    nl_texts = [x["nl"] for x in data]
    sysml_texts = [x["sysml"] for x in data]

    print("Encoding NL queries...")
    nl_emb = model.encode_query(
        nl_texts,
        batch_size=8,
        convert_to_tensor=True,
        normalize_embeddings=True,
        show_progress_bar=True,
    )

    print("Encoding SysML documents...")
    sysml_emb = model.encode_document(
        sysml_texts,
        batch_size=8,
        convert_to_tensor=True,
        normalize_embeddings=True,
        show_progress_bar=True,
    )

    print("Computing similarity matrix...")
    sims = model.similarity(nl_emb.float(), sysml_emb.float()).cpu().numpy()

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

    log_path = Path(__file__).resolve().parent / "log_run_baseline_qwen3_embed.txt"
    with log_path.open("w", encoding="utf-8") as f:
        f.write(f"{datetime.utcnow().isoformat()}Z\n")
        for k, score in recalls:
            f.write(f"Recall@{k}: {score:.4f}\n")
        f.write("\n")
