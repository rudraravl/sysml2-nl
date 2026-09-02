#!/usr/bin/env python3
"""Select the Solidity RAG corpus from cloned sources into dataset/data/<id>/.

Sources live under tmp/sol_sources (see README "Data Sources"). Selection is
deterministic: given the same checkouts it always produces the same ids.
"""
from __future__ import annotations

import hashlib
import json
import re
import subprocess
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "tmp" / "sol_sources"
DATA = Path(__file__).resolve().parents[1] / "data"

TARGET_TOTAL = 1500
AUDIT_CAP = 45

# repo dir -> (split, quality, provenance url, license)
REFERENCE = {
    "OpenZeppelin_openzeppelin-contracts": ("https://github.com/OpenZeppelin/openzeppelin-contracts", "MIT"),
    "Vectorized_solady": ("https://github.com/Vectorized/solady", "MIT"),
    "transmissions11_solmate": ("https://github.com/transmissions11/solmate", "AGPL-3.0"),
    "Uniswap_v3-core": ("https://github.com/Uniswap/v3-core", "BUSL-1.1"),
    "Uniswap_v3-periphery": ("https://github.com/Uniswap/v3-periphery", "GPL-2.0-or-later"),
    "Uniswap_v4-core": ("https://github.com/Uniswap/v4-core", "MIT"),
    "Uniswap_v4-periphery": ("https://github.com/Uniswap/v4-periphery", "MIT"),
    "safe-global_safe-smart-account": ("https://github.com/safe-global/safe-smart-account", "LGPL-3.0"),
    "aave_aave-v3-core": ("https://github.com/aave/aave-v3-core", "BUSL-1.1"),
    "aave-dao_aave-v3-origin": ("https://github.com/aave-dao/aave-v3-origin", "BUSL-1.1"),
}
AUDIT_ORGS = {"code-423n4": "Code4rena", "sherlock-audit": "Sherlock", "Cyfrin": "Cyfrin CodeHawks"}

EXCLUDE_DIR = re.compile(
    r"/(test|tests|mocks?|node_modules|script|scripts|out|cache|certora|echidna|halmos|fuzz|invariant|docs)/", re.I
)

# domain -> (name/path pattern, body pattern). The name/path signal is weighted
# higher because it is the most reliable indicator of what a contract is for.
DOMAIN_RULES = [
    ("bridge",     r"bridge|crosschain|cross_chain|ccip|layerzero|portal|relayer|messenger"),
    ("nft",        r"erc721|erc1155|nft|collectible|seaport|royalt|tokenuri"),
    ("proxy",      r"proxy|upgradeab|beacon|clone|initializable|erc1967|diamond|implementation"),
    ("crypto",     r"ecdsa|merkle|signature|eip712|secp256|poseidon|schnorr|\bzk\b|verifier"),
    ("math",       r"math|fixedpoint|\bsqrt\b|bitmap|wadray|percentage|\bq64\b|\bq96\b|\btick\b"),
    ("oracle",     r"oracle|pricefeed|price_feed|aggregator|\btwap\b|chainlink"),
    ("wallet",     r"multisig|multi_sig|\bsafe\b|smartaccount|smart_account|wallet|guardian|erc4337|entrypoint|paymaster|module manager|fallbackhandler"),
    ("governance", r"govern|voting|\bvote\b|timelock|proposal|\bdao\b|quorum"),
    ("lending",    r"lend|borrow|\bdebt\b|collateral|liquidat|flashloan|flash_loan|interestrate|atoken|vtoken|silo|reserve"),
    ("dex",        r"swap|\bpool\b|\bpair\b|router|\bamm\b|liquidity|orderbook|\bhook\b|quoter|position manager"),
    ("staking",    r"stak|reward|farm|vesting|emission|\bgauge\b|incentive|masterchef"),
    ("token",      r"erc20|erc4626|\btoken\b|\bmint\b|totalsupply|\bvault\b|\bshares?\b"),
    ("security",   r"reentran|pausable|ownable|accesscontrol|\brole\b|guard|blacklist|rescue|delegatecall|nodelegate"),
]


def classify(rel_path: str, code: str) -> str:
    """Pick a domain from the file/contract name, falling back to the body.

    A name hit is decisive; otherwise a domain has to dominate the body counts
    to beat "utility", which keeps generic libraries out of the DeFi buckets.
    """
    names = " ".join(re.findall(r"\b(?:contract|library|abstract\s+contract)\s+(\w+)", code))
    head = (rel_path + " " + names).lower()
    body = code.lower()
    # ties break toward the earlier (more specific) rule
    best_domain, best_hits = None, 0
    for d, pat in DOMAIN_RULES:
        n = len(re.findall(pat, head))
        if n > best_hits:
            best_domain, best_hits = d, n
    if best_domain:
        return best_domain
    body_hits = sorted(((len(re.findall(pat, body)), -i) for i, (d, pat) in enumerate(DOMAIN_RULES)), reverse=True)
    if body_hits[0][0] >= 8 and body_hits[0][0] >= 2 * body_hits[1][0]:
        return DOMAIN_RULES[-body_hits[0][1]][0]
    return "utility"


def difficulty(nlines: int) -> str:
    if nlines < 80:
        return "beginner"
    if nlines < 260:
        return "intermediate"
    return "advanced"


def commit_of(repo_dir: Path) -> str:
    try:
        return subprocess.run(
            ["git", "-C", str(repo_dir), "rev-parse", "HEAD"],
            capture_output=True, text=True, timeout=30,
        ).stdout.strip()
    except Exception:
        return ""


def candidates(repo_dir: Path):
    """Yield (rel_path, source_path, code) for usable contracts in one repo."""
    out = []
    for p in sorted(repo_dir.rglob("*.sol")):
        rel = "/" + str(p.relative_to(repo_dir))
        if EXCLUDE_DIR.search(rel) or p.name.endswith((".t.sol", ".s.sol")):
            continue
        try:
            code = p.read_text(encoding="utf-8")
        except Exception:
            continue
        if not (600 <= len(code) <= 60000):
            continue
        body = re.sub(r"//.*|/\*[\s\S]*?\*/", "", code)
        if not re.search(r"\b(contract|library)\s+\w+", body):
            continue
        out.append((rel, str(p.relative_to(ROOT)), code))
    return out


def stride(items, k):
    """Deterministic even-spread subsample preserving directory diversity."""
    if len(items) <= k:
        return items
    step = len(items) / k
    return [items[int(i * step)] for i in range(k)]


def main():
    seen: set[str] = set()
    picked: list[dict] = []

    def add(entries, split, quality, provenance, license_id, attribution, commit, cap=None):
        rows = []
        for rel, src, code in entries:
            body = re.sub(r"//.*|/\*[\s\S]*?\*/", "", code)
            h = hashlib.sha256(re.sub(r"\s+", " ", body).encode()).hexdigest()
            if h in seen:
                continue
            seen.add(h)
            rows.append((rel, src, code))
        if cap:
            rows = stride(rows, cap)
        for rel, src, code in rows:
            picked.append({
                "code": code, "split": split, "quality": quality,
                "source_path": src, "provenance": provenance, "license": license_id,
                "attribution": attribution, "commit": commit,
                "category": classify(rel, code),
            })

    # 1) curated reference implementations
    for name, (url, lic) in REFERENCE.items():
        d = SRC / name
        if not d.exists():
            print(f"missing reference repo: {name}")
            continue
        add(candidates(d), "reference", "A+", url, lic, name.replace("_", "/"), commit_of(d))
    n_ref = len(picked)

    # 2) audit-contest protocols
    audit_dirs = sorted(
        p for p in SRC.iterdir()
        if p.is_dir() and p.name.split("_")[0] in AUDIT_ORGS and p.name not in REFERENCE
    )
    for d in audit_dirs:
        org = d.name.split("_")[0]
        repo = d.name.replace("_", "/", 1)
        add(candidates(d), "audit", "A", f"https://github.com/{repo}",
            "MIT", f"{AUDIT_ORGS[org]}: {repo}", commit_of(d), cap=AUDIT_CAP)
    n_audit = len(picked) - n_ref

    # 3) real-world verified contracts (Smart Contract Sanctuary)
    sanct = SRC / "sanctuary"
    if sanct.exists():
        rows = []
        for p in sorted(sanct.glob("*.sol")):
            try:
                code = p.read_text(encoding="utf-8")
            except Exception:
                continue
            if not (600 <= len(code) <= 60000):
                continue
            chain, fname = p.name.split("__", 1)
            rows.append((f"/{chain}/{fname}", f"tmp/sol_sources/sanctuary/{p.name}", code))
        remaining = max(0, TARGET_TOTAL - len(picked))
        add(rows, "verified", "B",
            "https://github.com/tintinweb/smart-contract-sanctuary",
            "unknown", "Smart Contract Sanctuary (Etherscan-verified sources)", "",
            cap=remaining)
    n_verified = len(picked) - n_ref - n_audit

    picked = picked[:TARGET_TOTAL]
    now = datetime.now().isoformat()
    DATA.mkdir(parents=True, exist_ok=True)
    for i, rec in enumerate(picked, 1):
        did = f"{i:06d}"
        out = DATA / did
        out.mkdir(parents=True, exist_ok=True)
        (out / f"{did}.sol").write_text(rec["code"], encoding="utf-8")
        nlines = rec["code"].count("\n") + 1
        meta = {
            "id": did,
            "source_path": rec["source_path"],
            "split": rec["split"],
            "quality": rec["quality"],
            "category": rec["category"],
            "created": now,
            "labels": {
                "domain": rec["category"],
                "difficulty": difficulty(nlines),
                "quality_tier": rec["quality"],
            },
            "license": rec["license"],
            "source": {
                "provenance": rec["provenance"],
                "attribution": rec["attribution"],
                "version": rec["commit"],
                "timestamp": "",
            },
        }
        (out / "meta.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(picked)} samples -> reference={n_ref} audit={n_audit} verified={n_verified}")


if __name__ == "__main__":
    main()
