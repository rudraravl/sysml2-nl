from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
from sklearn.metrics import pairwise_distances
from transformers import AutoModel, AutoTokenizer
from tqdm import tqdm


REPO_ROOT = Path(__file__).resolve().parents[2]
DATASET_DIR = REPO_ROOT / "dataset"
MODEL_DIR = REPO_ROOT / "embed" / "models" / "qwen_dual"
PROJ_DIM = 768


def load_pairs(dataset_dir: Path) -> list[dict[str, str]]:
    manifest = dataset_dir / "index" / "manifest.jsonl"
    pairs: list[dict[str, str]] = []
    with manifest.open() as f:
        for line in f:
            if not line.strip():
                continue
            rec = json.loads(line)
            nl = (dataset_dir / rec["paths"]["text"]).read_text(encoding="utf-8").strip()
            sysml = (dataset_dir / rec["paths"]["sysml"]).read_text(encoding="utf-8").strip()
            pairs.append({"nl": nl, "sysml": sysml})
    return pairs


class LoadedEncoder:
    def __init__(self, backbone_dir: Path, proj_path: Path, device: torch.device) -> None:
        self.device = device
        self.encoder = AutoModel.from_pretrained(backbone_dir, trust_remote_code=True).to(device)
        self.tokenizer = AutoTokenizer.from_pretrained(
            backbone_dir,
            trust_remote_code=True,
            fix_mistral_regex=True,
        )

        hidden = self.encoder.config.hidden_size
        self.proj = nn.Linear(hidden, PROJ_DIM)
        state = torch.load(proj_path, map_location=device)
        self.proj.load_state_dict(state)
        self.proj.to(device)

        self.encoder.eval()
        self.proj.eval()

    def encode(self, texts: list[str], batch_size: int = 8, desc: str | None = None) -> np.ndarray:
        outputs: list[torch.Tensor] = []
        iterator = range(0, len(texts), batch_size)
        if desc:
            iterator = tqdm(iterator, desc=desc)
        for idx in iterator:
            batch = texts[idx : idx + batch_size]
            tokens = self.tokenizer(
                batch,
                padding=True,
                truncation=True,
                max_length=256,
                return_tensors="pt",
            ).to(self.device)
            with torch.no_grad():
                out = self.encoder(**tokens)
                cls = out.last_hidden_state[:, 0]
                emb = self.proj(cls)
                emb = nn.functional.normalize(emb, dim=-1)
            outputs.append(emb.cpu())
        return torch.cat(outputs, dim=0).numpy()


def evaluate() -> None:
    data = load_pairs(DATASET_DIR)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print("Using device:", device)

    nl_encoder = LoadedEncoder(
        MODEL_DIR / "nl_backbone",
        MODEL_DIR / "proj_nl.bin",
        device,
    )
    sysml_encoder = LoadedEncoder(
        MODEL_DIR / "sysml_backbone",
        MODEL_DIR / "proj_sysml.bin",
        device,
    )

    print("Encoding NL...")
    nl_emb = nl_encoder.encode([x["nl"] for x in data], desc="NL")

    print("Encoding SysML...")
    sysml_emb = sysml_encoder.encode([x["sysml"] for x in data], desc="SysML")

    print("Computing similarity...")
    sims = 1 - pairwise_distances(nl_emb, sysml_emb, metric="cosine")

    n = len(data)
    for k in [1, 5, 10]:
        hits = 0
        for i in range(n):
            topk = np.argsort(-sims[i])[:k]
            if i in topk:
                hits += 1
        print(f"Recall@{k}: {hits / n:.4f}")


if __name__ == "__main__":
    evaluate()
