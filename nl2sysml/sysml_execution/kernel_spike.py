"""
Probe the local SysML Jupyter kernel for Layer 2 execution patterns.

Run from repo root::

    python -m nl2sysml.sysml_execution.kernel_spike

Results inform harness generation; see KERNEL_CAPABILITIES.md.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List

_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from nl2sysml.sysml_execution.sysml_runtime_bridge import execute_sysml_candidate  # noqa: E402

_SPIKES: List[Dict[str, Any]] = [
    {
        "name": "minimal_package",
        "payload": "package SpikeMinimal { attribute def X; }",
        "expect": "parse",
    },
    {
        "name": "assign_in_action",
        "payload": """
package SpikeAssign {
    attribute def Count;
    action def Probe { in count: Count; assign count = 1; }
}
""",
        "expect": "assign_compiles",
    },
    {
        "name": "nested_action_usage",
        "payload": """
package SpikeNested {
    action def Inner { out done: Boolean; }
    action def Outer {
        action inner : Inner;
    }
}
""",
        "expect": "nested_action_compiles",
    },
]


def _classify_output(out) -> Dict[str, Any]:
    combined = (out.execution_status_payload or "") + "\n".join(out.error_lines)
    return {
        "kernel_available": out.kernel_available,
        "bridge_error": out.bridge_error,
        "shell_ok": (out.shell_reply or {}).get("content", {}).get("status") in (None, "ok"),
        "has_error": bool(out.error_lines) or "ERROR" in combined.upper(),
        "payload_preview": (out.execution_status_payload or "")[:500],
    }


def run_spikes() -> List[Dict[str, Any]]:
    results: List[Dict[str, Any]] = []
    for spike in _SPIKES:
        out = execute_sysml_candidate(spike["payload"], timeout_sec=60.0)
        row = {"spike": spike["name"], "expect": spike["expect"], **_classify_output(out)}
        results.append(row)
    return results


def main() -> None:
    results = run_spikes()
    print(json.dumps(results, indent=2))
    if not results[0].get("kernel_available"):
        print(
            "\nSysML kernel not available; see KERNEL_CAPABILITIES.md for offline assumptions.",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
