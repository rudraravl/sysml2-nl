"""Executable SysON textual SysML import tool."""

from __future__ import annotations

import json
import os
import re
import uuid
from dataclasses import dataclass
from typing import Any
from urllib.parse import urlsplit

import requests


FETCH_EDITING_CONTEXT = """
query FetchEditingContext($projectId: ID!) {
  viewer {
    project(projectId: $projectId) {
      currentEditingContext { id }
    }
  }
}
"""

UPLOAD_DOCUMENT = """
mutation UploadDocument($input: UploadDocumentInput!) {
  uploadDocument(input: $input) {
    __typename
    ... on UploadDocumentSuccessPayload { id report }
    ... on ErrorPayload { messages { body level } }
  }
}
"""

DEFAULT_FILENAME = "generated-model.sysml"
DEFAULT_MAX_BYTES = 1_000_000
_SAFE_FILENAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*\.sysml$")
_SAFE_PROJECT_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")


@dataclass(frozen=True)
class SysONConfig:
    enabled: bool
    base_url: str | None
    token: str | None
    timeout: float
    max_bytes: int

    @classmethod
    def from_env(cls) -> "SysONConfig":
        raw_timeout = os.getenv("SYSON_TIMEOUT_SECONDS", "15")
        raw_max_bytes = os.getenv("SYSON_MAX_MODEL_BYTES", str(DEFAULT_MAX_BYTES))
        try:
            timeout = float(raw_timeout)
            max_bytes = int(raw_max_bytes)
        except ValueError as exc:
            raise ValueError("SYSON_TIMEOUT_SECONDS and SYSON_MAX_MODEL_BYTES must be numeric") from exc
        if timeout <= 0 or max_bytes <= 0:
            raise ValueError("SysON timeout and model-size limit must be positive")
        base_url = os.getenv("SYSON_URL", "").strip().rstrip("/") or None
        if base_url:
            parsed = urlsplit(base_url)
            if parsed.scheme not in {"http", "https"} or not parsed.netloc or parsed.username:
                raise ValueError("SYSON_URL must be an http(s) URL without embedded credentials")
        return cls(
            enabled=os.getenv("SYSON_ENABLED", "false").strip().lower() == "true",
            base_url=base_url,
            token=os.getenv("SYSON_TOKEN") or None,
            timeout=timeout,
            max_bytes=max_bytes,
        )


class SysONClient:
    """Small client implementing SysON's documented GraphQL upload recipe."""

    def __init__(self, config: SysONConfig, session: requests.Session | None = None):
        self.config = config
        self.session = session or requests.Session()

    @property
    def headers(self) -> dict[str, str]:
        headers = {"Accept": "application/json"}
        if self.config.token:
            headers["Authorization"] = f"Bearer {self.config.token}"
        return headers

    def import_document(self, model_text: str, project_id: str, filename: str) -> dict[str, Any]:
        context_id = self._fetch_editing_context(project_id)
        before = self._project_snapshot(project_id)
        operation_id = str(uuid.uuid4())
        operations = {
            "query": UPLOAD_DOCUMENT,
            "variables": {
                "input": {
                    "id": operation_id,
                    "editingContextId": context_id,
                    "file": None,
                    "readOnly": False,
                }
            },
        }
        response = self._request(
            "POST",
            f"{self.config.base_url}/api/graphql/upload",
            data={"operations": json.dumps(operations), "map": json.dumps({"0": "variables.file"})},
            files={"0": (filename, model_text.encode("utf-8"), "text/plain")},
        )
        data = self._json(response, "upload")
        self._raise_graphql_errors(data, "upload")
        payload = data.get("data", {}).get("uploadDocument") or {}
        if payload.get("__typename") != "UploadDocumentSuccessPayload":
            messages = payload.get("messages") or []
            detail = "; ".join(str(item.get("body", item)) for item in messages) or "unexpected upload response"
            raise SysONImportRejected(detail)

        after = self._project_snapshot(project_id)
        before_ids = set(before.get("element_ids", []))
        after_ids = set(after.get("element_ids", []))
        added_ids = sorted(after_ids - before_ids)
        verified = after.get("queried", False) and bool(added_ids)
        report = payload.get("report")
        warnings = []
        if report and any(marker in report.lower() for marker in ("[warning]", "[error]")):
            warnings.append(f"SysON import report: {report}")
        if not verified:
            warnings.append(
                "SysON accepted the upload, but a follow-up REST query did not find newly created elements."
            )
        return {
            "ok": verified,
            "backend": "syson",
            "available": True,
            "project_id": project_id,
            "editing_context_id": context_id,
            "operation_id": payload.get("id") or operation_id,
            "filename": filename,
            "report": report,
            "verified": verified,
            "verification": {
                "queried_via": "SysML v2 REST API",
                "element_count_before": before.get("element_count"),
                "element_count_after": after.get("element_count"),
                "added_element_ids": added_ids,
            },
            "warnings": warnings,
        }

    def _fetch_editing_context(self, project_id: str) -> str:
        response = self._request(
            "POST",
            f"{self.config.base_url}/api/graphql",
            json={"query": FETCH_EDITING_CONTEXT, "variables": {"projectId": project_id}},
        )
        data = self._json(response, "editing-context lookup")
        self._raise_graphql_errors(data, "editing-context lookup")
        project = data.get("data", {}).get("viewer", {}).get("project")
        if not project:
            raise SysONImportRejected(f"SysON project not found: {project_id}")
        context_id = (project.get("currentEditingContext") or {}).get("id")
        if not context_id:
            raise SysONImportRejected(f"SysON editing context not found for project: {project_id}")
        return str(context_id)

    def _project_snapshot(self, project_id: str) -> dict[str, Any]:
        commits = self._request(
            "GET", f"{self.config.base_url}/api/rest/projects/{project_id}/commits"
        )
        commit_data = self._json(commits, "verification commit lookup")
        if not isinstance(commit_data, list) or not commit_data:
            raise SysONVerificationError("SysON returned no commit for the target project")
        commit_id = commit_data[-1].get("@id")
        if not commit_id:
            raise SysONVerificationError("SysON commit response did not contain @id")
        elements = self._request(
            "GET",
            f"{self.config.base_url}/api/rest/projects/{project_id}/commits/{commit_id}/elements",
        )
        element_data = self._json(elements, "verification element lookup")
        if not isinstance(element_data, list):
            raise SysONVerificationError("SysON element response was not a list")
        ids = [str(item["@id"]) for item in element_data if isinstance(item, dict) and item.get("@id")]
        return {"queried": True, "element_count": len(element_data), "element_ids": ids}

    def _request(self, method: str, url: str, **kwargs) -> requests.Response:
        try:
            response = self.session.request(
                method, url, headers=self.headers, timeout=self.config.timeout, **kwargs
            )
        except (requests.ConnectionError, requests.Timeout) as exc:
            raise SysONUnavailable(str(exc)) from exc
        except requests.RequestException as exc:
            raise SysONUnavailable(str(exc)) from exc
        if response.status_code in (401, 403):
            raise SysONAuthenticationError(f"SysON authentication failed (HTTP {response.status_code})")
        if response.status_code >= 400:
            detail = response.text[:500].strip()
            raise SysONAPIError(f"SysON API returned HTTP {response.status_code}: {detail}")
        return response

    @staticmethod
    def _json(response: requests.Response, operation: str) -> Any:
        try:
            return response.json()
        except (ValueError, json.JSONDecodeError) as exc:
            raise SysONAPIError(f"SysON returned non-JSON data during {operation}") from exc

    @staticmethod
    def _raise_graphql_errors(data: Any, operation: str) -> None:
        errors = data.get("errors") if isinstance(data, dict) else None
        if errors:
            messages = "; ".join(str(item.get("message", item)) for item in errors)
            raise SysONAPIError(f"SysON GraphQL {operation} failed: {messages}")


class SysONError(Exception):
    error_type = "api_error"
    available = True


class SysONUnavailable(SysONError):
    error_type = "transport_error"
    available = False


class SysONAuthenticationError(SysONError):
    error_type = "authentication_error"


class SysONAPIError(SysONError):
    pass


class SysONImportRejected(SysONError):
    error_type = "import_rejected"


class SysONVerificationError(SysONError):
    error_type = "verification_error"


def import_sysml_to_syson(
    model_text: str,
    project_id: str,
    filename: str = DEFAULT_FILENAME,
    *,
    config: SysONConfig | None = None,
    session: requests.Session | None = None,
) -> dict[str, Any]:
    """Import textual SysML into a configured SysON project and verify new elements."""

    resolved = config or SysONConfig.from_env()
    _validate_arguments(model_text, project_id, filename, resolved.max_bytes)
    if not resolved.enabled:
        return _failure("SysON integration is disabled; set SYSON_ENABLED=true", "configuration_error", False)
    if not resolved.base_url:
        return _failure("SYSON_URL is required when SysON integration is enabled", "configuration_error", False)
    try:
        return SysONClient(resolved, session=session).import_document(model_text, project_id, filename)
    except SysONError as exc:
        return _failure(str(exc), exc.error_type, exc.available, project_id, filename)


def import_sysml_to_syson_tool(arguments: dict[str, Any]) -> dict[str, Any]:
    """Generic tool-call wrapper."""

    unexpected = set(arguments) - {"model_text", "project_id", "filename"}
    if unexpected:
        raise ValueError(f"import_sysml_to_syson received unknown arguments: {sorted(unexpected)}")
    return import_sysml_to_syson(
        arguments.get("model_text"),
        arguments.get("project_id"),
        arguments.get("filename", DEFAULT_FILENAME),
    )


def _validate_arguments(model_text: Any, project_id: Any, filename: Any, max_bytes: int) -> None:
    if not isinstance(model_text, str) or not model_text.strip():
        raise ValueError("import_sysml_to_syson requires non-empty string argument 'model_text'")
    if len(model_text.encode("utf-8")) > max_bytes:
        raise ValueError(f"model_text exceeds the configured {max_bytes}-byte limit")
    if not isinstance(project_id, str) or not project_id.strip():
        raise ValueError("import_sysml_to_syson requires non-empty string argument 'project_id'")
    if not _SAFE_PROJECT_ID.fullmatch(project_id):
        raise ValueError("project_id must contain only letters, numbers, underscores, and hyphens")
    if not isinstance(filename, str) or not _SAFE_FILENAME.fullmatch(filename):
        raise ValueError("filename must be a safe basename ending in .sysml")


def _failure(
    message: str,
    error_type: str,
    available: bool,
    project_id: str | None = None,
    filename: str | None = None,
) -> dict[str, Any]:
    return {
        "ok": False,
        "backend": "syson",
        "available": available,
        "project_id": project_id,
        "filename": filename,
        "verified": False,
        "error_type": error_type,
        "error": message,
        "warnings": [],
    }
