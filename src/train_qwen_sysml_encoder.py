from __future__ import annotations

import json
from pathlib import Path

import torch
import torch.nn as nn
from transformers import AutoModel, AutoTokenizer
from tqdm import tqdm


SYSML_MODEL_NAME = "Qwen/Qwen2.5-Coder-1.5B"
PROJ_DIM = 768
REPO_ROOT = Path(__file__).resolve().parents[1]
SAVE_DIR = REPO_ROOT / "models" / "sysml_encoder"
DATASET_DIR = REPO_ROOT / "dataset"


def load_pairs(dataset_dir: Path) -> list[str]:
    manifest = dataset_dir / "index" / "manifest.jsonl"
    texts: list[str] = []
    with manifest.open() as f:
        for line in f:
            rec = json.loads(line)
            sysml_path = dataset_dir / rec["paths"]["sysml"]
            texts.append(sysml_path.read_text(encoding="utf-8").strip())
    return texts


class SysMLProjectionModel(nn.Module):
    def __init__(self, base_model_name: str, proj_dim: int) -> None:
        super().__init__()
        print(f"Loading Qwen SysML encoder: {base_model_name}")
        self.tokenizer = AutoTokenizer.from_pretrained(base_model_name, trust_remote_code=True)
        self.encoder = AutoModel.from_pretrained(base_model_name, trust_remote_code=True)

        for p in self.encoder.parameters():
            p.requires_grad = False

        hidden_size = self.encoder.config.hidden_size
        self.proj = nn.Linear(hidden_size, proj_dim)

    def forward(self, texts: list[str]) -> torch.Tensor:
        tokens = self.tokenizer(
            texts,
            padding=True,
            truncation=True,
            max_length=256,
            return_tensors="pt",
        ).to(next(self.encoder.parameters()).device)

        out = self.encoder(**tokens)
        cls = out.last_hidden_state[:, 0]
        emb = self.proj(cls)
        emb = nn.functional.normalize(emb, dim=-1)
        return emb


def train() -> None:
    SAVE_DIR.mkdir(parents=True, exist_ok=True)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    data = load_pairs(DATASET_DIR)

    model = SysMLProjectionModel(SYSML_MODEL_NAME, PROJ_DIM).to(device)
    optimizer = torch.optim.AdamW(model.proj.parameters(), lr=5e-4)

    print(f"Training projection head on {len(data)} SysML samples...")
    batch_size = 16
    model.train()

    for _ in range(1):
        pbar = tqdm(range(0, len(data), batch_size))
        for idx in pbar:
            batch = data[idx : idx + batch_size]
            emb = model(batch)
            target = torch.zeros_like(emb)
            loss = ((emb - target) ** 2).mean()

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            pbar.set_postfix({"loss": loss.item()})

    print(f"Saving SysML projection model to {SAVE_DIR}...")
    model.encoder.save_pretrained(SAVE_DIR)
    model.tokenizer.save_pretrained(SAVE_DIR)
    torch.save(model.proj.state_dict(), SAVE_DIR / "proj.bin")


if __name__ == "__main__":
    train()
