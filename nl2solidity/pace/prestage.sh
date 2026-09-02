#!/bin/bash
# Run ONCE on a PACE login node (which has outbound internet) before submitting.
# Compute nodes may have restricted egress; everything fetched here is cached in
# $HOME so the batch job never needs github.com or binaries.soliditylang.org.
set -euo pipefail

REPO="${REPO:-$HOME/sysml2-nl-creatix}"
cd "$REPO"

# SLURM resolves --output=logs/... before the job script runs, so this must
# exist at submit time or the job dies with no log to explain why.
mkdir -p logs

echo "== 1/5 python venv =="
module load python/3.11 2>/dev/null || echo "  (adjust the module name for your PACE stack)"
python3 -V
[ -d .venv ] || python3 -m venv .venv
./.venv/bin/pip install -q --upgrade pip
./.venv/bin/pip install -q -r requirements.txt
./.venv/bin/pip install -q py-solc-x slither-analyzer python-dotenv

echo "== 2/5 solc binaries (cached in ~/.solcx) =="
./.venv/bin/python - <<'PY'
import solcx
for v in ("0.8.26", "0.8.28", "0.7.6"):
    try:
        solcx.install_solc(v); print("  installed", v)
    except Exception as e:
        print("  FAILED", v, e)
print("  have:", [str(x) for x in solcx.get_installed_solc_versions()])
PY

echo "== 3/5 foundry (forge) =="
if ! command -v forge >/dev/null 2>&1; then
  curl -L https://foundry.paradigm.xyz | bash
  "$HOME/.foundry/bin/foundryup"
fi
export PATH="$HOME/.foundry/bin:$PATH"
forge --version

echo "== 4/5 forge-std (cached in ~/.cache/nl2solidity) =="
./.venv/bin/python -c "
from nl2solidity.solidity_execution.foundry_bridge import ensure_forge_std
print('  forge-std:', ensure_forge_std())"

echo "== 5/5 preflight =="
./.venv/bin/python - <<'PY'
import importlib.util
spec = importlib.util.spec_from_file_location("bg", "nl2solidity/batch_generate.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
m.print_preflight()
PY

echo
echo "Prestage complete. Put OPENROUTER_API_KEY in $REPO/.env (chmod 600, never committed)."
echo "Confirm compute nodes can reach openrouter.ai; if they need a proxy, set"
echo "HTTPS_PROXY in the sbatch script."
