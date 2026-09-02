# Solidity ↔ Natural Language Alignment Dataset

Paired Solidity sources (`.sol`) and natural-language descriptions (`.txt`) with
metadata and a canonical manifest index. It is the retrieval corpus for the
Solidity generation pipeline (`nl2solidity/agent_rag_moe.py`), and mirrors the
SysML v2 corpus in `dataset/` file-for-file so the two pipelines share tooling.

**Total: 1,500 samples** from curated reference implementations, audit-contest
protocols, and Etherscan-verified on-chain contracts.

### Dataset Composition
- **698 samples** from curated reference repositories (OpenZeppelin, Solady, Solmate, Uniswap v3/v4, Safe, Aave v3) — quality **A+**
- **593 samples** from public audit-contest protocols (Code4rena, Sherlock, Cyfrin CodeHawks) — quality **A**
- **209 samples** from Smart Contract Sanctuary, real-world verified mainnet contracts (Ethereum, Arbitrum, Optimism, Polygon) — quality **B**
- Average 237.3 Solidity lines and 140.0 description tokens per sample

## Dataset Curation

Every sample is a real, human-authored contract; nothing here is model-generated
Solidity. Only the natural-language side is synthesized. Selection is
deterministic (`scripts/select_samples.py`), so re-running it against the same
checkouts reproduces the same ids.

### Solidity Selection

For each source repository the collector walks all `.sol` files and keeps a
contract when it:
- is **not** a test, mock, script, or tooling artifact (`test/`, `mocks/`, `script/`, `certora/`, `echidna/`, `*.t.sol`, `*.s.sol` are excluded),
- is between 600 B and 60 KB, large enough to describe and small enough to embed,
- declares at least one `contract` or `library` (pure interface files are dropped),
- is not a near-duplicate: contracts are hashed after stripping comments and collapsing whitespace, so the same implementation vendored into several repositories is kept once.

Audit-contest repositories are capped at 45 samples each and sampled with an even
stride over the sorted file list, which keeps large protocols (Silo, Fluid,
Chainlink) from dominating the corpus while preserving directory diversity.
Verified on-chain sources are restricted to the 3 KB–35 KB band, which skips both
stub proxies and the megabyte-scale flattened deployments.

### Natural Language Generation

`scripts/gen_nl.py` produces the `.txt` side with `google/gemini-2.5-flash` via
OpenRouter (mirroring `script/gen_NL_SysML_v2_Models.py` on the SysML side). The
prompt asks for a 120–220 word functional requirement — purpose, state, callable
operations, access control, events, notable mechanics — written the way someone
would brief a developer, with instructions not to describe file layout or invent
unimplemented behavior. The generator is resumable and retries with backoff;
responses under 150 characters are rejected and regenerated.

### Labels

- `category` / `labels.domain`: one of 14 domains, assigned by keyword scoring over the file path and declared contract names, falling back to the body only when a single domain clearly dominates. Distribution: utility (365) | lending (158) | token (148) | math (140) | proxy (128) | dex (108) | nft (74) | wallet (72) | security (64) | staking (62) | crypto (56) | governance (51) | oracle (51) | bridge (23).
- `labels.difficulty`: by contract length — beginner < 80 lines (507), intermediate < 260 (533), advanced (460).
- `quality` / `labels.quality_tier`: **A+** curated reference, **A** audited protocol, **B** verified on-chain.

## Data Sources

| ids | n | split | source | license |
|---|---|---|---|---|
| `000001 - 000191` | 191 | reference | [OpenZeppelin/openzeppelin-contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) | MIT |
| `000192 - 000323` | 132 | reference | [Vectorized/solady](https://github.com/Vectorized/solady) | MIT |
| `000324 - 000341` | 18 | reference | [transmissions11/solmate](https://github.com/transmissions11/solmate) | AGPL-3.0 |
| `000342 - 000359` | 18 | reference | [Uniswap/v3-core](https://github.com/Uniswap/v3-core) | BUSL-1.1 |
| `000360 - 000388` | 29 | reference | [Uniswap/v3-periphery](https://github.com/Uniswap/v3-periphery) | GPL-2.0-or-later |
| `000389 - 000421` | 33 | reference | [Uniswap/v4-core](https://github.com/Uniswap/v4-core) | MIT |
| `000422 - 000467` | 46 | reference | [Uniswap/v4-periphery](https://github.com/Uniswap/v4-periphery) | MIT |
| `000468 - 000511` | 44 | reference | [safe-global/safe-smart-account](https://github.com/safe-global/safe-smart-account) | LGPL-3.0 |
| `000512 - 000581` | 70 | reference | [aave/aave-v3-core](https://github.com/aave/aave-v3-core) | BUSL-1.1 |
| `000582 - 000698` | 117 | reference | [aave-dao/aave-v3-origin](https://github.com/aave-dao/aave-v3-origin) | BUSL-1.1 |
| `000699` | 1 | audit | [Cyfrin CodeHawks: Cyfrin/4-puppy-raffle-audit](https://github.com/Cyfrin/4-puppy-raffle-audit) | MIT |
| `000700 - 000703` | 4 | audit | [Cyfrin CodeHawks: Cyfrin/6-thunder-loan-audit](https://github.com/Cyfrin/6-thunder-loan-audit) | MIT |
| `000704 - 000706` | 3 | audit | [Cyfrin CodeHawks: Cyfrin/7-boss-bridge-audit](https://github.com/Cyfrin/7-boss-bridge-audit) | MIT |
| `000707 - 000749` | 43 | audit | [Cyfrin CodeHawks: Cyfrin/advanced-defi-2024](https://github.com/Cyfrin/advanced-defi-2024) | MIT |
| `000750 - 000794` | 45 | audit | [Cyfrin CodeHawks: Cyfrin/defi-gmx-v2](https://github.com/Cyfrin/defi-gmx-v2) | MIT |
| `000795 - 000811` | 17 | audit | [Cyfrin CodeHawks: Cyfrin/sc-exploits-minimized](https://github.com/Cyfrin/sc-exploits-minimized) | MIT |
| `000812 - 000856` | 45 | audit | [Code4rena: code-423n4/2022-10-traderjoe](https://github.com/code-423n4/2022-10-traderjoe) | MIT |
| `000857 - 000890` | 34 | audit | [Code4rena: code-423n4/2022-11-stakehouse](https://github.com/code-423n4/2022-11-stakehouse) | MIT |
| `000891 - 000935` | 45 | audit | [Code4rena: code-423n4/2023-07-chainlink](https://github.com/code-423n4/2023-07-chainlink) | MIT |
| `000936 - 000961` | 26 | audit | [Code4rena: code-423n4/2023-07-moonwell](https://github.com/code-423n4/2023-07-moonwell) | MIT |
| `000962 - 001006` | 45 | audit | [Code4rena: code-423n4/2024-02-wise-lending](https://github.com/code-423n4/2024-02-wise-lending) | MIT |
| `001007 - 001036` | 30 | audit | [Code4rena: code-423n4/2024-03-abracadabra-money](https://github.com/code-423n4/2024-03-abracadabra-money) | MIT |
| `001037 - 001043` | 7 | audit | [Code4rena: code-423n4/2024-03-coinbase](https://github.com/code-423n4/2024-03-coinbase) | MIT |
| `001044 - 001072` | 29 | audit | [Code4rena: code-423n4/2024-07-loopfi](https://github.com/code-423n4/2024-07-loopfi) | MIT |
| `001073 - 001117` | 45 | audit | [Code4rena: code-423n4/2025-03-silo-finance](https://github.com/code-423n4/2025-03-silo-finance) | MIT |
| `001118 - 001143` | 26 | audit | [Code4rena: code-423n4/2025-12-panoptic](https://github.com/code-423n4/2025-12-panoptic) | MIT |
| `001144 - 001188` | 45 | audit | [Sherlock: sherlock-audit/2024-06-new-scope](https://github.com/sherlock-audit/2024-06-new-scope) | MIT |
| `001189 - 001206` | 18 | audit | [Sherlock: sherlock-audit/2024-08-flayer](https://github.com/sherlock-audit/2024-08-flayer) | MIT |
| `001207 - 001225` | 19 | audit | [Sherlock: sherlock-audit/2024-08-sentiment-v2](https://github.com/sherlock-audit/2024-08-sentiment-v2) | MIT |
| `001226 - 001233` | 8 | audit | [Sherlock: sherlock-audit/2024-09-predict-fun](https://github.com/sherlock-audit/2024-09-predict-fun) | MIT |
| `001234 - 001278` | 45 | audit | [Sherlock: sherlock-audit/2026-01-fluid-dex-v2](https://github.com/sherlock-audit/2026-01-fluid-dex-v2) | MIT |
| `001279 - 001291` | 13 | audit | [Sherlock: sherlock-audit/2026-07-tare](https://github.com/sherlock-audit/2026-07-tare) | MIT |
| `001292 - 001500` | 209 | verified | [Smart Contract Sanctuary (Etherscan-verified sources)](https://github.com/tintinweb/smart-contract-sanctuary) | unknown |

Sources were shallow-cloned into `tmp/sol_sources/`; the exact commit for each is
recorded per sample in `meta.json` under `source.version`.

## Layout
- `data/<id>/` holds triplets: `<id>.sol`, `<id>.txt`, `meta.json`
- `index/manifest.jsonl` is the canonical index (one JSON per line)
- `index/checksums.tsv` contains SHA256 checksums for integrity
- `index/stats.json` contains dataset statistics and summary information
- `schema/` has the JSON Schema for manifest validation
- `scripts/` contains the curation utilities

## Metadata Structure

```json
{
  "id": "000342",
  "source_path": "tmp/sol_sources/Uniswap_v3-core/contracts/NoDelegateCall.sol",
  "split": "reference|audit|verified",
  "quality": "A+|A|B",
  "category": "dex",
  "created": "2026-08-31T17:08:09.423619",
  "labels": { "domain": "dex", "difficulty": "beginner", "quality_tier": "A+" },
  "license": "BUSL-1.1",
  "source": {
    "provenance": "https://github.com/Uniswap/v3-core",
    "attribution": "Uniswap/v3-core",
    "version": "<commit sha>",
    "timestamp": ""
  }
}
```

## Retrieval Use

`nl2solidity/agent_rag_moe.py` loads this corpus in `_collect_examples()` and
ranks pairs against the incoming requirement, injecting the top matches into the
RAG context block alongside Solidity spec chunks from `nl2solidity/spec_index/`.
No configuration is needed — the agent picks the corpus up from this path.

## Quick start
- Rebuild the corpus from `tmp/sol_sources/`: `python scripts/select_samples.py`
- Generate any missing descriptions: `python scripts/gen_nl.py` (needs `OPENROUTER_API_KEY`)
- Rebuild the manifest and checksums: `python scripts/build_manifest.py`
- Validate the dataset: `python scripts/validate_manifest.py`

## Licensing

Descriptions, metadata, and scripts are CC-BY-4.0. Each `.sol` file keeps its
upstream license, recorded per sample. See `LICENSE`.
