# nl2solidity ablation on PACE

Six arms, each the one below it plus exactly one stage, run as independent SLURM
array jobs over disjoint shards of a shared evaluation set.

| arm | pipeline | adds over the arm below | walltime |
|-----|----------|-------------------------|----------|
| A0 | one-shot GLM-5.2 | baseline: bare requirement, one model call | 10h |
| A1 | + RAG | dataset exemplars + Solidity spec chunks in the prompt | 10h |
| A2 | + MoE | 4 parallel experts synthesised by the combiner | 12h |
| A3 | + compiler repair | `solc` diagnostics fed back (≤2 passes) | 12h |
| A4 | + execution repair | Foundry fuzz + requirement-derived property failures fed back | 16h |
| A5 | full pipeline | Slither static analysis + twin-blind spec alignment | 16h |

Every arm runs the *same* generator (`batch_generate.py` → `generate_solidity_moe`)
with stages switched off by environment variable. There is no per-arm code path,
so a difference between two arms is attributable to the stage named above and
nothing else.

**Every arm is scored on every metric.** A stage that is off for an arm is off as
*feedback*, never as *measurement*: all six arms are compiled by `solc`, executed
under Foundry against requirement-derived property tests, analysed by Slither and
scored by the twin-blind spec aligner. A2 is measured by Foundry, Slither and the
aligner while being repaired by none of them. That is what makes any metric
readable straight down the ladder, and it is why A0 asks for 10h rather than the
~1h its own stages would need.

The evaluation set is **the first 500 seeds** of `sol_seed.jsonl`, identical
across arms.

## Layout

```
nl2solidity/ablation/
  profiles.py          arm definitions — the single source of truth
  run_ablation.py      runs one shard of one arm; every sbatch calls this
  preflight.py         per-arm toolchain check, run before submitting
  gen_sbatch.py        regenerates pace/*.sbatch from profiles.py
  test_ablation.py     73 tests: ladder monotonicity, shard partition, knobs
  pace/
    common.sh          shared node setup, sourced by every sbatch
    a0..a5.sbatch      one array job per arm (GENERATED — do not hand-edit)
    submit_all.sh      submit some or all arms
    progress.sh        where every arm stands
```

## Parallelism

Each arm is one SLURM array job of `ABLATION_SHARDS` tasks (default 5, the study
calls for 4–6). Shard *k* takes the seeds where `seed_position % shards == k`:

* **Disjoint and complete.** The tasks of an arm partition the evaluation set
  exactly — every seed generated once, no seed twice. Tested, not assumed
  (`test_shards_partition_the_evaluation_set_exactly`).
* **Stable across arms.** Seed `U7` lands in the same shard for every arm, so a
  lost task costs the same seeds everywhere.
* **Balanced.** Shard sizes differ by at most one seed, so no single task becomes
  the walltime.
* **Belt and braces.** `batch_generate.py`'s atomic `.claim` directories still
  run underneath, which is what makes an overlapping *resubmission* safe.

Running three arms at 5 shards puts 15 tasks in the queue; six arms at 6 shards
puts 36. Each task uses 8 CPUs and caps itself at 8 concurrent OpenRouter calls.

## Running it

**1. Prestage, once, on a login node** (compute nodes may have no egress):

```bash
cd ~/sysml2-nl
bash nl2solidity/pace/prestage.sh
```

This builds `.venv`, caches solc into `~/.solcx`, installs Foundry into
`~/.foundry`, and clones `forge-std`. Every line of its table must read
`available`.

**2. Credentials** — create on PACE, never transfer, never commit:

```bash
printf 'OPENROUTER_API_KEY=sk-or-...\n' > ~/sysml2-nl/.env
chmod 600 ~/sysml2-nl/.env
```

**3. Set the account and partition** in the generated sbatch files:

```bash
python nl2solidity/ablation/gen_sbatch.py --account gts-youracct --partition cpu-small
```

**4. Preflight** — from a compute node, so the API probe is meaningful:

```bash
salloc -A gts-youracct -q inferno -N1 --ntasks-per-node=2 -t 0:15:00
.venv/bin/python nl2solidity/ablation/preflight.py --probe-api
exit
```

If the probe fails, compute nodes need a proxy: add `export HTTPS_PROXY=...` to
`pace/common.sh`.

**5. Submit**, from the repo root:

```bash
bash nl2solidity/ablation/pace/submit_all.sh                  # all six arms
bash nl2solidity/ablation/pace/submit_all.sh A1 A2 A3         # a subset
ABLATION_SHARDS=6 bash nl2solidity/ablation/pace/submit_all.sh A2 A3 A4
DRY=1 bash nl2solidity/ablation/pace/submit_all.sh            # print, submit nothing
```

or one arm directly: `sbatch nl2solidity/ablation/pace/a3.sbatch`.

**6. Monitor:**

```bash
bash nl2solidity/ablation/pace/progress.sh
tail -f logs/a3_*_1.out
```

**7. Resume** — resubmit the identical command. Completed seeds are skipped;
claims from a walltime-killed task age out after `BATCH_CLAIM_STALE_SEC` (15 min).

## Knobs

Set in the environment before `sbatch`; `common.sh` passes them through.

| variable | default | meaning |
|----------|---------|---------|
| `ABLATION_N` | `500` | evaluation set: the first N seeds of `sol_seed.jsonl` (which holds 1500). **Identical across arms — change it for all or none.** |
| `ABLATION_SHARDS` | `5` | instances per arm |
| `ABLATION_WORKERS` | `4` | seeds in flight within one shard |
| `ABLATION_OUTPUT_ROOT` | `nl2solidity/dataset/ablation` | one subdirectory per arm |
| `ABLATION_PROMPT_SOURCE` | `seed_long` | NL prompt source; keep identical across arms |
| `FUZZ_RUNS` | `64` | fuzz runs per property, every arm (256 was the pilot's dominant cost) |
| `REPO` | submit directory | repo root, if not submitting from it |

Stage on/off flags are **forced** by `profiles.apply()` and cannot be overridden
from the environment — an arm that silently ran a stage it is meant to be missing
would void the comparison. Repair *budgets* (`MAX_REFINEMENT_ITERATIONS`, …) do
yield to an explicit export, so you can tune cost without forking a profile.

## Output and grading

One directory per seed, per arm: `dataset/ablation/<arm>/U###/{U###.sol,U###.txt,meta.json}`.

Each `meta.json` carries its own provenance and the full metric set, so arms can
never be conflated and every arm is comparable on every number:

```json
{
  "id": "U1",
  "ablation": "A2",
  "ablation_stages": { "rag": true, "moe": true, "compiler_repair_iterations": 0, ... },
  "quality": "A",
  "quality_gates": { "validation": true, "execution": true, "security": true, "alignment": true },
  "validation":     { "is_valid": true, "error_count": 0 },
  "execution":      { "tier_status": { "fuzz": "passed", "properties": "passed" }, ... },
  "security":       { "tool": "slither", "n_findings": 0, "n_actionable": 0 },
  "spec_alignment": { "accepted": true, "similarity": 0.9425, "repairs": 0 }
}
```

`quality` is `A` when every gate ran and passed and `B` when one ran and failed.
(`U` means a gate never ran — it should not appear under the default mode, and is
a signal that a toolchain component was missing on the node.) `ablation_stages`
records the repair budgets, so a measured-only stage is visible as
`*_repair_iterations: 0`.

### Comparing arms

Per arm:

```bash
.venv/bin/python nl2solidity/analyze_with_kernel_spec.py \
    --dir nl2solidity/dataset/ablation/A2
```

This prints compile validity, Foundry fuzz pass rate, execution-clean rate,
Slither-clean rate, alignment similarity and the four-gate funnel, and writes
`dataset/analysis_results/A2_fidelity.json`. Because every arm is measured
identically, those six JSON files line up column for column.

### Cheap mode

`--no-measure-all` records only the metrics each arm's own stages produce. A0–A3
then run far faster, but the only metric all six share is compile validity, so
this is for smoke tests rather than for the study:

```bash
ABLATION_EXTRA_ARGS=--no-measure-all bash nl2solidity/ablation/pace/submit_all.sh
```

## Changing an arm

Edit `profiles.py`, then:

```bash
python nl2solidity/ablation/gen_sbatch.py --account gts-youracct
.venv/bin/python -m pytest nl2solidity/ablation/test_ablation.py -q
```

The sbatch headers are generated from the arm definitions, and a test fails if
they go stale — the header can never describe a different arm than the one that
runs.
