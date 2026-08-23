# Isaac GPU Handoff

## Required host information

- Linux x86_64;
- an Isaac Sim 6.0-compatible NVIDIA RTX-capable GPU and driver;
- Isaac Sim's `python.sh` path;
- the repository and frozen `execution-input.json`; and
- FMPy installed in the Isaac Python environment, or the FMI runtime Docker
  image when `--controller-backend docker` is used.

Run NVIDIA's Isaac Sim Compatibility Checker before headline experiments.
`nvidia-smi` identifies the device and driver but does not prove RT-core support.

## One command

From the repository root on the GPU machine:

```bash
python3 -m nl2robotics.hybrid.gpu_handoff \
  --bundle outputs/RHY101-isaac-input-v3/execution-input.json \
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
