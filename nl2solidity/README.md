# nl2solidity

NL → Solidity smart-contract generation pipeline. This is a retargeted copy of
`nl2sysml/`: the same Mixture-of-Experts (MoE) synthesis + iterative-refinement
framework, aimed at Solidity instead of SysML v2.

## Pipeline (identical control flow to nl2sysml)

```
NL requirement
   │
   ▼
RAG context   ← dataset/data/*.sol examples + spec_index/chunks.jsonl   [DANGLING samples]
   │
   ▼
MoE experts (parallel, OpenRouter)  →  combiner synthesis
   │
   ▼
compiler refine (solc --standard-json)                       [WIRED]
   │
   ▼
execution refine (Foundry)                                   [WIRED]
   ├─ Tier A: programmatic fuzz + boundary probing of the ABI
   └─ Tier B: requirement-derived properties + invariants
   │
   ▼
security analysis (Slither / Aderyn)                         [WIRED]
   │
   ▼
semantic spec-mismatch align + repair (spec_aligner)  [TWEAKABLE spec matching]
   │
   ▼
final Solidity + prompt_record
```

Each stage degrades gracefully: when the compiler or runner is unavailable, its
refine loop is skipped (exactly how nl2sysml behaves without its JAR / Jupyter
kernel), so the MoE + alignment path runs end to end regardless.

## Files

| File | Role | Status |
| --- | --- | --- |
| `agent_rag_moe.py` | MoE generation engine. Public entry: `generate_solidity_moe(nl) -> (code, record)` | transcribed |
| `batch_generate.py` | Parallel batch runner (claim/resume/stats), writes `{id}.sol`/`{id}.txt`/`meta.json` | transcribed |
| `quality_gate.py` | Post-generation validate→execute→align→repair gate | transcribed |
| `compiler_interface.py` | `solc` wrapper — identical API to nl2sysml | wired |
| `check_solidity.py` | `solc --standard-json` driver + CLI (analog of `sysml2-compiler/check_sysml.py`) | wired |
| `test_compiler_interface.py` | compiler-check tests (skip when solc is absent) | wired |
| `solidity_execution/` | Foundry harness: extractor → vector_planner → harness_builder → foundry_bridge → orchestrator | wired |
| `security_analysis.py` | headless Slither/Aderyn pass with impact filtering | wired |
| `test_execution.py` | execution + security tests (skip when the toolchain is absent) | wired |
| `spec_index/chunks.jsonl` | RAG spec chunks (Solidity docs) | **DANGLING** empty |
| `dataset/data/` | RAG example pairs `(NL, .sol)` | **DANGLING** to collect |
| `sol_seed.jsonl` / `dataset.json` | seed prompts (samples included) | sample data |
| `ingest_solidity_spec.py` | build `spec_index` from Solidity docs | stub |

## Dangling pieces (intentionally left for you)

1. **RAG samples** — collect `(NL, .sol)` pairs under `dataset/data/<id>/` and/or
   run `ingest_solidity_spec.py` to fill `spec_index/chunks.jsonl`.
2. **Spec matching** — `quality_gate.py` reuses `spec_aligner` unchanged. Its
   question bank / RUNTIME profile is SysML-flavored; tune it for smart-contract
   semantics.

## Compiler check (solc)

The compiler stage is wired. `check_solidity.SolidityChecker` drives
`solc --standard-json` and returns structured diagnostics; `compiler_interface`
adapts them to the same `CompilerResult` the SysML pipeline uses, so
`_refine_with_compiler` feeds real solc errors back to the combiner.

Setup (one time):

```bash
../.venv/bin/python3 -m pip install py-solc-x
../.venv/bin/python3 -c "import solcx; solcx.install_solc('0.8.26')"
```

A system `solc` on `$PATH` works too and takes precedence via `SOLC_BIN`.
With py-solc-x available, the compiler version is chosen per candidate from its
`pragma solidity` line and downloaded on demand; without it, the newest binary
in `~/.solcx` is used and a mismatched pragma simply surfaces as a solc error.

Check a file directly:

```bash
python3 -m nl2solidity.check_solidity Token.sol            # full analysis
python3 -m nl2solidity.check_solidity Token.sol --syntax-only --warnings
```

Run the tests (they skip, not fail, when solc is missing):

```bash
../.venv/bin/python3 -m pytest nl2solidity/test_compiler_interface.py -v
```

| Env var | Default | Effect |
| --- | --- | --- |
| `SOLC_COMPILER_ENABLED` | `true` | `false` disables the compiler stage entirely |
| `SOLC_BIN` | — | pin one binary (disables pragma-based selection) |
| `SOLC_DEFAULT_VERSION` | `0.8.26` | version used when a source has no pragma |
| `SOLC_AUTO_INSTALL` | `true` | `false` forbids downloading a missing version |
| `SOLC_EVM_VERSION` | solc default | `settings.evmVersion`, e.g. `cancun` |
| `SOLC_INCLUDE_WARNINGS` | `false` | report warnings alongside errors (never invalidate) |
| `SOLC_CODEGEN` | `false` | also run codegen, catching stack-too-deep |
| `SOLC_TIMEOUT_SEC` | `60` | per-invocation timeout |
| `SOLC_COMPILER_MAX_CONCURRENCY` | `4` | parallel solc processes across batch workers |

Default mode is analysis-only (parse + resolve + typecheck), which catches every
error that matters for "does this compile" without paying for codegen.
`syntax_only=True` maps to `settings.stopAfter = "parsing"`.

### Toolchain

```bash
brew install foundry                                   # forge (execution)
../.venv/bin/python3 -m pip install slither-analyzer   # security analysis
```

forge-std is cloned once on first use into `~/.cache/nl2solidity/forge-std`
(override with `FORGE_STD_PATH`, disable with `FORGE_STD_AUTO_CLONE=false`).
Every stage degrades gracefully: with no `forge` the execution refine is skipped,
with no analyzer the security pass is skipped, exactly as nl2sysml behaves
without its JAR or Jupyter kernel.

## Dynamic execution (Foundry)

Stage 2 runs the candidate, it does not just boot it. `solidity_execution`
mirrors the SysML module's flow — `extract_topology` → `vector_planner` →
`harness_builder` → `foundry_bridge` → `orchestrator` — with the Jupyter kernel
replaced by a throwaway Foundry project and two harness tiers.

### Tier A — programmatic fuzzing (prompt-independent)

The candidate's ABI (from solc) drives generation of a `.t.sol` that fuzzes every
external mutating function over its full parameter domain, plus explicit boundary
tests at `0`, `1`, `type(uintN).max`, `address(0)`, `address(this)`, empty
bytes/arrays. Payable functions are fuzzed over `msg.value` too.

**How a revert is judged is the whole game.** Two rules keep this signal rather
than noise:

1. A contract that reverts on bad input is *correct*. Every call is wrapped in
   try/catch: `require`/`revert`/custom errors pass, and only Solidity `Panic`
   codes — compiler-inserted invariant violations — can fail a test.
2. Under Solidity ≥0.8 an arithmetic `Panic` at `type(uint256).max` *is* the
   safety net working. So the probes judge arithmetic differently: fuzz tests
   `bound()` numeric inputs to a plausible magnitude (`FUZZ_NUMERIC_BOUND`,
   default `1e30`) and fail on any panic inside it, while boundary tests push
   past that range and tolerate `0x11`/`0x12` while still failing on logic
   panics (`0x01` assert, `0x21` enum, `0x31`/`0x32` array bounds).

Without rule 2 every correct ERC20 fails, because `totalSupply += type(uint256).max`
reverts. With it, a genuine unchecked underflow is still caught with the exact
counterexample that triggered it.

### Tier B — requirement-derived properties

During generation the combiner is asked for 3–6 Foundry test functions written
from the **NL requirement** (with the contract source marked "for reference
only"): accounting assertions, `vm.prank` + `vm.expectRevert` access-control
checks, state-transition properties, and `invariant_*` functions for stateful
fuzzing. They are authored once and then **held fixed** for the rest of the run —
including the post-alignment revalidation — so a repair cannot pass by weakening
its own test.

Before they cost a fuzz campaign the properties are compile-checked with a bare
`forge build` (`validate_property_tests`), and the model gets one round to fix
its own test code — in a live run the only defect in six otherwise sound
properties was `address(0xAB1T3R)`, an invalid hex literal. Properties that still
do not compile are dropped rather than shipped, so they cannot be re-reported as
a harness defect on every later execution. Only the tests are repaired here,
never the contract: repairing the contract from a failing property would let the
two be "fixed" into agreement with each other instead of with the requirement.

Tier B is evidence, not proof: the same model wrote the contract and the
properties, so a failing property may mean the property is wrong. Treat it as a
signal that model and requirement disagree somewhere, and note that a passing
`invariant_` whose calls nearly all reverted has explored very little — those are
flagged as `low_coverage_invariants` in the diagnostics.

### Fault isolation

Foundry builds the whole project at once, so a Tier B file that does not compile
would normally fail the build and discard the fuzz results too. When every build
error is inside the property file the run is retried with Tier A alone, and the
failure is recorded as a *harness* defect (`harness_defects`) rather than a
contract defect. Only `contract_defect` records are ever fed to the repair loop.

```bash
# Run the harness against one file
python3 -m nl2solidity.solidity_execution.orchestrator Token.sol --fuzz-runs 512
python3 -m nl2solidity.solidity_execution.orchestrator Token.sol --dry-run   # show the harness
python3 -m nl2solidity.solidity_execution.orchestrator Token.sol --properties props.sol
```

| Env var | Default | Effect |
| --- | --- | --- |
| `KERNEL_FEEDBACK_ENABLED` | `true` | `false` skips the whole execution stage |
| `FUZZ_RUNS` | `256` | random inputs per fuzzed function |
| `FUZZ_NUMERIC_BOUND` | `1e30` | plausible magnitude for bounded numeric fuzzing |
| `INVARIANT_RUNS` / `INVARIANT_DEPTH` | `64` / `32` | stateful invariant campaign size |
| `PROPERTY_TESTS_ENABLED` | `true` | `false` disables Tier B |
| `MAX_PROPERTY_REPAIR_ITERATIONS` | `1` | rounds allowed to fix non-compiling properties |
| `MAX_KERNEL_REFINEMENT_ITERATIONS` | `2` | execution-feedback repair rounds |
| `SOLIDITY_RUNNER_MAX_CONCURRENCY` | `3` | parallel forge processes across batch workers |
| `FORGE_BIN` / `FORGE_STD_PATH` | auto | pin the forge binary / forge-std checkout |
| `SOLIDITY_RUNNER_ENABLED` | `true` | `false` reports the runner unavailable |

Cost scales as `fuzz_runs × fuzzable functions × candidates`. 256 runs is
Foundry's own default and is a reasonable batch setting; 5000+ is an audit
setting and will dominate batch wall-clock.

## Security analysis (Slither)

Stage 3 runs before the expensive spec-alignment evaluator, so a contract with a
high-severity vulnerability is repaired first. Findings carry the detector name
and line number and are fed straight into the repair prompt.

Filtering is what makes this usable: Slither ships ~90 detectors, most of them
project hygiene (naming conventions, solc version, dead code). Only High/Medium
**impact** findings with High/Medium **confidence** trigger a repair; everything
else is recorded for analysis only. A repair is kept only if it strictly reduces
the actionable findings and still compiles — static analyzers have false
positives, and a model told to "fix" one can otherwise churn or make things worse.

```bash
python3 -m nl2solidity.security_analysis Token.sol          # actionable findings
python3 -m nl2solidity.security_analysis Token.sol --all --json
```

| Env var | Default | Effect |
| --- | --- | --- |
| `SECURITY_ANALYSIS_ENABLED` | `true` | `false` skips the stage |
| `SECURITY_ANALYSIS_TOOL` | `slither` | `aderyn` to use Aderyn instead |
| `SECURITY_EXCLUDED_DETECTORS` | see module | comma-separated detector exclusions |
| `MAX_SECURITY_REFINEMENT_ITERATIONS` | `1` | security repair rounds |
| `SECURITY_TIMEOUT_SEC` | `180` | per-contract analyzer timeout |
| `SLITHER_BIN` / `ADERYN_BIN` | auto | pin the analyzer binary |

## Usage

```bash
cd /Users/rudraraval/College/sysml2-nl/nl2solidity
source ../.venv/bin/activate

# Single requirement
python3 agent_rag_moe.py "Create an ERC20 token with a fixed supply"

# One-shot batch from dataset.json → result_rag_moe/
python3 agent_rag_moe.py

# Full batch from sol_seed.jsonl
python3 batch_generate.py --num-entries 5 --prompt-source seed
```

See `BATCH_GENERATION.md` for the full batch guide (workers, resume, rate
limits, quality-gate controls). Requires `OPENROUTER_API_KEY` in the repo `.env`.
