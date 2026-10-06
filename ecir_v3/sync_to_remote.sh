#!/bin/bash
# Copy the run state and the untracked inputs the Solidity queue needs to another machine
# (e.g. over Tailscale). Code itself comes from git (git pull on the remote).
#   ecir_v3/sync_to_remote.sh user@host:/path/to/sysml2-nl
# Stop the local queue first, or both machines will generate (and pay for) the same jobs.
set -e
DEST=${1:?usage: sync_to_remote.sh user@host:/path/to/sysml2-nl}
cd "$(dirname "$0")/.."
if pgrep -f "run_stage[12]_.*\.sh|ecir_v3/generate.py" >/dev/null; then
  echo "A local ecir_v3 queue/generate process is still running; stop it first:"; pgrep -fl "run_stage[12]_|ecir_v3/generate.py"; exit 1
fi
R="rsync -az --relative"          # macOS rsync is old: no --info
# v1 Solidity ladder (requirement list + v1 A0 programs reused as U0 sample 1); not in git
$R nl2solidity/ablation/solidity_ablation/ablation "$DEST/"
# retrieval lists, pools, R7 candidates, dense caches; run state (cached generations = resume point)
$R --exclude 'work/' --exclude 'prompts/' ecir_v3/retrieval ecir_v3/runs ecir_v3/analysis "$DEST/"
$R ecir_v3/placeholders.json ecir_v3/placeholders.provenance.json "$DEST/"
echo "done. .env (OPENROUTER_API_KEY) is NOT copied; set it on the remote yourself."
