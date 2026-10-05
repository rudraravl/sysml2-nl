#!/bin/bash
# Stage 1 without Modelica (R1b, R2-mod deferred). Stops the queue on any abort (exit 3) or crash.
cd "$(dirname "$0")/.."
P=.venv/bin/python
run() { echo "=== $(date '+%F %T') START $*"; $P ecir_v3/generate.py "$@" --workers 8 --min-balance 3; rc=$?
        echo "=== $(date '+%F %T') END $* rc=$rc"; [ $rc -eq 0 ] || { echo "=== QUEUE STOPPED (rc=$rc)"; exit $rc; }; }
run R1 --max-cost 40
run R2 --lang sol --max-cost 25
run R4 --max-cost 50
run R2 --lang sys --max-cost 150
echo "=== $(date '+%F %T') QUEUE DONE"
