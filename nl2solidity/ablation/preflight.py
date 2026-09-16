#!/usr/bin/env python3
"""Check that every arm about to be submitted can actually run.

A six-arm sweep is hours of queue time; a missing solc or an unreachable API key
should surface here, not on the first seed of task 1. Each arm is checked against
only what it needs - A0 does not care that Slither is missing, A5 very much does.

    python nl2solidity/ablation/preflight.py                  # all arms
    python nl2solidity/ablation/preflight.py --arms A2 A3 A4
    python nl2solidity/ablation/preflight.py --probe-api      # also call OpenRouter
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_NL2 = _HERE.parent
_ROOT = _NL2.parent
for _p in (str(_ROOT), str(_NL2), str(_HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import profiles  # noqa: E402

OK, WARN, FAIL = "ok", "warn", "FAIL"


def _check_api_key() -> tuple[str, str]:
    try:
        from dotenv import load_dotenv
        load_dotenv(_ROOT / ".env")
    except ImportError:
        return WARN, "python-dotenv missing; relying on the exported environment"
    if os.getenv("OPENROUTER_API_KEY"):
        return OK, "OPENROUTER_API_KEY set"
    return FAIL, f"OPENROUTER_API_KEY missing (put it in {_ROOT / '.env'}, chmod 600)"


def _check_solc() -> tuple[str, str]:
    try:
        from nl2solidity.compiler_interface import compiler_version, is_compiler_available
    except ImportError:
        from compiler_interface import compiler_version, is_compiler_available  # type: ignore
    if not is_compiler_available():
        return FAIL, "solc unreachable — run nl2solidity/pace/prestage.sh on a login node"
    return OK, f"solc {compiler_version() or 'available'}"


def _check_forge() -> tuple[str, str]:
    forge = shutil.which("forge")
    if not forge:
        return FAIL, "forge not on PATH — prestage.sh installs it into ~/.foundry/bin"
    try:
        from nl2solidity.solidity_execution.foundry_bridge import ensure_forge_std
        return OK, f"{forge}, forge-std at {ensure_forge_std()}"
    except Exception as exc:  # noqa: BLE001 - any failure here is a real blocker
        return FAIL, f"{forge} present but forge-std unavailable: {exc}"


def _check_slither() -> tuple[str, str]:
    try:
        from nl2solidity.security_analysis import is_analysis_available
    except ImportError:
        return FAIL, "nl2solidity.security_analysis not importable"
    if not is_analysis_available():
        return FAIL, "slither not available — pip install slither-analyzer"
    return OK, "slither available"


def _check_aligner() -> tuple[str, str]:
    try:
        import spec_aligner  # noqa: F401
    except ImportError as exc:
        return FAIL, f"spec_aligner not importable: {exc}"
    return OK, "spec_aligner importable"


def _check_rag_corpus() -> tuple[str, str]:
    data_dir = _NL2 / "dataset" / "data"
    if not data_dir.is_dir():
        return FAIL, f"retrieval corpus missing: {data_dir} (rsync nl2solidity/dataset/)"
    n = sum(1 for p in data_dir.glob("*/*.sol"))
    if n == 0:
        return FAIL, f"retrieval corpus at {data_dir} has no .sol pairs"
    spec = _NL2 / "spec_index" / "chunks.jsonl"
    spec_note = "" if spec.exists() else "; spec_index/chunks.jsonl absent (examples only)"
    return OK, f"{n} exemplar pairs{spec_note}"


def _check_seeds(num_entries: int) -> tuple[str, str]:
    seed_file = _NL2 / "sol_seed.jsonl"
    if not seed_file.is_file():
        return FAIL, f"seed file missing: {seed_file}"
    n = sum(1 for line in seed_file.open(encoding="utf-8") if line.strip())
    if n < num_entries:
        return FAIL, f"{seed_file.name} has {n} seeds, ABLATION_N={num_entries} asks for more"
    return OK, f"{n} seeds available, evaluation set is the first {num_entries}"


def _probe_api() -> tuple[str, str]:
    import urllib.error
    import urllib.request
    try:
        from dotenv import load_dotenv
        load_dotenv(_ROOT / ".env")
    except ImportError:
        pass
    key = os.getenv("OPENROUTER_API_KEY")
    if not key:
        return FAIL, "no key to probe with"
    base = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
    req = urllib.request.Request(base.rstrip("/") + "/models",
                                 headers={"Authorization": f"Bearer {key}"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return OK, f"{base} reachable (HTTP {resp.status})"
    except urllib.error.HTTPError as exc:
        return FAIL, f"{base} returned HTTP {exc.code}"
    except Exception as exc:  # noqa: BLE001
        return FAIL, f"{base} unreachable: {exc} (compute nodes may need HTTPS_PROXY)"


# Stage flag -> (label, checker). An arm is only checked for stages it enables.
#
# solc is deliberately NOT here: it is a shared requirement. Even an arm with
# compiler repair off still calls check_code() once to record compile validity,
# and that is the primary metric the whole ablation is compared on — without solc
# every arm silently produces meta.json with no "validation" block at all.
_STAGE_CHECKS = (
    ("RAG_ENABLED", "RAG corpus", _check_rag_corpus),
    ("KERNEL_FEEDBACK_ENABLED", "foundry", _check_forge),
    ("SECURITY_ANALYSIS_ENABLED", "slither", _check_slither),
    ("SPEC_ALIGNMENT_ENABLED", "spec aligner", _check_aligner),
)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--arms", nargs="*", default=profiles.ARM_IDS,
                        help=f"arms to check (default: all of {', '.join(profiles.ARM_IDS)})")
    parser.add_argument("--num-entries", type=int,
                        default=int(os.getenv("ABLATION_N", "500")))
    parser.add_argument("--no-measure-all", dest="measure_all",
                        action="store_false", default=True,
                        help="check against the cheap mode instead of the default full metric set")
    parser.add_argument("--probe-api", action="store_true",
                        help="make a real OpenRouter request; run this on a compute node")
    args = parser.parse_args(argv)

    arms = [a.strip().upper() for a in args.arms]
    unknown = [a for a in arms if a not in profiles.ARMS]
    if unknown:
        print(f"Error: unknown arm(s): {', '.join(unknown)}", file=sys.stderr)
        return 2

    shared: list[tuple[str, str, str]] = [("python", OK, sys.executable)]
    for label, check in (("api key", _check_api_key),
                         ("seeds", lambda: _check_seeds(args.num_entries)),
                         ("solc", _check_solc)):
        status, detail = check()
        shared.append((label, status, detail))
    if args.probe_api:
        status, detail = _probe_api()
        shared.append(("openrouter", status, detail))

    print("-" * 78)
    mode = "all metrics on every arm" if args.measure_all else "cheap (per-arm metrics)"
    print(f"Ablation preflight — arms: {', '.join(arms)} — mode: {mode}")
    print("-" * 78)
    worst = OK
    for label, status, detail in shared:
        print(f"  [{status:>4}] {label:<14} {detail}")
        if status == FAIL:
            worst = FAIL

    # Cache per-stage results: solc is checked by four arms, not four times.
    cache: dict[str, tuple[str, str]] = {}
    for arm_id in arms:
        arm = profiles.get(arm_id)
        env = arm.resolved_env(args.measure_all)
        needed = [(label, fn) for flag, label, fn in _STAGE_CHECKS if env[flag] == "true"]
        print(f"\n  {arm.id}  {arm.title}  ({arm.hours}h walltime)")
        if not needed:
            print("    [  ok] no extra toolchain required")
            continue
        for label, fn in needed:
            if label not in cache:
                cache[label] = fn()
            status, detail = cache[label]
            print(f"    [{status:>4}] {label:<14} {detail}")
            if status == FAIL:
                worst = FAIL

    print("-" * 78)
    if worst == FAIL:
        print("PREFLIGHT FAILED — fix the lines above before submitting.")
        return 1
    print("Preflight clear.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
