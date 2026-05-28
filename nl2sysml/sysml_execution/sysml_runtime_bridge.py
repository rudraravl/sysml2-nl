"""Phase 3: headless Jupyter SysML kernel execution via jupyter_client / ZeroMQ."""

from __future__ import annotations

import os
import time
from typing import Any, Dict, List, Optional

from .models import KernelExecutionOutput

# OMG SysML Jupyter kernel (Java) emits:
#   - iopub execute_result with content.data["text/plain"] on success
#   - iopub stream (stderr) with "ERROR:..." on parse/semantic failures
# It does NOT reliably populate content["text"] on iopub (unlike IPython).


def _apply_jupyter_path_override(explicit: Optional[str] = None) -> None:
    """
    Optional kernelspec search path override.

    By default KernelManager uses the active Python environment (project ``.venv``),
    where ``jupyter kernelspec install`` registers ``kernels/sysml``. Only set
    ``jupyter_path`` or ``SYSML_JUPYTER_PATH`` for non-standard layouts.
    """
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


def _serialize_message(msg: Dict[str, Any]) -> Dict[str, Any]:
    header = msg.get("header") or {}
    content = msg.get("content") or {}
    return {
        "msg_type": header.get("msg_type"),
        "msg_id": header.get("msg_id"),
        "parent_msg_id": (msg.get("parent_header") or {}).get("msg_id"),
        "content": content,
        "text": _message_text(content),
    }


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
    Headless SysML v2 kernel session: start kernel, execute payload, collect outputs, shutdown.

    The reference Java kernel returns primary output on iopub ``execute_result`` (``text/plain``)
    and diagnostics on iopub ``stream`` stderr (often prefixed with ``ERROR:``).
    """
    _apply_jupyter_path_override(jupyter_path)

    try:
        from jupyter_client.manager import KernelManager
    except ImportError as exc:
        return KernelExecutionOutput(
            execution_status_payload="",
            kernel_available=False,
            bridge_error=f"jupyter_client not installed: {exc}",
        )

    if not _kernel_spec_available(kernel_name):
        hint = (
            f"Jupyter kernelspec '{kernel_name}' not found in the active environment. "
            "From the project root with .venv activated: "
            "``jupyter kernelspec list`` should show sysml under "
            "``.venv/share/jupyter/kernels/sysml``. "
            "Or set SYSML_JUPYTER_PATH to an alternate share/jupyter directory."
        )
        return KernelExecutionOutput(
            execution_status_payload="",
            kernel_available=False,
            bridge_error=hint,
        )

    manager: Optional[KernelManager] = None
    client = None
    raw_messages: List[Dict[str, Any]] = []
    stdout_lines: List[str] = []
    stderr_lines: List[str] = []
    error_lines: List[str] = []
    shell_reply: Optional[Dict[str, Any]] = None

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

            serialized = _serialize_message(msg)
            raw_messages.append(serialized)

            parent_id = serialized.get("parent_msg_id")
            if parent_id and parent_id != msg_id:
                continue

            msg_type = serialized.get("msg_type")
            text = serialized.get("text") or ""
            content = serialized.get("content") or {}

            if msg_type == "stream":
                stream_name = content.get("name", "stdout")
                line = text
                if stream_name == "stderr":
                    stderr_lines.append(line)
                    if line.lstrip().upper().startswith("ERROR"):
                        error_lines.append(line)
                else:
                    stdout_lines.append(line)
            elif msg_type == "error":
                error_lines.append(text or str(content))
            elif msg_type == "execute_result":
                if text.strip():
                    stdout_lines.append(text)
            elif msg_type == "status":
                if content.get("execution_state") == "idle":
                    execute_idle = True

        shell_deadline = time.monotonic() + min(30.0, timeout_sec)
        while time.monotonic() < shell_deadline:
            try:
                shell_msg = client.get_shell_msg(timeout=1.0)
            except Exception:
                break
            if (shell_msg.get("parent_header") or {}).get("msg_id") != msg_id:
                continue
            shell_reply = _serialize_message(shell_msg)
            raw_messages.append(shell_reply)
            reply_text = shell_reply.get("text") or ""
            status = (shell_reply.get("content") or {}).get("status")
            if status == "error":
                error_lines.append(reply_text or "execute_reply status=error")
            elif reply_text.strip():
                stdout_lines.append(reply_text)
            break

        status_payload = "\n".join(
            part.strip()
            for part in stdout_lines + stderr_lines + error_lines
            if part and str(part).strip()
        )
        return KernelExecutionOutput(
            execution_status_payload=status_payload,
            stdout_lines=stdout_lines,
            stderr_lines=stderr_lines,
            error_lines=error_lines,
            raw_kernel_messages=raw_messages,
            shell_reply=shell_reply,
            kernel_available=True,
        )

    except Exception as exc:
        partial = "\n".join(
            p for p in stdout_lines + stderr_lines + error_lines if p
        )
        return KernelExecutionOutput(
            execution_status_payload=partial,
            stdout_lines=stdout_lines,
            stderr_lines=stderr_lines,
            error_lines=error_lines + [str(exc)],
            raw_kernel_messages=raw_messages,
            shell_reply=shell_reply,
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
