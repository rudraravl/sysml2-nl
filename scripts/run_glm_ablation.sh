#!/usr/bin/env bash
# Efficient single-job GLM-5.2 A0–A4 ablation ladder.
#
# Runs all selected conditions in one AblationRunner invocation so each
# task×repetition block shares IR normalization and resumes by fingerprint.
#
# Usage (from repo root):
#   bash scripts/run_glm_ablation.sh --dry-run
#   OUTPUT_DIR=outputs/glm52-ablation-v1 bash scripts/run_glm_ablation.sh
#   CONDITIONS=A1,A2,A3,A4 OUTPUT_DIR=outputs/glm52-ablation-v1 bash scripts/run_glm_ablation.sh
#   REPS=3 SHARD_COUNT=4 SHARD_INDEX=0 bash scripts/run_glm_ablation.sh
#
# Extra args are forwarded to run_cli (e.g. --family aerial_robotics --task-id ...).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUTPUT_DIR="${OUTPUT_DIR:-outputs/glm52-ablation-v1}"
MODEL="${MODEL:-z-ai/glm-5.2}"
PROVIDER="${PROVIDER:-openrouter}"
MANIFEST="${MANIFEST:-nl2robotics/corpus/pipeline_prompt_manifest.json}"
PROFILE="${PROFILE:-capability}"
VARIANT="${VARIANT:-rich}"
REPS="${REPS:-1}"
MODELICA_BACKEND="${MODELICA_BACKEND:-local}"
MODELICA_SUBSET="${MODELICA_SUBSET:-full1500}"
K="${K:-5}"
MAX_TOOL_REPAIRS="${MAX_TOOL_REPAIRS:-2}"
SHARD_COUNT="${SHARD_COUNT:-1}"
SHARD_INDEX="${SHARD_INDEX:-0}"
CONDITIONS="${CONDITIONS:-A0,A1,A2,A3,A4}"
SEED="${SEED:-20260830}"

TASK_ARGS=()
while IFS= read -r task_id; do
  [[ -n "$task_id" ]] && TASK_ARGS+=(--task-id "$task_id")
done < ecir2027/ids/ladder500_mod.txt

CONDITION_ARGS=()
IFS=',' read -r -a CONDITION_IDS <<< "$CONDITIONS"
for cid in "${CONDITION_IDS[@]}"; do
  cid="$(echo "$cid" | tr -d '[:space:]')"
  [[ -n "$cid" ]] || continue
  CONDITION_ARGS+=(--condition "$cid")
done
if [[ ${#CONDITION_ARGS[@]} -eq 0 ]]; then
  echo "FAIL: CONDITIONS is empty" >&2
  exit 1
fi

CMD=(
  "${PYTHON:-python3}" -m nl2robotics.experiments.run_cli
  --benchmark-manifest "$MANIFEST"
  --profile "$PROFILE"
  --variant "$VARIANT"
  "${CONDITION_ARGS[@]}"
  "${TASK_ARGS[@]}"
  --repetitions "$REPS"
  --randomization-seed "$SEED"
  --provider "$PROVIDER"
  --model "$MODEL"
  --modelica-backend "$MODELICA_BACKEND"
  --modelica-subset "$MODELICA_SUBSET"
  -k "$K"
  --max-tool-repairs "$MAX_TOOL_REPAIRS"
  --shard-count "$SHARD_COUNT"
  --shard-index "$SHARD_INDEX"
  --output-dir "$OUTPUT_DIR"
)

echo "=== GLM A0–A4 ablation ==="
echo "output: $OUTPUT_DIR"
echo "model: $PROVIDER / $MODEL"
echo "conditions: $CONDITIONS"
echo "repetitions: $REPS  shards: $SHARD_INDEX/$SHARD_COUNT"
echo

"${CMD[@]}" "$@"

if [[ " $* " != *" --dry-run "* ]]; then
  cat <<EOF

=== summarize (after the run finishes) ===
python3 -m nl2robotics.experiments.cli "$OUTPUT_DIR" \\
  --pair A0 A4 --metric all_properties_pass \\
  --output "$OUTPUT_DIR/ablation-summary.json"
EOF
fi
