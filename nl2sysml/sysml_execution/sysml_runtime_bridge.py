"""Headless Jupyter SysML kernel execution via jupyter_client / ZeroMQ."""

from __future__ import annotations

import json
import os
import time
from typing import Any, Dict, List, Optional

from .models import KernelExecutionOutput


def _apply_jupyter_path_override(explicit: Optional[str] = None) -> None:
    override = explicit or os.environ.get("SYSML_JUPYTER_PATH")
    if not override:
        return
    existing = os.environ.get("JUPYTER_PATH", "")
    parts = [override]
    if existing:
        parts.extend(p for p in existing.split(os.pathsep) if p and p not in parts)
    os.environ["JUPYTER_PATH"] = os.pathsep.join(parts)


def _message_text(content: Dict[str, Any]) -> str:
    if content.get("text"):
        return str(content["text"])
    data = content.get("data") or {}
    if isinstance(data, dict):
        for key in ("text/plain", "text/html"):
            if data.get(key):
                return str(data[key])
    if content.get("ename") and content.get("evalue"):
        return f"{content['ename']}: {content['evalue']}"
    traceback = content.get("traceback")
    if traceback:
        return "\n".join(str(t) for t in traceback)
    return ""


def _trace_entries_from_content(content: Dict[str, Any]) -> List[str]:
    """Extract compiler/kernel trace chunks, preferring structured JSON payloads."""
    data = content.get("data")
    if isinstance(data, dict):
        json_payload = data.get("application/json")
        if json_payload is not None:
            if isinstance(json_payload, (dict, list)):
                return [json.dumps(json_payload)]
            return [str(json_payload)]
        for key in ("text/plain", "text/html"):
            text = data.get(key)
            if text and str(text).strip():
                return [str(text)]

    text = _message_text(content)
    return [text] if text.strip() else []


def _append_trace(trace_chunks: List[str], content: Dict[str, Any]) -> None:
    for entry in _trace_entries_from_content(content):
        trace_chunks.append(entry)


def _kernel_spec_available(kernel_name: str) -> bool:
    try:
        from jupyter_client.kernelspec import KernelSpecManager

        return kernel_name in KernelSpecManager().find_kernel_specs()
    except Exception:
        return False


def execute_sysml_candidate(
    consolidated_payload: str,
    *,
    kernel_name: str = "sysml",
    timeout_sec: float = 120.0,
    jupyter_path: Optional[str] = None,
    kernel_ready_timeout_sec: float = 180.0,
) -> KernelExecutionOutput:
    """
    Start SysML kernel, execute payload, collect stdout/errors, shutdown.
    """
    _apply_jupyter_path_override(jupyter_path)

    try:
        from jupyter_client.manager import KernelManager
    except ImportError as exc:
        return KernelExecutionOutput(
            kernel_available=False,
            bridge_error=f"jupyter_client not installed: {exc}",
        )

    if not _kernel_spec_available(kernel_name):
        return KernelExecutionOutput(
            kernel_available=False,
            bridge_error=(
                f"Jupyter kernelspec '{kernel_name}' not found. "
                "Activate .venv and run: jupyter kernelspec list"
            ),
        )

    manager = None
    client = None
    stdout_lines: List[str] = []
    error_lines: List[str] = []
    trace_chunks: List[str] = []

    try:
        manager = KernelManager(kernel_name=kernel_name)
        manager.start_kernel()
        client = manager.client()
        client.start_channels()
        client.wait_for_ready(timeout=kernel_ready_timeout_sec)

        msg_id = client.execute(consolidated_payload)
        deadline = time.monotonic() + timeout_sec
        execute_idle = False

        while time.monotonic() < deadline and not execute_idle:
            try:
                msg = client.get_iopub_msg(timeout=1.0)
            except Exception:
                continue

            header = msg.get("header") or {}
            parent_id = (msg.get("parent_header") or {}).get("msg_id")
            if parent_id and parent_id != msg_id:
                continue

            msg_type = header.get("msg_type")
            content = msg.get("content") or {}
            text = _message_text(content)

            if msg_type == "status":
                if content.get("execution_state") == "idle":
                    execute_idle = True
                continue

            _append_trace(trace_chunks, content)

            if msg_type == "stream":
                stream_name = content.get("name", "stdout")
                if stream_name == "stderr":
                    error_lines.append(text)
                else:
                    stdout_lines.append(text)
            elif msg_type == "error":
                error_lines.append(text or str(content))
            elif msg_type == "execute_result":
                if text.strip():
                    stdout_lines.append(text)
            elif msg_type == "display_data":
                if text.strip():
                    stdout_lines.append(text)

        shell_deadline = time.monotonic() + min(30.0, timeout_sec)
        while time.monotonic() < shell_deadline:
            try:
                shell_msg = client.get_shell_msg(timeout=1.0)
            except Exception:
                break
            if (shell_msg.get("parent_header") or {}).get("msg_id") != msg_id:
                continue
            content = shell_msg.get("content") or {}
            reply_text = _message_text(content)
            status = content.get("status")
            _append_trace(trace_chunks, content)
            if status == "error":
                error_lines.append(reply_text or "execute_reply status=error")
            elif reply_text.strip():
                stdout_lines.append(reply_text)
            break

        return KernelExecutionOutput(
            stdout=stdout_lines,
            errors=error_lines,
            trace=trace_chunks,
            kernel_available=True,
        )

    except Exception as exc:
        trace_chunks.append(str(exc))
        return KernelExecutionOutput(
            stdout=stdout_lines,
            errors=error_lines + [str(exc)],
            trace=trace_chunks,
            kernel_available=False,
            bridge_error=str(exc),
        )
    finally:
        if client is not None:
            try:
                client.stop_channels()
            except Exception:
                pass
        if manager is not None:
            try:
                manager.shutdown_kernel(now=True)
            except Exception:
                pass
