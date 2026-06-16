#!/usr/bin/env python3
"""Smoke test Vercel AI Gateway with OpenAI GPT-5.5."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path


DEFAULT_BASE_URL = "https://ai-gateway.vercel.sh/v1"
DEFAULT_MODEL = "openai/gpt-5.5"
KEY_ENV_VARS = (
    "AI_GATEWAY_API_KEY",
    "VERCEL_AI_GATEWAY_API_KEY",
    "VERCEL_API_KEY",
    "VERCEL_API_TOKEN",
)


def load_dotenv_file(path: Path) -> None:
    """Load simple KEY=VALUE lines without requiring python-dotenv."""
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def get_api_key() -> tuple[str | None, str | None]:
    for env_name in KEY_ENV_VARS:
        value = os.getenv(env_name)
        if value:
            return value, env_name
    return None, None


def post_chat_completion(base_url: str, api_key: str, model: str, prompt: str) -> dict:
    url = f"{base_url.rstrip('/')}/chat/completions"
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
    }
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code} from Vercel AI Gateway:\n{body}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Network error calling Vercel AI Gateway: {exc}") from exc


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default=os.getenv("GPT55_MODEL", DEFAULT_MODEL))
    parser.add_argument("--prompt", default="hi")
    parser.add_argument("--base-url", default=os.getenv("AI_GATEWAY_BASE_URL", DEFAULT_BASE_URL))
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    load_dotenv_file(repo_root / ".env")
    load_dotenv_file(repo_root / ".env.local")

    api_key, env_name = get_api_key()
    if not api_key:
        print(
            "Missing Vercel AI Gateway API key. Set one of: "
            + ", ".join(KEY_ENV_VARS),
            file=sys.stderr,
        )
        return 2

    print(f"Calling {args.model} via Vercel AI Gateway ({env_name})...")
    response = post_chat_completion(args.base_url, api_key, args.model, args.prompt)

    try:
        output = response["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError):
        print("Unexpected response shape:")
        print(json.dumps(response, indent=2, ensure_ascii=False))
        return 1

    print("\nModel output:")
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
