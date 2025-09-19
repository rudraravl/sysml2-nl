Open Datasets for SysML and SysML v2:
A Comprehensive Survey of Research Resources
Survey Report
September 19, 2025

Abstract
Model-Based Systems Engineering (MBSE) relies on the Systems Modeling Language
(SysML) to capture system requirements, architecture, behavior, and parametrics in a consistent formalism. The newer SysML v2 introduces a textual notation and richer semantics.
As researchers explore ways to build and analyze systems using large language models, publicly available training data remains limited. This survey provides a comprehensive overview
of open, research-usable datasets and model libraries for both SysML v1.x and SysML
v2, documenting their key features, formats, application domains, and associated research
contributions.

1

Introduction

The evolution of Model-Based Systems Engineering (MBSE) has been significantly influenced by
the development and adoption of the Systems Modeling Language (SysML). While SysML v1.x
established a solid foundation for systems modeling, SysML v2 represents a paradigm shift with
its textual notation and enhanced semantic capabilities.
The intersection of MBSE with artificial intelligence, particularly large language models
(LLMs), presents unprecedented opportunities for automated system design and analysis. However, progress in this domain is constrained by the scarcity of high-quality, publicly available
training datasets. This survey addresses this gap by cataloging existing open datasets and repositories that can support research in automated systems modeling, model analysis, and AI-driven
MBSE applications.

2

Open Datasets and Repositories

The following comprehensive table summarizes the current landscape of open datasets and repositories available for SysML and SysML v2 research. Each entry is characterized by its organizational source, temporal scope, key technical features, supported formats, application domains,
and associated scholarly contributions.
Dataset/Repository
Organization/Authors
Year &
Version

Key Features

Formats

Domain/Examples
Asso
Pub

lightgray SysML
DELS Model
Libraries

Discrete-event
logistics system
libraries; modular
block architecture;
requires MagicDraw
18.5+

XMI,
HTML

Manufacturing
plants,
warehouses,
supply chain
optimization

NIST
(Barbau &
Bock)

2019
(SysML
1.4)

1

NIST

Open Datasets for SysML and SysML v2
Dataset/Repository
Organization/Authors
Year &
Version
Wireless
Factory
Work-cell
Model

NIST (Bock
& Barbau)

2024

lightgray
SysPhS
PhysicalInteraction
Models

NIST
(Manion &
Bock)

2024
(SysPhS
1.0)

SysLMA
Translator

NIST
(Barbau &
Bock)

2025

lightgray
SysPhS
Translator v1.0

NIST
(Manion &
Bock)

2019–2020

SysPhS
Translator v1.1

NIST
(Manion &
Bock)

2023–2025

lightgray OBM
&
SysML→Alloy
Translations

NIST
(Manion &
Bock)

2024–2025

2
Key Features

Formats

Domain/Examples
Asso
Pub

Structural
component models,
interface definitions,
parametric
constraints for
wireless industrial
systems
Libraries for rotational/translational
mechanics, heat
transfer; 1-D physics
simulation;
Modelica/Simscape
translation
SysML model
translation with
SysLMA profile
extension; logistics
analysis integration;
comprehensive
examples
SysPhS 1.0
implementation;
SysML+SysPhS to
Modelica/Simulink
translation;
cross-platform
compatibility
Enhanced SysPhS
1.1 implementation;
improved Modelica
&
Simulink/Simscape
generation;
expanded model
library
Alloy Analyzer
integration; SysML
behavioral model
translation;
Ontological
Behavior Modeling;
executability
verification

MagicDraw
XML,
HTML

Industrial
wireless
connectivity,
IoT
manufacturing

NIST
docu

Manufacturing
SysML/SysPhS,
physical
executable
interactions,
code
mechatronics

NIST

Source &
binary
code, model
libraries

Logistics
analysis,
supply chain
modeling

NIST

Source &
binary
code,
example
models

Cross-platform
simulation,
multi-physics
modeling

Data
docu

Source &
binary
code,
sample
models

Advanced
simulation
platforms,
model interoperability

NIST
docu
page

Alloy code,
verification
examples

Behavior
verification,
model
consistency
checking

NIST
8388

Open Datasets for SysML and SysML v2
Dataset/Repository
Organization/Authors
Year &
Version
SysML v2
Models
Collection

lightgray SysML
v2 Release
Repository

SysMBench
Benchmark

lightgray
Aerospace
SysML Model
Dataset

3

3
Key Features

Formats

Domain/Examples
Asso
Pub

Cross-domain
Curated high-quality .sysml,
modeling,
Markdown
SysML v2 models;
documenta- educational
best-practice
applications
tion
examples;
educational
resources; LLM
training data;
BSD-3 license
General
PDF,
2023–2025 Official SysML v2
OMG
.sysml/.kerml, systems
specifications;
Systems
modeling,
XMI
normative libraries;
Modeling
standards
Eclipse & Jupyter
Community
compliance
integration;
comprehensive
tooling support
SysML text Multi-domain
Jin et al.
2025
151 curated
(automotive,
&
scenarios;
aerospace,
diagrams,
natural-language
photography,
metadata
requirements;
traffic)
textual & graphical
models; domain
classification;
difficulty grading
Spacecraft
SysML
Zhang &
2024
Domain-specific
systems,
models,
Yang
SysML models;
aerospace
validation
validation rule sets;
engineering
rules
spacecraft system
knowledge; MBSE
recommendation
training data
Table 1: Comprehensive overview of open SysML and SysML
v2 datasets and repositories

GfSE
Community

2025
(ongoing)

Research Impact and Applications

The datasets cataloged above have enabled significant research contributions across multiple
domains of systems engineering and artificial intelligence. The following subsections detail the
key research outcomes and their implications for the broader MBSE community.

3.1

NIST Research Contributions

The National Institute of Standards and Technology (NIST) has been instrumental in developing
foundational resources for MBSE research:
• NIST IR 8262 documents the Discrete Event Logistics Systems (DELS) libraries, providing
reference implementations for logistics and manufacturing systems analysis with comprehensive
validation studies.

Repo
docu

Offic
speci
docu

SysM
resea

Appl
journ

Open Datasets for SysML and SysML v2

4

• NIST IR 8490 introduces expanded physical-interaction component libraries for SysPhS,
demonstrating cross-platform simulation capabilities and providing empirical validation of
translation accuracy.
• NIST IR 8571 defines the SysLMA (Systems Logistics Modeling and Analysis) extension
methodology, showcasing practical applications in supply chain optimization and logistics
workflow automation.
• NIST IR 8388-upd1 proposes novel verification methodologies for SysML behavioral models
through formal translation to Alloy constraints, addressing critical gaps in model executability
verification.

3.2

Community-Driven Initiatives

3.2.1

SysML v2 Ecosystem Development

The SysML v2 Release repository serves as the authoritative source for the new modeling
standard, providing:
• Official specification documents with detailed semantic definitions
• Normative libraries serving as reference implementations
• Comprehensive tooling infrastructure including Eclipse and Jupyter integrations
• Extensive example models demonstrating best practices
The GfSE community collection complements official resources by providing curated,
high-quality models specifically designed for educational applications and LLM training, addressing the critical need for diverse, well-documented training data.
3.2.2

AI and Machine Learning Applications

Recent research has begun exploring the intersection of MBSE and artificial intelligence:
• SysMBench (Jin et al., 2025) represents the first comprehensive benchmark for evaluating
large language models on SysML generation tasks. The study evaluated 17 different LLMs and
introduced the SysMEval metric for assessing model quality, establishing baseline performance
measurements for future research.
• Zhang & Yang (2024) developed domain-specific datasets for aerospace applications, demonstrating how specialized model collections can improve MBSE tool recommendations and modeling efficiency in specific engineering domains.

4

Dataset Characteristics and Quality Assessment

4.1

Format Diversity and Interoperability

The surveyed datasets exhibit significant diversity in format support, reflecting the evolving
landscape of MBSE tooling:
• Legacy formats: XMI and HTML remain prevalent for SysML v1.x compatibility
• Native textual formats: .sysml and .kerml files represent the future of human-readable
modeling

Open Datasets for SysML and SysML v2

5

• Executable representations: Source code and binary distributions enable practical application
• Documentation formats: Markdown and PDF provide essential context and usage guidelines

4.2

Domain Coverage Analysis

The current dataset landscape demonstrates broad domain coverage:
• Manufacturing and Logistics: Well-represented through NIST contributions
• Aerospace and Defense: Emerging coverage through specialized datasets
• Cross-domain Applications: SysMBench provides multi-domain scenarios
• Physical Systems: Strong representation through SysPhS libraries

4.3

Licensing and Accessibility

Most datasets adopt open licensing models (BSD-3, LGPL/GPL) that facilitate research applications, though researchers should verify current licensing terms before use in derivative works.

5

Challenges and Future Directions

5.1

Current Limitations

Despite significant progress, several challenges persist in the current dataset ecosystem:
• Scale limitations: Most datasets remain relatively small-scale compared to datasets in other
AI domains
• Quality variability: Inconsistent documentation and validation across different sources
• Domain imbalance: Some engineering domains remain underrepresented
• Temporal coverage: Limited longitudinal data for studying model evolution

5.2

Emerging Opportunities

The MBSE research community is positioned to address these limitations through:
• Collaborative curation: Community-driven efforts like the GfSE collection demonstrate the
potential for collaborative dataset development
• AI-assisted generation: Large language models could help generate synthetic training data
to augment existing collections
• Industry partnerships: Collaborations with industrial partners could provide larger-scale,
real-world datasets
• Cross-domain integration: Efforts to create unified datasets spanning multiple engineering
domains

Open Datasets for SysML and SysML v2

6

6

Recommendations for Researchers

Based on this survey, we provide the following recommendations for researchers working in MBSE
and related fields:

6.1

For Model Analysis Research

• Utilize NIST SysPhS libraries for physical system modeling validation
• Leverage OBM/Alloy translations for formal verification studies
• Consider SysML v2 Release repository for standards-compliant research

6.2

For AI and LLM Applications

• Start with SysMBench for baseline LLM evaluation
• Utilize GfSE community models for training data diversity
• Consider domain-specific datasets (aerospace) for specialized applications

6.3

For Tool Development

• Use SysML v2 Release repository for reference implementations
• Leverage NIST translators for interoperability validation
• Consider SysLMA extensions for logistics applications

7

Conclusion

The MBSE research community has made substantial progress in assembling open datasets to
support research on model analysis, simulation, and large language model training. NIST’s
comprehensive contributions provide robust foundations for SysML v1.x research, while emerging
SysML v2 resources establish the groundwork for next-generation modeling research.
The introduction of benchmarks like SysMBench and domain-specific datasets represents
crucial steps toward systematic evaluation of AI applications in systems engineering. However,
significant opportunities remain for expanding dataset scale, improving quality consistency, and
broadening domain coverage.
As the field continues to evolve, the success of AI-driven MBSE applications will largely
depend on the availability of high-quality, diverse, and well-documented datasets. The resources
cataloged in this survey provide an essential foundation, but sustained community effort will
be required to build the comprehensive data ecosystem needed to realize the full potential of
intelligent systems engineering tools.
The convergence of traditional MBSE methodologies with modern AI capabilities promises to
transform how complex systems are designed, analyzed, and maintained. The datasets surveyed
here represent the first steps in this transformation, providing the empirical foundation necessary
for evidence-based advances in automated systems engineering.

