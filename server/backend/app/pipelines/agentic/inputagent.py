"""
Input Agent for the Agentic Pipeline.

The Input Agent preprocesses natural language input by:
1. Refining and clarifying the requirement
2. Extracting key concepts and entities
3. Identifying relevant SysML constructs
4. Expanding ambiguous terms

This runs in parallel with RAG to provide enhanced context.
"""

import json
import re
from typing import List, Dict, Optional, Tuple
from pathlib import Path

from app.core.logging import get_logger
from app.core.config import GEMINI_API_KEY, OPENROUTER_API_KEY, OPENROUTER_BASE_URL

log = get_logger(__name__)

# SysML v2 construct categories for classification
SYSML_CONSTRUCTS = {
    "structural": [
        "part", "port", "connection", "interface", "block", "item", 
        "attribute", "reference", "binding", "allocation"
    ],
    "behavioral": [
        "action", "state", "transition", "flow", "succession", 
        "perform", "accept", "send", "decide", "merge", "fork", "join"
    ],
    "requirements": [
        "requirement", "constraint", "objective", "stakeholder",
        "concern", "satisfy", "verify", "refine", "trace"
    ],
    "parametric": [
        "constraint", "equation", "calculation", "analysis",
        "value", "unit", "quantity"
    ],
    "types": [
        "enum", "attribute def", "item def", "part def", "port def",
        "connection def", "interface def", "action def", "state def"
    ]
}

# Domain keywords that suggest specific modeling patterns
DOMAIN_PATTERNS = {
    "control_system": ["control", "feedback", "sensor", "actuator", "pid", "loop", "regulate"],
    "safety_system": ["safety", "hazard", "fault", "redundant", "failsafe", "emergency", "alarm"],
    "thermal_system": ["heat", "temperature", "thermal", "cooling", "heating", "insulation"],
    "electrical_system": ["power", "voltage", "current", "battery", "motor", "circuit", "electrical"],
    "mechanical_system": ["mechanical", "force", "torque", "pressure", "structural", "load"],
    "communication_system": ["message", "signal", "protocol", "interface", "data", "transmit", "receive"],
    "software_system": ["software", "algorithm", "process", "function", "module", "api"],
}

# Prompt template for input refinement
REFINEMENT_PROMPT = """Analyze the following system requirement and provide a structured analysis.

Requirement: {input}

Provide your analysis in JSON format with these fields:
{{
  "refined_requirement": "A clearer, more detailed version of the requirement",
  "key_concepts": ["list", "of", "main", "concepts"],
  "system_type": "The type of system (e.g., control system, safety system, etc.)",
  "suggested_constructs": ["sysml", "constructs", "to", "use"],
  "ambiguities": ["any", "unclear", "aspects"],
  "assumptions": ["reasonable", "assumptions", "to", "make"],
  "constraints": ["identified", "constraints"],
  "interfaces": ["external", "interfaces", "or", "connections"]
}}

Only output valid JSON, no markdown or explanation."""


class InputAgent:
    """
    Agent that preprocesses and refines natural language input for SysML generation.
    """
    
    def __init__(self, progress_callback=None):
        self._progress_callback = progress_callback
    
    def _report_progress(self, stage: str, detail: str = ""):
        """Report progress to callback if set."""
        if self._progress_callback:
            self._progress_callback(stage, detail)
        log.info(f"[InputAgent:{stage}] {detail}")
    
    def _extract_keywords(self, text: str) -> List[str]:
        """Extract important keywords from text."""
        # Simple tokenization
        words = re.findall(r'\b[a-zA-Z][a-zA-Z0-9_]*\b', text.lower())
        # Filter common words
        stopwords = {
            'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
            'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
            'should', 'may', 'might', 'must', 'shall', 'can', 'need', 'dare',
            'ought', 'used', 'to', 'of', 'in', 'for', 'on', 'with', 'at', 'by',
            'from', 'as', 'into', 'through', 'during', 'before', 'after', 'above',
            'below', 'between', 'under', 'again', 'further', 'then', 'once', 'here',
            'there', 'when', 'where', 'why', 'how', 'all', 'each', 'few', 'more',
            'most', 'other', 'some', 'such', 'no', 'nor', 'not', 'only', 'own',
            'same', 'so', 'than', 'too', 'very', 'just', 'and', 'but', 'if', 'or',
            'because', 'until', 'while', 'although', 'this', 'that', 'these', 'those',
            'i', 'me', 'my', 'myself', 'we', 'our', 'ours', 'you', 'your', 'he',
            'him', 'his', 'she', 'her', 'it', 'its', 'they', 'them', 'their', 'what',
            'which', 'who', 'whom', 'design', 'system', 'create', 'make', 'build'
        }
        return [w for w in words if w not in stopwords and len(w) > 2]
    
    def _identify_domain(self, text: str) -> List[str]:
        """Identify relevant domain patterns from the text."""
        text_lower = text.lower()
        matched_domains = []
        
        for domain, keywords in DOMAIN_PATTERNS.items():
            matches = sum(1 for kw in keywords if kw in text_lower)
            if matches >= 1:
                matched_domains.append((domain, matches))
        
        # Sort by match count and return top domains
        matched_domains.sort(key=lambda x: x[1], reverse=True)
        return [d[0] for d in matched_domains[:3]]
    
    def _suggest_constructs(self, text: str, domains: List[str]) -> List[str]:
        """Suggest SysML constructs based on text and domain analysis."""
        text_lower = text.lower()
        suggestions = set()
        
        # Check for structural keywords
        if any(w in text_lower for w in ['component', 'part', 'subsystem', 'module', 'unit']):
            suggestions.update(['part def', 'part'])
        
        # Check for interface keywords
        if any(w in text_lower for w in ['interface', 'connect', 'communicate', 'interact', 'port']):
            suggestions.update(['port def', 'port', 'interface def', 'connection'])
        
        # Check for behavioral keywords
        if any(w in text_lower for w in ['process', 'action', 'behavior', 'operation', 'function', 'step']):
            suggestions.update(['action def', 'action', 'perform'])
        
        # Check for state keywords
        if any(w in text_lower for w in ['state', 'mode', 'status', 'condition', 'phase']):
            suggestions.update(['state def', 'state', 'transition'])
        
        # Check for requirement keywords
        if any(w in text_lower for w in ['require', 'must', 'shall', 'constraint', 'need']):
            suggestions.update(['requirement', 'constraint'])
        
        # Check for value/attribute keywords
        if any(w in text_lower for w in ['value', 'parameter', 'attribute', 'property', 'measure']):
            suggestions.update(['attribute def', 'attribute'])
        
        # Domain-specific suggestions
        if 'control_system' in domains:
            suggestions.update(['action', 'state', 'port', 'flow'])
        if 'safety_system' in domains:
            suggestions.update(['requirement', 'constraint', 'state'])
        if 'thermal_system' in domains or 'electrical_system' in domains or 'mechanical_system' in domains:
            suggestions.update(['attribute def', 'constraint', 'port'])
        
        return list(suggestions)
    
    def _call_llm_for_refinement(self, text: str) -> Optional[Dict]:
        """Call LLM to get structured refinement of the input."""
        import google.generativeai as genai
        
        if not GEMINI_API_KEY:
            return None
        
        try:
            genai.configure(api_key=GEMINI_API_KEY)
            model = genai.GenerativeModel("gemini-2.0-flash")
            
            prompt = REFINEMENT_PROMPT.format(input=text)
            response = model.generate_content(prompt)
            
            # Parse JSON from response
            response_text = response.text.strip()
            # Remove markdown code fences if present
            if response_text.startswith("```"):
                lines = response_text.split("\n")
                response_text = "\n".join(lines[1:-1] if lines[-1].startswith("```") else lines[1:])
            
            return json.loads(response_text)
        except Exception as e:
            log.warning(f"LLM refinement failed: {e}")
            return None
    
    def process(self, text: str) -> Dict:
        """
        Process the input text and return enhanced context.
        
        Returns:
            Dict with keys:
            - original: Original input text
            - refined: Refined/clarified requirement
            - keywords: Extracted keywords
            - domains: Identified domains
            - constructs: Suggested SysML constructs
            - llm_analysis: Full LLM analysis (if available)
            - search_terms: Terms to use for enhanced RAG search
        """
        self._report_progress("start", "Processing input...")
        
        # Step 1: Extract keywords
        keywords = self._extract_keywords(text)
        self._report_progress("keywords", f"Extracted {len(keywords)} keywords")
        
        # Step 2: Identify domains
        domains = self._identify_domain(text)
        self._report_progress("domains", f"Identified domains: {', '.join(domains) if domains else 'general'}")
        
        # Step 3: Suggest constructs
        constructs = self._suggest_constructs(text, domains)
        self._report_progress("constructs", f"Suggested {len(constructs)} constructs")
        
        # Step 4: Call LLM for deeper analysis
        self._report_progress("llm", "Refining with LLM...")
        llm_analysis = self._call_llm_for_refinement(text)
        
        # Build result
        result = {
            "original": text,
            "refined": text,  # Default to original
            "keywords": keywords,
            "domains": domains,
            "constructs": constructs,
            "llm_analysis": None,
            "search_terms": keywords[:10],  # Top keywords for RAG
        }
        
        # Enhance with LLM analysis if available
        if llm_analysis:
            result["llm_analysis"] = llm_analysis
            if llm_analysis.get("refined_requirement"):
                result["refined"] = llm_analysis["refined_requirement"]
            if llm_analysis.get("key_concepts"):
                result["search_terms"] = list(set(result["search_terms"] + llm_analysis["key_concepts"]))
            if llm_analysis.get("suggested_constructs"):
                result["constructs"] = list(set(result["constructs"] + llm_analysis["suggested_constructs"]))
            self._report_progress("llm_done", "LLM refinement complete")
        else:
            self._report_progress("llm_done", "LLM refinement skipped")
        
        self._report_progress("done", f"Input processing complete")
        return result
    
    def format_enhanced_prompt(self, analysis: Dict) -> str:
        """
        Format the analysis into an enhanced prompt section.
        
        This can be prepended to the RAG context or human message.
        """
        lines = []
        
        # Add refined requirement if different from original
        if analysis.get("refined") and analysis["refined"] != analysis.get("original"):
            lines.append(f"Clarified Requirement: {analysis['refined']}")
        
        # Add identified domains
        if analysis.get("domains"):
            lines.append(f"System Domain(s): {', '.join(analysis['domains'])}")
        
        # Add suggested constructs
        if analysis.get("constructs"):
            lines.append(f"Recommended SysML Constructs: {', '.join(analysis['constructs'])}")
        
        # Add LLM insights
        if analysis.get("llm_analysis"):
            llm = analysis["llm_analysis"]
            if llm.get("assumptions"):
                lines.append(f"Assumptions: {', '.join(llm['assumptions'][:3])}")
            if llm.get("constraints"):
                lines.append(f"Constraints: {', '.join(llm['constraints'][:3])}")
            if llm.get("interfaces"):
                lines.append(f"Interfaces: {', '.join(llm['interfaces'][:3])}")
        
        if lines:
            return "Input Analysis:\n" + "\n".join(f"- {line}" for line in lines) + "\n\n"
        return ""


async def run_input_agent(text: str, progress_callback=None) -> Dict:
    """
    Async wrapper to run input agent in executor.
    
    Args:
        text: Natural language input
        progress_callback: Optional callback for progress updates
        
    Returns:
        Analysis dictionary from InputAgent.process()
    """
    import asyncio
    
    agent = InputAgent(progress_callback=progress_callback)
    loop = asyncio.get_event_loop()
    
    # Run in executor since LLM call is blocking
    result = await loop.run_in_executor(None, agent.process, text)
    return result
