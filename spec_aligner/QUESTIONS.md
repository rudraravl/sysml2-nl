# Alignment question bank – design notes

`questions.json` is the measurement instrument that replaces the deprecated regex aligner.
Paradigm: **twin-blind QA** (cf. QAGS/QAEval for summarization, TIFA/DSG for text-to-image) –
one LLM answers every question reading ONLY the NL description, another reading ONLY the SysML
code; answer agreement is the alignment signal. Disagreeing questions localize the mismatch and
carry two-sided evidence for repair feedback.

## Architecture

- **Tier 1 – universal** (45 questions, fixed): category-level existence/counting, answerable
  for any sample. The cross-sample-comparable "public ruler". Category weights follow measured
  construct frequency over the 1935 gold models (port 96%, attribute 92%, part def 89%,
  action 88%, requirement 83%, connect 81%, constraint 74%, state 64%, ...).
- **Tier 2 – templates** (27 + 3 distractors, instantiated per sample): a question-writer LLM
  reads BOTH modalities and fills slots, targeting 30–60 instances. This tier reaches fact
  granularity: named entities, containment, connections, values, bounds, transitions.
- **Distractors**: fabricated-fact questions whose true answer is no/not_stated on both sides.
  They never enter the similarity score; they estimate each answerer's hallucination rate
  (reliability gate).

Per sample: 45 + 30–60 + distractors ≈ 80–110 questions.

## Non-negotiable question rules

1. Closed answer space; `not_stated` auto-appended to every question.
2. Atomic – one fact per question (disagreement must be localizable).
3. Neutral vocabulary – phrased in plain domain language; SysML-only facts are described
   functionally (`part def PressureRegulator` → "a pressure regulator"), never by identifier.
4. Options harvested from BOTH modalities for value questions, so a 12V-vs-10V conflict
   surfaces as two different committed options, not two "other"s.
5. `depends_on` skip logic applied at scoring time only (answerers answer everything).

## Answering protocol (asymmetric worldviews)

- **NL answerer – open world**: the text is a partial description; silence → `not_stated`,
  never "no".
- **SysML answerer – closed world**: the code is the complete model; absence → "no"/"none".
  Its prompt carries the SysML v2 notation cheat-sheet (from mycelium-hypha
  `knowledge/textual-notation/index.md`) so `:>>`, `alias`, `connect…to…` are read correctly.
- Both: evidence span mandatory for committed answers, strict JSON.
- **LLM calls go through `codex exec`** (single-shot, read-only sandbox, ChatGPT sign-in – the
  `nl2sysml/ablation_gpt55/batch_codex_gpt55.py` scheme, no API billing). Per modality the question
  list is split into **5 contiguous shards answered by 5 parallel codex processes**.
- **NL answers are cached** per (sample, bank version, question-set hash) and reused across every
  candidate SysML (gold / codex / gpt55 / RAG …) – halves the cost of each additional generator.

## Scoring

Outcome per question (see `scoring.outcome_rules`):

| NL \ SysML       | committed same | committed different | no / none          | not_stated   |
| ---------------- | -------------- | ------------------- | ------------------ | ------------ |
| committed        | aligned 1.0    | **conflict 0.0**    | missing_in_model 0.3 | unverifiable 0.4 |
| not_stated       | –              | extra_in_model 0.85–1.0 | **vacuous – excluded** | **vacuous – excluded** |

- Vacuous agreement is excluded so padding questions cannot inflate similarity.
- `extra_in_model` is judged by the question's `origin` tag: a sysml-origin fact that NL never
  mentioned is legitimate elaboration (credit 1.0), not a defect.
- Similarity `S` = mean credit over scored questions, overall + per-category vector
  (structure / interface / connectivity / attribute / constraint / requirement / state /
  action / classification) – the vector is the radar-chart payload.
- Every non-aligned scored question becomes a mismatch record with two-sided evidence –
  the direct input for repair-feedback generation (grounded in hypha metamodel refs via each
  question's `metamodel_refs`).
- U-GLB-01 (domain) is a canary: disagreement = catastrophic misalignment, reported standalone.

## Validation

1. **Golden set**: the 10 samples drawn with seed 20260708 (same as the legacy regex test,
   incl. 000050); instantiated questions + expected answers hand-reviewed, kept as fixtures.
2. **Perturbation sensitivity**: mutate one fact in an aligned sample's SysML (bound value,
   delete a `connect`, rename a state) – the corresponding question must flip to
   conflict/missing. Automated.
3. **Question health**: per-question vacuous rate (>80% → demote), NL not_stated rate,
   distractor failure rate; prune/rephrase on each version bump. U-CLS-03 (alias, ~4% of
   dataset) is the first candidate under watch.

## Calibration record (loop-until-dry, 2 clean rounds to converge)

Live-calibrated on 7 disjoint random waves of 10 samples each (~6.6k questions answered
twice), seeds 20260708–20260715, each wave's mismatches manually triaged into
genuine-vs-noise before touching the bank:

| Version | Wave (seed) | Key changes driven by that wave's noise |
| --- | --- | --- |
| 0.1.0 | baseline 20260708 | – (mean similarity 0.825 on golden 10) |
| 0.1.1 | – | encoding-equivalence worldview (package-as-system, multiplicity=counts, rule encodings, flow encodings), NL open-world tightening, referent-merged options, REQ-family auto-dependency, coarse count buckets, canary wildcards, deleted U-CLS-03 |
| 0.1.2 | 20260709 (0.932) | numeric equivalence rule, system-wide-count discipline, subtype-vs-'specialized' rewording, short canonical option labels, origin=both gating |
| 0.1.3 | 20260710 (0.940) | deterministic NL remap of `declared_without_value`, T-INT-02 perspective+counterpart rewrite, unit/granularity merging, bare-entity slots |
| 0.1.4 | 20260711 (0.926) | container excluded from counts, deleted U-CST-02/U-REQ-02 (M:N count semantics), ACT-04 branching≠event-wait, canary requires global collapse (<0.7) |
| 0.1.5 | 20260712 (0.930) | ordinal adjacent-bucket partial credit (0.7/low), consistency rule, generic-first payload labels |
| 0.1.6 | 20260713 (0.951) | STA-05 state-name≠behavior discipline, STR-08 modes≠variants, trigger-name merging |
| 0.1.6 | 20260714 **dry 1** (0.853*) | no bank defect – low mean traced to 4 minimal grammar-example models whose NL heavily embellishes (genuine findings) |
| 0.1.6 | 20260715 **dry 2** (0.948) | no bank defect – converged; residual isolated writer merge-slips ≈0.5%, visible with two-sided evidence in reports |

Notable genuine catches during calibration: a one-way endobronchial valve modeled with
symmetric in+out ports (000446), controller command ports lacking conjugation so flows
point backwards (001439, 000416), declared-but-never-connected ports (001394), signals
defined but never sent (001233), missing transition triggers (000438), ESA capability
naming from the ground segment's perspective attached to the spacecraft (000383).

## Worked example – sample 000050 (regex aligner scored 0 matches)

| Question (instantiated) | NL answer | SysML answer | outcome |
| --- | --- | --- | --- |
| How many hardware units does the system contain? | two | two (`p1`, `p2`) | aligned |
| Are the two units of the same kind? | yes ("identical… same design template") | yes (both `: P1`) | aligned |
| Can a port be referred to by more than one name? | yes ("multiple names or aliases") | yes (`alias po1 for porig1`) | aligned |
| Is unit 1 directly connected to unit 2? | yes ("point-to-point link") | yes (`connect p1.po1 to p2.pdest`) | aligned |
| Does the system have a physical breadth dimension? | yes | yes (`attribute b :> breadth`) | aligned |

The failure modes that sank the regex extractor (identifier bridging, `connect`/`alias`
constructs, abstraction asymmetry) are all absorbed by the answerers + protocol.

## Pipeline (implemented; Python 3.10+, use /usr/bin/python3.11 – system python3 is 3.6)

```
bank.py         load + validate questions.json, resolve option sets
instantiate.py  question-writer prompt + strict validation of generated questions
answer.py       twin-blind answering: 5-shard parallel calls, strict answer parsing
score.py        outcome matrix, dependency skip, credits, reliability, mismatches
report.py       JSON + markdown report
llm.py          codex exec single-shot calls (batch_codex_gpt55 scheme)
pipeline.py     compare_pair / compare_files + question & NL-answer caching
cli.py          python3.11 -m spec_aligner.cli --nl f.txt --sysml f.sysml [--cache DIR]
```

Tests (`/usr/bin/python3.11 -m unittest spec_aligner.test_spec_aligner -v`) are fully
deterministic – LLM calls stubbed. The dataset test reuses the legacy seed **20260708**:
identical stub answers on both sides must score 1.0 (self-consistency) and one flipped
SysML answer must be caught (perturbation sensitivity); reports land in `test_result/`.
