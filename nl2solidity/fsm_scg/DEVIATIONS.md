# FSM-SCG\* reimplementation: deviations from upstream

Upstream: <https://github.com/pluto-ms/FSM-Smart-Contract-Generation>, commit
`9dcd83ed533cc12b6c6b91bdfa0bfc4c3a46c6ea` (2025-02-06). Paper: Luo et al., IJCAI 2025,
arXiv:2505.08542 (`luo2025fsm`).

We run the prompting-only variant, FSM-SCG\*. It uses the same control loop as the fine-tuned
variant (`data/ft_llm_gen_data/_Model.py::generate_use_fsm_scg`), with an off-the-shelf model
and no fine-tuning. The prompts (`utils/prompt_utils.py`), the FSM checks (`utils/fsm_utils.py`),
`extract_fsm`, and Slither's `merge_check_items` are copied verbatim into `upstream_prompts.py`
and `upstream_fsm_utils.py`. Everything else is in `run_fsm_scg.py`. This file lists every place
where we differ from upstream.

Kept as upstream: the system prompt; the with-example prompt pair
(`generate_code_with_fsm_prompt`); one multi-turn conversation whose history accumulates; per-call
`temperature ~ U(0.6, 1.0)` and `top_p ~ U(0.9, 1.0)` rounded to 2 dp; `feedback_count = 1`,
which allows 2 FSM repairs, 1 compile repair and 1 security repair; the FSM acceptance rule (valid,
no unreachable states, **and** a cycle); the text of the FSM repair message; the Slither finding
rules (all detectors except Informational and Optimization, first element per result, line ranges
merged per check type); the final contract is the last code the model returned and is not
recompiled inside the loop; the risk scoring (impact × confidence, 10 when the contract fails).

## A. Upstream bugs we fixed

| # | Upstream behaviour | What we do |
|---|---|---|
| 1 | `_Model` calls `prompt_utils.generate_code_with_fsm`, which does not exist (AttributeError). | Call `generate_code_with_fsm_prompt`. |
| 2 | `validate_fsm` is passed the *string* returned by `extract_fsm`. It would crash on the first index. | Parse with `json.loads`, then fall back to `json_repair.loads`, which the prompt's own format example needs because it contains `//` and `/** */` comments. If neither yields a JSON object, send a repair turn with the upstream header plus `### FSM is not valid JSON: <err>`. This counts against the FSM budget. |
| 3 | In both loops, `response` is undefined when no repair fires (UnboundLocalError). | Keep the last model reply (`response_1` or `response_2`). |
| 4 | The security condition `not (isinstance(check_info, str) and len(check_info) == 0)` is True for an **empty** findings list, so a security turn always fires. | Fire only when the merged findings list is non-empty, as the paper describes. So a seed takes **2–6** calls, not 3–6. |
| 5 | `extract_code` matches only a lowercase ```` ```solidity ```` fence and otherwise returns the whole reply, prose included. | Take the first ```` ```solidity ````/```` ```sol ```` fence in any case, else the first bare fence, else the whole reply. Then apply `naive_glm_generate._postprocess`, which drops stray fence lines and `solidity` tag lines. |
| 6 | When Slither raises, `check_one_by_slither` returns the exception string, which is treated as a finding. `feedback_by_security_risk_prompt` would then iterate over its characters and crash. | Treat a Slither failure as no security feedback. Record `security_feedback: "slither_error"` and the error text. |
| 7 | `extract_fsm`'s regex `^```(StateMachine/json)?` never matches the `json` tag of a ```` ```json ```` fence, so a stray `json` line is left in front of the object. | No extra code. The `json_repair` fallback from fix 2 skips it, so these FSMs are recorded with `parser: "json_repair"`. |
| 8 | `check_reachability_and_cycles` raises when the initial state has no transitions (it is then not a node of the graph, a NetworkXError) and when a state has no `transitions` key (KeyError), although `validate_fsm` accepts both. A missing top-level key (`states`, `initialState`) raises in both checks. | For the first two cases, recompute with every state as a node and a missing transition list read as empty. This returns exactly upstream's answer whenever upstream does not crash. For a missing top-level key or a wrong type, send `### FSM structure error: <exception>` as the repair issue instead of crashing. |
| 9 | When a Slither result's first element has no source lines, `lines[0]` raises (IndexError), which becomes case 6. | Record the finding with `start_line = end_line = 0`. |

## B. Protocol choices

- **Backbone:** `z-ai/glm-5.2` through OpenRouter, the same model and transport as `naive_glm`
  (`naive_glm_generate._openrouter_chat`), and the FORGE combiner. Upstream's paper used
  GPT-4o-class, Llama-3.1-8B and Qwen2.5-7B models.
- **Seeded sampling:** we keep upstream's per-call random temperature and top_p, but seed the RNG
  per sample with `random.Random(int(sha256(sid), 16) % 2**32)`, so a rerun draws the same
  parameters. Every draw is stored in `transcript.json`. The model's outputs are still
  non-deterministic.
- **Empty completions:** an empty reply is re-requested with the same parameters, up to 2 more
  times. After that the seed fails as an infrastructure error. Upstream would crash later on the
  empty string. Seeds that fail on transport or provider errors are never written, and are redone.
- **Solidity version for `{version}`:** `0.8.26`, our `SOLC_DEFAULT_VERSION`. Upstream reads it from
  a `version` field that our seeds do not have.
- **Compiler for feedback:** our `compiler_interface.check_code` (solc standard-JSON, version
  selected by the pragma), with `CompilerResult.format_errors()` as `{error_info}`. Upstream uses
  py-solc-x `compile_source` and passes the raw solc stderr cut from `> stderr:`. The diagnostics
  are the same solc errors, but ours omit warnings and add the offending source line.
  `check_code` also stops before code generation (`SOLC_CODEGEN` is off, as for every arm we
  score), so a "Stack too deep" contract passes it, while upstream's full compile would reject it
  and send a compile-repair turn. In the 500-seed run this affected 3 seeds (U192, U335, U417):
  they passed our check, Slither then failed on them (it needs the full build), so no security
  turn fired (`security_feedback: "slither_error"`).
- **Slither invocation:** the Slither CLI (`slither Candidate.sol --json - --solc <bin>`) with no
  `--exclude`, instead of the Python API with every detector registered. It runs the same detector
  set and applies upstream's filtering and merging. The solc binary is the one our checker picks
  for the pragma (`security_analysis._solc_binary_for`). Upstream uses `solc-select`, taking the
  first `=` pragma, else the first pragma, else 0.8.0. The scratch paths in descriptions are
  rewritten to `Candidate.sol#L`, where upstream shows `temp_sc.sol#L`. We do **not** apply our
  `DEFAULT_EXCLUDED_DETECTORS` or the actionable filter to the feedback.
- **Imports:** upstream rewrites `@openzeppelin` to a local OpenZeppelin checkout. We do not. Every
  arm we compare (naive, Best-of-6, FORGE) is compiled as a single file, and an unresolved import
  fails in all of them the same way. The upstream prompt already asks for a single contract.
- **Unreachable-state list:** upstream formats a Python `set`, whose order depends on the hash seed.
  We print the same `{'A', 'B'}` form, sorted.
- **Loop unrolled:** with `feedback_count = 1`, upstream's `while` loop in
  `check_compilation_and_security` runs one more compile and Slither pass after a security repair.
  That pass checks code that did not change: the security reply is never re-extracted inside the
  loop, so the pass always exits. We unroll the loop and skip the redundant pass. The model calls
  are the same.
- **Requirement text:** `description_long` from `sol_seed.jsonl`, the same prompt source as
  `naive_glm` and `with_kernel_spec` (median 125 words; upstream requirements are 60–150 words).
- **Final validation:** `meta.json`'s `validation` and `errors` come from a fresh `check_code` of the
  final `.sol`, because upstream never compiles the security reply. Scoring then runs our unchanged
  measure-only pipeline (`score_naive_glm.py`: Foundry tiers A and B, Slither, twin-blind aligner,
  zero repair passes).

## C. Upstream quirks kept

- Upstream's own `state_machine_json` format example fails its own `validate_fsm`: `EventC` is a
  trigger but is missing from `events`. We send the example unchanged.
- A security repair's reply is the final code and is never compiled inside the loop, so it can
  break a contract that compiled. `meta.json.validation` reports that honestly, and
  `fsm_scg.compiled_before_security` records the state before the security turn.
- If compilation still fails after the one compile repair, Slither is run anyway. It fails on
  non-compiling code, so no security turn follows (after fix 6).

## D. Metrics (`vrs_metrics.py`)

CPR, VRS, ZRCP and HRCP follow `evaluate/effectiveness/CPR.py` and
`evaluate/security/slither_check.py`, with the finding rules above. CPR uses our `check_code`
instead of py-solc-x. Risk is 10 for a contract that does not compile and, as upstream conflates
the two, for a compiling contract that Slither cannot analyse. We count those separately
(`n_slither_error`). ZRCP and HRCP are computed over analysed contracts, which matches upstream's
denominator.
