# Related Papers Summary

## Open Datasets for SysML and SysML v2: A Comprehensive Survey of Research Resources
[PDF](survey/SysML2_NL.pdf)

This comprehensive survey report catalogs existing open datasets and repositories available for SysML and SysML v2 research, addressing the critical gap in publicly available training data for AI-driven MBSE applications. The survey documents key features, formats, application domains, and associated research contributions across various datasets, providing essential resource information for researchers working on automated systems modeling and model analysis. This survey is particularly valuable for the SysML2-NL project as it identifies the foundational datasets and resources needed to develop joint embeddings between SysML v2 and natural language, serving as the primary resource guide for data collection and model training.

## IEEE ISSE 2025: LLM-Assisted Semantic Alignment for SysML v2 Models

[PDF](IEEE_ISSE_2025_LLM_Semantic_Alignment_SysML_v2.pdf)

This paper proposes a structured, prompt-driven approach for LLM-assisted semantic alignment of SysML v2 models to address cross-organizational collaboration challenges in Model-Based Systems Engineering. The work leverages GPT-based Large Language Models to enable semantic matching and integration across independently developed system models, utilizing SysML v2's enhanced structural modularity and formal semantics. The approach incorporates model extraction, semantic matching, and verification processes, demonstrating practical applications through a measurement system example. This research is highly relevant to the SysML2-NL project as it directly addresses the core challenge of bridging SysML v2 models with natural language understanding using AI technology.

## INCOSE 2024: Leveraging Large Language Models for Direct Interaction with SysML v2

[PDF](INCOSE_2024_LLM_Direct_Interaction_SysML_v2.pdf)

This INCOSE 2024 paper examines the potential integration of Large Language Models with SysML v2, proposing a novel methodology for systems engineering that capitalizes on the enhanced readability and human-friendly syntax of SysML v2. The work explores how LLMs can serve as an interpretive layer for syntactically simplified manipulation of system models and as a catalyst for knowledge-driven design approaches, reducing dependency on technical expertise traditionally needed for API navigation and model management. This research is highly relevant to the SysML2-NL project as it directly addresses the core challenge of enabling natural language interaction with SysML v2 models, providing insights into conversational engagement with system models and democratizing the design process through LLM integration.

## Computers in Industry 2025: Agent-Based Approach for Automatic Generation of Valid SysML v2 Models

[PDF](Computers_in_Industry_2025_Agent_Based_SysML_v2_Generation.pdf)

This Computers in Industry 2025 paper introduces a domain-informed, agent-based framework that combines Large Language Models with structured retrieval and iterative validation to synthesize correct SysML v2 models from natural language specifications. The system integrates Retrieval-Augmented Generation (RAG) using a curated repository of SysML v2 examples and enforces compliance through a validation engine based on the official ANTLR grammar, addressing the challenge that current LLM-only approaches often fail to meet the syntactic and semantic rigor required by formal modeling languages. This research is highly relevant to the SysML2-NL project as it demonstrates how domain-specific integration can transform general-purpose LLMs into reliable assistants for engineering design tasks, providing insights into validation mechanisms and retrieval-augmented generation approaches that could enhance joint embedding development.

## arXiv 2025: SysTemp Multi-Agent System for Template-Based Generation of SysML v2

[PDF](arXiv_2025_SysTemp_Multi_Agent_SysML_v2_Generation.pdf)

This paper presents SysTemp, a multi-agent system designed to facilitate and improve the creation of SysML v2 models from natural language specifications, addressing the major challenge of automatic SysML v2 model generation due to scarcity of learning corpora and complex syntax. The system employs a template generator that structures the generation process and includes multiple agents working together to convert natural language descriptions into formal SysML v2 models. This work is highly relevant to the SysML2-NL project as it demonstrates practical approaches for natural language to SysML v2 translation, providing insights into template-based generation methods and multi-agent architectures that could inform the development of joint embeddings between natural language and SysML v2 models.

## NPS 2024: Leveraging Generative AI to Create, Modify, and Query MBSE Models

[PDF](NPS_2024_Generative_AI_MBSE_Models.pdf)

This Naval Postgraduate School 2024 paper explores the ability of current Large Language Models to generate, modify, and query Systems Modeling Language (SysML) v2 models, utilizing techniques such as Retrieval-Augmented Generation (RAG) to add domain-specific knowledge and improve model accuracy. The research compares ChatGPT 3.5, ChatGPT 4, and a custom GPT called Senior System Engineer - Systems Modeler (SSE-SM) for creating, modifying, and querying SysML v2 models from natural language prompts, with a focus on minimizing the number of prompts required to generate models. This work is highly relevant to the SysML2-NL project as it provides practical insights into LLM capabilities for systems modeling, demonstrates the effectiveness of domain-specific customization, and identifies future research directions including systems modeling benchmarks and domain-specific language models that could inform joint embedding development.

## arXiv 2025: SysMBench - A System Model Generation Benchmark from Natural Language Requirements

[PDF](arXiv_2025_SysMBench_System_Model_Generation_Benchmark.pdf)

This arXiv 2025 paper presents SysMBench, the first benchmark designed to evaluate the capability of Large Language Models in generating system models with model description languages from natural language requirements. The benchmark comprises 151 human-curated scenarios spanning a wide range of popular domains and varying difficulty levels, each containing natural language requirements descriptions, reference SysML v2 models, and visualized diagrams. The paper introduces SysMEval, a semantic-aware evaluation metric that decomposes models into atomic semantic claims for more reliable assessment than traditional string-based metrics. This work is highly relevant to the SysML2-NL project as it provides a comprehensive evaluation framework for assessing joint embedding quality, establishes baseline performance metrics for LLM-based system model generation, and offers valuable insights into the challenges and limitations of current approaches that could inform the development of more effective joint embedding techniques.

## IEEE Access 2025: Ensuring Semantic Consistency in SysML v2 Models through Metamodel-Driven Validation

[PDF](IEEE_Access_2025_Semantic_Consistency_SysML_v2_Models.pdf)

[github](https://github.com/edcisa/SysMLv2_Models_Validation)

This IEEE Access 2025 paper presents a systematic, metamodel-based method for validating SysML v2 models, utilizing the SysML v2 metamodel as a formal specification to facilitate automated detection of structural and semantic inconsistencies. The work addresses the emerging challenge of SysML v2 model validation by defining validation rules derived from the metamodel, enabling systematic identification and resolution of errors across aerospace, automotive, and software development domains. Unlike SysML v1 which was constrained by UML dependencies, SysML v2's standalone architecture with improved model semantics and enhanced consistency mechanisms requires sophisticated validation approaches. This research is highly relevant to the SysML2-NL project as it provides essential validation frameworks for ensuring correctness and reliability in SysML v2 models, offering insights into metamodel-driven validation techniques that could enhance the quality and consistency of joint embeddings between natural language and SysML v2 representations.

## Medium 2023: Automated Reasoning for SysML v2

[Article](Medium_2023_Automated_Reasoning_SysML_v2.md)

This Medium article by Jamie Smith from Imandra Inc. demonstrates the integration of automated reasoning capabilities with SysML v2 models, leveraging the formal semantics of KerML to enable rigorous analysis and verification. The work presents a comprehensive traffic light case study using Imandra's reasoning engine to verify deterministic behavior, proper error handling, and safety properties through formal verification techniques. The article showcases automated translation between SysML v2 and Imandra Modeling Language (IML), enabling mathematical proof of model correctness and systematic identification of design flaws. This research is highly relevant to the SysML2-NL project as it provides practical examples of formal verification techniques for SysML v2 models, demonstrates the value of automated reasoning in safety-critical systems, and offers insights into AI-powered model validation approaches that could enhance the quality and reliability of joint embeddings between natural language and SysML v2 representations.

## Medium 2024: Overview of SysML 2.0 with Examples

[Article](Medium_2024_SysML_2_0_Overview_Examples.md)

This Medium article by Laurent Balmelli provides a practical overview of SysML 2.0 features and capabilities with concrete examples from automotive systems. The article demonstrates key SysML 2.0 concepts including part definitions and usages, port and connection modeling, state-based and action-based behavior modeling, and integration with modern CI/CD workflows. It includes practical examples of vehicle systems, brake systems, and engine components, showing how SysML 2.0's textual notation enables better integration with software development pipelines. This work is highly relevant to the SysML2-NL project as it provides practical examples of SysML 2.0 constructs and usage patterns that could inform the development of joint embeddings, offering real-world context for understanding how natural language descriptions relate to formal SysML 2.0 models in industrial applications.
