# Executable SysON Import Tool

`import_sysml_to_syson` is a real external tool integration. It uploads textual
SysML v2 to an existing SysON project, accepts success only when SysON returns
`UploadDocumentSuccessPayload`, and then queries SysON's SysML v2 REST API to
confirm that new model elements exist.

A successful end-to-end test against the official SysON `v2026.5.0` Docker
image was completed on 2026-07-08. See `server/SYSON_LIVE_TEST.md` for the
request, server-generated identifiers, verification evidence, and negative
tests.

The existing `validate_sysml` tool exposes this repository's pre-existing
compiler validation. `list_mbse_tools` and `recommend_mbse_tools` only query a
compatibility catalog; they do not execute those products.

## Contract and configuration

Required tool arguments are `model_text` and `project_id`. `filename` is
optional and defaults to `generated-model.sysml`. The filename must be a safe
basename ending in `.sysml`.

Configure the backend process:

```bash
export SYSON_ENABLED=true
export SYSON_URL=http://localhost:8080
export SYSON_TIMEOUT_SECONDS=15
export SYSON_MAX_MODEL_BYTES=1000000
# Optional; never commit a real token:
export SYSON_TOKEN=
```

The integration is off by default and never falls back to a mock or catalog
result. Credentials and authorization headers are not logged.

## Reproducible local setup

This implementation targets SysON `v2026.5.0` and its documented
`uploadDocument` recipe. Install Docker, download the `v2026.5.0`
`docker-compose.yml` linked by the official local-install guide, then run:

```bash
# Required on Apple Silicon because the published image is x86_64.
export DOCKER_DEFAULT_PLATFORM=linux/amd64
docker compose up
```

Open `http://localhost:8080`, create a disposable project, and copy its ID from
the project URL. Confirm these endpoints respond:

```bash
curl -f http://localhost:8080/
curl -f http://localhost:8080/swagger-ui/index.html
curl -f http://localhost:8080/api/rest/projects
```

Official references:

- https://doc.mbse-syson.org/syson/v2026.5.0/installation-guide/how-tos/install/local_test.html
- https://doc.mbse-syson.org/syson/v2026.5.0/developer-guide/api/api-cookbook.html#import-a-sysml-file

## Call the tool

With the backend running:

```bash
curl -sS http://localhost:8000/api/tools/call \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "import_sysml_to_syson",
    "arguments": {
      "project_id": "REPLACE_WITH_PROJECT_ID",
      "filename": "tool-calling-demo.sysml",
      "model_text": "package ToolCallingDemo { part def Vehicle; }"
    }
  }'
```

A verified response has `ok: true`, `backend: "syson"`, `available: true`,
the actual project and editing-context IDs, the upload operation ID and report,
and `verification.added_element_ids` populated by a post-upload REST query.
HTTP success without the documented GraphQL success payload is rejected.
Upload acceptance without newly observed elements returns `ok: false` and a
warning, so it cannot be mistaken for a completed integration.

## Live demonstration checklist

1. Start SysON and create an empty disposable project.
2. Call `validate_sysml` for the demo text.
3. Call `import_sysml_to_syson` with the copied project ID.
4. Save the returned structured evidence and confirm `verified` is `true`.
5. Refresh the SysON project and visually confirm the imported package.
6. Repeat with invalid SysML and an invalid project ID.
7. Stop SysON and repeat; the result must have `available: false` and
   `error_type: "transport_error"`.

Run deterministic tests with:

```bash
cd server/backend
PYTHONPATH=. python3 -m unittest discover -s tests -v
```

## Known limitations

SysON labels textual import experimental. Unsupported concepts may be
incomplete, and referenced SysML/KerML dependencies must be imported first.
Live testing confirmed that malformed input may still be accepted and converted
into partial elements; conversion warnings are returned in SysON's `report`
field and surfaced by this tool in `warnings`. Run `validate_sysml` before
import and treat a warning-free import as distinct from a merely accepted one.
The current verification proves that the target project gained elements; it
does not claim semantic equivalence with every input construct. The tool only
imports into an explicitly supplied existing project and performs no deletion
or arbitrary command execution. SysON does not provide a built-in simulation
capability through this integration.
