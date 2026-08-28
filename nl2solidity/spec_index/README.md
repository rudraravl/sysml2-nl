# nl2solidity spec_index

RAG spec chunks live here as `chunks.jsonl` (one JSON record per line:
`{id, title, source, chunk_index, text}`).

DANGLING: this index is empty. Populate it by running
`python3 ../ingest_solidity_spec.py` after dropping Solidity reference material
under `nl2solidity/spec_source/`. Until then `agent_rag_moe._rag_context`
retrieves no spec chunks (returns "" when there are also no dataset examples),
which is harmless — generation proceeds without retrieval.
