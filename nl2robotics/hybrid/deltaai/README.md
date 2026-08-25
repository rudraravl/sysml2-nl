# DeltaAI Newton H2 Run

This path executes the Modelica-FMU/OpenUSD closed loop on NCSA DeltaAI's
ARM64 Grace-Hopper nodes. It produces Newton Physics evidence, not Isaac Sim or
PhysX evidence.

## Set up once without root

From the repository root on DeltaAI:

```bash
module load apptainer
bash nl2robotics/hybrid/deltaai/setup_deltaai.sh
```

This pulls the official ARM64 OpenModelica SIF and installs the pinned Newton,
Warp, OpenUSD, and FMPy packages into `.deltaai-python`. It uses only user-space
files; no root, `fakeroot`, proprietary package, or paid license is required.
`Apptainer.def` is retained as an optional single-image build recipe.

## Submit

```bash
sbatch -A YOUR_ALLOCATION nl2robotics/hybrid/deltaai/run_rhy201.sbatch
```

Use the mixed revolute/prismatic multi-joint oracle with:

```bash
ORACLE=RHY202 sbatch -A YOUR_ALLOCATION \
  --job-name=nl2robotics-rhy202 nl2robotics/hybrid/deltaai/run_rhy201.sbatch
```

The job fails before simulation unless it sees ARM64, an H100, pinned Newton and
Warp versions, CUDA through Apptainer, OpenModelica, FMPy, and a successful
Newton import of the articulated USD stage. The FMU is exported inside the ARM64
container so its binary matches the DeltaAI host.

Each job writes a unique `outputs/deltaai-rhy201-JOB_ID` directory containing
preflight evidence, the hashed execution bundle, three traces, STL property
results, repeatability comparison, post-execution alignment, and the final
Newton claim gate.
