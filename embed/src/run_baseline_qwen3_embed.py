from __future__ import annotations

import importlib
from datetime import datetime
from pathlib import Path

import numpy as np
import torch
from sentence_transformers import SentenceTransformer
from retrieval_eval import eval_bidirectional_recalls_by_source, format_paper_row, load_records


MODEL_ID = "Qwen/Qwen3-Embedding-8B"
MODEL_CLASS = "E"  # embedding model baseline


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
    records = load_records(dataset_dir)
    nl_texts = [r.nl for r in records]
    sysml_texts = [r.sysml for r in records]
    splits = [r.split for r in records]

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

    print("Evaluating recall@K (avg over both directions) ...")
    by_k = eval_bidirectional_recalls_by_source(sims, splits, ks=(1, 5, 10))
    for k, scores in by_k.items():
        print(f"R@{k} (All): {scores['All']:.4f}")
        if k == 5:
            print("Paper row (R@5):", format_paper_row(MODEL_ID, MODEL_CLASS, scores))

    log_path = Path(__file__).resolve().parent / "log_run_baseline_qwen3_embed.txt"
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
