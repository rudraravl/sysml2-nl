# Solidity-NL Dataset Data Card

**Purpose:** Retrieval corpus and joint-embedding resource for Solidity ↔ natural
language alignment. It grounds the `nl2solidity` generation pipeline with real,
production-grade contract examples, and mirrors the SysML v2 data card in
`dataset/DATACARD.md` so results across the two languages stay comparable.

**Collection:** 1,500 human-authored Solidity contracts drawn from three tiers —
curated reference libraries and protocols, public audit-contest codebases, and
Etherscan-verified mainnet deployments — each paired with a generated
natural-language functional description.

**Structure:** Single unified dataset without train/val/test splits. Each sample
contains:
- `{id}.sol` — Solidity source, byte-identical to upstream
- `{id}.txt` — natural language description of what the contract does
- `meta.json` — split, quality tier, domain, difficulty, license, and provenance

**Quality Assurance:**
- Test, mock, script, and tooling files excluded; interface-only files dropped
- Near-duplicate contracts removed by comment-stripped, whitespace-normalized hashing
- Per-repository caps and stride sampling to prevent single-protocol dominance
- UTF-8 validation, SHA256 checksum integrity, and JSON schema compliance
- Descriptions shorter than 150 characters rejected and regenerated

**Quality Tiers:** A+ (curated reference implementations, 698), A (audited
protocols, 593), B (verified on-chain sources, 209). See `labels.quality_tier`.

**Validation:** `python nl2solidity/dataset/scripts/validate_manifest.py`.

**Known Limitations:**
- Descriptions are LLM-generated and unreviewed by hand; they can miss or soften edge-case behavior, and they occasionally name functions where a purely functional summary was requested.
- Contracts are stored as single files without their imports, so a sample is not necessarily compilable in isolation.
- The `verified` split is Etherscan-verified source of unknown provenance and quality; it may contain buggy, abandoned, or intentionally malicious contracts and is included to represent real-world deployment style, not as an example of good practice.
- Audit-contest samples are the *pre-audit* code and may contain the very vulnerabilities the contest was run to find.
- Domain labels are heuristic, not hand-verified; `utility` is a catch-all.
- Coverage skews toward EVM DeFi and token standards, matching the source ecosystems.

**Licensing:** Descriptions, metadata, and scripts are CC-BY-4.0. Each `.sol`
retains its upstream license (MIT, AGPL-3.0, LGPL-3.0, GPL-2.0-or-later, BUSL-1.1,
or unknown for verified sources), recorded per sample. See `LICENSE`.
