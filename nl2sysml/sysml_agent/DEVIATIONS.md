# SysMLAgent reimplementation: decisions and deviations

SysMLAgent (Cibrián, Olivert-Iserte, Llorens, Álvarez-Rodríguez, *Computers in Industry* 172
(2025) 104350) has no released code. This file records every choice the paper leaves open, each
fixed before any result was seen, and every place the reimplementation departs from the paper.
It is written to be pasted into a "Reimplementation fidelity" appendix paragraph.

## Taken verbatim from the paper

- **Algorithm 1** (§3.2.3): retrieve context, generate, validate, then while invalid: extract errors,
  build a corrective prompt with the current model and the errors, regenerate, re-validate.
- **System and user prompts** (§3.2.2), character for character, including their grammar
  (`run_sysml_agent.SYSTEM_PROMPT`, `USER_PROMPT`).
- **Context engine** (§3.3): SentenceTransformers embeddings (384-d), cosine similarity against
  stored descriptions, the k = 2 nearest, each hit's SysML v2 model inserted in the prompt, database
  embeddings precomputed.
- **Validator** (§3.4): an ANTLR lexer + parser for the official SysML v2 grammar, a custom error
  listener reporting each error with its location, and a parse-tree listener with the two semantic
  checks the paper names ("identifiers are unique within a given scope", "references point to
  previously defined elements").
- **Sampling**: T = 0.2 on every call (§4.1.3).
- **Evaluation prompts** for the fidelity check: Table 2 (U1–U20), verbatim, in
  `paper_prompts.json` (ids P1–P20, so they cannot collide with the evaluation seeds U1…).

## Decisions for points the paper leaves open (D1–D11 from the brief, as implemented)

| # | Decision as implemented | Note |
|---|---|---|
| D1 | Grammar: ANTLR4 grammar from the `daltskin/sysml-v2-grammar` generator at tag **v2026.05.0 (commit 7292dc3)**, run against the **OMG SysML-v2-Release 2025-12** KEBNF (`generate_grammar.py --tag 2025-12`; 53/54 of the generator's own translation patches apply, see `grammar/PATCHES.md`). Python3 target generated with the ANTLR 4.13.2 tool jar (SHA-256 `eae2dfa1…df4d76`, checked), runtime pinned `antlr4-python3-runtime==4.13.2`. Start rule `rootNamespace`. The generated parser is committed. | **Deviation from the brief's pinning rule.** Our Pilot is at OMG release 2025-10 (+5 commits, `0.54.0-SNAPSHOT`). The OMG release repo publishes the KEBNF only from **2025-12**, so no grammar for 2025-10 (or older) can exist, and "nearest not newer" is impossible. 2025-12 is the nearest release that has a spec grammar. The published daltskin tag `v2025-12` is the generator's first-day output (commit 3c2470e) and predates the maintainer's fixes to the KEBNF→ANTLR translation, so we regenerate 2025-12 with the pinned current generator instead. For scale: its grammar differs from the tag's own 2026-05 grammar by 14 parser lines. The paper's exact grammar is **unknown**; the daltskin repository dates from 2026, after the paper. |
| D2 | Two semantic checks, conservative, run only on syntactically valid input. (a) **Duplicate names:** two declarations whose nearest enclosing namespace is the same one declare the same (regular, else short) name. A namespace is any node that opens a brace (`{…}` bodies, including expression bodies such as `{ in x; … }`), `rootNamespace`, or a transition, which owns its trigger and effect without braces. (b) **Unresolved references:** the first segment of the target of `:` / `defined by` (incl. `~Port`), `:>` / `specializes` on definitions, `:>` / `subsets` and `:>>` / `redefines` must be declared somewhere in the file, be a top-level standard-library package, or be exported by an import in the file. For subsetting and redefinition targets, any name the library declares is also accepted, because those can be features inherited from implicit library supertypes (`Parts::Part`…), which no import brings in. Feature chains check only their head. If any import names a namespace that is neither in the library nor in the file, (b) abstains for that file. Imports anywhere in the file count for the whole file, and declaration order is ignored. | The library symbol table (`library_symbols.py`) comes from parsing the Pilot's `sysml.library` (2025-10-5-g373cd4d2d) with the same grammar. `.kerml` files are parsed through the grammar's KerML rules (`library package` read as `namespace`). For every `.kerml` file and every file with syntax errors, each namespace also exports **all word tokens of its file**: the grammar accepts KerML `feature x : T;` without error but as three separate elements, so declarations there cannot be read off the tree. That over-approximation can only silence (b). |
| D3 | Algorithm 1 as an explicit loop in **one multi-turn conversation** (system, first user turn, then assistant/fixer turns appended; every call resends the whole history). No LangChain ReAct planner. | Mirrors `ConversationBufferMemory`. Assistant turns store the raw reply, as the memory would. |
| D4 | Fixer turn, verbatim from the brief: `The SysML v2 model you generated is not valid. The validator reported the following errors:\n{errors}\nHere is the current model:\n{model}\nFix the errors and return ONLY the corrected SysML v2 code.` Errors are one per line, `line L:C <syntax\|semantic> <message>`, capped at 40 plus `... (N more)`. | Not tuned after the fidelity check failed (see below). Because semantic checks only run on syntax-valid input, a fixer turn lists either syntax errors or semantic errors, never both. |
| D5 | At most **6 fix rounds** (7 calls). | `AgentExecutor.max_iterations = 15`: 1 generate + 1 validate + 6 × (fix + validate) = 14. |
| D6 | The last candidate is kept and scored whether or not it converged. `converged` records ANTLR validity at stop. | Paired comparison needs one output per requirement. |
| D7 | Retrieval database: FORGE's retrieval pool (`agent_rag_moe._collect_examples`: `dataset/data`, first 300 by id) restricted to the official OMG Release split, ids **000001–000250 → 250 entries** (the paper: 92). The description embedded is each sample's `<ID>.txt`. | Every evaluation seed derives from `dataset/data` 000387+ (`dataset_data_id` in `with_kernel_spec/*/meta.json`), so the pool is disjoint from the evaluation set (unit-tested). Our descriptions are long (median 898 characters) paraphrases, whereas the paper's are short "what a user would ask" requests. |
| D8 | `sentence-transformers/all-MiniLM-L6-v2`, normalized embeddings, cosine similarity, ties broken by dataset id. | Query embeddings for all 1,543 evaluation and 20 paper prompts are precomputed (`index/query_emb.npz`) so PACE nodes need no torch; the result is identical to computing them on the fly. |
| D9 | First user turn = paper user prompt, then for each hit `Example i description:\n…\nExample i SysML v2 model:\n…`, then `User input:\n<requirement>`. Retrieved models are inserted whole, never truncated (the largest pool model is 73 k characters). | |
| D10 | If the reply has ``` fences, only the fenced blocks are kept; then `naive_glm_generate._postprocess` (the naive arm's extraction) runs. | Unfenced prose is not stripped, because the naive arm's extraction does not strip it either. |
| D11 | Main run `z-ai/glm-5.2` via OpenRouter, T = 0.2, no top_p. The transport is the hardened one FORGE and best-of-N use (`agent_rag_moe._openrouter_invoke`, extended with a `messages=` argument for multi-turn calls; single-turn behavior is unchanged). Same `max_completion_tokens` (32768) as the other arms. | |

## Additional implementation decisions (fixed before any result)

| # | Decision | Why |
|---|---|---|
| D12 | An **empty candidate is invalid** (`line 1:0 syntax empty model: …`). | The grammar accepts the empty file (`packageBodyElement* EOF`); without this rule an empty reply would "converge". |
| D13 | **Agent_NoRAG** (fidelity check only): same loop, no retrieval, and the user prompt without its retrieval sentence ("In order to help you, I have extracted…"). Nothing else changes. | The paper gives no NoRAG prompt. |
| D14 | ANTLR validation has a **300 s timeout**. A timeout counts as invalid, with one error `validator timed out` (recorded per iteration as `antlr_timeout_by_iter`). | Pathological inputs cannot hang a seed. No curated reference took more than 40 s. |
| D15 | A provider error anywhere in a conversation **discards the seed**, which is redone on resume and never scored (same policy as best-of-N). | Infrastructure, not a model outcome. |
| D16 | After the loop, **our** compiler (`compiler_interface.check_code`, errors only, 120 s timeout as in best-of-N) scores every snapshot. It never feeds back into the loop. | Per-iteration compile curve, plus `validation` for each corpus's `meta.json`. |

## Gate 7.1: validator conformance (386 curated references `dataset/data` 000001–000386)

Pre-registered rule: a semantic check that flags > 2% of the curated references is disabled.
Syntax rejections are reported, and the grammar is not patched.

**Pass 1** (`reports/conformance_pass1.json`): syntax-accept 380/386 (98.4%); duplicates flagged
1.04%; **unresolved references flagged 3.89% → over the limit.**

Before applying the rule, every flag was checked against the Pilot compiler and the source:

- 3 of the 15 unresolved flags were **true positives**: 000254 (`String`, `int` without import) and
  000347 (`Integer`) are rejected by the Pilot with the same "Couldn't resolve reference", and 000376
  is rejected by the Pilot outright. **The brief's premise that all 386 references compile does not
  hold**: the Pilot compiler accepts 290 of them (see below).
- The other 12, plus 3 of the 4 duplicate flags, were **defects in our implementation of D2**, not
  behavior D2 specifies:
  1. KerML library declarations were missing from the symbol table (the three-element `feature`
     misparse above): `baseType` (Metaobjects), `participant` (Links), and `KerML::Kernel::*` members.
  2. Library names that are SysML keywords (`frame`, `accept`) were dropped from the fallback token scan.
  3. Relative re-exports inside library packages were resolved from the wrong namespace.
  4. Scope detection missed expression bodies `{ in x; … }` and transitions, so parameters of two
     different lambdas, or effects of two different transitions, looked like duplicates.

  We fixed these four defects and re-ran. The fixes only change which names count as declared, or
  where namespace boundaries fall. None of them loosens what either check tests.

**Pass 2** (final, `reports/conformance.json`): syntax-accept **380/386 (98.4%)** (official
249/250, community 33/36, pilot 88/90, ESA 10/10); duplicates flagged **0.26%** (1 file);
unresolved references flagged **0.78%** (3 files). No check exceeds the limit, so both checks stay on.
**Every remaining semantic flag falls on a reference the Pilot compiler also rejects**
(000254, 000347, 000376 unresolved; 000270 duplicate: the Pilot rejects that file for unresolved
namespaces). Of the 6 syntax rejections, 5 are files the Pilot compiler also rejects (000253,
000257, 000262, 000288, 000359). The one genuine grammar disagreement is 000086 (line 1546:
`mismatched input ':' expecting {';', '{'}`), which the Pilot accepts. Mean parse + checks 1.9 s,
max 39.5 s.

**Over the references our Pilot compiler actually accepts** (290 of 386, `reports/reference_compile.json`;
the other 96 fail to compile, many because they reference packages from other files of their source
repositories): syntax-accept **289/290 (99.7%)**, semantic false positives **0/290** for both checks
(pass 1: unresolved 12/290 = 4.14%, duplicates 3/290 = 1.03%), fully ANTLR-valid 289/290.

> **Needs sign-off:** the rule was applied after fixing implementation defects rather than to the
> first-pass number. If the stricter reading is preferred ("the check as first implemented flagged
> 3.89%, so disable it"), set `CHECKS = ("duplicates",)` in `antlr_validator.py` and log it here.

## Gate 7.2: fidelity check (GPT-4o-mini, paper prompts, T = 0.2) — FAILED

| Configuration | ANTLR-valid, ours | Paper Table 4 |
|---|---|---|
| SysMLAgent (full) | **65%** (13/20) | 100% |
| LLM_Raw+RAG (= iter-0 of the full run) | 40% (8/20) | 55% |
| Agent_NoRAG | 5% (1/20) | 20% |

The ordering holds (full > Raw+RAG > NoRAG), but the full system is below the pre-registered 80%,
so **the gate fails**. Per the brief the run stopped here, and nothing was tuned. Backbone
`openai/gpt-4o-mini` (= `gpt-4o-mini-2024-07-18`) on OpenRouter. Total cost $0.08.
Outputs: `dataset/sysml_agent_fidelity/{full,norag}/`, summary `reports/fidelity_summary.txt`.

Diagnosis (descriptive only):

- All 7 non-converged full-system seeds (P1, P3, P9, P12, P15, P16, P20) are also rejected by our
  Pilot compiler at the same lines, so the validator is not rejecting valid SysML. The errors are
  genuine non-SysML v2 constructs (`property x : ISQ::power`, calls such as `do log(x)`, `flow … connect`,
  `String` without import).
- The loop stalls: at T = 0.2 the model resubmits the same model (P3: 1 distinct candidate in 7;
  P1: 2 in 7). P1, P3 and P15 end with exactly the error count they started with.
- ANTLR validity is far more lenient than our compiler: 13/20 ANTLR-valid but only 6/20 compile.
- Fix-round distribution (full): 0 rounds ×8, 1 ×4, 2 ×1, 6 (cap) ×7.

## Things the reimplementation cannot reproduce

The paper's grammar version, its 92-model database and its descriptions, its LangChain
prompt/agent scaffolding beyond the two quoted prompts, and its Fixer prompt are unknown.

## Post-gate amendment A1 (registered 2026-09-24, before the re-run below)

**What went wrong.** In the failed run, the Fixer turn gave the model `line L:C <message>` with no
line numbers on the code. GPT-4o-mini could not map `line 21:12 mismatched input 'ratedPower'` to
`property ratedPower : ISQ::power;`, so it returned the model unchanged. P3's first fix reply is
byte-identical to its input.

**Change (D4 amended).** Each reported error is followed by the offending source line with the
offending token underlined by carets:

    line 21:12 syntax mismatched input 'ratedPower' expecting {...}
        property ratedPower : ISQ::power; // in kilowatts
                 ^^^^^^^^^^

This is the canonical ANTLR custom error listener, `underlineError` from Parr, *The Definitive
ANTLR 4 Reference* (2013), §9.2. The paper cites that book for its Validation Engine and describes
the listener as giving "precise feedback … including specific locations of detected issues". The
Fixer prompt wording, the 40-error cap, the prompts, the retrieval and the loop are unchanged.

**Honesty note.** This change was made *after* seeing the gate fail, because of how it failed. It is
the only change. It is not tuned further, whatever the re-run shows.

**Re-run protocol and pass rule (fixed now).** The same 20 paper prompts, GPT-4o-mini, T = 0.2, run as
3 independent repetitions of both the full system and Agent_NoRAG (LLM_Raw+RAG = iter-0 of the full
system). The gate passes if the **mean over the 3 repetitions** has full ≥ 80% ANTLR-valid and
full > Raw+RAG > NoRAG. Every repetition is reported, and the failed first run stays on record above.
If the gate still fails, the full run proceeds with the gap documented, not with more changes.

### Re-run result under A1 — gate 7.2 still FAILS (as registered: proceed, gap documented)

| Configuration (GPT-4o-mini, n = 20) | Rep 1 | Rep 2 | Rep 3 | **Mean** | Paper |
|---|---|---|---|---|---|
| SysMLAgent (full) | 70% | 65% | 65% | **66.7%** | 100% |
| LLM_Raw+RAG (iter-0) | 50% | 45% | 40% | **45.0%** | 55% |
| Agent_NoRAG | 5% | 5% | 5% | **5.0%** | 20% |

The ordering holds in every repetition, but the full system stays below 80%. Summaries are in
`reports/fidelity_a1_summary.txt` and outputs in `dataset/sysml_agent_fidelity_a1/`; the cost was
about $0.25. A1 made the Fixer edit more (more distinct candidates per stalled loop) but did not
change the rate.

Why the gap remains (descriptive):

- The same prompts fail in every run (P1, P3, P9, P12 and P20 in all three; P6, P15 and P16 in
  some). The final errors are real SysML v2 errors: `property x : T` (not a SysML v2 keyword),
  `String` used without `import ScalarValues::*`, undefined metadata `#situation` / `#failure`, and
  unresolved `LogEntry`.
- In all 80 full-system runs (the original plus the three repetitions), **no model the ANTLR
  validator rejected at stop is accepted by our Pilot compiler**, so the validator is not
  rejecting valid SysML.
- The most likely source of the gap is therefore the unrecoverable parts of the original: its
  grammar version, and above all how strict its semantic phase was (a checker that treats `String`
  as built-in, or checks only in-file references, would pass P9, P12 and P20), plus its 92-model
  database with short request-style descriptions. We do not relax our checks to close the gap,
  because that would make the baseline accept models the reference implementation rejects.

## Gate 7.3: GLM-5.2 pilot (20 evaluation ids, stratified by domain, `pilot_ids.txt`)

Outputs are in `dataset/sysml_agent_pilot{,_iter0,_iter1}/` and the summary in `reports/pilot_summary.txt`.
The run used A1.

- Converged (ANTLR-valid at stop): **19/20**. Fix rounds: 0 ×4, 1 ×7, 2 ×1, 3 ×4, 4 ×1, 5 ×2,
  6 ×1. Calls per seed: mean 3.05, median 2, max 7.
- ANTLR-valid by iteration 0…6 (carried forward): 20, 55, 60, 80, 85, 95, 95%.
  Compile-valid (our compiler): 20, 45, 55, 65, 70, 75, 80%. Mean unique compile errors:
  10.2 → 0.8.
- Compiler-valid on the same 20 ids: naive 0/20, **SysMLAgent iter-0 4/20, iter-1 9/20,
  final 16/20**, FORGE 4/20 (best-of-6 so far only has 5 of these ids, 0/5).
- **Model size:** SysMLAgent outputs are much smaller (median 88 non-blank lines vs FORGE 204 and
  naive 351). The paper's prompts do not ask for detailed models; FORGE's and naive's do. Compile
  validity is therefore partly a size effect, which is why the pre-registered primary outcomes are
  kernel, standard rules and spec alignment.
- U488 is the one non-converged seed: its final model is accepted by our compiler but has two
  duplicate feature names (`in item fluid; out item fluid;` in the same part def). The paper's check
  ("identifiers are unique within a given scope") flags this, and our compiler does not report it,
  so the check stays as is. That seed is ANTLR-invalid, compile-valid.
- Cost: $1.53 billed ($0.076 per seed, 30.6 k tokens per seed). Walltime per seed: mean 217 s,
  median 95 s, max 1,159 s.
  **Projection for 1,543 prompts: ≈ $118, ≈ 2.3 h** on 5 shards × 8 seeds in flight, plus the
  tail from slow seeds.
