# SysON Live Integration Evidence

Date: 2026-07-08

SysON version: `v2026.5.0`

Runtime: Docker Desktop 4.81.0 on Apple Silicon using the official x86_64 image

Compose source: official `eclipse-syson/syson` `v2026.5.0` release

## Environment proof

The official Compose stack started PostgreSQL and
`eclipsesyson/syson:v2026.5.0`. These endpoints returned HTTP 200:

- `http://localhost:8080/`
- `http://localhost:8080/swagger-ui/index.html`
- `http://localhost:8080/api/rest/projects`

A disposable project named `ToolCallingLiveTest` was created through the
SysML v2 REST API.

## Independent API recipe proof

Before testing repository code, the official API cookbook recipe was exercised
directly:

1. The GraphQL `FetchEditingContext` query returned a real editing-context ID.
2. A multipart request to `/api/graphql/upload` uploaded:

   ```sysml
   package DirectRecipeProof {
       part def Sensor;
   }
   ```

3. SysON returned `UploadDocumentSuccessPayload`.
4. A REST element query found:
   - `Package` named `DirectRecipeProof`
   - `PartDefinition` named `Sensor`

Both had server-generated UUIDs. This proves the SysON instance and documented
upload recipe worked independently of this repository's adapter.

## Repository tool proof

The registered `import_sysml_to_syson` tool uploaded:

```sysml
package ToolCallingDemo {
    part def Vehicle;
}
```

The live result contained:

```json
{
  "ok": true,
  "backend": "syson",
  "available": true,
  "filename": "tool-calling-demo.sysml",
  "verified": true,
  "verification": {
    "element_count_before": 3,
    "element_count_after": 6,
    "added_element_ids": [
      "3b9c6864-e721-4787-92b8-05417d1e7991",
      "bfc68aa0-3e1f-4f07-ac22-925eb308ddb0",
      "d9515f26-fdcc-4f37-aede-316c32a97cd4"
    ]
  },
  "warnings": []
}
```

The three new elements correspond to the package, its owning membership, and
the `Vehicle` part definition.

The repository FastAPI server was then started on a temporary local port.
`GET /api/tools` listed `import_sysml_to_syson`, and
`POST /api/tools/call` imported:

```sysml
package GenericAPIProof {
    part def Controller;
}
```

The HTTP endpoint returned 200 with both the envelope and tool result
`ok: true`; verification observed the element count increase from 21 to 24
with three additional server-generated UUIDs. This proves the live integration
through the public generic tool route, not only through direct Python dispatch.

## Negative live tests

- A nonexistent project ID returned `ok: false`, `available: true`, and
  `error_type: "import_rejected"`.
- With the SysON app container stopped, the tool returned `ok: false`,
  `available: false`, and `error_type: "transport_error"` with connection
  refused. The container was restarted afterward.
- SysON's experimental textual importer accepted malformed input and created
  partial elements. For unmistakable non-SysML text it returned a conversion
  report containing an unresolved-reference warning. The adapter was updated
  after this live observation so report warnings are now surfaced in the
  structured `warnings` list.

The malformed-input behavior means callers should retain the intended workflow:
run `validate_sysml` first, import only validated text, and inspect any SysON
conversion warnings. Import success proves SysON accepted and materialized
content; it does not prove complete semantic equivalence.

## Automated validation after the live test

```text
10 tests passed
python compileall passed
git diff --check passed
```

No credentials were used or stored. All changes were confined to a disposable
local SysON project.
