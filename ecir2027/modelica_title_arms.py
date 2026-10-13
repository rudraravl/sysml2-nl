#!/usr/bin/env python3
"""Modelica arms that separate repair from retrieval and from extra attempts.

No retrieval. One pinned route (DeepInfra fp4, GLM-5.2, temperature 0.2).
The 500 ladder requirements are the denominator. A requirement that failed
normalization in the archived ladder is not sent to the model and counts as
not compiled on every arm.

    python ecir2027/modelica_title_arms.py
    python ecir2027/modelica_title_arms.py --execute --limit 1
    python ecir2027/modelica_title_arms.py --execute --workers 6

Arms, all starting from the same first sample:
  A0   one call
  A0C  that sample, then up to two repairs that include the compiler diagnostics
  A0B  that sample, then up to two repairs whose only feedback is "Compilation failed."
  RS   up to three independent draws of the A0 prompt, kept if any compiles

A later round is skipped once an arm has compiled. Re-running continues from
the logs already on disk and does not repeat a finished call.
"""

from __future__ import annotations

import json
import os
import queue
import sys
import threading
import time
import traceback
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
sys.path.insert(0, str(REPO))

from ecir2027.generate import (  # noqa: E402
    MODEL,
    MODELICA_SYSTEM,
    PROVIDER,
    TEMPERATURE,
    call_openrouter,
    completion_text,
    load_env,
    modelica_messages,
    modelica_requests,
    read_ids,
    served_provider,
)
from nl2robotics.modelica.openmodelica import OpenModelicaRunner  # noqa: E402
from nl2robotics.modelica.pipeline import clean_code  # noqa: E402

ROOT = HERE / "runs" / "title_mod"
TAR = Path("/Users/siveshkannan/Downloads/glm52-ablation-exact-500x5-results.tar.gz")
NORMFAIL = HERE / "ids" / "normfail_mod.txt"
MAX_REPAIRS = 2
MAX_DRAWS = 3


def normfail_ids() -> set[str]:
    """Requirements the archived ladder never sent to the model."""
    if NORMFAIL.exists():
        return {line.strip() for line in NORMFAIL.read_text().splitlines() if line.strip()}
    if not TAR.exists():
        raise SystemExit(f"missing {NORMFAIL} and {TAR}")
    import tarfile
    found = []
    with tarfile.open(TAR, "r:gz") as archive:
        for member in archive:
            name = member.name
            if not name.endswith("/A0/repeat-00/run.json"):
                continue
            handle = archive.extractfile(member)
            if handle is None:
                continue
            row = json.loads(handle.read().decode("utf-8"))
            stage = ((row.get("metrics") or {}).get("failure_stage"))
            if stage == "requirement_normalization":
                found.append(row.get("task_id") or name.split("/")[-5])
    found = sorted(set(found))
    NORMFAIL.write_text("\n".join(found) + ("\n" if found else ""), encoding="utf-8")
    return set(found)


def atomic_write(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(payload) + "\n", encoding="utf-8")
    temporary.replace(path)


def load_json(path: Path) -> dict | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def compile_code(code: str, work: Path, cache: Path) -> dict:
    work.mkdir(parents=True, exist_ok=True)
    backend = os.environ.get("MODELICA_BACKEND", "docker")
    runner = OpenModelicaRunner(backend=backend, library_cache=cache, timeout=180)
    last = None
    for _ in range(3):
        build = runner.compile(code, output_dir=work)
        errors = [item.message.strip() for item in build.diagnostics if item.severity == "error" and item.message.strip()]
        infrastructure = (not build.available) or any(
            item.stage == "infrastructure" for item in build.diagnostics
        )
        last = {
            "compile_valid": bool(build.success) and not infrastructure,
            "infrastructure": infrastructure,
            "diagnostics": errors,
        }
        if not infrastructure:
            return last
        time.sleep(2)
    return last


def generate(system: str, human: str) -> dict:
    body = call_openrouter(system, human, PROVIDER)
    text = completion_text(body)
    usage = body.get("usage") or {}
    code = ""
    error = ""
    if text:
        try:
            code = clean_code(text)
        except ValueError as exc:
            error = str(exc)
    return {
        "code": code,
        "error": error,
        "tokens_in": usage.get("prompt_tokens"),
        "tokens_out": usage.get("completion_tokens"),
        "provider_served": served_provider(body),
        "system": system,
        "human": human,
    }


def repair_messages(requirement: str, code: str, diagnostics: list[str], bare: bool) -> tuple[str, str]:
    feedback = "Compilation failed." if bare else (
        "\n".join(diagnostics).strip() or "OpenModelica did not return a diagnostic."
    )
    human = (
        "Generate one complete Modelica model for this requirement:\n"
        f"{requirement.strip()}\n\n"
        "The previous model did not compile. Repair it and return one complete model.\n\n"
        f"Compiler feedback:\n{feedback}\n\n"
        f"Previous model:\n{code}\n"
    )
    return MODELICA_SYSTEM, human


def call_and_compile(directory: Path, stem: str, system: str, human: str, cache: Path) -> dict:
    path = directory / f"{stem}.json"
    existing = load_json(path)
    if existing and not existing.get("infrastructure"):
        return existing
    try:
        generated = generate(system, human)
    except Exception as exc:
        record = {
            "compile_valid": False,
            "infrastructure": True,
            "diagnostics": [],
            "error": str(exc),
            "tokens_in": None,
            "tokens_out": None,
            "provider_served": "",
            "model_calls": 0,
        }
        atomic_write(path, record)
        return record
    code = generated["code"]
    if code:
        (directory / f"{stem}.mo").write_text(code, encoding="utf-8")
        scored = compile_code(code, directory / "builds" / stem, cache)
    else:
        scored = {"compile_valid": False, "infrastructure": False, "diagnostics": []}
    record = {
        "compile_valid": scored["compile_valid"],
        "infrastructure": scored["infrastructure"],
        "diagnostics": scored["diagnostics"][:40],
        "error": generated["error"],
        "tokens_in": generated["tokens_in"],
        "tokens_out": generated["tokens_out"],
        "provider_served": generated["provider_served"],
        "model_calls": 1,
        "system": generated["system"],
        "human": generated["human"],
    }
    atomic_write(path, record)
    return record


def repair_arm(directory: Path, requirement: str, initial: dict, prefix: str, bare: bool, cache: Path) -> dict:
    """Up to two repairs. The first repair always starts from the initial sample."""
    valid = bool(initial.get("compile_valid"))
    attempts = 1 if initial.get("model_calls") else 0
    tokens_in = initial.get("tokens_in") or 0
    tokens_out = initial.get("tokens_out") or 0
    code_path = directory / "s0.mo"
    code = code_path.read_text(encoding="utf-8") if code_path.exists() else ""
    diagnostics = list(initial.get("diagnostics") or [])
    for round_index in range(1, MAX_REPAIRS + 1):
        if valid or not code:
            break
        system, human = repair_messages(requirement, code, diagnostics, bare)
        record = call_and_compile(directory, f"{prefix}{round_index}", system, human, cache)
        attempts += record.get("model_calls") or 0
        tokens_in += record.get("tokens_in") or 0
        tokens_out += record.get("tokens_out") or 0
        valid = bool(record.get("compile_valid"))
        diagnostics = list(record.get("diagnostics") or [])
        repaired = directory / f"{prefix}{round_index}.mo"
        if repaired.exists():
            code = repaired.read_text(encoding="utf-8")
    return {"valid": valid, "attempts": attempts, "tokens_in": tokens_in, "tokens_out": tokens_out}


def resample_arm(directory: Path, requirement: str, initial: dict, cache: Path) -> dict:
    valid = bool(initial.get("compile_valid"))
    attempts = 1 if initial.get("model_calls") else 0
    tokens_in = initial.get("tokens_in") or 0
    tokens_out = initial.get("tokens_out") or 0
    system, human = modelica_messages(requirement, [])
    for draw in range(1, MAX_DRAWS):
        if valid:
            break
        record = call_and_compile(directory, f"r{draw}", system, human, cache)
        attempts += record.get("model_calls") or 0
        tokens_in += record.get("tokens_in") or 0
        tokens_out += record.get("tokens_out") or 0
        valid = bool(record.get("compile_valid"))
    return {"valid": valid, "attempts": attempts, "tokens_in": tokens_in, "tokens_out": tokens_out}


def one_requirement(req_id: str, requirement: str | None, cache: Path) -> dict:
    directory = ROOT / req_id
    done = load_json(directory / "cell.json")
    if done:
        return done
    if requirement is None:
        cell = {
            "req_id": req_id,
            "skipped": "missing_requirement",
            "a0": False,
            "a0c": False,
            "a0b": False,
            "rs": False,
            "attempts": {"a0": 0, "a0c": 0, "a0b": 0, "rs": 0},
            "tokens_in": {"a0": 0, "a0c": 0, "a0b": 0, "rs": 0},
            "tokens_out": {"a0": 0, "a0c": 0, "a0b": 0, "rs": 0},
        }
        atomic_write(directory / "cell.json", cell)
        return cell
    directory.mkdir(parents=True, exist_ok=True)
    system, human = modelica_messages(requirement, [])
    initial = call_and_compile(directory, "s0", system, human, cache)
    diagnostic = repair_arm(directory, requirement, initial, "c", False, cache)
    bare = repair_arm(directory, requirement, initial, "b", True, cache)
    resampled = resample_arm(directory, requirement, initial, cache)
    shared_in = initial.get("tokens_in") or 0
    shared_out = initial.get("tokens_out") or 0
    cell = {
        "req_id": req_id,
        "skipped": None,
        "provider_served": initial.get("provider_served") or "",
        "a0": bool(initial.get("compile_valid")),
        "a0c": diagnostic["valid"],
        "a0b": bare["valid"],
        "rs": resampled["valid"],
        "attempts": {
            "a0": 1 if initial.get("model_calls") else 0,
            "a0c": diagnostic["attempts"],
            "a0b": bare["attempts"],
            "rs": resampled["attempts"],
        },
        "tokens_in": {
            "a0": shared_in,
            "a0c": diagnostic["tokens_in"],
            "a0b": bare["tokens_in"],
            "rs": resampled["tokens_in"],
        },
        "tokens_out": {
            "a0": shared_out,
            "a0c": diagnostic["tokens_out"],
            "a0b": bare["tokens_out"],
            "rs": resampled["tokens_out"],
        },
        "infrastructure": bool(initial.get("infrastructure")),
    }
    atomic_write(directory / "cell.json", cell)
    return cell


def skipped_cell(req_id: str, reason: str) -> dict:
    return {
        "req_id": req_id,
        "skipped": reason,
        "a0": False,
        "a0c": False,
        "a0b": False,
        "rs": False,
        "attempts": {"a0": 0, "a0c": 0, "a0b": 0, "rs": 0},
        "tokens_in": {"a0": 0, "a0c": 0, "a0b": 0, "rs": 0},
        "tokens_out": {"a0": 0, "a0c": 0, "a0b": 0, "rs": 0},
    }


def summarize(cells: list[dict]) -> dict:
    n = len(cells)
    arms = ("a0", "a0c", "a0b", "rs")

    def rate(arm: str) -> dict:
        passed = sum(1 for cell in cells if cell[arm])
        return {"passed": passed, "percent": round(100 * passed / n, 1) if n else None}

    def calls(arm: str) -> dict:
        total = sum(cell["attempts"][arm] for cell in cells)
        tin = sum(cell["tokens_in"][arm] for cell in cells)
        tout = sum(cell["tokens_out"][arm] for cell in cells)
        return {"calls": total, "tokens_in": tin, "tokens_out": tout}

    return {
        "n": n,
        "model": MODEL,
        "provider_requested": PROVIDER,
        "temperature": TEMPERATURE,
        "max_repairs": MAX_REPAIRS,
        "max_draws": MAX_DRAWS,
        "rates": {arm: rate(arm) for arm in arms},
        "usage": {arm: calls(arm) for arm in arms},
        "skipped": sum(1 for cell in cells if cell.get("skipped")),
    }


def main(argv: list[str] | None = None) -> int:
    load_env()
    argv = list(sys.argv[1:] if argv is None else argv)
    execute = "--execute" in argv
    limit = None
    workers = 6
    shard = 0
    shards = 1
    if "--limit" in argv:
        limit = int(argv[argv.index("--limit") + 1])
    if "--workers" in argv:
        workers = int(argv[argv.index("--workers") + 1])
    if "--shard" in argv:
        shard = int(argv[argv.index("--shard") + 1])
        shards = int(argv[argv.index("--shards") + 1])
    ladder = read_ids("ladder500_mod.txt")
    ladder = [req_id for index, req_id in enumerate(ladder) if index % shards == shard]
    if limit is not None:
        ladder = ladder[:limit]
    blocked = normfail_ids()
    requests = modelica_requests()
    pending = []
    finished = []
    for req_id in ladder:
        if req_id in blocked:
            cell = skipped_cell(req_id, "normalization")
            atomic_write(ROOT / req_id / "cell.json", cell)
            finished.append(cell)
            continue
        existing = load_json(ROOT / req_id / "cell.json")
        if existing:
            finished.append(existing)
            continue
        requirement = requests.get(req_id)
        pending.append((req_id, requirement))
    print(
        f"ladder {len(ladder)}  normalization failures {sum(1 for req in ladder if req in blocked)}  "
        f"done {len(finished) - sum(1 for req in ladder if req in blocked)}  remaining {len(pending)}",
        flush=True,
    )
    print("A0 one call; A0C diagnostics; A0B 'Compilation failed.'; RS up to 3 draws", flush=True)
    if not execute:
        print("dry run; pass --execute to call the model")
        return 0
    if not pending:
        report = summarize(finished)
        atomic_write(ROOT / f"summary_{shard}.json", report)
        print(json.dumps(report["rates"]))
        return 0
    caches: queue.Queue[Path] = queue.Queue()
    for index in range(workers):
        cache = ROOT / "omc-cache" / f"s{shard}-{index}"
        cache.mkdir(parents=True, exist_ok=True)
        caches.put(cache)
    lock = threading.Lock()
    errors = []

    def run(item: tuple[str, str | None]) -> dict:
        req_id, requirement = item
        cache = caches.get()
        try:
            cell = one_requirement(req_id, requirement, cache)
        except Exception:
            errors.append(req_id)
            traceback.print_exc()
            cell = skipped_cell(req_id, "runner_error")
        finally:
            caches.put(cache)
        with lock:
            finished.append(cell)
            print(
                f"  {len(finished)}/{len(ladder)} {req_id} "
                f"A0={int(cell['a0'])} A0C={int(cell['a0c'])} "
                f"A0B={int(cell['a0b'])} RS={int(cell['rs'])}",
                flush=True,
            )
        return cell

    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with ThreadPoolExecutor(max_workers=max(1, workers)) as pool:
        list(pool.map(run, pending))
    report = summarize([cell for cell in finished if cell["req_id"] in set(ladder)])
    report["started"] = started
    report["ended"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    report["runner_errors"] = errors
    atomic_write(ROOT / f"summary_{shard}.json", report)
    print(json.dumps(report["rates"]), flush=True)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
