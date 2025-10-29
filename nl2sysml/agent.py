import os
from pathlib import Path
import sys, json
from pathlib import Path

# Keep it simple: minimal imports and setup
from dotenv import load_dotenv
import google.generativeai as genai


def _load_env():
    # Load repo-level .env (two dirs up from this file)
    load_dotenv(Path(__file__).parent.parent / ".env")
    key = os.getenv("GEMINI_API_KEY")
    if not key:
        raise RuntimeError("GEMINI_API_KEY missing in environment/.env")
    genai.configure(api_key=key)
    return key


def build_agent(system_hint: str | None = None):
    """
    Return a simple LangChain pipeline backed by Gemini 2.5 Pro.
    - Uses a concise system prompt tuned for SysML v2 concrete syntax.
    - Minimal plumbing; fail fast if deps or key are missing.
    """
    _load_env()

    # Prefer LangChain wrapper, but keep a direct model for simple calls/tests
    try:
        from langchain_core.prompts import ChatPromptTemplate
        from langchain_core.output_parsers import StrOutputParser
        from langchain_google_genai import ChatGoogleGenerativeAI
    except Exception as e:
        raise RuntimeError(
            "LangChain or langchain-google-genai not installed: "
            "pip install langchain-core langchain-google-genai"
        ) from e

    # Default system guidance distilled from related papers
    sys_msg = (
        (system_hint or "").strip()
        or (
            "You generate valid SysML v2 concrete syntax only. "
            "Follow official grammar; prefer simple, correct structures. "
            "Model parts, interfaces, flows, requirements when applicable. "
            "Do not explain; output SysML v2 code only."
        )
    )

    # LLM
    llm = ChatGoogleGenerativeAI(
        model="gemini-2.5-flash",
        api_key=os.getenv("GEMINI_API_KEY"),
        temperature=0.2,
    )

    # Prompt → LLM → text
    prompt = ChatPromptTemplate.from_messages([
        ("system", sys_msg),
        ("human", "{input}"),
    ])
    chain = prompt | llm | StrOutputParser()
    return chain


def generate_sysml(prompt_text: str, system_hint: str | None = None) -> str:
    """
    One-shot helper to get SysML v2 code for a natural-language prompt.
    """
    chain = build_agent(system_hint)
    return chain.invoke({"input": prompt_text})


if __name__ == "__main__":

    base = Path(__file__).parent
    ds_path = base / "dataset.json"
    result_dir = base / "result"
    result_dir.mkdir(parents=True, exist_ok=True)

    data = json.load(open(ds_path))
    prompts = data.get("prompts", [])
    if not prompts:
        raise SystemExit("No prompts found in dataset.json")

    # Build once, reuse
    chain = build_agent()

    for item in prompts:
        pid = str(item.get("id", "")).strip()
        desc = str(item.get("description", "")).strip()
        if not desc:
            continue
        fname = f"{pid.upper()}.sysml"
        out_path = result_dir / fname
        sysml = chain.invoke({"input": desc})
        content = f"// {desc}\n{sysml}\n"
        out_path.write_text(content)
        print(f"wrote {out_path}")
