# SysML2-NL Overview

This research project develops a joint embedding space that bridges SysML v2 
(Systems Modeling Language version 2) and Natural Language, enabling seamless
understanding and semantic alignment between formal system models and human-readable
descriptions. The goal is to create a unified representation space where both
SysML v2 constructs and natural language expressions can be embedded and compared,
facilitating cross-organizational collaboration in Model-Based Systems Engineering.

The project focuses on developing joint embeddings that enable semantic search
across both modalities, support automated documentation generation, and facilitate
model understanding and validation processes through AI-assisted semantic alignment
techniques, without requiring explicit bidirectional translation between the two 
representations.

## Project Structure

```
sysml2-nl/
├── README.md                    # Primary project documentation and AI agent entry point
├── .gitignore                   # Git ignore rules for VSCode, macOS, and Python cache files
├── related_paper/              # Research papers and academic documentation
│   ├── summary.md              # Concise summaries of all related research papers with clickable PDF links
│   ├── IEEE_ISSE_2025_LLM_Semantic_Alignment_SysML_v2.pdf      # IEEE ISSE 2025 paper on LLM-assisted semantic alignment for SysML v2 models
│   ├── IEEE_ISSE_2025_LLM_Semantic_Alignment_SysML_v2_content.md      # Extracted text content from the IEEE ISSE semantic alignment paper
│   ├── INCOSE_2024_LLM_Direct_Interaction_SysML_v2.pdf      # INCOSE 2024 paper on leveraging LLMs for direct interaction with SysML v2
│   ├── INCOSE_2024_LLM_Direct_Interaction_SysML_v2_content.md      # Extracted text content from the INCOSE direct interaction paper
│   ├── ...               # Additional research papers and their extracted content files
│   └── survey/                 # Survey papers and related work analysis
│       ├── SysML2_NL.pdf      # Comprehensive survey of open datasets for SysML and SysML v2 research
│       ├── SysML2_NL_content.md      # Extracted text content from the survey paper
│       └── SysML2_NL.tex      # LaTeX source files for survey paper generation
├── dataset/                    # SysML2-NL dataset with 386 samples from official OMG sources and community repositories
│   ├── README.md              # Dataset documentation with composition, data sources, and quality tiers
│   ├── DATACARD.md            # Dataset documentation and quality assurance information
│   ├── VERSION                # Dataset version information
│   ├── data/                  # 386 paired SysML v2 models and natural language descriptions (000001-000386)
│   │   ├── 000001-000250/     # Official OMG SysML v2 Release samples (A+ quality, official split)
│   │   ├── 000251-000286/     # Community SysML-v2-Models samples (B quality, community split)
│   │   ├── 000287-000376/     # OMG SysML-v2-Pilot-Implementation samples (A quality, pilot split)
│   │   └── 000377-000386/     # ESA/ESA_Comet aerospace models (A quality, esa split)
│   ├── index/                 # Dataset manifest and checksum files
│   │   ├── manifest.jsonl    # JSONL manifest with all 386 dataset entries and metadata
│   │   ├── checksums.tsv     # SHA256 checksums for all dataset files
│   │   └── stats.json        # Dataset statistics and summary information
│   ├── schema/                # JSON schema definitions for dataset validation
│   │   ├── manifest.schema.json      # Schema for manifest.jsonl validation
│   │   └── sample_meta.schema.json   # Schema for individual sample metadata validation
│   └── scripts/               # Dataset management and validation scripts
│       ├── build_manifest.py  # Script to build manifest, checksums, and statistics from dataset files
│       └── validate_manifest.py      # Comprehensive validation script for file existence, UTF-8 encoding, SHA256 checksums, and JSON schema compliance
├── script/                    # Dataset generation and processing scripts with fixed ID ranges
│   ├── gen_dataset_SysML-v2-Release.py    # Script to generate official release samples (000001-000250)
│   ├── gen_dataset_SysML_v2_Models.py     # Script to generate community samples (000251-000286)
│   ├── gen_dataset_SysML-v2-Pilot.py      # Script to generate pilot implementation samples (000287-000685)
│   └── gen_NL_SysML_v2_Models.py          # Script to generate natural language descriptions from SysML v2 models using Gemini API
├── server/                    # Web service for NL to SysML conversion (Nginx + Next.js + FastAPI)
│   ├── README.md              # Server documentation with deployment instructions
│   ├── frontend/              # Next.js 14 frontend with Monokai theme UI
│   ├── backend/               # FastAPI backend with /api/nl2llm endpoint
│   └── deploy/                # Deployment scripts (nginx.conf, tmux_start.sh, stop.sh, status.sh)
└── tmp/                       # Temporary directory for external repositories and processing
    ├── SysML-v2-Models/       # External SysML v2 models repository for dataset generation
    │   └── models/            # Source SysML v2 model files organized by example categories
    └── SysMLv2_Models_Validation/  # SysML v2 model validation tool with web interface
        ├── run.sh             # Main script to run validation (web interface, command line, or sample models)
        ├── SysMLAPIOM/        # Core validation library with SysML v2 metamodel validation
        └── WebApp_SysMLv2APIOM/  # Web-based validation interface
```

## Maintain Logic

This README serves as the primary entry point for the Cursor AI agent and contains three main sections: (1) Project introduction; (2) File architecture; (3) Maintain Logic. No additional sections may be added.

1. When the user requests the agent to refresh the README, the agent should review the overview and rewrite it while maintaining exactly two paragraphs. The agent should rewrite the project structure to provide one-sentence descriptions for each file. Never modify Maintain Logic part except modify grammar error. The project structure can contain '...'.

2. When the user request the agent to download paper with an link, the AI agent should download the paper to related_paper, then extract pdf's content into a content.md, then rename both the pdf and the content.md to some good name decide by the content, then modify related_paper/summary.md to have a short summary for this paper

3. When writing code, follow Linus Torvalds' coding philosophy: avoid over-engineering, write minimal code with short variable names, use single functions instead of classes when possible, fail fast without excessive error handling, and prioritize readability over fancy abstractions. The code should be brutally simple and do exactly what's needed without fluff.

## SysML v2 Model Validation Tool

The project includes a comprehensive SysML v2 model validation tool located in `tmp/SysMLv2_Models_Validation/`. This tool validates SysML v2 models against the official metamodel specification and provides a web-based interface for easy model validation.
```bash
cd tmp/SysMLv2_Models_Validation
./run.sh
```
This will automatically build the application and start the web server at http://localhost:5213 where you can upload and validate SysML v2 model files.

## NL-to-SysML Web Service

The `server/` directory contains a web service for converting natural language to SysML, deployed on GCP VM (34.83.162.173). Architecture: Nginx (:80) → Next.js frontend (:3000) + FastAPI backend (:8000), all bound to localhost except Nginx.
```bash
cd server/deploy
./tmux_start.sh      # Start all services
./stop.sh            # Stop all services
./status.sh          # Check service status
```
Access at http://34.83.162.173/ or test API: `curl -X POST http://34.83.162.173/api/nl2llm -H "Content-Type: application/json" -d '{"text":"test"}'`