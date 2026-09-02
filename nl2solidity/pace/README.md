# Running nl2solidity generation on PACE

Async, resumable Solidity generation: 1500 rich specs → MoE synthesis → solc →
Foundry → Slither → spec-mismatch alignment. Designed to run unattended across
several SLURM jobs and survive walltime kills.

## What actually runs

Per seed, the pipeline queries 4 expert models in parallel, synthesizes one
contract with a combiner, then refines it against `solc`, generates property
tests and runs them under Foundry, runs Slither, and finally scores the contract
against its specification with the twin-blind spec aligner, repairing once if
alignment is poor. Output is one directory per seed.

Nearly all wall time is **model latency, not compute** — measured at 10-15
sequential API round trips per entry, ~450-570s each, with the node otherwise
idle. Scale with more concurrent workers, not more cores.

## 1. Transfer the repo

From your laptop:

```bash
rsync -av --progress \
  --exclude '.venv' --exclude 'tmp' --exclude '.git' \
  --exclude '__pycache__' --exclude 'server/frontend/node_modules' \
  ~/College/sysml2-nl-creatix/ \
  <you>@login-phoenix.pace.gatech.edu:~/sysml2-nl-creatix/
```

Do **not** copy `.venv` (macOS binaries, useless on Linux) or `tmp` (scratch).
Do copy `nl2solidity/dataset/` (~30 MB) — that is the RAG retrieval corpus and
generation quality drops without it.

## 2. Prestage on a LOGIN node

Login nodes have outbound internet; compute nodes may not. This caches
everything the job needs into `$HOME` so the batch job only ever needs
`openrouter.ai`.

```bash
cd ~/sysml2-nl-creatix
bash nl2solidity/pace/prestage.sh
```

It builds the venv, installs `requirements.txt`, downloads solc 0.8.26/0.8.28/0.7.6
into `~/.solcx`, installs Foundry into `~/.foundry`, clones `forge-std` into
`~/.cache/nl2solidity`, creates `logs/`, and prints the preflight table. Every
line of that table must read `available` before you submit.

Adjust the `module load python/3.11` line to match your PACE software stack.

## 3. Credentials

```bash
printf 'OPENROUTER_API_KEY=sk-or-...\n' > ~/sysml2-nl-creatix/.env
chmod 600 ~/sysml2-nl-creatix/.env
```

`.env` is gitignored and is not transferred by the rsync above — create it on
PACE directly. Never put the key in the sbatch file, which lands in logs.

## 4. Confirm egress from a compute node

The single most likely reason for a silent failure. Grab an interactive node and
check the API is reachable:

```bash
salloc -A gts-CHANGEME -q inferno -N1 --ntasks-per-node=2 -t 0:10:00
curl -sS -o /dev/null -w '%{http_code}\n' https://openrouter.ai/api/v1/models
exit
```

`200` means you are clear. Anything else means compute nodes need a proxy — set
`export HTTPS_PROXY=...` in the sbatch script before the python call.

## 5. Submit

Edit the account and partition at the top of `run_batch.sbatch`, then:

```bash
cd ~/sysml2-nl-creatix
sbatch nl2solidity/pace/run_batch.sbatch
```

The job is a `--array=1-4%4`. All four tasks point at the **same** output
directory and compete for seeds through atomic `.claim` directories, so no seed
is ever generated twice. Scale by widening the array (`--array=1-8%8`), not by
raising `--workers` past the node's cores.

## 6. Monitor

```bash
squeue -u $USER                                        # task states
tail -f logs/nl2sol_*_1.out                            # live progress
ls nl2solidity/dataset/with_kernel_spec | grep -c '^U' # completed entries
grep -c "Generated" logs/nl2sol_*.out                  # per-task completions
```

## 7. Resume

Rerun the identical `sbatch` command. Completed entries are skipped by
`entry_is_complete()`, and claims held by a killed task stop being refreshed by
its heartbeat, so they age out after `BATCH_CLAIM_STALE_SEC` (15 min) and are
reclaimed. Nothing needs cleaning up by hand between runs.

`--signal=B:TERM@300` gives the job SIGTERM five minutes before walltime; the
handler stops taking new entries, lets in-flight ones finish, and releases
claims. In-flight entries interrupted by the final SIGKILL leave incomplete
directories, which fail the completeness check and are simply redone.

## Tuning

| Variable | Default here | Meaning |
|---|---|---|
| `FUZZ_RUNS` | 64 | Foundry fuzz runs per property test. 256 was the pilot's dominant cost. |
| `OPENROUTER_MAX_CONCURRENCY` | 8 | In-flight API calls per task. Raise with `--workers`. |
| `SOLC_COMPILER_MAX_CONCURRENCY` | 4 | Parallel solc invocations. |
| `SOLIDITY_RUNNER_MAX_CONCURRENCY` | 3 | Parallel `forge` processes — the real CPU hog. |
| `BATCH_CLAIM_STALE_SEC` | 900 | When another task's claim is reclaimable. Must exceed the heartbeat by a wide margin. |
| `SOLC_AUTO_INSTALL` | false | Fail loudly instead of silently downloading mid-run. |
| `FORGE_STD_AUTO_CLONE` | false | Same, for forge-std. |

Because workers are network-blocked rather than CPU-bound, `--workers 8-12` per
task is reasonable on 8 cores; raise `OPENROUTER_MAX_CONCURRENCY` with it.

## Expected throughput

~450-570s per entry, `--workers 4` per task × 4 tasks ≈ 16 concurrent entries,
so roughly **150-250 entries/hour** for the array. 1500 entries lands near 8-12
hours of aggregate walltime. With `--time=8:00:00` expect to submit twice.

## Output

```
nl2solidity/dataset/with_kernel_spec/U<n>/
    U<n>.sol      generated contract
    U<n>.txt      the specification it was generated from
    meta.json     compile / execution / slither / spec-alignment records
```

Sanity-check a finished batch:

```bash
./.venv/bin/python - <<'EOF'
import json, pathlib, statistics as st
ms=[json.load(open(d/"meta.json"))
    for d in pathlib.Path("nl2solidity/dataset/with_kernel_spec").iterdir()
    if d.is_dir() and (d/"meta.json").exists()]
sims=[m["spec_alignment"]["similarity"] for m in ms if m["spec_alignment"].get("similarity")]
print(f"{len(ms)} entries | compiles {sum(m['validation']['is_valid'] for m in ms)}"
      f" | accepted {sum(m['spec_alignment']['accepted'] for m in ms)}")
print(f"similarity mean {st.mean(sims):.4f} median {st.median(sims):.4f}"
      f" | exactly 0.85: {sum(1 for s in sims if s==0.85)}")
EOF
```

**`exactly 0.85` should stay near zero.** That value is the `extra_in_model`
credit constant: a cluster of entries landing on it means the NL side is
answering `not_stated` to everything and alignment has stopped measuring
anything. It was 91/192 with the old one-line seeds and 0/3 with the rich ones.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Job dies instantly, no log | `logs/` missing at submit | `mkdir -p logs` |
| `Compiler (solc): unavailable` | `~/.solcx` not staged | rerun `prestage.sh` on a login node |
| `Execution (forge): unavailable` | forge not on PATH | `export PATH="$HOME/.foundry/bin:$PATH"` |
| Every entry soft-fails | no egress to openrouter.ai | set `HTTPS_PROXY` (step 4) |
| Entries skipped as `claimed_elsewhere` | claims from a killed task | wait 15 min, or lower `BATCH_CLAIM_STALE_SEC` |
| Disk/quota errors mid-run | Foundry projects on shared FS | ensure `TMPDIR` points at node-local scratch |
