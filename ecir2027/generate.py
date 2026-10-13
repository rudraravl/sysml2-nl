#!/usr/bin/env python3
"""Single-call generation for the ECIR 2027 runs.

Prompts are the ladder templates. Only the exemplar list changes. There is no
repair loop and no second model. Nothing is sent unless --execute is set.

    python ecir2027/generate.py R1 --dry-run
    python ecir2027/generate.py R1 --execute --limit 1

R1b is Modelica A1 filled with retrieval/mod/cos.jsonl top 5. R2mod draws five
random Modelica exemplars. U0mod is two extra no-retrieval samples on the
100 pooled requirements. --score checks Modelica with the OpenModelica image.
"""

from __future__ import annotations  # Python 3.9 on this machine; the study asks for 3.11.

import hashlib
import http.client
import json
import os
import queue
import sys
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
MODEL = "z-ai/glm-5.2"
TEMPERATURE = 0.2
TRUNCATION = 80
# Live OpenRouter endpoints on 2026-10-05. Code generation is output-heavy, so
# the cheapest host is DeepInfra fp4 ($0.5625 / $1.80 per million tokens), not
# the hosts with the lowest input price.
PROVIDER = "deepinfra"
PROVIDER_QUANTIZATIONS = ["fp4"]

# Ladder prompt text, copied from nl2solidity/agent_rag_moe.py so a generation
# process does not import the MoE pipeline.
SOLIDITY_SYSTEM = (
    "You generate valid Solidity source code only. "
    "No markdown, no fences, no prose. "
    "Every file MUST start with an SPDX license identifier comment "
    "(e.g. // SPDX-License-Identifier: MIT) and a pragma solidity version "
    "(e.g. pragma solidity ^0.8.20;). "
    "Prefer correct grammar and consistency. "
    "Produce complete, non-trivial contracts that satisfy the requirement with "
    "appropriate state variables, a constructor, external/public functions, events, "
    "modifiers/access control, and custom errors or require checks where applicable. "
    "Follow common security practices (checks-effects-interactions, access control, "
    "safe arithmetic). Avoid placeholders and undefined references."
)
SOLIDITY_HUMAN = (
    "{context}\n\n"
    "Generate Solidity code for the following requirement. "
    "Produce a complete, detailed, non-trivial contract with appropriate state "
    "variables, a constructor, external/public functions, events, access-control "
    "modifiers, and custom errors / require checks as applicable. "
    "Avoid placeholders. Requirement: {input}"
)


def stable_rng(key: str) -> np.random.Generator:
    digest = hashlib.sha256(key.encode("utf-8")).digest()
    return np.random.default_rng(int.from_bytes(digest[:8], "little"))


def read_ids(name: str) -> list[str]:
    path = HERE / "ids" / name
    if not path.exists():
        raise SystemExit(f"missing {path}; run ecir2027/stage0.py ids first")
    return [line.strip() for line in path.read_text().splitlines() if line.strip()]


def load_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        raise SystemExit(f"missing {path}; run ecir2027/stage0.py retrieval first")
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def truncate(code: str, limit: int = TRUNCATION) -> str:
    kept = []
    for line in code.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue
        kept.append(line)
        if len(kept) >= limit:
            break
    return "\n".join(kept)


def solidity_exemplars() -> dict[str, tuple[str, str]]:
    root = REPO / "nl2solidity" / "dataset" / "data"
    found = {}
    for folder in root.iterdir():
        if not folder.is_dir():
            continue
        text = folder / f"{folder.name}.txt"
        code = folder / f"{folder.name}.sol"
        if text.exists() and code.exists():
            found[folder.name] = (text.read_text(encoding="utf-8"), code.read_text(encoding="utf-8"))
    return found


def solidity_context(pairs: list[tuple[str, str]]) -> str:
    blocks = []
    for index, (text, code) in enumerate(pairs, 1):
        blocks.append(
            f"Example {index} NL:\n{text.strip()}\n\nExample {index} Solidity:\n{truncate(code)}\n---"
        )
    if not blocks:
        return ""
    return (
        "Use the following examples and documentation excerpts as guidance. "
        "Follow the language grammar; prefer simple, correct, secure constructs.\n"
        + "\n".join(blocks)
    )


def solidity_messages(requirement: str, pairs: list[tuple[str, str]]) -> tuple[str, str]:
    return SOLIDITY_SYSTEM, SOLIDITY_HUMAN.format(
        context=solidity_context(pairs), input=requirement)


# Ladder prompt text, copied from nl2robotics/modelica/pipeline.py.
# New runs truncate exemplar code to 80 non-comment lines, as the paper specifies.
MODELICA_SYSTEM = (
    "You generate one self-contained, executable Modelica model.\n"
    "Return Modelica code only, without markdown or prose. Use explicit SI units,\n"
    "parameters, initial conditions, and observable state variables. Prefer simple\n"
    "equations and Modelica Standard Library components demonstrated by the examples.\n"
    "The top-level model must compile in OpenModelica. Standalone plant requests must\n"
    "be directly simulatable and exportable as an FMI 2.0 Co-Simulation FMU. Prefer\n"
    "scalar, explicitly Real-valued equations when an array reduction or ambiguous\n"
    "overload could prevent OpenModelica FMU code generation. Give dynamic states\n"
    "finite, non-singular initial conditions, and give any norm used as a divisor a\n"
    "well-defined zero-error branch. Controller-only FMI requests must\n"
    "instead preserve the declared top-level input/output causalities and must not\n"
    "invent plant dynamics.\n"
    "Never copy numeric values from retrieved examples into the requested artifact;\n"
    "only the requirement and its grounded IR are sources of factual values. A model\n"
    "must not contain unbound parameters: omit unresolved behavior and label it in a\n"
    "comment instead of fabricating a binding or blocking code generation."
)


def modelica_requests() -> dict[str, str]:
    manifest = json.loads(
        (REPO / "nl2robotics" / "corpus" / "pipeline_prompt_manifest.json").read_text(encoding="utf-8")
    )
    return {row["id"]: row["request"] for row in manifest["cases"]}


def modelica_examples() -> dict[str, object]:
    sys.path.insert(0, str(REPO))
    from nl2robotics.modelica.corpus import ExampleCorpus
    return {item.id: item for item in ExampleCorpus().examples}


def modelica_context(examples: list) -> str:
    blocks = []
    for index, item in enumerate(examples, 1):
        blocks.append(
            f"Example {index} [{item.id}; {item.category}; {item.difficulty}]\n"
            f"Requirement: {item.requirement}\nModelica:\n{truncate(item.code)}"
        )
    return "\n\n---\n\n".join(blocks)


def modelica_messages(requirement: str, examples: list) -> tuple[str, str]:
    if examples:
        human = (
            f"Retrieved examples:\n{modelica_context(examples)}\n\n"
            "Generate one complete Modelica model for this requirement:\n"
            f"{requirement.strip()}\n"
        )
    else:
        human = (
            "Generate one complete Modelica model for this requirement:\n"
            f"{requirement.strip()}\n"
        )
    return MODELICA_SYSTEM, human


def _modelica_plan(source: str, k: int) -> list[dict]:
    lists = {row["req_id"]: row for row in load_jsonl(HERE / "retrieval" / "mod" / source)}
    planned = []
    for req_id in read_ids("ladder500_mod.txt"):
        row = lists[req_id]
        planned.append({
            "req_id": req_id,
            "file_id": req_id,
            "exemplar_ids": row["exemplar_ids"][:k],
            "scores": row.get("scores", [])[:k],
        })
    return planned


def plan_r1b() -> list[dict]:
    return _modelica_plan("cos.jsonl", 5)


def plan_r2_mod() -> list[dict]:
    sys.path.insert(0, str(REPO))
    from nl2robotics.modelica.corpus import ExampleCorpus
    corpus = sorted(item.id for item in ExampleCorpus().examples)
    planned = []
    for req_id in read_ids("ladder500_mod.txt"):
        draw = stable_rng(req_id).choice(corpus, size=5, replace=False)
        planned.append({
            "req_id": req_id,
            "file_id": req_id,
            "exemplar_ids": list(draw),
            "scores": [],
        })
    return planned


def plan_u0_mod() -> list[dict]:
    planned = []
    for req_id in read_ids("pool100_mod.txt"):
        for sample in (1, 2):
            planned.append({
                "req_id": req_id,
                "file_id": f"{req_id}__s{sample}",
                "exemplar_ids": [],
                "scores": [],
            })
    return planned


def plan_u1_mod() -> list[dict]:
    planned = []
    for row in load_jsonl(HERE / "retrieval" / "mod" / "pool.jsonl"):
        planned.append({
            "req_id": row["req_id"],
            "file_id": f"{row['req_id']}__{row['exemplar_id']}",
            "exemplar_ids": [row["exemplar_id"]],
            "scores": [],
            "label": row,
        })
    return planned


def plan_u2_mod() -> list[dict]:
    pairs = plan_u1_mod()
    take = int(round(len(pairs) * 0.10))
    chosen = np.random.default_rng(0).choice(len(pairs), size=take, replace=False)
    planned = []
    for index in sorted(int(item) for item in chosen):
        item = dict(pairs[index])
        item["file_id"] = item["file_id"] + "__s2"
        item["label"] = dict(item["label"])
        planned.append(item)
    return planned


def requirement_text(req_id: str) -> str:
    import csv
    path = REPO / "nl2solidity" / "sol_seed.csv"
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            if row["id"] == req_id:
                return row["description"]
    raise SystemExit(f"requirement {req_id} is not in sol_seed.csv")


def plan_r1() -> list[dict]:
    lists = {row["req_id"]: row for row in load_jsonl(HERE / "retrieval" / "sol" / "bm25.jsonl")}
    planned = []
    for req_id in read_ids("ladder500_sol.txt"):
        row = lists[req_id]
        planned.append({
            "req_id": req_id,
            "exemplar_ids": row["exemplar_ids"][:5],
            "scores": row["scores"][:5],
        })
    return planned


def plan_r2_sol() -> list[dict]:
    corpus = sorted(solidity_exemplars())
    planned = []
    for req_id in read_ids("ladder500_sol.txt"):
        draw = stable_rng(req_id).choice(corpus, size=5, replace=False)
        planned.append({"req_id": req_id, "exemplar_ids": list(draw), "scores": []})
    return planned


def plan_u0_sol() -> list[dict]:
    planned = []
    for req_id in read_ids("pool100_sol.txt"):
        for sample in (1, 2):
            planned.append({
                "req_id": req_id,
                "file_id": f"{req_id}__s{sample}",
                "exemplar_ids": [],
                "scores": [],
            })
    return planned


def _plan_u1(lang: str) -> list[dict]:
    planned = []
    for row in load_jsonl(HERE / "retrieval" / lang / "pool.jsonl"):
        planned.append({
            "req_id": row["req_id"],
            "file_id": f"{row['req_id']}__{row['exemplar_id']}",
            "exemplar_ids": [row["exemplar_id"]],
            "scores": [],
            "label": row,
        })
    return planned


def plan_u1_sol() -> list[dict]:
    return _plan_u1("sol")


def plan_u2_sol() -> list[dict]:
    pairs = plan_u1_sol()
    take = int(round(len(pairs) * 0.10))
    chosen = np.random.default_rng(0).choice(len(pairs), size=take, replace=False)
    planned = []
    for index in sorted(int(item) for item in chosen):
        item = dict(pairs[index])
        item["file_id"] = item["file_id"] + "__s2"
        item["label"] = dict(item["label"])
        planned.append(item)
    return planned


PLANS = {
    "R1": {
        "lang": "sol",
        "condition": "A1alt",
        "n": 500,
        "plan": plan_r1,
        "note": "Solidity A1, top 5 of BM25 with lineage diversity",
    },
    "R2": {
        "lang": "sol",
        "condition": "random",
        "n": 500,
        "plan": plan_r2_sol,
        "note": "Solidity A1, five random exemplars",
    },
    "U0sol": {
        "lang": "sol",
        "condition": "A0extra",
        "n": 200,
        "plan": plan_u0_sol,
        "note": "Two extra Solidity A0 samples on the 100 pooled requirements",
    },
    "U1sol": {
        "lang": "sol",
        "condition": "k1",
        "n": 0,
        "plan": plan_u1_sol,
        "note": "Each pooled Solidity exemplar used alone",
        "labels": True,
    },
    "U2sol": {
        "lang": "sol",
        "condition": "k1repeat",
        "n": 0,
        "plan": plan_u2_sol,
        "note": "Second sample on 10 percent of the Solidity pool pairs, seed 0",
        "labels": True,
    },
    "R1b": {
        "lang": "mod",
        "condition": "A1alt",
        "n": 500,
        "plan": plan_r1b,
        "note": "Modelica A1, top 5 of binary cosine",
    },
    "R2mod": {
        "lang": "mod",
        "condition": "random",
        "n": 500,
        "plan": plan_r2_mod,
        "note": "Modelica A1, five random exemplars",
    },
    "U0mod": {
        "lang": "mod",
        "condition": "A0extra",
        "n": 200,
        "plan": plan_u0_mod,
        "note": "Two extra Modelica A0 samples on the 100 pooled requirements",
    },
    "U1mod": {
        "lang": "mod",
        "condition": "k1",
        "n": 0,
        "plan": plan_u1_mod,
        "note": "Each pooled Modelica exemplar used alone",
        "labels": True,
    },
    "U2mod": {
        "lang": "mod",
        "condition": "k1repeat",
        "n": 0,
        "plan": plan_u2_mod,
        "note": "Second sample on 10 percent of the Modelica pool pairs, seed 0",
        "labels": True,
    },
}


def load_env() -> None:
    """Read a local .env when the key is not already in the environment."""
    if os.environ.get("OPENROUTER_API_KEY"):
        return
    for path in (REPO / ".env", HERE / ".env"):
        if not path.is_file():
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            name, value = line.split("=", 1)
            name = name.strip()
            value = value.split("#", 1)[0].strip().strip('"').strip("'")
            if name and name not in os.environ:
                os.environ[name] = value
        return


def provider_prefs(provider: str) -> dict:
    prefs = {"order": [provider], "allow_fallbacks": False}
    if provider == PROVIDER:
        prefs["quantizations"] = PROVIDER_QUANTIZATIONS
    return prefs


def call_openrouter(system: str, human: str, provider: str) -> dict:
    key = os.environ.get("OPENROUTER_API_KEY", "")
    if not key:
        raise RuntimeError("OPENROUTER_API_KEY is not set")
    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": human},
        ],
        "temperature": TEMPERATURE,
        "provider": provider_prefs(provider),
    }
    request = urllib.request.Request(
        os.environ.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1") + "/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {key}",
            "HTTP-Referer": "https://localhost",
            "X-Title": "dsl-retrieval",
        },
    )
    delay = 1.0
    last = None
    for attempt in range(8):
        try:
            with urllib.request.urlopen(request, timeout=600) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            last = exc
            if exc.code not in (408, 409, 429, 500, 502, 503, 504) or attempt == 7:
                raise
        except (urllib.error.URLError, TimeoutError, http.client.IncompleteRead, http.client.RemoteDisconnected) as exc:
            last = exc
            if attempt == 7:
                raise
        time.sleep(delay)
        delay = min(delay * 2, 30)
    raise last


def completion_text(body: dict) -> str:
    choices = body.get("choices") or []
    if not choices:
        return ""
    return ((choices[0].get("message") or {}).get("content") or "").strip()


def served_provider(body: dict) -> str:
    return str(body.get("provider") or body.get("model") or "")


def score_modelica(code: str, work: Path, library_cache: Path | None = None) -> dict:
    sys.path.insert(0, str(REPO))
    from nl2robotics.modelica.openmodelica import OpenModelicaRunner
    build = OpenModelicaRunner(backend="docker", library_cache=library_cache).compile(code, output_dir=work)
    messages = [item.message for item in build.diagnostics if item.severity == "error"]
    return {
        "compile_valid": bool(build.success),
        "n_compiler_errors": len(messages),
        "compiler_error_classes": [],
        "compiler_errors": messages,
    }


def score_solidity(code: str) -> dict:
    sys.path.insert(0, str(REPO))
    from nl2solidity.compiler_interface import check_code
    from ecir2027.forge_ecir_tools import classify_solc
    result = check_code(code)
    messages = [error.message for error in result.errors]
    return {
        "compile_valid": bool(result.is_valid),
        "n_compiler_errors": len(messages),
        "compiler_error_classes": [classify_solc(message) for message in messages],
        "compiler_errors": messages,
    }


MODELICA_TASKS = ("R1b", "R2mod", "U0mod", "U1mod", "U2mod")


def _compiler_caches(count: int) -> queue.Queue:
    """One OpenModelica library directory per compile worker.

    Concurrent containers cannot share one cache directory.
    """
    root = HERE / "runs" / "omc-cache"
    slots = queue.Queue()
    for index in range(count):
        cache = root / str(index)
        cache.mkdir(parents=True, exist_ok=True)
        slots.put(cache)
    return slots


def execute_jobs(jobs: list[dict], *, provider: str, score: bool, workers: int, score_workers: int) -> None:
    """Send calls on `workers` threads and compile on a separate `score_workers` pool."""
    provider = provider or PROVIDER
    mod_exemplars = modelica_examples() if any(job["lang"] == "mod" for job in jobs) else {}
    mod_requests = modelica_requests() if mod_exemplars else {}
    sol_exemplars = solidity_exemplars() if any(job["lang"] == "sol" for job in jobs) else {}
    pending = []
    done = 0
    total = 0
    for job in jobs:
        dest = job["dest"]
        (dest / "outputs").mkdir(parents=True, exist_ok=True)
        (dest / "logs").mkdir(parents=True, exist_ok=True)
        for item in job["planned"]:
            total += 1
            file_id = item.get("file_id", item["req_id"])
            if (dest / "logs" / f"{file_id}.json").exists():
                done += 1
                continue
            pending.append((job, item))
    print(
        f"  remaining: {len(pending)} of {total}  "
        f"model calls at once: {workers}  compiles at once: {score_workers if score else 0}",
        flush=True,
    )
    if not pending:
        return
    lock = threading.Lock()
    caches = _compiler_caches(score_workers) if score else None
    compile_pool = ThreadPoolExecutor(max_workers=max(1, score_workers))
    compile_futures = []
    future_lock = threading.Lock()

    def finish(job, item, system, human, status, body, error, text) -> None:
        nonlocal done
        dest = job["dest"]
        lang = job["lang"]
        req_id = item["req_id"]
        file_id = item.get("file_id", req_id)
        record = {
            "req_id": req_id,
            "file_id": file_id,
            "status": status,
            "compile_valid": False,
            "n_compiler_errors": 0,
            "compiler_error_classes": [],
            "gain": 0,
            "retrieval": {
                "exemplar_ids": item["exemplar_ids"],
                "scores": item["scores"],
                "spec_chunk_ids": [],
            },
            "model_calls": 1 if status != "infra_error" else 0,
            "tokens_in": ((body or {}).get("usage") or {}).get("prompt_tokens"),
            "tokens_out": ((body or {}).get("usage") or {}).get("completion_tokens"),
            "error": error,
        }
        if status == "ok" and score and text and lang == "sol":
            record.update(score_solidity(text))
            record["gain"] = 1 if record["compile_valid"] else 0
        elif status == "ok" and score and text and lang == "mod":
            cache = caches.get()
            try:
                record.update(score_modelica(text, dest / "builds" / file_id, cache))
                record["gain"] = 1 if record["compile_valid"] else 0
            except Exception as exc:
                record["error"] = f"score: {exc}"
                record["gain"] = 0
            finally:
                caches.put(cache)
        label = item.get("label")
        if label:
            record = {
                "req_id": req_id,
                "exemplar_id": label["exemplar_id"],
                "gain": record["gain"],
                "g0": None,
                "ranks": label["ranks"],
                "random": label["random"],
                "features": label["features"],
                "status": status,
                "file_id": file_id,
            }
        with lock:
            if text:
                (dest / "outputs" / f"{file_id}{job['suffix']}").write_text(text, encoding="utf-8")
            with job["results"].open("a", encoding="utf-8") as handle:
                handle.write(json.dumps(record) + "\n")
            (dest / "logs" / f"{file_id}.json").write_text(json.dumps({
                "prompt": {"system": system, "human": human},
                "provider_served": served_provider(body or {}),
                "raw": body,
                "error": error,
            }) + "\n", encoding="utf-8")
            done += 1
            print(f"  {done}/{total} {job['task']} {file_id} {status}", flush=True)

    def call(pair: tuple[dict, dict]) -> None:
        job, item = pair
        lang = job["lang"]
        req_id = item["req_id"]
        exemplars = mod_exemplars if lang == "mod" else sol_exemplars
        chosen = [exemplars[eid] for eid in item["exemplar_ids"] if eid in exemplars]
        if lang == "mod":
            system, human = modelica_messages(mod_requests[req_id], chosen)
        else:
            system, human = solidity_messages(requirement_text(req_id), chosen)
        status, body, error = "infra_error", None, ""
        try:
            body = call_openrouter(system, human, provider)
            text = completion_text(body)
            status = "ok" if text else "empty_output"
        except (urllib.error.URLError, TimeoutError, RuntimeError, json.JSONDecodeError, http.client.IncompleteRead, http.client.RemoteDisconnected) as exc:
            text = ""
            error = str(exc)
        future = compile_pool.submit(
            finish, job, item, system, human, status, body, error, text
        )
        with future_lock:
            compile_futures.append(future)

    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    try:
        with ThreadPoolExecutor(max_workers=max(1, workers)) as pool:
            list(pool.map(call, pending))
    finally:
        for future in compile_futures:
            future.result()
        compile_pool.shutdown(wait=True)
    ended = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    for job in jobs:
        (job["dest"] / "run_meta.json").write_text(json.dumps({
            "task": job["task"],
            "model": MODEL,
            "provider_requested": provider,
            "provider_quantizations": PROVIDER_QUANTIZATIONS if provider == PROVIDER else [],
            "temperature": TEMPERATURE,
            "started": started,
            "ended": ended,
            "model_workers": workers,
            "compile_workers": score_workers,
        }, indent=2) + "\n", encoding="utf-8")


def _job(task: str, limit: int | None) -> dict:
    spec = PLANS[task]
    planned = spec["plan"]()
    if limit is not None:
        planned = planned[:limit]
    dest = HERE / "runs" / task / spec["lang"] / spec["condition"]
    print(f"{task}: {spec['note']}")
    print(f"  calls: {len(planned)}  dir: {dest.relative_to(REPO)}")
    return {
        "task": task,
        "lang": spec["lang"],
        "planned": planned,
        "dest": dest,
        "suffix": ".mo" if spec["lang"] == "mod" else ".sol",
        "results": dest / ("labels.jsonl" if spec.get("labels") else "results.jsonl"),
    }


def run_task(task: str, *, execute: bool, score: bool, provider: str, limit: int | None, workers: int, score_workers: int) -> None:
    job = _job(task, limit)
    if not execute:
        print("  dry run; pass --execute to call the model")
        return
    execute_jobs([job], provider=provider, score=score, workers=workers, score_workers=score_workers)


def run_modelica(*, execute: bool, score: bool, provider: str, limit: int | None, workers: int, score_workers: int) -> None:
    jobs = [_job(task, limit) for task in MODELICA_TASKS]
    if not execute:
        print("  dry run; pass --execute to call the model")
        return
    execute_jobs(jobs, provider=provider, score=score, workers=workers, score_workers=score_workers)


def main(argv: list[str] | None = None) -> int:
    load_env()
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv or argv[0] in {"-h", "--help"}:
        print(__doc__)
        print("tasks:", ", ".join(PLANS))
        return 2
    task = argv[0]
    if task not in PLANS and task != "modelica":
        print(f"unknown task {task}; this runner currently plans {', '.join(PLANS)}", file=sys.stderr)
        return 2
    execute = "--execute" in argv
    score = "--score" in argv
    limit = None
    provider = ""
    workers = 32
    score_workers = 12
    if "--limit" in argv:
        limit = int(argv[argv.index("--limit") + 1])
    if "--provider" in argv:
        provider = argv[argv.index("--provider") + 1]
    if "--workers" in argv:
        workers = int(argv[argv.index("--workers") + 1])
    if "--score-workers" in argv:
        score_workers = int(argv[argv.index("--score-workers") + 1])
    runner = run_modelica if task == "modelica" else run_task
    kwargs = dict(execute=execute, score=score, provider=provider, limit=limit, workers=workers, score_workers=score_workers)
    if task == "modelica":
        runner(**kwargs)
    else:
        runner(task, **kwargs)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
