# vlm-gen — Multi-Modal SysML v2 Generation (Pass 1)

Hybrid dual-path pipeline: **Path A** (LLM writes Python → sandbox execution → SysML) and **Path B** (direct FM SysML), merged by an **MoE synthesizer**.

## Layout

```
nl2sysml/vlm-gen/sysml_pipeline/
├── config.py
├── main.py                 # run_pass_1()
├── generators/
│   ├── path_a_codegen.py
│   └── path_b_direct.py
├── executors/
│   └── sandbox.py
└── aggregator/
    └── moe_synthesis.py
```

## Prerequisites

- Python 3.10+
- Repo root `.env` with `OPENROUTER_API_KEY` (and optionally `GEMINI_API_KEY` if using Gemini models)
- Same Python deps as `nl2sysml` (`python-dotenv`, `langchain-google-genai`, etc. — see root `requirements.txt`)

## Environment (optional overrides)

| Variable | Default | Role |
|----------|---------|------|
| `VLM_PATH_A_MODEL` | `openai/gpt-5.4` | Path A Python codegen |
| `VLM_PATH_B_MODEL` | `openai/gpt-5.4` | Path B direct SysML |
| `VLM_MOE_MODEL` | `anthropic/claude-sonnet-4.5` | MoE combiner |
| `VLM_SANDBOX_TIMEOUT_SEC` | `45` | Subprocess timeout |
| `VLM_PATH_A_MAX_RETRIES` | `1` | Verifier 1 regeneration count |

## Run

```bash
cd nl2sysml/vlm-gen
PYTHONPATH=. python3 -m sysml_pipeline.main "Model a battery pack with voltage sensor and BMS."
```

Or programmatically:

```python
import asyncio
from sysml_pipeline.main import run_pass_1

result = asyncio.run(run_pass_1("Your requirement here."))
```

From repository root:

```bash
PYTHONPATH=nl2sysml/vlm-gen python3 -m sysml_pipeline.main "Your requirement..."
```

## Reused components

- LLM invoke / postprocess: `nl2sysml/agent_rag_moe.py` (`_invoke_with_retry`, `_postprocess`, `_default_system_prompt`)
- API keys: repo `.env` via `python-dotenv`

Pass 1 does **not** run the SysML compiler refinement loop (that remains in `agent_rag_moe` for later passes).
