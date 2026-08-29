# Frozen RHY201 DeltaAI checkpoint

Date: 2026-08-29  
Frozen source commit: `35049bf24efe29801e124c3abd51624fc04523af`  
Slurm job: `3046960`  
Allocation: `bhit-dtai-gh`

## Outcome

The frozen RHY201 Modelica/FMI + OpenUSD + Newton workflow completed end to end
on genuine NCSA DeltaAI CUDA hardware:

```text
claim_eligible_h2=true
claim_eligible_newton_h2=true
claim_eligible_deltaai_h2=true
claim_eligible_isaac_h2=false
```

This is Newton Physics evidence. It is not Isaac Sim or PhysX evidence.

| Field | Verified value |
|---|---|
| Slurm | `COMPLETED`, exit `0:0`, 61 seconds |
| Partition / node | `ghx4` / `gh055` |
| Allocation | `gres/gpu=1`, 8 CPUs, 64 GB RAM |
| Accelerator | NVIDIA GH200 120GB, `cuda:0`, SM90 |
| Host | Linux AArch64 |
| Runtime | OpenModelica 1.27.0, FMPy 0.3.29, Newton 1.5.0, Warp 1.16.0 |
| Coupling | FMI 2.0 Co-Simulation, Featherstone, two physics substeps |

## Result

- All 6 fail-closed runtime preflight checks passed.
- The ARM64 FMU passed 7/7 behavioral probes with zero absolute error.
- The OpenUSD stage passed semantic validation with zero errors.
- Three repetitions completed 300 communication steps each.
- The three CSV traces are byte-identical; maximum absolute delta is `0.0`.
- Both temporal properties passed.
- Post-execution alignment satisfied 23/23 grounded questions with no unknowns
  or violations, score `1.0`, and evidence coverage `1.0`.
- The final angle was `0.5235997438430786` rad; effort remained within the
  grounded 5 N.m bound.

## Integrity

The original evidence archive is retained under `evidence/job-3046960/`. Its
SHA-256 is:

```text
813d7869a5d1fcbeea309a17bca9b8fdf5e5743b6fd826afe04f0fde41d790ee
```

An independent verifier rechecked all 35 files in the internal SHA-256
manifest, all execution-input hashes, the FMU metadata and ARM64 binary, every
trace value and bound, every runtime invariant and claim, and the durable Slurm
accounting record. The `sacct` record preserves the job account, GPU allocation,
node, and timestamps. `slurm-job.txt` is empty because the completed job had
already aged out of `scontrol` when the bundle was assembled.

## Compatibility delta

The archived patch records only the narrowly required DeltaAI ARM64 changes:

1. use native ARM64 `usd-exchange==2.2.0` in place of unavailable
   `usd-core==26.3`;
2. expose the extracted ARM64 Python 3.10 shared library inside Apptainer;
3. recognize DeltaAI GH200 alongside H100 as Hopper CUDA provenance; and
4. defer Newton 1.5.0 solver annotations under Python 3.10.

The reconstructed one-line Newton runtime change exactly matches the archived
runtime hash `1ebe7e711d5e97020e654a2d3a96dd67aa58875bf61bc7042e354b1390f6f650`.
No evidence was edited and no validation or claim gate was weakened.

## Files

- `evidence/job-3046960/deltaai-rhy201-3046960-evidence.tar.gz`
- `evidence/job-3046960/deltaai-rhy201-3046960-evidence.tar.gz.sha256`
- `evidence/job-3046960/independent-verification.json`

