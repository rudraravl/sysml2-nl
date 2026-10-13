#!/usr/bin/env python3
"""Compile Modelica files the generator has already written.

Does not call the model. Writes runs/compile.jsonl. Safe to run beside generate.py.
"""

from __future__ import annotations

import json
import queue
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
sys.path.insert(0, str(REPO))

from nl2robotics.modelica.openmodelica import OpenModelicaRunner  # noqa: E402

RUNS = HERE / "runs"
OUT = RUNS / "compile.jsonl"
WORKERS = 12
IMAGE = "openmodelica/openmodelica:v1.27.0-ompython"


def image_ready() -> bool:
    import subprocess
    found = subprocess.run(
        ["docker", "image", "inspect", IMAGE],
        capture_output=True,
        text=True,
    )
    return found.returncode == 0


def scored_paths() -> set[str]:
    if not OUT.exists():
        return set()
    found = set()
    for line in OUT.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        found.add(row.get("path") or row["file_id"])
    return found


def pending() -> list[Path]:
    done = scored_paths()
    files = []
    for path in RUNS.glob("*/*/*/outputs/*.mo"):
        rel = str(path.relative_to(RUNS))
        if rel not in done and time.time() - path.stat().st_mtime > 2:
            files.append(path)
    return files


CACHES: queue.Queue[Path] = queue.Queue()


def compile_one(path: Path) -> dict:
    code = path.read_text(encoding="utf-8", errors="replace")
    work = path.parent.parent / "builds" / path.stem
    cache = CACHES.get()
    try:
        build = OpenModelicaRunner(backend="docker", library_cache=cache).compile(code, output_dir=work)
        messages = [item.message for item in build.diagnostics if item.severity == "error"]
        gain = 1 if build.success else 0
        error = ""
    except Exception as exc:
        messages = []
        gain = 0
        error = str(exc)
    finally:
        CACHES.put(cache)
    return {
        "file_id": path.stem,
        "path": str(path.relative_to(RUNS)),
        "gain": gain,
        "compile_valid": gain == 1,
        "n_compiler_errors": len(messages),
        "compiler_errors": messages,
        "error": error,
    }


def main() -> int:
    print("waiting for the OpenModelica image", flush=True)
    while not image_ready():
        time.sleep(10)
    print(f"compiles at once: {WORKERS}", flush=True)
    for index in range(WORKERS):
        cache = RUNS / "omc-cache-score" / str(index)
        cache.mkdir(parents=True, exist_ok=True)
        CACHES.put(cache)
    while True:
        batch = pending()
        if not batch:
            time.sleep(5)
            continue
        with ThreadPoolExecutor(max_workers=WORKERS) as pool:
            for record in pool.map(compile_one, batch):
                with OUT.open("a", encoding="utf-8") as handle:
                    handle.write(json.dumps(record) + "\n")
                print(f"  {record['path']} gain {record['gain']}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
