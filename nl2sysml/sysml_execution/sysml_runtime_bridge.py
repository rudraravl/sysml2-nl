"""Phase 3: headless Jupyter SysML kernel execution via jupyter_client / ZeroMQ."""

from __future__ import annotations

import time
from typing import Any, Dict, List, Optional

from .models import KernelExecutionOutput

# NOTE: Kernel iopub message shapes vary by SysML kernel build. Parsing is best-effort.


def _message_text(content: Dict[str, Any]) -> str:
    if "text" in content and content["text"]:
        return str(content["text"])
    if "ename" in content and "evalue" in content:
        return f"{content['ename']}: {content['evalue']}"
    if "traceback" in content:
        return "\n".join(str(t) for t in content["traceback"])
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


def execute_sysml_candidate(
    consolidated_payload: str,
    *,
    kernel_name: str = "sysml",
    timeout_sec: float = 120.0,
) -> KernelExecutionOutput:
    """
    Connect to the SysML reference runtime, deliver code, and capture stream blocks.

    Requires the official SysML v2 Jupyter kernel (kernel spec name ``sysml``),
    e.g. in an OrbStack Linux container.
    """
    try:
        from jupyter_client.manager import KernelManager
    except ImportError as exc:
        return KernelExecutionOutput(
            execution_status_payload="",
            kernel_available=False,
            bridge_error=f"jupyter_client not installed: {exc}",
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

        msg_id = client.execute(consolidated_payload)
        deadline = time.monotonic() + timeout_sec
        idle_seen = False

        while time.monotonic() < deadline:
            try:
                msg = client.get_iopub_msg(timeout=1.0)
            except Exception:
                if idle_seen:
                    break
                continue

            serialized = _serialize_message(msg)
            raw_messages.append(serialized)

            parent_id = serialized.get("parent_msg_id")
            if parent_id and parent_id != msg_id:
                continue

            msg_type = serialized.get("msg_type")
            text = serialized.get("text") or ""

            if msg_type == "stream":
                stream_name = (serialized.get("content") or {}).get("name", "stdout")
                if stream_name == "stderr":
                    stderr_lines.append(text)
                else:
                    stdout_lines.append(text)
            elif msg_type in ("error", "execute_result", "display_data"):
                if msg_type == "error":
                    error_lines.append(text)
                elif text:
                    stdout_lines.append(text)
            elif msg_type == "status":
                state = (serialized.get("content") or {}).get("execution_state")
                if state == "idle":
                    idle_seen = True

        try:
            shell_msg = client.get_shell_msg(timeout=5.0)
            shell_reply = _serialize_message(shell_msg)
            if shell_reply.get("text"):
                stdout_lines.append(shell_reply["text"])
            status = (shell_reply.get("content") or {}).get("status")
            if status == "error":
                error_lines.append(shell_reply.get("text") or "shell execution error")
        except Exception:
            pass

        status_payload = "\n".join(
            line for line in (stdout_lines + stderr_lines + error_lines) if line
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
        partial = "\n".join(stdout_lines + stderr_lines + error_lines)
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
