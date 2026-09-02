#!/usr/bin/env python3
# sol_seed_generator.py
"""Harvest smart-contract seed prompts from the DefiLlama protocol catalog.

Solidity counterpart of nl2sysml/nl_generator.py. Where the SysML harvester
walks Wikipedia categories for device/system titles, this one walks the public
DefiLlama protocol index for real on-chain protocols, maps each DefiLlama
category to a contract domain, and template-fills a short, high-level prompt.

Prompts are intentionally shallow and deterministic, matching the SysML seed
style so the two pipelines stay methodologically comparable.

Writes nl2solidity/sol_seed.jsonl (+ .csv), preserving any hand-written seeds
already in the file.
"""
import csv
import json
import os
import re
import time
import zlib
from pathlib import Path

import requests

LLAMA_API = "https://api.llama.fi/protocols"
_DEFAULT_UA = "sol2nl-seed-harvester/0.1 (+https://github.com/; contact: set LLAMA_USER_AGENT)"

SESSION = requests.Session()
SESSION.headers.update({
    "User-Agent": os.getenv("LLAMA_USER_AGENT", _DEFAULT_UA),
    "Accept": "application/json",
})

HERE = Path(__file__).resolve().parent
TARGET_TOTAL = 1500

# ---- 1) Configure sources (DefiLlama category -> contract domain) ----
CATEGORY_DOMAINS = {
    "dex": ["Dexs", "DEX Aggregator", "Liquidity Manager", "Liquidity Automation",
            "OTC Marketplace", "MEV", "Volume Boosting"],
    "lending": ["Lending", "CDP", "NFT Lending", "RWA Lending", "Uncollateralized Lending",
                "CDP Manager", "Collateral Management", "Collateral Markets",
                "Secondary Debt Markets", "Liquidations", "Leveraged Farming"],
    "yield": ["Yield", "Yield Aggregator", "Farm", "Options Vault", "Basis Trading",
              "NFT Automated Strategies", "DCA Tools", "Gamified Mining",
              "ve-Incentive Automator"],
    "staking": ["Liquid Staking", "Staking Pool", "Restaking", "Liquid Restaking",
                "Restaked BTC", "Anchor BTC", "Staking Rental", "Mining Pools"],
    "derivatives": ["Derivatives", "Options", "Synthetics", "Interest Rate Derivatives",
                    "Exotic Options"],
    "bridge": ["Bridge", "Canonical Bridge", "Cross Chain Bridge", "Bridge Aggregator",
               "Bridge Aggregators", "Decentralized BTC"],
    "stablecoin": ["Algo-Stables", "Reserve Currency", "Dual-Token Stablecoin",
                   "Partially Algorithmic Stablecoin", "Stablecoin Issuer",
                   "Stablecoin Wrapper"],
    "nft": ["NFT Marketplace", "NftFi", "Domains", "NFT Launchpad", "Physical TCG"],
    "prediction": ["Prediction Market", "Luck Games", "Yield Lottery"],
    "governance": ["Governance Incentives", "Onchain Capital Allocator", "Treasury Manager",
                   "Chain Bribes", "DOR"],
    "rwa": ["RWA"],
    "insurance": ["Insurance"],
    "payments": ["Payments", "Charity Fundraising", "Crypto Card Issuer"],
    "privacy": ["Privacy"],
    "launchpad": ["Launchpad", "Private Investment Platform"],
    "gaming": ["Gaming"],
    "token": ["Indexes", "SoFi", "Meme"],
    "oracle": ["Oracle"],
    "wallet": ["Wallets", "Identity & Reputation"],
    "security": ["Security Extension", "Token Locker"],
}
# Categories deliberately dropped: exchanges, front-ends, chains, trackers, bots,
# tooling and off-chain services, none of which describe a contract to generate.
CATEGORY_TO_DOMAIN = {cat: dom for dom, cats in CATEGORY_DOMAINS.items() for cat in cats}


# ---- 2) Helpers ----
def llama_api(url, retries: int = 5):
    """Call the DefiLlama API with retries and a friendly User-Agent."""
    backoff = 1.0
    last_err = None
    for _ in range(retries):
        try:
            r = SESSION.get(url, timeout=60)
            if r.status_code in (403, 429, 502, 503, 504):
                last_err = requests.HTTPError(f"HTTP {r.status_code}")
                time.sleep(backoff)
                backoff = min(backoff * 2, 16)
                continue
            r.raise_for_status()
            return r.json()
        except requests.RequestException as e:
            last_err = e
            time.sleep(backoff)
            backoff = min(backoff * 2, 16)
            continue
    if last_err:
        raise last_err
    raise RuntimeError("llama_api failed without an exception")


# Protocols whose real source is in the RAG corpus (nl2solidity/dataset). A seed
# naming one of these would let retrieval hand the generator the very
# implementation it is being asked to write, so they are excluded outright.
# Matching is whole-word, so Superfluid, SafePal and Aavegotchi are NOT excluded -
# they are distinct protocols that merely share a substring.
CORPUS_PROTOCOLS = [
    "uniswap", "aave", "safe", "solady", "solmate", "openzeppelin", "silo", "fluid",
    "panoptic", "moonwell", "abracadabra", "traderjoe", "chainlink", "sentiment",
    "flayer", "predict fun", "wise lending", "stakehouse", "loopfi", "gmx",
    "thunder loan", "puppy raffle", "tare", "coinbase",
]


def collides_with_corpus(title: str) -> str | None:
    """The corpus protocol this title names, if any (whole-word match)."""
    tk = set(re.findall(r"[a-z0-9]+", title.lower()))
    for p in CORPUS_PROTOCOLS:
        if set(re.findall(r"[a-z0-9]+", p)) <= tk:
            return p
    return None


TITLE_BAD_WORDS = re.compile(r"\b(test|demo|deprecated|old|fork|clone|copy|scam|fake)\b", re.I)
PARENS = re.compile(r"\s*\(.*?\)")
VERSION_SUFFIX = re.compile(r"\s+(v|V)\s?\d+(\.\d+)?$")

# "Describe" is deliberately absent: the template already ends in "describe its
# ...", and pairing the two reads redundantly.
VERB_ROTATION = {
    "generic": ["Design", "Model", "Define", "Specify", "Create", "Outline"],
}
ASPECT_ROTATION = ["core mechanism", "primary function", "main flows", "core behavior"]

DOMAIN_NOUNS = {
    "dex": "decentralized exchange contract",
    "lending": "lending protocol",
    "yield": "yield strategy contract",
    "staking": "staking contract",
    "derivatives": "derivatives contract",
    "bridge": "cross-chain bridge contract",
    "stablecoin": "stablecoin contract",
    "nft": "NFT contract",
    "prediction": "prediction market contract",
    "governance": "governance contract",
    "rwa": "real-world asset tokenization contract",
    "insurance": "on-chain insurance contract",
    "payments": "payments contract",
    "privacy": "privacy-preserving contract",
    "launchpad": "token launchpad contract",
    "gaming": "on-chain game contract",
    "token": "token contract",
    "oracle": "price oracle contract",
    "wallet": "smart account contract",
    "security": "token locking contract",
}


def stable_hash(s: str) -> int:
    """Deterministic across runs, unlike the built-in hash()."""
    return zlib.crc32(s.encode("utf-8"))


def clean_title(t):
    t = PARENS.sub("", t or "").strip()
    t = re.sub(r"^(The|A|An)\s+", "", t, flags=re.I)
    return t.strip(" -_.")


def dedupe_key(title):
    """Collapse 'Aave V2' / 'Aave V3' / 'aave' onto one protocol."""
    t = VERSION_SUFFIX.sub("", title).lower()
    return re.sub(r"[^a-z0-9]", "", t)


def looks_like_protocol(title):
    if not title or TITLE_BAD_WORDS.search(title):
        return False
    if "," in title or len(title) > 40 or len(title) < 3:
        return False
    if not re.search(r"[A-Za-z]{3}", title):
        return False
    # reject bare tickers / addresses
    if re.fullmatch(r"[A-Z0-9]{2,6}", title):
        return False
    return True


def article(noun):
    return "an" if noun[0].lower() in "aeiou" or noun.startswith("NFT") else "a"


def to_prompt(title, domain):
    """Very high-level, one sentence, no specifics - mirrors the SysML seeds."""
    verbs = VERB_ROTATION.get(domain, VERB_ROTATION["generic"])
    h = stable_hash(title)
    verb = verbs[h % len(verbs)]
    noun = DOMAIN_NOUNS.get(domain, "smart contract")
    aspect = ASPECT_ROTATION[(h // 7) % len(ASPECT_ROTATION)]
    return f"{verb} {article(noun)} {noun} based on {title} and describe its {aspect} at a high level."


def allocate(available: dict, target: int) -> dict:
    """Water-fill a per-domain cap so no single domain floods the seed set."""
    lo, hi = 0, max(available.values(), default=0)
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if sum(min(n, mid) for n in available.values()) <= target:
            lo = mid
        else:
            hi = mid - 1
    caps = {d: min(n, lo) for d, n in available.items()}
    # hand the rounding remainder to the largest domains
    leftover = target - sum(caps.values())
    for d in sorted(available, key=lambda d: -available[d]):
        if leftover <= 0:
            break
        room = available[d] - caps[d]
        take = min(room, leftover)
        caps[d] += take
        leftover -= take
    return caps


# ---- 3) Harvest ----
def harvest(target_total=TARGET_TOTAL, reserved=0):
    protocols = llama_api(LLAMA_API)
    print(f"Fetched {len(protocols)} protocols from DefiLlama")

    # highest-TVL first, so the sample favours real, recognizable protocols
    protocols.sort(key=lambda p: p.get("tvl") or 0, reverse=True)

    rows, seen = [], set()
    for p in protocols:
        domain = CATEGORY_TO_DOMAIN.get(p.get("category"))
        if not domain or not (p.get("description") or "").strip():
            continue
        title = clean_title(p.get("name"))
        if not looks_like_protocol(title) or collides_with_corpus(title):
            continue
        key = dedupe_key(title)
        if key in seen:
            continue
        seen.add(key)
        rows.append({"title": title, "domain": domain, "category": p["category"],
                     "source_description": " ".join((p.get("description") or "").split())})

    by_domain = {}
    for r in rows:
        by_domain.setdefault(r["domain"], []).append(r)
    caps = allocate({d: len(v) for d, v in by_domain.items()}, target_total - reserved)
    print("per-domain quota:", dict(sorted(caps.items(), key=lambda x: -x[1])))

    selected = []
    for d, items in by_domain.items():
        selected.extend(items[:caps[d]])

    out = []
    for r in selected:
        desc = re.sub(r"\s+", " ", to_prompt(r["title"], r["domain"])).strip()
        if 10 <= len(desc.split()) <= 28:
            out.append({
                "description": desc,
                "source_title": r["title"],
                "domain": r["domain"],
                "provenance": "defillama-harvest",
                # external grounding for enrich_seeds.py; never from the RAG corpus
                "source_description": r["source_description"],
            })
    return out


def load_existing(path: Path):
    """Keep hand-written seeds (and their U### ids) already in the file."""
    if not path.exists():
        return []
    kept = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        rec = json.loads(line)
        if rec.get("provenance") != "defillama-harvest":
            kept.append(rec)
    return kept


if __name__ == "__main__":
    seed_path = HERE / "sol_seed.jsonl"
    existing = load_existing(seed_path)
    print(f"Preserving {len(existing)} hand-written seed(s)")

    data = harvest(TARGET_TOTAL, reserved=len(existing))
    data = sorted(data, key=lambda x: stable_hash(x["source_title"]))

    # Ids are stable across re-harvests: a protocol keeps the id it already had, and
    # retired ids are never recycled, so generated output under nl2solidity/dataset/
    # with_kernel_spec/U### keeps pointing at the seed it was produced from.
    prior = {}
    retired = set()
    for line in (seed_path.read_text(encoding="utf-8").splitlines() if seed_path.exists() else []):
        if line.strip():
            rec = json.loads(line)
            prior[rec.get("source_title")] = rec["id"]
            retired.add(rec["id"])
    used = {r["id"] for r in existing} | retired
    n = 1
    for r in data:
        keep = prior.get(r["source_title"])
        if keep:
            r["id"] = keep
            continue
        while f"U{n}" in used:
            n += 1
        r["id"] = f"U{n}"
        used.add(r["id"])
    field_order = ["id", "description", "source_title", "domain", "provenance",
                   "source_description"]
    data = [{k: r[k] for k in field_order if k in r} for r in data]
    allrows = existing + data

    with open(seed_path, "w", encoding="utf-8") as f:
        for r in allrows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    with open(HERE / "sol_seed.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["id", "description", "domain", "source_title", "provenance"])
        for r in allrows:
            w.writerow([r["id"], r["description"], r.get("domain", ""),
                        r.get("source_title", ""), r.get("provenance", "")])
    print(f"Wrote {len(allrows)} items to sol_seed.jsonl and sol_seed.csv")
