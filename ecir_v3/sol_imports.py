"""Import-resolved Solidity compile check (sensitivity analysis for the A0 -> A1 import finding).

Single-file scoring (langs.compile_check, v1's scorer) gives solc only the candidate, so every
`import "@openzeppelin/..."` fails with "Source not found". solc stops at import resolution, so such a
contract is never type-checked. Dropping the import errors would therefore pass contracts whose body
is broken. This module resolves the imports instead and compiles the candidate *with* the library
sources it names:

  * Allowlisted packages only (PROFILES): OpenZeppelin contracts + contracts-upgradeable, pinned to the
    last v4 release (4.9.6) and a v5 release (5.6.1), fetched from npm by vendor/fetch.sh (integrity
    checked). Both npm (`@openzeppelin/contracts/...`) and Foundry (`openzeppelin-contracts/contracts/...`)
    spellings map to the package root.
  * Library files are added to the standard-JSON `sources` under their import names, recursively
    (relative imports resolved against the importing unit, as solc does), so no filesystem access or
    remapping is involved. Anything else - local files ("./interfaces/IERC20.sol"), misspelled or
    nonexistent library paths - stays unresolved and fails exactly as before.
  * Each profile (oz5, then oz4) is tried; the contract is valid if it compiles cleanly against either
    release. Otherwise the attempt with the fewest errors is reported (ties -> the earlier profile).
  * solc is chosen from the candidate's pragma exactly as in single-file scoring (PACE set), and errors
    in library units (e.g. a library pragma the chosen solc cannot satisfy) count against the candidate.

  python ecir_v3/sol_imports.py selftest
"""
from __future__ import annotations

import json
import os
import posixpath
import re
import subprocess
from functools import lru_cache
from pathlib import Path

VENDOR = Path(__file__).resolve().parent / "vendor"
OZ5 = os.getenv("ECIR_OZ5", "5.6.1")
OZ4 = os.getenv("ECIR_OZ4", "4.9.6")


def _profile(v: str) -> dict[str, Path]:
    c, u = VENDOR / f"openzeppelin-contracts-{v}", VENDOR / f"openzeppelin-contracts-upgradeable-{v}"
    return {"@openzeppelin/contracts/": c, "@openzeppelin/contracts-upgradeable/": u,
            "openzeppelin-contracts/contracts/": c, "openzeppelin-contracts-upgradeable/contracts/": u}


PROFILES = {"oz5": _profile(OZ5), "oz4": _profile(OZ4)}
PROFILE_VERSIONS = {"oz5": OZ5, "oz4": OZ4}

_IMPORT = re.compile(r"""\bimport\s+[^;]*?["']([^"']+)["']""")
_COMMENT = re.compile(r"//[^\n]*|/\*.*?\*/", re.S)


def imports_of(code: str) -> list[str]:
    """Import paths in source order, comments ignored."""
    return _IMPORT.findall(_COMMENT.sub(" ", code))


def _unit_name(path: str, importer: str) -> str:
    """solc's import-path -> source-unit-name rule: relative paths resolve against the importer's dir."""
    if path.startswith("./") or path.startswith("../"):
        return posixpath.normpath(posixpath.join(posixpath.dirname(importer), path))
    return path


def _lookup(name: str, profile: dict[str, Path]) -> Path | None:
    for prefix, root in profile.items():
        if name.startswith(prefix):
            f = root / name[len(prefix):]
            return f if f.is_file() else None
    return None


@lru_cache(None)
def _read(f: Path) -> str:
    return f.read_text(encoding="utf-8")


def resolve(code: str, profile: dict[str, Path], filename: str = "Candidate.sol"):
    """-> (sources for standard JSON, resolved import names of the candidate, unresolved ones)."""
    sources = {filename: code}
    todo = [filename]
    resolved, unresolved = [], []
    while todo:
        unit = todo.pop()
        for p in imports_of(sources[unit]):
            name = _unit_name(p, unit)
            if name in sources:
                continue
            f = _lookup(name, profile)
            if unit == filename:
                (resolved if f else unresolved).append(name)
            if f:
                sources[name] = _read(f)
                todo.append(name)
    return sources, resolved, unresolved


def touches_allowlist(code: str) -> bool:
    """True if any import could be resolved by some profile (else the single-file verdict stands)."""
    names = [_unit_name(p, "Candidate.sol") for p in imports_of(code)]
    return any(_lookup(n, prof) for n in names for prof in PROFILES.values())


@lru_cache(None)
def _checker():
    from langs import _restrict_solcx
    _restrict_solcx()
    from nl2solidity.compiler_interface import _get_compiler
    c = _get_compiler()
    if c is None:
        raise RuntimeError("solc unavailable")
    return c


def _solc(sources: dict, code: str, timeout: float = 120.0) -> list[dict]:
    chk = _checker()
    binary = chk._resolve_binary(chk._pragma_of(code))
    settings = {"outputSelection": {}}            # analysis only, as single-file scoring
    if chk.evm_version:
        settings["evmVersion"] = chk.evm_version
    payload = {"language": "Solidity", "sources": {k: {"content": v} for k, v in sources.items()},
               "settings": settings}
    try:
        proc = subprocess.run([binary, "--standard-json"], input=json.dumps(payload),
                              capture_output=True, text=True, timeout=timeout)
        out = json.loads(proc.stdout)
    except subprocess.TimeoutExpired:
        return [{"code": "Timeout", "message": f"solc timed out after {timeout:g}s", "file": None}]
    except Exception as exc:  # no/unparseable output
        return [{"code": "CompilerFailure", "message": str(exc), "file": None}]
    return [{"code": e.get("type"), "message": e.get("message", ""),
             "file": (e.get("sourceLocation") or {}).get("file")}
            for e in out.get("errors", []) if e.get("severity") == "error"]


def compile_resolved(code: str) -> dict:
    """{"compile_valid", "n_compiler_errors", "errors", "profile", "oz_version", "resolved_imports",
        "unresolved_imports", "lib_errors", "infra"}. profile None = nothing resolvable (single file)."""
    attempts = []
    for name, prof in PROFILES.items():
        sources, res, unres = resolve(code, prof)
        if not res:
            continue
        errs = _solc(sources, code)
        a = {"profile": name, "oz_version": PROFILE_VERSIONS[name], "resolved_imports": res,
             "unresolved_imports": unres, "errors": errs}
        attempts.append(a)
        if not errs:
            break
    if not attempts:
        sources, _, unres = resolve(code, {})
        attempts.append({"profile": None, "oz_version": None, "resolved_imports": [],
                         "unresolved_imports": unres, "errors": _solc(sources, code)})
    best = min(attempts, key=lambda a: len(a["errors"]))     # min() keeps the first of equals
    errs = best["errors"]
    infra = "solc unavailable or timed out" if any(e["code"] in ("Timeout", "CompilerFailure") for e in errs) else None
    return {**best, "compile_valid": not errs, "n_compiler_errors": len(errs),
            "lib_errors": sum(1 for e in errs if e["file"] not in (None, "Candidate.sol")),
            "profiles_tried": [a["profile"] for a in attempts], "infra": infra}


# ---------------------------------------------------------------- controls
_V5 = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
contract Vault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    constructor(IERC20 t) Ownable(msg.sender) { token = t; }
    function pull(uint256 a) external nonReentrant onlyOwner { token.safeTransfer(msg.sender, a); }
}
"""
_V4 = _V5.replace("utils/ReentrancyGuard.sol", "security/ReentrancyGuard.sol").replace(" Ownable(msg.sender)", "")
CONTROLS = {   # name: (code, expected valid, expected profile)
    "oz5 contract": (_V5, True, "oz5"),
    "oz4 contract": (_V4, True, "oz4"),
    "broken body behind an import": (_V5.replace("token.safeTransfer(msg.sender, a);",
                                                 "token.safeTransfer(msg.sender, a); undefinedThing();"), False, "oz5"),
    "local import stays unresolved": (_V5.replace("@openzeppelin/contracts/token/ERC20/IERC20.sol",
                                                  "./interfaces/IERC20.sol"), False, None),
    "nonexistent library path": (_V5.replace("access/Ownable.sol", "access/OwnableUpgradeable.sol"), False, None),
    "v4 and v5 paths mixed": (_V5.replace("utils/ReentrancyGuard.sol", "security/ReentrancyGuard.sol"), False, None),
    "no imports": ("// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\ncontract T {}\n", True, None),
}


def selftest() -> bool:
    for f in (VENDOR / f"openzeppelin-contracts-{v}" / "package.json" for v in PROFILE_VERSIONS.values()):
        if not f.exists():
            raise SystemExit(f"missing {f.parent}; run ecir_v3/vendor/fetch.sh")
    ok = True
    for name, (code, valid, prof) in CONTROLS.items():
        r = compile_resolved(code)
        good = r["compile_valid"] == valid and (prof is None or r["profile"] == prof)
        ok &= good
        print(f"{'ok ' if good else 'BAD'} {name}: valid={r['compile_valid']} profile={r['profile']} "
              f"errors={[e['message'][:70] for e in r['errors']][:2]}")
    print("SELFTEST", "OK" if ok else "FAILED")
    return ok


if __name__ == "__main__":
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import common  # noqa: F401  (puts the repo root on sys.path)
    if sys.argv[1:] != ["selftest"]:
        raise SystemExit(__doc__)
    raise SystemExit(0 if selftest() else 1)
