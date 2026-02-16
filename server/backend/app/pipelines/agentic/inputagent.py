"""
Input Agent: Refines the RAG-enriched prompt using Gemini 2.5 Pro with Google Search grounding.

Flow:
  1. Receives the user's NL requirement + RAG context (examples & spec chunks).
  2. Uses Gemini 2.5 Pro with Google Search to:
     - Look up current SysML v2 syntax and best practices online.
     - Find domain-specific engineering patterns relevant to the requirement.
     - Identify any ambiguities or missing details in the requirement.
  3. Returns a refined, enriched prompt that the MoE experts will use.
"""

import asyncio
import os
import time
from datetime import datetime
from pathlib import Path
from typing import Callable, Optional

from google import genai
from google.genai import types

from app.core.config import GEMINI_API_KEY
from app.core.logging import get_logger

log = get_logger(__name__)

# Log file path
_REPO_ROOT = Path(__file__).resolve().parents[5]
_LOG_FILE = _REPO_ROOT / "log" / "inputagent.txt"


def _write_log(content: str):
    """Append a log entry to /log/inputagent.txt."""
    try:
        _LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(_LOG_FILE, "a", encoding="utf-8") as f:
            f.write(content)
    except Exception as e:
        log.warning(f"Failed to write input agent log: {e}")

INPUT_AGENT_MODEL = "gemini-2.5-pro"

REFINEMENT_SYSTEM_PROMPT = """\
You are a SysML v2 expert assistant. Your job is to refine and enrich a prompt \
that will be sent to multiple LLMs to generate SysML v2 code.

You will receive:
1. A natural language requirement from the user.
2. RAG context: retrieved examples and specification excerpts.

CRITICAL RULES:
- You MUST use Google Search to look up information. Perform at least 2-3 searches.
- You MUST keep ALL original RAG examples and spec excerpts EXACTLY as they are, word-for-word. Do NOT summarize, paraphrase, or remove any RAG content.
- You MUST search for: (a) "SysML v2 textual notation" + keywords from the requirement, (b) domain-specific engineering patterns.
- After searching, ADD new information you found to the prompt as additional guidance, but NEVER remove or modify the original RAG content.

Your task:
1. SEARCH online for the latest SysML v2 syntax rules relevant to this requirement.
2. SEARCH for domain-specific engineering knowledge related to the requirement.
3. KEEP all original RAG context verbatim.
4. ADD a "SEARCH FINDINGS" section with what you found online.
5. ADD a "GUIDANCE" section with specific syntax tips based on your search.

Output format — you MUST follow this structure exactly:

ORIGINAL RAG CONTEXT (keep verbatim):
[Copy-paste the ENTIRE RAG context here unchanged]

SEARCH FINDINGS:
[New information from your Google searches — SysML v2 syntax rules, domain knowledge, relevant examples you found online]

REQUIREMENT:
[The original user requirement, plus any clarifications based on your search]

GUIDANCE:
[Specific SysML v2 syntax tips and patterns relevant to this requirement]
"""


def _extract_search_keywords(nl_input: str) -> list[str]:
    """Extract domain keywords from user input for targeted searches."""
    stop = {"a", "an", "the", "is", "it", "in", "to", "of", "and", "or", "for",
            "with", "has", "have", "that", "this", "be", "are", "was", "were",
            "its", "from", "by", "as", "on", "at", "can", "will", "should",
            "must", "shall", "into", "each", "three", "two", "one", "called"}
    words = [w.strip(".,;:()[]{}\"'") for w in nl_input.lower().split()]
    keywords = [w for w in words if len(w) >= 3 and w not in stop]
    return keywords[:10]


def _build_refinement_query(nl_input: str, rag_context: str) -> str:
    """Build the query for the Input Agent."""
    keywords = _extract_search_keywords(nl_input)
    keyword_str = ", ".join(keywords)

    parts = []
    if rag_context:
        parts.append(f"=== RAG CONTEXT (keep this VERBATIM in your output) ===\n{rag_context}")
    parts.append(f"=== USER REQUIREMENT ===\n{nl_input}")
    parts.append(
        f"\n=== INSTRUCTIONS ===\n"
        f"You MUST perform the following Google searches before producing your output:\n"
        f"1. Search: \"SysML v2 textual notation {keyword_str}\"\n"
        f"2. Search: \"{keyword_str} systems engineering model\"\n"
        f"3. Search any other terms you think are relevant to produce better SysML v2 code.\n"
        f"\nAfter searching, produce the refined prompt. Remember: keep ALL RAG context verbatim."
    )
    return "\n\n".join(parts)


class InputAgent:
    """Refines RAG-enriched prompts using Gemini 2.5 Pro with Google Search."""

    def __init__(self, progress_callback: Optional[Callable] = None):
        self._progress = progress_callback

    def _report(self, stage: str, detail: str = ""):
        if self._progress:
            self._progress(stage, detail)
        log.info(f"[InputAgent:{stage}] {detail}")

    def run_sync(self, nl_input: str, rag_context: str) -> dict:
        """
        Synchronous execution (meant to be called via run_in_executor).

        Returns dict with:
          - refined_prompt: str  (the enriched prompt for experts)
          - search_queries: list[str]  (search queries Gemini used, if available)
          - duration_ms: int
        """
        start = time.time()
        self._report("input_agent_start", "Initializing Gemini 2.5 Pro with Google Search...")

        client = genai.Client(api_key=GEMINI_API_KEY)

        # Build the query
        query = _build_refinement_query(nl_input, rag_context)
        self._report("input_agent_search", "Searching online for SysML v2 syntax & domain knowledge...")

        # Call Gemini 2.5 Pro with Google Search grounding
        google_search_tool = types.Tool(google_search=types.GoogleSearch())

        try:
            response = client.models.generate_content(
                model=INPUT_AGENT_MODEL,
                contents=query,
                config=types.GenerateContentConfig(
                    system_instruction=REFINEMENT_SYSTEM_PROMPT,
                    tools=[google_search_tool],
                    temperature=0.3,
                ),
            )
            refined = response.text or ""
        except Exception as e:
            log.warning(f"Input Agent Gemini call failed: {e}")
            self._report("input_agent_error", f"Search failed: {e}, using original prompt")
            duration_ms = int((time.time() - start) * 1000)
            # Log the failure
            _write_log(
                f"\n{'='*80}\n"
                f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] INPUT AGENT - FAILED\n"
                f"{'='*80}\n"
                f"Error: {e}\n"
                f"\n--- PROMPT BEFORE (original) ---\n{query}\n"
                f"\n--- PROMPT AFTER (unchanged due to error) ---\n(empty)\n"
                f"{'='*80}\n\n"
            )
            return {
                "refined_prompt": "",
                "search_queries": [],
                "duration_ms": duration_ms,
                "error": str(e),
            }

        # Extract grounding metadata: search queries and search results
        search_queries = []
        search_results = []
        grounding_raw = ""
        try:
            candidate = response.candidates[0]
            grounding = getattr(candidate, "grounding_metadata", None)
            if grounding:
                # Dump raw grounding metadata for debugging
                grounding_raw = str(grounding)

                # Search queries used by Gemini
                web_queries = getattr(grounding, "web_search_queries", [])
                if web_queries:
                    search_queries = list(web_queries)
                # Search result chunks (snippets from web pages)
                chunks = getattr(grounding, "grounding_chunks", [])
                if chunks:
                    for chunk in chunks:
                        web = getattr(chunk, "web", None)
                        if web:
                            search_results.append({
                                "title": getattr(web, "title", ""),
                                "uri": getattr(web, "uri", ""),
                            })
                # Also try support_chunks for more details
                support = getattr(grounding, "grounding_supports", [])
                if support:
                    for s in support:
                        seg = getattr(s, "segment", None)
                        text_snippet = getattr(seg, "text", "") if seg else ""
                        if text_snippet:
                            indices = getattr(s, "grounding_chunk_indices", [])
                            search_results.append({
                                "snippet": text_snippet,
                                "chunk_indices": list(indices) if indices else [],
                            })
                # Try search_entry_point for rendered search suggestions
                sep = getattr(grounding, "search_entry_point", None)
                if sep:
                    rendered = getattr(sep, "rendered_content", "")
                    if rendered:
                        search_results.append({"rendered_search": rendered[:500]})
        except Exception as ex:
            log.debug(f"Could not extract grounding metadata: {ex}")
            grounding_raw = f"ERROR extracting: {ex}"

        duration_ms = int((time.time() - start) * 1000)
        self._report(
            "input_agent_done",
            f"Refined prompt ({len(refined)} chars) in {duration_ms}ms"
            + (f", {len(search_queries)} searches" if search_queries else "")
        )

        # Write detailed log
        log_entry = []
        log_entry.append(f"\n{'='*80}")
        log_entry.append(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] INPUT AGENT RUN  |  {duration_ms}ms")
        log_entry.append(f"{'='*80}")
        log_entry.append(f"\n--- PROMPT BEFORE (sent to Input Agent) ---")
        log_entry.append(query)
        log_entry.append(f"\n--- SEARCH QUERIES (used by Gemini) ---")
        if search_queries:
            for i, sq in enumerate(search_queries, 1):
                log_entry.append(f"  [{i}] {sq}")
        else:
            log_entry.append("  (none detected)")
        log_entry.append(f"\n--- SEARCH RESULTS (grounding sources) ---")
        if search_results:
            for i, sr in enumerate(search_results, 1):
                if "title" in sr and sr["title"]:
                    log_entry.append(f"  [{i}] {sr.get('title', '')}  —  {sr.get('uri', '')}")
                if "snippet" in sr and sr["snippet"]:
                    snippet_preview = sr["snippet"][:300]
                    log_entry.append(f"  [{i}] snippet: {snippet_preview}...")
                if "rendered_search" in sr:
                    log_entry.append(f"  [{i}] rendered: {sr['rendered_search'][:200]}...")
        else:
            log_entry.append("  (none detected)")
        log_entry.append(f"\n--- RAW GROUNDING METADATA (debug) ---")
        log_entry.append(grounding_raw[:2000] if grounding_raw else "(no grounding metadata on response)")
        log_entry.append(f"\n--- PROMPT AFTER (refined by Input Agent) ---")
        log_entry.append(refined.strip())
        log_entry.append(f"\n{'='*80}\n")
        _write_log("\n".join(log_entry))

        return {
            "refined_prompt": refined.strip(),
            "search_queries": search_queries,
            "search_results": search_results,
            "duration_ms": duration_ms,
        }


async def run_input_agent(
    nl_input: str,
    rag_context: str,
    progress_callback: Optional[Callable] = None,
) -> dict:
    """Async wrapper to run the Input Agent in a thread executor."""
    agent = InputAgent(progress_callback=progress_callback)
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, agent.run_sync, nl_input, rag_context)
