# DeltaAI Newton H2 Run

This path executes the Modelica-FMU/OpenUSD closed loop on NCSA DeltaAI's
ARM64 Grace-Hopper nodes. It produces Newton Physics evidence, not Isaac Sim or
PhysX evidence.

## Set up once without root

From the repository root on DeltaAI:

```bash
bash nl2robotics/hybrid/deltaai/setup_deltaai.sh
```

DeltaAI currently exposes Apptainer at `/usr/bin/apptainer`; no module load is
required. If a future software stack provides it as a module, loading that
module first remains compatible.

This pulls the official ARM64 OpenModelica SIF and creates the pinned Newton,
Warp, OpenUSD, and FMPy environment in `.deltaai-python`. Newton's native ARM
dependency path uses `usd-exchange==3.0.0` for OpenUSD 26.08. Pinned
micromamba supplies Python 3.11 because the OpenUSD binding needs a shared
libpython and Newton 1.5 relies on Warp array annotations unsupported by Python
3.10. It uses only user-space files; no root, `fakeroot`, proprietary package,
or paid license is required.

## Submit

```bash
sbatch -A YOUR_ALLOCATION nl2robotics/hybrid/deltaai/run_rhy201.sbatch
```

Use the mixed revolute/prismatic multi-joint oracle with:

```bash
ORACLE=RHY202 sbatch -A YOUR_ALLOCATION \
  --job-name=nl2robotics-rhy202 nl2robotics/hybrid/deltaai/run_rhy201.sbatch
```

Use the broad branching oracle with:

```bash
ORACLE=RHY203 sbatch -A YOUR_ALLOCATION \
  --job-name=nl2robotics-rhy203 nl2robotics/hybrid/deltaai/run_rhy201.sbatch
```

After that broad smoke passes, the economical breadth matrix runs RHY201,
RHY202, and RHY203 sequentially with at most one H100 allocated at a time:

```bash
sbatch -A YOUR_ALLOCATION \
  nl2robotics/hybrid/deltaai/run_articulated_study.sbatch
```

The three-task array has a maximum reservation of 1.5 GPU-hours and normally
finishes far below that ceiling. Start with RHY203 alone when debugging cluster
setup so a shared configuration failure does not spend three job allocations.

The job fails before simulation unless it sees ARM64, an H100 or GH200 Hopper
GPU, pinned Newton and Warp versions, CUDA through Apptainer, OpenModelica,
FMPy, and a successful Newton import of the articulated USD stage. The FMU is
exported inside the ARM64 container so its binary matches the DeltaAI host.

Each job writes a unique `outputs/deltaai-ORACLE-JOB_ID` directory containing
preflight evidence, the hashed execution bundle, three traces, STL property
results, repeatability comparison, post-execution alignment, and the final
Newton claim gate. During the Newton process, `nvidia-smi` samples the allocated
GPU every 200 ms. `gpu-memory-summary.json` records the device, total VRAM,
baseline and peak VRAM use, incremental peak, peak utilization, and sampling
window; the raw observations remain in `gpu-memory-samples.csv`.

## Recorded frozen checkpoint

The original frozen RHY201 commit `35049bf24efe29801e124c3abd51624fc04523af`
completed as DeltaAI Slurm job `3046960` on a real NVIDIA GH200 120GB CUDA
device. All three repetitions, both temporal properties, 23/23 grounded
alignment questions, repeatability, and the fail-closed DeltaAI claim gate
passed. The report, untouched evidence archive, checksum, and independent
verification summary are retained in
[`DELTA_AI_JOB_3046960.md`](DELTA_AI_JOB_3046960.md) and
[`evidence/job-3046960/`](evidence/job-3046960/).
