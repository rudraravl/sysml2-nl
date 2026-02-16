from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModel, AutoTokenizer

from retrieval_eval import eval_bidirectional_recalls_by_source, format_paper_row, load_records


MODELS: list[dict[str, object]] = [
    {"id": "Qwen/Qwen2.5-1.5B", "tag": "qwen25_1p5b", "trust_remote_code": True},
    {"id": "Qwen/Qwen2.5-Coder-1.5B", "tag": "qwen25_coder_1p5b", "trust_remote_code": True},
    {"id": "meta-llama/Llama-3.2-3B", "tag": "llama32_3b", "trust_remote_code": False},
    {"id": "bigcode/starcoder2-3b", "tag": "starcoder2_3b", "trust_remote_code": False},
]


def mean_pool(last_hidden: torch.Tensor, mask: torch.Tensor) -> torch.Tensor:
    mask = mask.unsqueeze(-1).to(dtype=last_hidden.dtype)
    summed = (last_hidden * mask).sum(dim=1)
    counts = mask.sum(dim=1).clamp(min=1e-6)
    return summed / counts


@torch.inference_mode()
def encode(
    model,
    tokenizer,
    texts: list[str],
    *,
    device: torch.device,
    batch_size: int,
    max_len: int,
) -> np.ndarray:
    embs: list[torch.Tensor] = []
    for i in range(0, len(texts), batch_size):
        batch = texts[i : i + batch_size]
        tok = tokenizer(
            batch,
            padding=True,
            truncation=True,
            max_length=max_len,
            return_tensors="pt",
        )
        tok = {k: v.to(device) for k, v in tok.items()}
        out = model(input_ids=tok["input_ids"], attention_mask=tok["attention_mask"])
        pooled = mean_pool(out.last_hidden_state, tok["attention_mask"])
        pooled = torch.nn.functional.normalize(pooled, dim=-1)
        embs.append(pooled.to(dtype=torch.float32).detach().cpu())
    return torch.cat(embs, dim=0).numpy()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--batch-size", type=int, default=4)
    ap.add_argument("--max-len", type=int, default=256)
    ap.add_argument("--model", type=str, default="all", help="Run a single model tag, or 'all'.")
    args = ap.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    dataset_dir = repo_root / "dataset"
    out_dir = Path(__file__).resolve().parent

    records = load_records(dataset_dir)
    nl_texts = [r.nl for r in records]
    sysml_texts = [r.sysml for r in records]
    splits = [r.split for r in records]

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print("Using device:", device)

    for spec in MODELS:
        tag = str(spec["tag"])
        if args.model != "all" and args.model != tag:
            continue

        model_id = str(spec["id"])
        trust_remote_code = bool(spec.get("trust_remote_code", False))

        print(f"\n=== {model_id} (D) ===")
        try:
            print("Loading tokenizer...")
            tok = AutoTokenizer.from_pretrained(model_id, trust_remote_code=trust_remote_code)
            tok.padding_side = "right"

            dtype = torch.bfloat16 if device.type == "cuda" else torch.float32
            print("Loading model...")
            model = AutoModel.from_pretrained(
                model_id,
                dtype=dtype,
                trust_remote_code=trust_remote_code,
            ).to(device)
            model.eval()
        except Exception as e:
            print(f"Skipping {model_id}: {e}")
            continue

        print("Encoding NL...")
        nl_emb = encode(
            model,
            tok,
            nl_texts,
            device=device,
            batch_size=args.batch_size,
            max_len=args.max_len,
        )

        print("Encoding SysML...")
        sysml_emb = encode(
            model,
            tok,
            sysml_texts,
            device=device,
            batch_size=args.batch_size,
            max_len=args.max_len,
        )

        sims = (nl_emb @ sysml_emb.T).astype(np.float32, copy=False)
        by_k = eval_bidirectional_recalls_by_source(sims, splits, ks=(1, 5, 10))

        for k, scores in by_k.items():
            print(f"R@{k} (All): {scores['All']:.4f}")
            if k == 5:
                print("Paper row (R@5):", format_paper_row(model_id, "D", scores))

        log_path = out_dir / f"log_run_baseline_{tag}.txt"
        with log_path.open("w", encoding="utf-8") as f:
            f.write(f"{datetime.utcnow().isoformat()}Z\n")
            f.write(f"Model: {model_id}\n")
            f.write("Class: D\n")
            for k in [1, 5, 10]:
                scores = by_k[k]
                f.write(f"R@{k} Off/Com/Pilot/ESA/Agent/All (%): ")
                f.write(
                    ", ".join(
                        [f"{col}={100.0 * scores[col]:.1f}" for col in ["Off", "Com", "Pilot", "ESA", "Agent", "All"]]
                    )
                    + "\n"
                )
            f.write("Paper row (R@5): " + format_paper_row(model_id, "D", by_k[5]) + "\n")


if __name__ == "__main__":
    main()
