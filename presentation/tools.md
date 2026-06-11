# Verification Tools for the NL→SysML v2 Pipeline

This report surveys candidate verification tools that can be bolted onto
the NL→SysML v2 generation workflow. Two categories are covered:

1. **MCMC / probabilistic simulation frameworks** — for parameter
   inference and forward uncertainty propagation on the *attributes*
   of a generated SysML v2 model (failure rates, timings, demands).
2. **Probabilistic model checking** — for formal verification with
   quantitative guarantees on the *behavioral* portion of the model
   (state machines, CTMCs / DTMCs / MDPs / stochastic TA).

All demos share one running example, `tmp/tools/shared/sensor_system.sysml`,
a 2-out-of-3 redundant sensor array whose `ReliabilityReq` states
`P[system operational at t=1000 h] >= 0.99`. This keeps the tools directly
comparable.

---

## Category 1 — MCMC / Probabilistic Simulation Frameworks

The verification question here is:

> Given observed telemetry (e.g., `tmp/tools/shared/failure_log.csv`), is
> the SysML requirement credible under the posterior / propagated
> distribution of the model's uncertain parameters?

### 1.1 Stan
- **What it is.** Mature HMC / NUTS MCMC engine with a dedicated `.stan`
  modeling language and bindings for Python (`cmdstanpy`), R, Julia, etc.
- **How we use it.** `tmp/tools/mcmc_probabilistic/stan/sensor.stan`
  encodes an exponential likelihood on sensor inter-arrivals with a
  Gamma prior on `lambda`; a `generated quantities` block computes
  `p_sys_1000`. `demo.py` samples 8k draws and reports posterior mean /
  90% CI and a PASS/FAIL against `ReliabilityReq`.
- **Strengths.** Best-in-class diagnostics (R-hat, ESS, divergence),
  extremely well-documented, battle-tested on large hierarchical models.
- **Weaknesses.** Compiles a C++ executable per model (slower dev loop),
  no discrete-parameter support, heavier install (cmdstan).
- **Fit for NL2SysML.** Excellent for lifting *attribute* priors from a
  requirements document and posteriorly checking them against logs.
- **Availability.** Stable. `pip install cmdstanpy` (plus a one-time
  `install_cmdstan()` step).

### 1.2 PyMC
- **What it is.** Pure-Python Bayesian framework (PyMC v5 uses the
  PyTensor backend; NUTS and many other samplers built-in).
- **How we use it.** `tmp/tools/mcmc_probabilistic/pymc/demo.py` expresses
  the same model as Stan but as a Python `with pm.Model():` context and
  uses `pm.Deterministic` to derive `p_sys`.
- **Strengths.** No extra toolchain, tight integration with NumPy / Arviz,
  interactive-friendly in notebooks.
- **Weaknesses.** Slower than Stan/NumPyro on very wide/deep hierarchies.
- **Fit for NL2SysML.** Ideal for quick Bayesian sanity checks in
  notebooks alongside the NL2SysML agent output.
- **Availability.** Stable. `pip install pymc`.

### 1.3 NumPyro / Pyro
- **What it is.** Pyro is Uber's probabilistic programming library on
  PyTorch; NumPyro is its JAX-backed sibling with near-identical API and
  dramatically faster NUTS.
- **How we use it.** `tmp/tools/mcmc_probabilistic/numpyro/demo.py`
  expresses the model as a `def model(dt):` function using
  `numpyro.sample` and `numpyro.deterministic`, then runs parallel NUTS
  chains. Switching to Pyro only requires importing `pyro` and
  replacing the MCMC driver.
- **Strengths.** GPU-accelerated, works out-of-the-box with variational
  inference, SVI, normalizing flows — useful if we later train a neural
  surrogate for SysML reliability.
- **Weaknesses.** JAX install is non-trivial on some HPC nodes; Pyro's
  pure-PyTorch variant is slower than NumPyro.
- **Fit for NL2SysML.** The right choice once we scale to hundreds of
  generated models and need vectorized inference.
- **Availability.** Stable. `pip install numpyro` (or `pyro-ppl`).

### 1.4 OpenTURNS
- **What it is.** C++/Python library (EDF + Airbus + Phimeca) specialized
  in *forward* UQ — reliability analysis, Sobol sensitivity, meta-models.
- **How we use it.** `tmp/tools/mcmc_probabilistic/openturns/demo.py`
  wraps `lambda`'s epistemic uncertainty (approx normal around MLE) as an
  `ot.TruncatedDistribution`, propagates through the reliability
  function, and uses `ot.ProbabilitySimulationAlgorithm` to estimate
  `P[ReliabilityReq violated]` with a Monte-Carlo error bound.
- **Strengths.** Rich reliability API (FORM, SORM, subset simulation,
  importance sampling), well-suited to engineering UQ, integrates with
  Salome.
- **Weaknesses.** Not Bayesian — intended for *distributions known in
  advance*. Cannot itself infer `lambda` from logs.
- **Fit for NL2SysML.** Complementary to Stan/PyMC: use MCMC to get a
  posterior on `lambda`, then pipe moments into OpenTURNS for structured
  reliability analyses (sensitivity ranking, FORM).
- **Availability.** Stable. `pip install openturns`.

### 1.5 Dakota (Sandia NL)
- **What it is.** Long-running Sandia National Labs C++ toolkit for UQ,
  optimization, and sensitivity. Driven via a textual input file plus an
  external analysis driver (Python / shell / executable).
- **How we use it.** `tmp/tools/mcmc_probabilistic/dakota/sensor.in`
  declares a normal-uncertain `lambda` variable with
  `response_levels 0.99`. The `reliability_driver.py` is called per
  sample to compute `p_sys` and write it to `results.out`. Dakota
  reports the probability `p_sys` crosses the 0.99 threshold directly.
- **Strengths.** Battle-tested in aerospace/defense, huge catalog of UQ
  methods (LHS, PCE, stochastic collocation, multilevel), integrates with
  HPC job schedulers.
- **Weaknesses.** Heavy install, textual input format is unfriendly,
  interfaces to Python are through files rather than in-process calls.
- **Fit for NL2SysML.** Useful once the pipeline produces safety-critical
  SysML artefacts whose certification evidence has to be generated by an
  "approved" tool (Dakota is commonly accepted by V&V authorities).
- **Availability.** Stable (current release 6.19+). External download;
  not a `pip` package.

### 1.6 UQpy
- **What it is.** Pure-Python UQ library from Johns Hopkins (SURG).
  Covers sampling (MC, LHS, SubSim, MCMC), reliability (FORM, SORM),
  inference, and surrogate modelling.
- **How we use it.** `tmp/tools/mcmc_probabilistic/uqpy/demo.py` samples
  `lambda` around its MLE using `MonteCarloSampling`, propagates through
  the 2-of-3 reliability function, and reports
  `P[ReliabilityReq violated]`.
- **Strengths.** Pure Python, clean object-oriented API, includes
  surrogate methods (Kriging, PCE) that are handy when the reliability
  function is expensive to evaluate.
- **Weaknesses.** Smaller user base than Stan/PyMC/Dakota; some modules
  are research-quality rather than production-hardened.
- **Fit for NL2SysML.** Great glue between a pure-Python NL2SysML
  pipeline and UQ analyses — no external binaries.
- **Availability.** Stable. `pip install UQpy`.

### MCMC / UQ comparison

| Tool       | Bayesian inference | Forward UQ / reliability | Install     | Best for                                                   |
|------------|--------------------|--------------------------|-------------|------------------------------------------------------------|
| Stan       | yes (HMC/NUTS)     | via `generated quantities` | cmdstan + pip | Gold-standard posterior with diagnostics                 |
| PyMC       | yes                | via `Deterministic`      | pip         | Interactive Bayesian checks in notebooks                   |
| NumPyro    | yes (fast NUTS)    | via `deterministic`      | pip + JAX   | Scale to many generated SysML models                       |
| OpenTURNS  | limited            | excellent                | pip         | Structured reliability / sensitivity studies               |
| Dakota     | some               | excellent, HPC-friendly  | binary      | Certification-grade UQ evidence                            |
| UQpy       | some               | good                     | pip         | Pure-Python UQ glue with surrogates                        |

---

## Category 2 — Probabilistic Model Checking

The verification question here is:

> Does the *state-machine* semantics of the generated SysML v2 model
> satisfy a quantitative temporal property such as
> `P>=0.99 [G<=1000 operational]`?

### 2.1 PRISM
- **What it is.** The canonical probabilistic model checker (Birmingham /
  Oxford). Supports DTMC, CTMC, MDP, PTA; query language PCTL / PCTL* /
  CSL.
- **How we use it.** `tmp/tools/model_checking/prism/sensor.prism`
  encodes the 2-of-3 array as a CTMC with three `Sensor` modules;
  `props.pctl` contains both the transient (`P=?`) and boolean
  (`P>=0.99`) forms of `ReliabilityReq`. `run.sh` runs them.
- **Strengths.** Ubiquitous, textbook-standard, GUI for state-space
  exploration, mature symbolic engines (MTBDD).
- **Weaknesses.** Java-based CLI; large state spaces hit memory limits;
  PRISM-format must be generated from SysML v2 (small translator needed).
- **Fit for NL2SysML.** Natural target for a SysML-v2-behavior → PRISM
  back-end; directly encodes reliability / performance requirements.
- **Availability.** Stable. JAR download from prismmodelchecker.org.

### 2.2 Storm
- **What it is.** Modern probabilistic model checker (RWTH Aachen). Reads
  PRISM / JANI, exposes a C++ core and `stormpy` Python bindings.
- **How we use it.** `tmp/tools/model_checking/storm/run.sh` and
  `demo_stormpy.py` reuse `../prism/sensor.prism` verbatim and check the
  same CSL properties via the `storm` CLI or `stormpy.model_checking`.
- **Strengths.** Typically 2-10× faster than PRISM, cleaner CLI, first
  class Python bindings, continuously maintained.
- **Weaknesses.** Fewer GUI tools; building from source on niche
  platforms can be fiddly.
- **Fit for NL2SysML.** Recommended primary back-end: reuse PRISM
  encoders, get better performance, and script everything from Python
  (same ecosystem as the rest of our pipeline).
- **Availability.** Stable. Docker image `movesrwth/storm:stable` or
  `movesrwth/stormpy:ci`.

### 2.3 ePMC — NOT AVAILABLE
- **What it was.** ePMC (née iscasMC) is an extensible probabilistic
  model checker from ISCAS / Saarland. Accepts PRISM-format input.
- **Why it's excluded here.** The official distribution
  (`http://iscasmc.ios.ac.cn/epmc/`) has been intermittently down for
  years; the public source repo (`github.com/liyi-david/ePMC`) has no
  maintained release since 2018 and does not build cleanly against
  current JDKs; no Docker image or Maven artifact is published. We
  therefore cannot produce a reproducible demo.
- **If it returns.** Integration is trivial — it consumes the exact same
  `sensor.prism` + PCTL* property strings as PRISM / Storm. A placeholder
  launcher is kept in `tmp/tools/model_checking/epmc/README.md`.
- **Availability.** **UNAVAILABLE** at the time of writing.

### 2.4 UPPAAL (and UPPAAL SMC)
- **What it is.** UPPAAL (Uppsala / Aalborg) is the de-facto timed-automata
  model checker. UPPAAL SMC extends it to *stochastic* timed automata and
  `Pr[...]` queries via statistical model checking.
- **How we use it.** `tmp/tools/model_checking/uppaal/sensor_system.xml`
  encodes each sensor as a two-location TA with exponential failure /
  repair rates; the `<queries>` block contains `Pr[<=1000] ([] operational())`.
  `run.sh` invokes `verifyta -s`.
- **Strengths.** First-class handling of real-time constraints (SysML
  timing requirements, watchdog timeouts), excellent GUI, SMC scales to
  very large stochastic systems.
- **Weaknesses.** Vanilla UPPAAL *cannot* express probabilistic
  reachability — SMC (commercial UPPAAL Stratego / academic UPPAAL SMC)
  is required. SMC answers are statistical (CIs), not exact.
- **Fit for NL2SysML.** Best when the generated SysML v2 model involves
  non-trivial *timing* (e.g., watchdogs, scheduling, pilot behavior) in
  addition to stochastic transitions.
- **Availability.** Stable. Download from uppaal.org (free academic
  license).

### Model-checking comparison

| Tool     | Input format | Timing | Probabilistic | Python API | Availability |
|----------|--------------|--------|---------------|------------|--------------|
| PRISM    | PRISM        | limited (PTA) | exact + approximate | via CLI | stable |
| Storm    | PRISM / JANI | limited (PTA) | exact + approximate | `stormpy` | stable |
| ePMC     | PRISM        | —      | exact + approximate | — | **UNAVAILABLE** |
| UPPAAL   | XML (TA)     | full   | SMC only            | — | stable |

---

## Recommended integration strategy

1. **Primary stack**: Storm (model checking) + NumPyro (inference) +
   OpenTURNS (forward UQ). All three are pip-installable and scriptable
   from the existing Python pipeline.
2. **Fallback / cross-check**: PRISM for textbook-standard results; Stan
   for high-assurance posteriors when a paper claim needs defending.
3. **Certification-grade**: Dakota when the deliverable requires a
   V&V-approved tool chain.
4. **Timed / real-time SysML v2 models**: UPPAAL SMC.
5. **Skip**: ePMC, until an actively maintained binary reappears.

## Running the demos

Everything lives under `tmp/tools/`:

```
tmp/tools/
├── shared/                        # SysML model + failure log
├── mcmc_probabilistic/            # category 1 demos (6 tools)
└── model_checking/                # category 2 demos (4 tools)
```

Each tool folder has a self-contained `README.md` and either a `demo.py`
or a `run.sh`. The shared `tmp/tools/shared/sensor_system.sysml` is the
only SysML v2 artifact the tools need as input.
