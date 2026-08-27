# Modelica Layer 1 Quickstart

## Setup

```bash
git fetch origin
git checkout robotics-modelica-mvp
git pull origin robotics-modelica-mvp
python3 -m pip install -r requirements.txt
```

Start Docker Desktop and place `OPENROUTER_API_KEY` in the repository root
`.env`. The key is never written to a report. The commands below use the API
backend, which routes all experts through OpenRouter and has passed preflight on
the development machine.

## Preflight

This command makes no LLM calls. It audits the corpus, builds a known Modelica
model with OpenModelica, verifies provider routing, and checks credentials and
CLI availability:

```bash
python3 -m nl2robotics.modelica.preflight_layer1 \
  --llm-backend api --backend docker
```

Continue only when the JSON output contains `"ready": true`.

## One-Task Smoke Experiment

This invokes the models and can consume subscription/API usage:

```bash
python3 -m nl2robotics.modelica.evaluate_layer1 \
  --ids RBT-E001 --conditions baseline rag full \
  --llm-backend api --backend docker \
  --output-dir results/modelica-layer1-smoke
```

## Full Held-Out Experiment

```bash
python3 -m nl2robotics.modelica.evaluate_layer1 \
  --conditions baseline rag full \
  --llm-backend api --backend docker --resume \
  --output-dir results/modelica-layer1-full
```

The experiment writes one `model.mo` and `report.json` per task/condition, plus
top-level `results.csv` and `summary.json`. The primary comparison is final
native-build success. The full condition also records its initial build result,
so compiler-repair gain can be measured from the same generation.

To use local subscriptions instead, replace `--llm-backend api` with
`--llm-backend cli` after authenticating both `codex` and `claude`. The Llama
expert still requires `OPENROUTER_API_KEY` in CLI mode.

## No-Cost Regression Commands

```bash
python3 -m unittest discover -v
python3 -m nl2robotics.modelica.validate_layer1 \
  --subset semantic500 --backend docker \
  --output-dir modelica-layer1-validation
```
