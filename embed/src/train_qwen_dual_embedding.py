from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List

import torch
import torch.nn as nn
from torch.utils.data import DataLoader, Dataset
from transformers import AutoModel, AutoTokenizer
from tqdm import tqdm


class SysMLNLDataset(Dataset):
    """Dataset that yields NL/SysML text pairs from the manifest."""

    def __init__(self, dataset_dir: Path) -> None:
        self.dataset_dir = dataset_dir
        self.records: List[Dict] = []
        manifest = dataset_dir / "index" / "manifest.jsonl"
        with manifest.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                rec = json.loads(line)
                self.records.append(rec)

    def __len__(self) -> int:
        return len(self.records)

    def __getitem__(self, idx: int) -> Dict[str, str]:
        rec = self.records[idx]
        nl = (self.dataset_dir / rec["paths"]["text"]).read_text(encoding="utf-8").strip()
        sysml = (self.dataset_dir / rec["paths"]["sysml"]).read_text(encoding="utf-8").strip()
        return {"nl": nl, "sysml": sysml}


class Collator:
    def __init__(self, tok_nl, tok_sys, max_len: int = 256) -> None:
        self.tok_nl = tok_nl
        self.tok_sys = tok_sys
        self.max_len = max_len

    def __call__(self, batch: List[Dict[str, str]]) -> Dict[str, torch.Tensor]:
        nl_texts = [b["nl"] for b in batch]
        sysml_texts = [b["sysml"] for b in batch]

        nl_tok = self.tok_nl(
            nl_texts,
            padding=True,
            truncation=True,
            max_length=self.max_len,
            return_tensors="pt",
        )
        sysml_tok = self.tok_sys(
            sysml_texts,
            padding=True,
            truncation=True,
            max_length=self.max_len,
            return_tensors="pt",
        )

        return {
            "nl_input_ids": nl_tok["input_ids"],
            "nl_attention_mask": nl_tok["attention_mask"],
            "sysml_input_ids": sysml_tok["input_ids"],
            "sysml_attention_mask": sysml_tok["attention_mask"],
        }


def mean_pool(hidden: torch.Tensor, mask: torch.Tensor) -> torch.Tensor:
    mask = mask.unsqueeze(-1).float()
    summed = (hidden * mask).sum(dim=1)
    counts = mask.sum(dim=1).clamp(min=1e-6)
    return summed / counts


class QwenDualEncoder(nn.Module):
    """Frozen Qwen backbones with trainable projection heads."""

    def __init__(
        self,
        nl_model_name: str,
        sysml_model_name: str,
        proj_dim: int = 768,
        freeze_backbones: bool = True,
    ) -> None:
        super().__init__()

        print(f"Loading NL backbone: {nl_model_name}")
        self.nl_encoder = AutoModel.from_pretrained(nl_model_name, trust_remote_code=True)

        print(f"Loading SysML backbone: {sysml_model_name}")
        self.sysml_encoder = AutoModel.from_pretrained(sysml_model_name, trust_remote_code=True)

        hidden_nl = self.nl_encoder.config.hidden_size
        hidden_sysml = self.sysml_encoder.config.hidden_size

        self.proj_nl = nn.Linear(hidden_nl, proj_dim)
        self.proj_sysml = nn.Linear(hidden_sysml, proj_dim)

        if freeze_backbones:
            print("Freezing Qwen backbones...")
            for p in self.nl_encoder.parameters():
                p.requires_grad = False
            for p in self.sysml_encoder.parameters():
                p.requires_grad = False

    def encode_nl(self, ids: torch.Tensor, mask: torch.Tensor) -> torch.Tensor:
        out = self.nl_encoder(input_ids=ids, attention_mask=mask)
        pooled = mean_pool(out.last_hidden_state, mask)
        emb = self.proj_nl(pooled)
        return nn.functional.normalize(emb, dim=-1)

    def encode_sysml(self, ids: torch.Tensor, mask: torch.Tensor) -> torch.Tensor:
        out = self.sysml_encoder(input_ids=ids, attention_mask=mask)
        pooled = mean_pool(out.last_hidden_state, mask)
        emb = self.proj_sysml(pooled)
        return nn.functional.normalize(emb, dim=-1)

    def forward(self, batch: Dict[str, torch.Tensor]) -> tuple[torch.Tensor, torch.Tensor]:
        nl_vec = self.encode_nl(batch["nl_input_ids"], batch["nl_attention_mask"])
        sysml_vec = self.encode_sysml(batch["sysml_input_ids"], batch["sysml_attention_mask"])
        return nl_vec, sysml_vec


def info_nce(nl_vec: torch.Tensor, sysml_vec: torch.Tensor, temperature: float = 0.05) -> torch.Tensor:
    sims = nl_vec @ sysml_vec.t() / temperature
    labels = torch.arange(sims.size(0), device=sims.device)
    loss1 = nn.CrossEntropyLoss()(sims, labels)
    loss2 = nn.CrossEntropyLoss()(sims.t(), labels)
    return (loss1 + loss2) / 2


def main() -> None:
    repo_root = Path(__file__).resolve().parents[2]
    dataset_dir = repo_root / "dataset"
    save_dir = repo_root / "embed" / "models" / "qwen_dual"
    save_dir.mkdir(parents=True, exist_ok=True)

    nl_model = "Qwen/Qwen2.5-1.5B"
    sysml_model = "Qwen/Qwen2.5-Coder-1.5B"
    batch_size = 8
    proj_dim = 768
    epochs = 1
    freeze_backbones = True

    print("Loading dataset...")
    ds = SysMLNLDataset(dataset_dir)

    tok_nl = AutoTokenizer.from_pretrained(
        nl_model,
        trust_remote_code=True,
        fix_mistral_regex=True,
    )
    tok_sys = AutoTokenizer.from_pretrained(
        sysml_model,
        trust_remote_code=True,
        fix_mistral_regex=True,
    )

    use_cuda = torch.cuda.is_available()
    loader = DataLoader(
        ds,
        batch_size=batch_size,
        shuffle=True,
        collate_fn=Collator(tok_nl, tok_sys),
        num_workers=4 if use_cuda else 0,
        pin_memory=use_cuda,
    )

    device = torch.device("cuda" if use_cuda else "cpu")
    print("Using device:", device)

    model = QwenDualEncoder(nl_model, sysml_model, proj_dim, freeze_backbones).to(device)

    optimizer = torch.optim.AdamW(
        list(model.proj_nl.parameters()) + list(model.proj_sysml.parameters()),
        lr=5e-4,
    )

    model.train()
    for epoch in range(epochs):
        print(f"===== Epoch {epoch + 1}/{epochs} =====")
        pbar = tqdm(loader)
        for batch in pbar:
            for key in batch:
                batch[key] = batch[key].to(device, non_blocking=use_cuda)

            nl_vec, sysml_vec = model(batch)
            loss = info_nce(nl_vec, sysml_vec)

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            pbar.set_postfix({"loss": f"{loss.item():.4f}"})

    print("Saving NL encoder...")
    nl_save = save_dir / "nl_backbone"
    model.nl_encoder.save_pretrained(nl_save)
    tok_nl.save_pretrained(nl_save)
    torch.save(model.proj_nl.state_dict(), save_dir / "proj_nl.bin")

    print("Saving SysML encoder...")
    sysml_save = save_dir / "sysml_backbone"
    model.sysml_encoder.save_pretrained(sysml_save)
    tok_sys.save_pretrained(sysml_save)
    torch.save(model.proj_sysml.state_dict(), save_dir / "proj_sysml.bin")

    print("Done.")


if __name__ == "__main__":
    main()
