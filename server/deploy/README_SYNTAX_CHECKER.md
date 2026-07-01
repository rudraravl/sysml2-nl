# Enabling Syntax Checking on the Cloud Server

The agentic pipeline can validate and refine generated SysML using the SysML v2 parser. By default the backend runs **without** the checker if the compiler is not set up; once the steps below are done, the same frontend "Generate" flow will use the checker automatically.

## What the pipeline does when the checker is enabled

- After the combiner model produces the final SysML, the backend runs the syntax checker.
- If there are errors, it asks the combiner model to fix them (up to `MAX_REFINEMENT_ITERATIONS`, default 2).
- The response includes `syntax_check_available`, `final_valid`, and `final_errors` in the diagnostics.
- The checker is also exposed as a tool call through `GET /api/tools`, `POST /api/tools/call`, and `POST /api/tools/validate_sysml`.

## Tool-calling contract

The preferred MBSE tool backend is the SysML compiler/pilot-style validator wrapped as `validate_sysml`.
The tool uses an OpenAI-compatible function schema so model experts can request validation with a typed payload instead of free-form prose:

```json
{
  "name": "validate_sysml",
  "arguments": {
    "model_text": "package Test {}",
    "syntax_only": true
  }
}
```

The response is structured for repair loops and future MBSE adapters:

```json
{
  "ok": true,
  "backend": "sysml_compiler",
  "available": true,
  "syntax_only": true,
  "error_count": 0,
  "diagnostics": []
}
```

The MBSE compatibility list is roadmap input for adding later adapters such as SysIDE, SysON, Cameo, or PTC. Those tools can plug into the same `validate_sysml` contract without changing the generation pipeline.

For the research MVP, validation is intentionally conservative:

- If `sysml2-compiler` is configured, `validate_sysml` uses it and returns authoritative parser diagnostics.
- If `SYSML_VALIDATOR_URL` is configured, `validate_sysml` can call a REST validator using the same tool contract.
- If no authoritative backend is available, the tool returns `available: false` instead of pretending weak heuristic validation is enough.

## 1. SSH into the server

- Add your SSH key to the `creatix-a100-sysml` machine (as your collaborator set up).
- SSH in. The project is under `~/documents/sysml2-nl` (or `~/document/sysml2-nl` depending on setup).

```bash
ssh <user>@<creatix-a100-sysml-ip-or-host>
cd ~/documents/sysml2-nl   # or ~/document/sysml2-nl
```

## 2. Install Java 21 and Maven

The parser is a Java CLI; the backend runs it via `nl2sysml/compiler_interface.py`.

```bash
# Example on Debian/Ubuntu
sudo apt update
sudo apt install -y openjdk-21-jdk maven
java -version   # should show 21
mvn -version    # 3.6+
```

## 3. Build the parser JAR

From the **project root** (e.g. `~/documents/sysml2-nl`):

```bash
cd sysml2-compiler/sysml-parser-cli
mvn clean package -DskipTests
cd ../..
```

Expected JAR:

- `sysml2-compiler/sysml-parser-cli/target/sysml-parser-cli-1.0.0-shaded.jar`

Optional: if you use the SysML v2 Pilot Implementation library, clone and build it, then set `SYSML_COMPILER_LIBRARY_PATH` (see below). Otherwise syntax-only checking works without it.

## 4. Environment variables (optional)

The backend and `compiler_interface` auto-detect the JAR under the project root. If you need to override or disable the checker, use a `.env` in the **repository root** (same place as `server/`). The backend loads it via `server/backend/app/core/config.py`.

```bash
# In project root: sysml2-nl/.env

# Enable checker (default: true)
SYSML_COMPILER_ENABLED=true

# Refinement attempts after synthesis (default: 2)
MAX_REFINEMENT_ITERATIONS=2

# Syntax-only vs full semantic check (default: false)
COMPILER_SYNTAX_ONLY=false

# Useful MVP mode when the SysML standard library is not installed:
# COMPILER_SYNTAX_ONLY=true
# SYSML_COMPILER_LOAD_LIBRARY=false

# Only if auto-detection fails:
# SYSML_COMPILER_JAR_PATH=/full/path/to/sysml-parser-cli-1.0.0-shaded.jar
# SYSML_COMPILER_LIBRARY_PATH=/path/to/SysML-v2-Pilot-Implementation/sysml.library

# If Java is not on PATH, point directly at a Java 21 home:
# SYSML_COMPILER_JAVA_HOME=/path/to/jdk-21

# Optional alternate backend for a hosted/pilot validator:
# SYSML_VALIDATOR_URL=http://localhost:9000/validate
# SYSML_VALIDATOR_TIMEOUT=30
```

To **disable** the checker on the server:

```bash
SYSML_COMPILER_ENABLED=false
```

## 5. Restart the backend

After any change under `server/backend/` or after building the JAR / changing `.env`:

```bash
cd ~/documents/sysml2-nl/server/deploy
./tmux_start.sh
```

This restarts the FastAPI backend (and frontend). The website will then use the syntax checker when you generate a sample.

## 6. Verify

- Use the frontend at `http://34.7.142.37/` (or your server URL), generate a sample, and check the response/diagnostics for `syntax_check_available: true` and `final_valid` / `final_errors`.
- Or call the API and inspect the JSON for those fields.

## Reference

- Checker interface: `nl2sysml/compiler_interface.py`
- Pipeline integration: `server/backend/app/pipelines/agentic/pipeline.py`
- Full compiler/feedback docs: `nl2sysml/COMPILER_FEEDBACK.md`
