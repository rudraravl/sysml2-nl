# SysML2-NL Overview

This research project develops a joint embedding space that bridges SysML v2 (Systems Modeling Language version 2) and Natural Language, enabling seamless translation and understanding between formal system models and human-readable descriptions. The goal is to create a unified representation that allows bidirectional mapping between structured modeling constructs and natural language expressions, facilitating cross-organizational collaboration in Model-Based Systems Engineering.

The project focuses on developing joint embeddings capable of translating between SysML v2 models and natural language descriptions, enabling semantic search across both modalities, supporting automated documentation generation, and facilitating model understanding and validation processes through AI-assisted semantic alignment techniques.

## Project Structure

```
sysml2-nl/
├── README.md                    # Primary project documentation and AI agent entry point
├── related_paper/              # Research papers and academic documentation
│   ├── summary.md              # Concise summaries of all related research papers with clickable PDF links
│   ├── IEEE_ISSE_2025_LLM_Semantic_Alignment_SysML_v2.pdf      # IEEE ISSE 2025 paper on LLM-assisted semantic alignment for SysML v2 models
│   ├── IEEE_ISSE_2025_LLM_Semantic_Alignment_SysML_v2_content.md      # Extracted text content from the IEEE ISSE semantic alignment paper
│   ├── INCOSE_2024_LLM_Direct_Interaction_SysML_v2.pdf      # INCOSE 2024 paper on leveraging LLMs for direct interaction with SysML v2
│   ├── INCOSE_2024_LLM_Direct_Interaction_SysML_v2_content.md      # Extracted text content from the INCOSE direct interaction paper
│   ├── Computers_in_Industry_2025_Agent_Based_SysML_v2_Generation.pdf      # Computers in Industry 2025 paper on agent-based automatic generation of valid SysML v2 models
│   ├── Computers_in_Industry_2025_Agent_Based_SysML_v2_Generation_content.md      # Extracted text content from the Computers in Industry agent-based paper
│   ├── arXiv_2025_SysTemp_Multi_Agent_SysML_v2_Generation.pdf      # arXiv 2025 paper on SysTemp multi-agent system for template-based SysML v2 generation
│   ├── arXiv_2025_SysTemp_Multi_Agent_SysML_v2_Generation_content.md      # Extracted text content from the arXiv SysTemp multi-agent paper
│   ├── NPS_2024_Generative_AI_MBSE_Models.pdf      # Naval Postgraduate School 2024 paper on leveraging generative AI for MBSE models
│   ├── NPS_2024_Generative_AI_MBSE_Models_content.md      # Extracted text content from the NPS generative AI paper
│   └── survey/                 # Survey papers and related work analysis
│       ├── SysML2_NL.pdf      # Comprehensive survey of open datasets for SysML and SysML v2 research
│       ├── SysML2_NL_content.md      # Extracted text content from the survey paper
│       └── SysML2_NL.tex      # LaTeX source files for survey paper generation
```

## Maintain Logic

This README serves as the primary entry point for the Cursor AI agent and contains three main sections: (1) Project introduction; (2) File architecture; (3) Maintain Logic. No additional sections may be added.

1. When the user requests the agent to refresh the README, the agent should review the overview and rewrite it while maintaining exactly two paragraphs. The agent should rewrite the project structure to provide one-sentence descriptions for each file and potentially add one or more Maintain Logic points.

2. When the user request the agent to download file with an link, the AI agent should download the paper to related_paper, then extract pdf's content into a content.md, then rename both the pdf and the content.md to some good name decide by the content, then modify related_paper/summary.md to have a short summary for this paper