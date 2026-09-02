# Quarantined: generated from corpus-colliding prompts

These entries were generated from seeds naming a protocol whose real source is in
the RAG corpus (Fluid, Predict.fun, GMX, Coinbase, Moonwell). Retrieval could have
returned the actual implementation the prompt asked for, so the pairs are not valid
evaluation samples. The seeds were removed from sol_seed.jsonl by the
`CORPUS_PROTOCOLS` filter in `nl2solidity/sol_seed_generator.py`; their ids are
retired and never recycled. Kept for audit, excluded from results.
