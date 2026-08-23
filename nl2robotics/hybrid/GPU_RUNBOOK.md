# Isaac GPU Handoff

## Required host information

- Linux x86_64;
- an Isaac Sim 6.0-compatible NVIDIA RTX-capable GPU and driver;
- Isaac Sim's `python.sh` path;
- the repository and frozen `execution-input.json`; and
- FMPy installed in the Isaac Python environment, or the FMI runtime Docker
  image when `--controller-backend docker` is used.

Run NVIDIA's Isaac Sim Compatibility Checker before headline experiments.
The handoff rejects known non-RT accelerators and unknown GPU families, but the
Compatibility Checker remains the final hardware gate.

NCSA DeltaAI is not a valid host for this checkpoint: its Grace CPU is ARM and
its H100 GPU has no RT cores. A regular NCSA Delta `gpuA40x4` allocation is a
candidate because those nodes are x86_64 and have A40 RT cores, subject to the
Compatibility Checker and Isaac Sim availability. The lowest-risk cloud route
is NVIDIA's Isaac Sim 6.0 AWS workstation on `g6e.2xlarge` (L40S).

## One command

From the repository root on the GPU machine:

```bash
python3 -m nl2robotics.hybrid.gpu_handoff \
  --bundle outputs/RHY101-isaac-input-v4/execution-input.json \
  --output-dir outputs/RHY101-isaac-handoff \
  --isaac-python /opt/isaacsim/python.sh \
  --controller-backend local \
  --device cpu --solver TGS --repetitions 3
```

Add `--dry-run` to check the bundle, OS, GPU visibility, launcher, and Python
dependencies without starting Isaac. The handoff captures preflight evidence,
the exact command, simulator stdout/stderr, three run directories, repeatability
results, post-execution semantic alignment, and the final claim gate. The bundle
must use schema 1.1 and contain successful contract and active controller-law
preflight evidence.

Never substitute the deterministic reference backend for a failed Isaac run.
The report is H2-eligible only when real Isaac provenance is present, all three
runs and properties pass, and traces agree within tolerance.
The adapter reapplies effort on every physics substep to preserve the frozen
zero-order-hold coupling semantics.
