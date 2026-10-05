# ecir_v3: missing results for the ECIR 2027 v3 paper (retrieval-utility study)

Code for the v3 runbook ("FORGE v3 (ECIR 2027 short paper) runbook for the missing results",
Sep 30, 2026). It reuses the v1 ladder code (`nl2solidity/`, `nl2sysml/`, `nl2robotics/`) for
prompts, retrievers and scorers. Where the runbook and the existing pipelines disagree, the
existing pipelines win; every such case is listed under **Deviations**.

Run everything from the repo root with the project venv (`.venv/bin/python`; needs `statsmodels`).

## Files

| File | What it does |
|---|---|
| `ecirv3.tex` | The v3 paper template (119 keys: 117 `\tbd`, 2 `\verify`); every key has a producer in `analyze.py` / `stage0.py`. |
| `forge_ecir_tools.py` | The runbook's helper, reconstructed (the original was not delivered): `keys`, `template`, `set`, `fill`, `compare`, `holm`, `selective`, `curve`, `pool`, `rerank-cv`, `rerank-apply`. |
| `common.py` | Paths, ID lists, JSONL I/O, per-requirement seeds, provenance helpers. |
| `corpora.py` | Requirements and exemplar corpora for each language, exactly as the v1 ladder saw them. |
| `retrievers.py` | Binary cosine, BM25 with lineage diversity, and dense retrieval; the SysML spec scorer; pool features. |
| `langs.py` | Per-language A0/A1 prompts (the ladder's own builders), output post-processing, compile/gain scoring, solc error classes. |
| `llm.py` | OpenRouter transport with provider pinning (`allow_fallbacks: false`); logs served provider, usage, finish reason. |
| `stage0.py` | ID lists, retrieval lists (L), the deployed-top-5 check (L2), D2, pools, R7 candidates. |
| `convert_ladder.py` | v1 ladder A0/A1/A3 → `runs/ladder/<lang>/<arm>/results.jsonl` (set-level schema). |
| `generate.py` | All model-call runs: R1, R1b, R2, R4, U0, U1, U2, R7; plus `preflight` and `labels`. |
| `analyze.py` | Every analysis without model calls; writes keys to `placeholders.json` (+ `placeholders.provenance.json`). |
| `ids/` | `ladder500_{sys,sol,mod}`, `pool100_{sol,mod}`, `heldout400_{sol,mod}`. |
| `retrieval/<lang>/` | `{cos,bm25,dense}.jsonl` (top 10 + scores), `pool.jsonl`, `cands_heldout.jsonl`, `sanity_check.json`. |
| `runs/<task>/<lang>/<cond>/` | `outputs/`, `logs/` (prompt, raw completions, compiler/test output), `results.jsonl`, `run_meta.json`. |
| `analysis/` | JSON reports behind every key (Holm families, gate decision, leakage list, harm model, ...). |
| `fig-selective.pdf` | Figure for A2, written next to `ecirv3.tex`. |

## Status (2026-10-05)

Done (no model calls):

| Item | Result |
|---|---|
| ID lists | 500 / 500 / 498 ladder IDs; pools of 100; held-out 400 / 398. |
| L: retrieval lists (cos, BM25) | All three languages, top 10 with scores. Dense lists are **waiting on the D9 model download**. |
| L2 sanity check | Modelica: 432/432 recomputed BM25 top 5 identical to the v1 A1 `retrieved_examples`. SysML v2: 500/500 rebuilt A1 prompts byte-identical to the v1 `generation-{system,user}.txt`. Solidity: v1 logged nothing, but the scorer is deterministic and the corpus is unchanged since the run. |
| v1 → set-level schema | Solidity A0/A1/A3 (solc rescoring agrees with v1 on 1,500/1,500), SysML A1, Modelica A0/A1/A3. |
| Helper self-test | Solidity A0 vs A1: 69.6% vs 58.2%, −11.4 pp. Errors per sample 0.82 vs 1.38. Modelica +13.7 pp. All match v1. |
| D2 | `0.8.28`: every one of the 1,000 A0/A1 contracts resolves to it. |
| A10 | 7 DefiLlama protocols match exemplar source names (each one checked by hand, list in `analysis/A10_leakage.json`); 0 of 1,000 programs are near-duplicates. |
| A14 | Solidity OR 1.30 [0.93, 1.82]; Modelica OR 1.66 [1.06, 2.61]. |
| A1 (A0, A1 arms) | Unresolved imports account for the whole A0→A1 increase. The share is 102.5% because the other classes fell slightly. |
| A2 (Solidity, Modelica) | Selective and oracle rates set. Holm p values are held back until the 11-test family is complete. |

Stage 1 without Modelica, run 2026-10-05 00:53–05:12 (OpenRouter default routing). Every run finished all 500 jobs with 0 infra errors and 0 possibly-billed failures:

| Run | Result (compile-valid) | Calls | Cost |
|---|---|---|---|
| R1 Solidity A1, BM25 + lineage | 59.2% (A0 69.6%: −10.4 pp, raw p = 4.3e-4; vs cos A1 58.2%: +1.0) | 508 | $24.78 |
| R2 Solidity A1, random | 63.2% (vs A1 58.2%: +5.0 pp, CI −0.6 to 10.6, raw p = 0.10) | 505 | $13.03 |
| R4 SysML v2 A0 | 6.8% (A1 15.2%: +8.4 pp, raw p = 1.7e-5) | 523 | $20.34 |
| R2 SysML v2 A1, random | 6.0% (vs A1 15.2%: −9.2 pp, raw p = 9.2e-7) | 545 | $46.90 |
| **Total** | 2,000 generations | 2,081 | **$105.05** (≈ $0.053 per generation; the balance fell $104.06) |

The selective policy does not beat the better fixed policy in any language (sys −0.6, sol +0.4, mod −0.6 pp; all p ≥ 0.25). Suggested switches so far: Rone false, Sel false. Rtwo needs R2 on Modelica.
Still to run: R1b and R2-mod (Modelica, needs Docker), Stage 2 (U0, U1, U2) and R7. The Holm keys stay held back until the two Modelica tests complete the 11-test family.

## Before the paid runs

1. **Provider (D7).** v1 never pinned or logged the provider (`provider_routing: openrouter_default_balanced_with_fallback`), so "the provider GLM-5.2 used in v1" cannot be recovered. Decision (2026-10-05): **keep the existing pipelines' OpenRouter default routing** (no pinning). Every call logs the provider that served it, and `D7.providers` lists those providers. `--provider <name>` still pins one provider with `allow_fallbacks: false`. The pilot was served by Wafer, Together, Morph, DeepInfra (fp4) and InferenceNet, so quantization varies across calls.
2. **Dense model (D9).** `stage0.py retrieval` downloads `BAAI/bge-base-en-v1.5` (about 440 MB) from Hugging Face on first use. Override with `ECIR_DENSE_MODEL`. After that, re-run `stage0.py pools` and `stage0.py cands` so pools include the dense top 5.
3. **Modelica toolchain.** Needs Docker running with `openmodelica/openmodelica:v1.27.0-ompython`, and for gain level 2 the `nl2robotics-fmi-runtime:0.1` image (`nl2robotics/modelica/fmi_runtime/`), or `omc` locally (`ECIR_MODELICA_BACKEND=local`).
4. **Spend guards** (added after an earlier large bill):
   * One completion per job, plus the ladder's single stricter retry on empty, fenced or degenerate output.
   * Rate-limit and 5xx rejections are retried (no completion is produced). Timeouts and dropped connections, which may already have been billed, are retried at most once. A generated program is cached in its log before scoring, so a scorer failure or a resume never pays twice.
   * HTTP 402 stops the whole run, and so does an OpenRouter balance below `--min-balance` (polled every `--credit-poll` s and logged to `analysis/spend_log.jsonl`), or this invocation's spend reaching `--max-cost`. Jobs that never ran write nothing, so re-running the command resumes them.
   * `run_meta.json` records calls, tokens, `cost_usd` (OpenRouter usage accounting) and any possibly-billed failures.
5. **Preflight:** `python ecir_v3/generate.py preflight --provider <P> [--probe]`. It runs compiler controls (a valid and an invalid program must be told apart), checks solc, OpenModelica and forge, and checks the provider is listed. `--probe` makes one paid call.

## Running the runbook

```bash
# Stage 0 (done except dense)
python ecir_v3/stage0.py ids
python ecir_v3/stage0.py retrieval            # add --no-dense to skip D9
python ecir_v3/stage0.py check                # L2; exits non-zero if > 5 lists differ
python ecir_v3/stage0.py d2
python ecir_v3/stage0.py pools && python ecir_v3/stage0.py cands
python ecir_v3/convert_ladder.py --tier-a pool   # Solidity gain 2 (Tier A) for the 100 pooled A0 programs
python ecir_v3/analyze.py a10 && python ecir_v3/analyze.py a14

# Stage 1 (3,000 calls)
python ecir_v3/generate.py R1  --provider P
python ecir_v3/generate.py R1b --provider P
python ecir_v3/generate.py R2  --lang sys --provider P   # and --lang sol, --lang mod
python ecir_v3/generate.py R4  --provider P
python ecir_v3/analyze.py stage1 && python ecir_v3/analyze.py a1

# Stage 2 (~3,150 calls)
python ecir_v3/generate.py U0 --lang sol --provider P    # and --lang mod (see deviation 9)
python ecir_v3/generate.py U1 --lang sol --provider P    # and --lang mod
python ecir_v3/generate.py labels --lang sol             # and --lang mod (needs U0 + U1)
python ecir_v3/generate.py U2 --lang sol --provider P    # and --lang mod
python ecir_v3/analyze.py u2 && python ecir_v3/analyze.py a13   # writes runs/R7/gate_decision.json

# Stage 3 (only for languages with gate "pass": true)
F=cos_score,bm25_score,dense_score,n_imports,pragma_mismatch,n_lines,truncated,same_category
python ecir_v3/forge_ecir_tools.py rerank-apply ecir_v3/runs/U1/sol/labels.jsonl \
    ecir_v3/retrieval/sol/cands_heldout.jsonl $F ecir_v3/runs/R7/sol/top5.jsonl
python ecir_v3/generate.py R7 --lang sol --provider P
python ecir_v3/analyze.py r7

# Wrap-up
python ecir_v3/analyze.py d7 && python ecir_v3/analyze.py switches
python ecir_v3/forge_ecir_tools.py fill ecir_v3/ecirv3.tex ecir_v3/placeholders.json   # writes ecirv3.filled.tex
```

Every generation command takes `--limit N` (pilot on the first N jobs), `--dry-run` (writes prompts, makes no calls), `--workers N` and `--no-gain2`. Runs are resumable: finished jobs are skipped, and infra errors are retried (3 attempts per invocation) before being recorded as `infra_error` and listed in `run_meta.json`.

`analyze.py stage1` writes Holm-adjusted p keys (`R1.sol.p`, `R4.sys.p`, `V.p.*`, `A2.sel.*`, `R2.mingap`) only once all 11 Table 1 tests exist. Interim values sit in `analysis/stage1.json` under `held_back_until_family_complete`.

`ECIR_WORKDIR=<dir>` redirects all outputs (runs, analysis, paper, placeholders) for dry tests; inputs (`ids/`, `retrieval/`) stay in place.

## Definitions in the reconstructed helper

* **compare**: exact McNemar (rates) or Wilcoxon (counts). Percentile bootstrap CI over requirements (10,000 resamples, seed 0). Delta = B − A. Pairs with `infra_error` on either side are dropped; `empty_output` counts as a failure.
* **selective**: the policy retrieves iff the top-1 retrieval score is ≥ t (the paper: "clears a threshold"). t is learned on 9 folds and applied to the 10th (10-fold CV, seed 0); never and always are special cases. Oracle = A0 OR A1. Recovery = (selective − best fixed) / (oracle − best fixed). The p value is McNemar against the better fixed policy.
* **curve**: validity as retrieval is switched on for requirements in descending top-1 score order; dotted lines are the oracles.
* **pool** (also reports retriever-vs-retriever nDCG@5 / Gain@5 differences with randomization p, e.g. dense vs lexical, under `pairs`): Gain@5 = mean gain of a retriever's top-5 pairs (per requirement, then averaged). help/hurt@5 = share of those pairs with gain > g0 / < g0. nDCG@5 uses graded gain (2^g − 1), with the ideal taken over the requirement's whole pool; requirements whose pool is all zero are left out of nDCG. The random block holds the 2 random exemplars. gain − random uses a paired randomization test (10,000 sign flips) and is Holm-adjusted across 3 retrievers × 2 languages in `analyze.py`.
* **rerank-cv / rerank-apply**: logistic regression (multinomial over gain 0/1/2, C = 1) on standardized features, ranking candidates by expected gain (the paper: "logistic regression over the three retrieval scores and exemplar features"); features that are missing or constant are dropped. CV is 5-fold, grouped by requirement (seed 0). It ranks only the retrieved candidates (random exemplars are training labels only, because R7 candidates never include them). Gate: CV nDCG@5 beats the best single retriever with randomization p < 0.05 (raw; the Holm value over the 2-test family is recorded too).

## Deviations from the runbook (existing flow kept)

1. **Modelica prompts.** v1 A0 and A1 sent the *raw request* to the generator (system `TEXT_PREFIX`; user = `SYSTEM_PROMPT` + examples + requirement). Normalization and the contract only gate the cell and drive evaluation. The normalization outcome was computed once and reused by every v1 arm. v3 reuses it: the 66 ladder tasks whose normalization failed are failures in every new arm without a model call, as in v1.
2. **`pool100_mod` is drawn from the 432 normalization-passing tasks** (seed 0). Drawing from all 498 would put about 13 never-generated requirements, with all-zero labels, into the pool. `heldout400_mod` is still the other 398.
3. **Modelica truncation** is the deployed `format_context` rule: the first 100 lines, not 80 non-comment lines. The `truncated` feature uses that rule (more than 100 lines) on Modelica and more than 80 non-blank, non-`//` lines elsewhere.
4. **Modelica BM25 keeps family routing**: 4 of 5 exemplars come from the family's three categories (`ExampleCorpus.retrieve`). Ranks 6–10 continue the k=10 routed list. Binary cosine (R1b) is plain top-5 cosine over exemplar requirement text, the same as the Solidity/SysML scorer. `same_category` = the exemplar's category is one of the family's routed categories.
5. **BM25 for Solidity/SysML** reuses `nl2robotics.retrieval.DiverseBM25` (description + category + tags) with no routing. The lineage is the exemplar's source directory; each Etherscan-sanctuary contract is its own lineage. These corpora have no paraphrase families, so the semantic case is the exemplar itself.
6. **Solidity A1 never had spec chunks**: `nl2solidity/spec_index/chunks.jsonl` was never built. So R2 on Solidity draws 5 random exemplars only. SysML R2 draws 5 random exemplars plus 3 random spec chunks.
7. **Transport.** One call per requirement, plus the ladder's own single stricter retry when the output is empty, fenced or degenerate (counted in `model_calls`). max tokens follow v1: SysML 32,768; Solidity and Modelica no limit. Provider pinning and served-provider logging are new.
8. **Solidity gain 2 = Tier A only.** That means the programmatic fuzz and boundary suite at 64 runs, then `forge build` plus 0 contract defects. v1's "defect-free execution" also counted LLM-written Tier B tests, so these values are not comparable to v1 table rows.
9. **Modelica gain 2** uses the B0 path (`run_compiler_execution_baseline`): FMU export, then a run over the task clock with a finite trace, under the generated top-level model name, so no identity gate applies. **v1 kept only `run.json`.** The v1 A0 `.mo` files are on PACE, under the ablation run's `outputs/…/<task>/rich/A0/repeat-00/artifacts/`. Pass `--v1-mod-artifacts DIR` to U0 to use them as sample 1. Without them, U0 Modelica generates all three samples (+100 calls).
10. **solc** follows `nl2solidity/check_solidity.py`: a per-pragma choice from the PACE-installed set {0.7.6, 0.8.26, 0.8.28} (`ECIR_SOLC_VERSIONS`). `pragma_mismatch` = the exemplar's pragma is not satisfiable by D2 = 0.8.28.
11. **v1 logged no prompts, retrieval IDs or scores (Solidity, SysML), no tokens, no provider, and no OpenModelica messages.** Retrieval is recomputed (and verified by L2). Tokens are null in converted files. Modelica compiler-error fields are null.
12. **A2 runs on all three languages**. The SysML A0 comes from R4.
13. **A14 top-1 score** is the score of the first-ranked exemplar. On routed Modelica lists that is not always the largest score.
14. **g0** is `median_low` of the available U0 samples (the median of 3 when none was infra-excluded).
15. **A10** uses token matching, not substrings. Plain substrings flagged audit-platform labels and generic words (e.g. "Veda" inside "aave-dao"). The rule is in `analysis/A10_leakage.json`. The 7 matches are protocol-adapter contracts (e.g. `PendleLpOracle`, `StakeDAOStrategy`), not copies of the protocol.
16. **SysML evaluator = v1's, no standard library.** The parser jar is tracked in the `sysml2-compiler` submodule (`60a8372`, unchanged since v1). But the CLI loads a standard library from fixed home-directory paths. One exists on this machine (`~/College/SysML-v2-Pilot-Implementation/sysml.library`) and none existed on the v1 machine. With the library loaded, only 11 of v1's 76 valid A1 outputs pass. With `SYSML_COMPILER_LOAD_LIBRARY=false` (now the default in `langs.py`), the 497 v1 A1 outputs reproduce v1's verdicts **and** error counts exactly, 497/497 (`analysis/sysml_evaluator_check.json`). The current `compiler_interface` lost v1's Java guard, so `preflight` runs a valid/invalid control first. `convert_ladder.py --rescore-sys` and `rescore.py` re-score with the current settings if a toolchain changes again.
17. **Provider routing**: see "Before the paid runs", item 1.
