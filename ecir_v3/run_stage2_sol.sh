#!/bin/bash
# Stage 2 (utility-labeled pools) and the gated Stage 3 (R7) for Solidity.
#   U0 -> U1 -> labels -> U2 -> analyze u2/a13 (R7 gate) -> [R7 if the gate passes] -> analyze r7
# SysML has no Stage 2/3 work in the runbook; Modelica results come from the collaborator's runs.
# Stops the queue on any abort (exit 3: out of credits / balance floor / cost cap) or crash.
# Resumable: re-running skips finished jobs (generations are cached before scoring).
cd "$(dirname "$0")/.."
P=${PYTHON:-.venv/bin/python}     # override with PYTHON=/path/to/python
F=cos_score,bm25_score,dense_score,n_imports,pragma_mismatch,n_lines,truncated,same_category
step() { echo "=== $(date '+%F %T') START $*"; "$@"; rc=$?
         echo "=== $(date '+%F %T') END $* rc=$rc"; [ $rc -eq 0 ] || { echo "=== QUEUE STOPPED (rc=$rc)"; exit $rc; }; }
# each run gets one extra pass that re-runs only infra_error jobs (finished jobs are skipped, nothing re-billed)
gen() { step $P ecir_v3/generate.py "$@" --workers 8 --min-balance 3
        step $P ecir_v3/generate.py "$@" --workers 8 --min-balance 3; }

step $P ecir_v3/generate.py preflight --lang sol
gen U0 --lang sol --max-cost 20          # 300 jobs: s1 = v1 A0 program (no call, Tier A scored), s2/s3 = 200 calls
gen U1 --lang sol --max-cost 90          # 1,384 jobs: one k=1 generation per pooled exemplar
step $P ecir_v3/generate.py labels --lang sol
gen U2 --lang sol --max-cost 15          # ~138 jobs: second sample on 10% of U1 pairs (seed 0)
step $P ecir_v3/analyze.py u2
step $P ecir_v3/analyze.py a13           # writes ecir_v3/runs/R7/gate_decision.json

if $P -c "import json,sys; sys.exit(0 if json.load(open('ecir_v3/runs/R7/gate_decision.json'))['sol']['pass'] else 1)"; then
  mkdir -p ecir_v3/runs/R7/sol
  step $P ecir_v3/forge_ecir_tools.py rerank-apply ecir_v3/runs/U1/sol/labels.jsonl \
       ecir_v3/retrieval/sol/cands_heldout.jsonl $F ecir_v3/runs/R7/sol/top5.jsonl
  gen R7 --lang sol --max-cost 40        # 400 jobs: reranked top 5 on the held-out requirements
  step $P ecir_v3/analyze.py r7
else
  echo "=== R7 gate not passed for Solidity: R7 not run (decision recorded in runs/R7/gate_decision.json)"
fi
step $P ecir_v3/analyze.py d7
step $P ecir_v3/analyze.py switches
echo "=== $(date '+%F %T') QUEUE DONE"
