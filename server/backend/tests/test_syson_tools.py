"""Tests for the executable SysON tool at the HTTP boundary."""

import os
import unittest
from unittest.mock import patch

import requests

from app.tools.registry import execute_tool_call, list_tool_definitions
from app.tools.schemas import ToolCallRequest
from app.tools.syson_tools import SysONConfig, import_sysml_to_syson


MODEL = "package ToolCallingDemo { part def Vehicle; }"
PROJECT = "project-123"


class FakeResponse:
    def __init__(self, status=200, data=None, text=""):
        self.status_code = status
        self._data = data
        self.text = text

    def json(self):
        if isinstance(self._data, Exception):
            raise self._data
        return self._data


class FakeSession:
    def __init__(self, responses):
        self.responses = list(responses)
        self.calls = []

    def request(self, method, url, **kwargs):
        self.calls.append((method, url, kwargs))
        response = self.responses.pop(0)
        if isinstance(response, Exception):
            raise response
        return response


def config(**overrides):
    values = {
        "enabled": True,
        "base_url": "http://syson.test",
        "token": None,
        "timeout": 2.0,
        "max_bytes": 1000,
    }
    values.update(overrides)
    return SysONConfig(**values)


def context_response():
    return FakeResponse(data={
        "data": {"viewer": {"project": {"currentEditingContext": {"id": "context-456"}}}}
    })


def snapshot_responses(ids):
    return [
        FakeResponse(data=[{"@id": "commit-1"}]),
        FakeResponse(data=[{"@id": item} for item in ids]),
    ]


class SysONToolTests(unittest.TestCase):
    def test_successful_upload_is_verified_by_new_elements(self):
        session = FakeSession([
            context_response(),
            *snapshot_responses(["existing"]),
            FakeResponse(data={"data": {"uploadDocument": {
                "__typename": "UploadDocumentSuccessPayload",
                "id": "operation-789",
                "report": "Imported",
            }}}),
            *snapshot_responses(["existing", "new-package", "new-part"]),
        ])

        result = import_sysml_to_syson(MODEL, PROJECT, config=config(), session=session)

        self.assertTrue(result["ok"])
        self.assertTrue(result["verified"])
        self.assertEqual(result["operation_id"], "operation-789")
        self.assertEqual(result["verification"]["added_element_ids"], ["new-package", "new-part"])
        upload = session.calls[3]
        self.assertEqual(upload[1], "http://syson.test/api/graphql/upload")
        self.assertEqual(upload[2]["files"]["0"][0], "generated-model.sysml")

    def test_disabled_and_missing_url(self):
        disabled = import_sysml_to_syson(MODEL, PROJECT, config=config(enabled=False))
        missing = import_sysml_to_syson(MODEL, PROJECT, config=config(base_url=None))
        self.assertEqual(disabled["error_type"], "configuration_error")
        self.assertFalse(disabled["available"])
        self.assertEqual(missing["error_type"], "configuration_error")

    def test_connection_refused_and_timeout_are_unavailable(self):
        for error in (requests.ConnectionError("refused"), requests.Timeout("slow")):
            with self.subTest(error=type(error).__name__):
                result = import_sysml_to_syson(
                    MODEL, PROJECT, config=config(), session=FakeSession([error])
                )
                self.assertEqual(result["error_type"], "transport_error")
                self.assertFalse(result["available"])

    def test_authentication_and_http_api_errors_are_distinct(self):
        auth = import_sysml_to_syson(
            MODEL, PROJECT, config=config(), session=FakeSession([FakeResponse(401)])
        )
        missing = import_sysml_to_syson(
            MODEL, PROJECT, config=config(), session=FakeSession([FakeResponse(404, text="missing")])
        )
        self.assertEqual(auth["error_type"], "authentication_error")
        self.assertTrue(auth["available"])
        self.assertEqual(missing["error_type"], "api_error")

    def test_graphql_error_and_rejected_import(self):
        graphql = import_sysml_to_syson(
            MODEL,
            PROJECT,
            config=config(),
            session=FakeSession([FakeResponse(data={"errors": [{"message": "bad query"}]})]),
        )
        rejected_session = FakeSession([
            context_response(),
            *snapshot_responses([]),
            FakeResponse(data={"data": {"uploadDocument": {
                "__typename": "ErrorPayload",
                "messages": [{"level": "ERROR", "body": "invalid SysML"}],
            }}}),
        ])
        rejected = import_sysml_to_syson(MODEL, PROJECT, config=config(), session=rejected_session)
        self.assertEqual(graphql["error_type"], "api_error")
        self.assertEqual(rejected["error_type"], "import_rejected")
        self.assertIn("invalid SysML", rejected["error"])

    def test_invalid_arguments(self):
        invalid = [
            ("", PROJECT, "model.sysml"),
            (MODEL, "", "model.sysml"),
            (MODEL, "../project", "model.sysml"),
            (MODEL, PROJECT, "../model.sysml"),
            (MODEL, PROJECT, "model.txt"),
        ]
        for model, project, filename in invalid:
            with self.subTest(filename=filename):
                with self.assertRaises(ValueError):
                    import_sysml_to_syson(model, project, filename, config=config())
        with self.assertRaisesRegex(ValueError, "byte limit"):
            import_sysml_to_syson(MODEL, PROJECT, config=config(max_bytes=2))

    def test_upload_accepted_but_verification_finds_no_new_elements(self):
        session = FakeSession([
            context_response(),
            *snapshot_responses(["same"]),
            FakeResponse(data={"data": {"uploadDocument": {
                "__typename": "UploadDocumentSuccessPayload", "id": "op", "report": None
            }}}),
            *snapshot_responses(["same"]),
        ])
        result = import_sysml_to_syson(MODEL, PROJECT, config=config(), session=session)
        self.assertFalse(result["ok"])
        self.assertFalse(result["verified"])
        self.assertTrue(result["warnings"])

    def test_conversion_report_warnings_are_exposed(self):
        session = FakeSession([
            context_response(),
            *snapshot_responses([]),
            FakeResponse(data={"data": {"uploadDocument": {
                "__typename": "UploadDocumentSuccessPayload",
                "id": "op",
                "report": "[Warning] unresolved reference",
            }}}),
            *snapshot_responses(["partial-element"]),
        ])
        result = import_sysml_to_syson(MODEL, PROJECT, config=config(), session=session)
        self.assertTrue(result["ok"])
        self.assertTrue(result["verified"])
        self.assertIn("unresolved reference", result["warnings"][0])

    def test_registry_lists_and_dispatches_tool(self):
        names = [tool.function.name for tool in list_tool_definitions()]
        self.assertIn("import_sysml_to_syson", names)
        with patch.dict(os.environ, {"SYSON_ENABLED": "false"}, clear=False):
            result = execute_tool_call(
                "import_sysml_to_syson", {"model_text": MODEL, "project_id": PROJECT}
            )
        self.assertEqual(result["backend"], "syson")
        self.assertFalse(result["ok"])


class SysONAPIRouteTests(unittest.IsolatedAsyncioTestCase):
    async def test_generic_api_route_invokes_syson_tool(self):
        from app.api.routes import call_tool

        request = ToolCallRequest(
            name="import_sysml_to_syson",
            arguments={"model_text": MODEL, "project_id": PROJECT},
        )
        with patch.dict(os.environ, {"SYSON_ENABLED": "false"}, clear=False):
            response = await call_tool(request)
        self.assertEqual(response.name, "import_sysml_to_syson")
        self.assertFalse(response.ok)
        self.assertEqual(response.result["backend"], "syson")


if __name__ == "__main__":
    unittest.main()
