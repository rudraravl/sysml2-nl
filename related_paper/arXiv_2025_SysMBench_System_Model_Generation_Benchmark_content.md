A System Model Generation Benchmark from Natural Language Requirements
Dongming Jin 1,2 , Zhi Jin 1,2 * , Linyu Li 1,2 , Zheng Fang 1,2 , Jia Li 3 , Xiaohong Chen 4 , Yixing Luo 5

arXiv:2508.03215v1 [cs.SE] 5 Aug 2025

1

Key Laboratory of High Confidence Software Technologies (Peking University), Ministry of Education, Beijing, China
2
School of Computer Science, Peking University, Beijing, China
3
Wuhan University, Wuhan, China
4
East China Normal University, Shanghai, China
5
Beijing Institute of Control Engineering, Beijing, China

Abstract
System models, a critical artifact in software development,
provide a formal abstraction of both the structural and behavioral aspects of software systems, which can facilitate the
early requirements analysis and architecture design. However, developing system models remains challenging due to
the specific syntax of model description languages and the
relative scarcity of public model examples. While large language models (LLMs) have shown promise in generating
code with programming languages and could potentially aid
in system model development, no benchmarks currently exist for evaluating their ability to generate system models
with specific description languages. We present SysMBench,
which comprises 151 human-curated scenarios spanning a
wide range of popular domains and varying difficulty levels.
Each scenario mainly comprises a natural language requirements description, a system model expressed in a specific
model description language, and a visualized system model
diagram. The requirements description is fed as user input
to the LLM, the system model with description language is
used to verify if the generated system model conforms to
the requirements, and the visualized diagram serves to support manual validation. We introduce SysMEval, a semanticaware evaluation metric to evaluate the quality of generated
system models. We evaluate 17 popular LLMs on this task
with three traditional metrics and SysMEval, from directly
prompting to three commonly used enhancement strategies.
Our in-depth evaluation shows that LLMs perform poorly on
SysMBench, with the highest BLEU of 4% and SysMEval-F1
of 62%. We release the SysMBench and its evaluation framework to enable future research on LLM-based system model
generation.

Introduction
System models are widely recognized as critical artifacts
in the software development process (Basha, Moiz, and
Rizwanullah 2012), particularly for large-scale and safetycritical systems (Ahlbrecht et al. 2024). As illustrated in Figure 1, they provide structured representations of a system’s
architecture and behaviors, thereby facilitating rigorous requirements analysis and architecture design. Many organizations (e.g., NASA and Airbus) have utilized system models
to reduce late-stage defects and accelerate development cycles. NASA reported that the use of system models halved
* Corresponding author

Vehicle
<<attribute def>>

<<part def>>

VehicleStatus

Vehicle

attributes

acceleratorPosition
gearSetting

attributes

mass
status: VehicleStatus

<<part>>

<<part>>

eng: Engine

driver: Person

<<part def>>

<<part def>>

Engine

Person

Graphical Notation

package 'Vehicle' {
private import ScalarValues::*;
part def Vehicle {
attribute mass : Real;
attribute status : VehicleStatus;
part eng : Engine;
ref part driver : Person;
}
attribute def VehicleStatus {
attribute gearSetting : Integer;
attribute acceleratorPosition : Real;
}
part def Engine;
part def Person;
}

Textual Notation

Figure 1: A system model example with graphical notation
and textual notation

the preliminary design review cycle for Orion spacecraft’s
electrical architecture, reducing it from six weeks to three
weeks (Lindsey, Alimardani, and Gallo 2020). Against this
backdrop, constructing high-quality system models from
natural language requirements has become an increasingly
important concern in the software engineering community.
Developing system models remains a non-trivial task. For
one, it requires not only a deep understanding of the underlying system requirements, but also proficiency in the
specific syntax and semantics of model description language such as SysML (Hause et al. 2006) or AADL (Feiler
and Gluch 2012). These languages are often complex, verbose, and domain-specific, making them difficult to master, particularly for practitioners without formal training in
model-driven engineering. Moreover, publicly available system model examples are scarce, limiting the opportunities
for data-driven learning or tool development. As a result,
the manual construction of system models remains timeconsuming and error-prone, posing a significant barrier to
the widespread adoption of model-based practices in realworld projects.
Recent advances in large language models (LLMs) have
demonstrated remarkable capabilities in translating natural
language text into structured formal representations, such
as source code (Zhu et al. 2025), SQL queries (Cen et al.
2025), and formal expressions (Cao et al. 2025). Given these
strengths, LLMs hold significant potential for assisting in
system model development, particularly in translating nat-

ural language requirements into system models written in
model description language. Unfortunately, the ability of existing LLMs to effectively generate system models remains
uncertain, since there exist no systematic studies or datasets/benchmarks available to quantitatively evaluate LLM performance on system model generation.
To bridge this gap, we introduce SysMBench, the first
benchmark designed to evaluate the capability of LLMs in
generating system models with model description language
from natural language requirements. SysMBench’s dataset
includes 151 human-curated scenarios (comparable in size
to the HumanEval dataset (Liu et al. 2023) which contains
164 programming problems) covering a wide range of popular domains, ranging from simple to highly challenging
scenarios that contain hundreds of lines of system model
descriptions (LoM). Each scenario mainly contains three
components: (1) a natural language requirements description
(e.g., “Define the basic information of vehicles”) fed as user
input to the LLMs; (2) a reference system model written in a
specific modeling language (i.e., SysML) serving as ground
truth to check against the LLM-generated models; and (3)
a visualized diagram of the system model to support human
validation and qualitative analysis. This benchmark enables
both automatic and manual assessment of generated models, laying a foundation for systematic evaluation and future
advancement in LLM-based system model generation.
To address the limitation of traditional metrics for this
task, which primarily measure surface-level similarity, we
introduce a semantics-aware evaluation metric named SysMEval. Instead of relying on surface-level string comparison, SysMEval decomposes each candidate model into a set
of atomic semantic claims. Each claim represents a minimal,
verifiable statement about structural or behavioral elements,
e.g., an attribute or a port connection. Levering the reasoning capabilities of GPT-4 (Achiam et al. 2023), SysMEval
checks whether each atomic claim is explicitly supported
by the reference system model. The final score is computed
as the proportion of supported claims among all extracted
claims, offering a fine-grained assessment of both correctness and completeness. By aligning evaluation with the semantics of system models, SysMEval provides a more reliable and informative metric for assessing the quality of the
generated system models.
Finally, we conduct a comprehensive evaluation of 17
popular LLMs on the SysMBench, covering 10 general
LLMs and 7 code LLMs. To simulate realistic usage scenarios, we assess each LLM under multiple widely used
prompting settings, including zero-shot, few-shot, chainof-thought, and grammar prompting. We reported results
across multiple traditional metrics (i.e., BLEU, ROUGEL, and BertScore) and our proposed SysMEval to capture
both surface-level and semantics-level generation quality.
Our empirical findings reveal that all LLMs struggle significantly with the system model generation task. Even the
best-performing LLM (i.e., Qwen3-32B) achieves only 62%
on SysM-F1 and 2.4% on BLUE, indicating the limitations
in current LLMs’ ability to generate a system model based
on a given natural language requirements description.
In summary, this paper makes the following contributions.

• We introduce the first system model generation benchmark from natural language requirements named SysMBench, comprising 151 scenarios across multiple domains and difficulty levels.
• We propose a semantics-aware evaluation metric named
SysMEval, which assesses the correctness and completeness of generated models based on structured claim comparison using LLMs.
• We conduct a thorough evaluation of 17 mainstream
LLMs using four metrics and four prompting strategies,
revealing the current limitations of LLMs in this challenging task.

Related Work
System Model Generation Benchmark.
Benchmarks for structured language generation are well established in programming languages (e.g., Python (Austin
et al. 2021) and SQL (Yu et al. 2018)). However, there is
no comparable, standardized benchmark for generating system models from natural language requirements in declarative modeling languages such as SysML. Prior work (Jin
et al. 2024) typically reformulates the task as information
extraction of model elements (i.e., various entities and relations) and releases only small, hand-crafted datasets (often fewer than ten scenarios), which lack scale and domain
diversity and do not assess end-to-end generation under a
model description language. Unlike imperative programming languages, system modeling languages are declarative. While related benchmark exist for other declarative formalisms (e.g., VHDL-Eval (Vijayaraghavan et al. 2024) for
hardware description and LTL-pattern (Hahn et al. 2022)
for temporal logic), they target domain-specific specifications rather than SysML-based system modeling. This motivates a benchmark grounded in a specific modeling language. To fill this gap, we introduce SysMBench, the first
public benchmark for SysML-based system model generation from natural-language requirements.

System Model Evaluation Metrics.
Evaluating system models expressed in a specific modeling
language poses challenges distinct from free-form text generation. Text similarity metrics (e.g., BLUE (Papineni et al.
2002) and ROUGE (Lin 2004)) and human evaluation do not
work well for evaluating system models with a specific modeling language for various reasons. Text similarity metrics
and embedding-based scores (e.g., bertscore (Zhang et al.
2019)) are convenient but operate primarily on strings and
thus fail to capture syntactic correctness, structural correctness, and deeper semantics. Even minor dissimilarities can
result in significant problems. Human expert evaluation (Li
et al. 2023) is more reliable but costly, slow, and difficult to
scale. Structure-aware metrics (e.g., incorporating abstract
syntax trees (Ren et al. 2020)) better assess structural plausibility yet still struggle to judge semantic equivalence and
constraint preservation. To address these limitations, we propose SysMEval, which decomposes both reference and predicted models into atomic semantic assertions and computes

1 Requirements

2 System Model with Textual Notation

Once charging begins, the system monitors package 'Charging’ {
the current battery level (displayed as a
private import ScalarValues::*;
percentage). If the battery level is below
attribute def BatteryCharged;
100%, it will automatically replenish the
part battery;
battery. This cycle repeats until the battery
part powerSystem;
level reaches or exceeds 100%, at which
action def MonitorBattery {…}
point the system automatically terminates
action def AddCharge {…}
the charging process. The entire charging
action def EndCharging;
operation is fully automated, requiring no
action def ChargeBattery {
manual intervention, thereby ensuring the
loop action charging {
battery is safely and reliably fully charged
action monitor : MonitorBattery{…}
while preventing overcharging.
then if monitor.charge < 100 {…}
}until charging.monitor.charge >=100;
4
Domain Label
Energy materials
then action endCharging : EndCharging;
then done;
Control Structure
5 Key Grammar
}
2
6 Difficulty Level }

3 System Model with Graphical Notation
Charging
<<action def>>

ChargeBattery
<<action>>

monitor

[monitor.batteryCharge < 100]
[monitor.batteryCharge >= 100]

<<action>>

<<action>>

addCharge

endCharge

Figure 2: An overview of SysMBench. Each sample consists of six components.
assertion-level precision and recall to determine correctness
and completeness.

SysMBench
Overview
SysMBench aims to facilitate the development and evaluation of automated system model generation techniques. As
shown in Figure 2, each sample in SysMBench consists of
six components. ❶ Requirements: An English natural language description detailing the functional requirements of
the software system. ❷ System Model with Textual Notation: A developer-written textual implementation of the
system model using SysML syntax. ❸ System Model with
Graphical Notation: A corresponding visualized system
model diagram automatically rendered from the textual representation. ❹ Domain Label: The application domain of
the system. ❺ Key Grammar: A key grammar to construct
the system model. ❻ Difficulty Level: A assigned difficulty
level ranging from 1 to 5.

Benchmark Construction Pipeline
The construction pipeline consists of five stages as follows.
Stage 1: System Model Collection and Preprocessing.
We crawl system models with textual notation from publicly
available SysML teaching materials and example repositories (Community 2025), resulting in a list of 161 unique system models across multiple domains. However, due to their
origin from teaching materials, some system models suffer
from three types of issues. (1) Lack practical scenarios: the
system models are only used to demonstrate some grammar usage (e.g., comment) and do not contain actual scenarios. (2) Cross reference: some model reference elements
are defined in external files. (3) The name lacks semantics:
some system models are poorly named and do not reflect
their functionality, e.g., “example1”. The examples of these

three issues is provided in Appendix A. To address these issues, the first author manually reviewed and preprocessed all
models, i.e., the models without practical scenarios were removed, referenced elements from other files were manually
inlined to make each system model self-contained, and all
model names were revised to accurately reflect their semantics. This preprocessing ensures that each system model is
independent, meaningful, and suitable for downstream generation and evaluation.
Stage 2: Natural Language Requirements Annotation. We assembled an annotation team consisting of two
graduate-level software engineering students from a prestigious university. Each annotator has over four years of experience in software engineering and is familiar with system
modeling concepts. The annotators are not co-authors and
obtain adequate payments. To ensure quality, we first establish two key criteria for requirements through discussions
with annotators. (1) Naturalness: ensures the requirements
read like a natural description from the perspective of a realworld stakeholder. (2) Completeness: all structural and behavioral aspects of a system model must be reflected in the
natural language requirements. During the annotation process, each requirement undergoes a dual-annotation process,
with one annotator assigned to its initial drafting and another
responsible for meticulous double-checking.
Stage 3: Requirements and Model Validation. To ensure the quality of our SysMBench, we conduct model-side
and requirements-side validation. (1) System Model Validation. Since some system models were modified during preprocessing, the first author manually loaded each system
model with textual notation into a SysML interpreter to ensure it compiles correctly into a valid system model diagram
with graphical notation. (2) Requirements Validation. For
each requirements description, we verify that all elements
in the system model are traceable to at least one sentence,
and the description does not contain extra content.

Domain

Number

Requirement Tokens
Avg Max
Min

System Model Lines
Avg Max
Min

Vehicle Traffic
Photography Technique
Information Management
Simulation Calculation
Energy materials
Network Communication
Fault diagnosis
Aerospace
Confidentiality and security
Systems Engineering
Embedded device
Medical Health
Water resource transportation

108
12
8
4
3
3
3
3
2
2
1
1
1

131
100
122
124
126
125
137
109
101
153
85
135
111

229
119
181
156
192
130
178
152
136
196
85
135
111

71
78
82
101
88
118
102
70
67
110
85
135
111

45
23
21
23
34
30
42
29
28
52
16
144
18

158
34
44
36
55
34
62
54
33
73
16
144
18

7
14
3
15
23
24
25
15
24
32
16
144
18

Total

151

127

229

67

41

158

3

Table 1: Statistics of our SysMBench.
Stage 4: Domain Label Annotation. To annotate each
sample’s domain label, we manually design a domain taxonomy. Specifically, we read the office tutorial from the
SysML organization. Based on this tutorial, we determine
the top 10 domains that frequently occur. Finally, we invited
the annotation team to annotate domain labels for each sample based on the requirements and our taxonomy. During the
domain labeling process, the annotators found that five samples did not belong to any domain in our taxonomy. Thus,
we add three additional domains to solve this issue. The domain taxonomy can be found in Appendix B.
Stage 5: Key Grammar Label Annotation. This label
indicates that generating a system model requires mastering
key grammar. Due to our system model from teaching materials, all system models have been classified into a set of
categories by their official developers, which indicates that
a system model is used to demonstrate which key grammar.
Thus, we take the categories as our grammar taxonomy and
the classification of each sample as its key grammar label.
The grammar taxonomy and the grammar label distribution
can be found in Appendix C.
Stage 5: Difficulty Level Creation. We introduce a system of difficulty levels for system model generation problems. We recognize that determining these levels is inherently ambiguous and subjective, akin to the informal designations used by online programming platforms (e.g., LeetCode (LeetCode 2025)) and in existing research (Luo et al.
2023). Nevertheless, we propose an approximation that can
calculate a difficulty level by parsing the system model expressed in a specific model description language, which is
based on the LoM. The rules to label difficulty level and the
difficulty level distribution can be found in Appendix D.

Benchmark Statistics
Table 1 summarizes the core statistics of SysMBench, which
contains 151 samples across 13 domains. The domain distribution is naturally uneven (i.e., vehicle traffic domain contribute many samples) due to the varying availability of pub-

lic teaching materials. To mitigate this bias, we report both
macro-averaged in our experiments. In terms of the size, requirement description contains about 127 tokens on average,
ranging from 67 to 229. The corresponding system models
have an average of 41 lines in textual notation, with a minimum of 3 lines and a maximum of 158 lines. This reflects
the diversity of real-world modeling tasks covered by SysMBench.

SysMEval Metrics
We design a novel semantics-aware evaluation metric named
SysMEval to assess the quality of automatically generated
system models.

Key Ideas
Inspired by Fact-QA (Fernandez, Scarlatos, and Lan 2024)
and FActScore (Min et al. 2023), SysMEval is based on two
key ideas.
Key idea 1: Atomic component or behavior as a unit.
A system model is composed of multiple granular elements
that define either structural components (e.g., part and attribute) or behavioral aspects (e.g., action and control structure). SysMEval treats each such element as an atomic modeling claim and assigns them an equal weight of importance,
enabling fine-grained evaluation that aligns with the semantics of system-level design.
Key idea 2: Reference-supported matching. Unlike traditional metrics that rely on exact string or syntactic tree
matching, SysMEval adopts a semantics-aware comparison
strategy. An atomic modeling claim is correct if it is semantically supported by the reference model, even if the textual
form or syntactic structure differs. This allows SysMEval
to capture equivalence under renaming, reordering, or abstracted representations, which are common in real-world
modeling practices.

Family

LLMs
Name

Size

BLEU

ROGUE

Evaluation Metric (%)
BertScore SysM-P SysM-R

SysM-F1

General LLMs
GPT-4
Claude 3
DeepSeek
Mistral
Qwen3
Gemma2
LLama3
InternLM
Baichuan2
ChatGLM3

gpt-4.1-2025-04-14
Claude 3 Opus
DeepSeek R1
Mistral-7B-instruct
Qwen3-32B
gemma-2-9b-it
Llama-3.1-8B-Instruct
internlm3-8b-instruct
Baichuan2-13B-Chat
ChatGLM3-6B

?
?
685B
7B
32B
9B
8B
8B
13B
6B

2.0
2.6
4.0
1.0
2.4
1.2
1.0
<0.1
<0.1
<0.1

41
42
47
42
44
44
41
36
38
37

65
62
69
59
66
59
57
52
52
47

71
70
58
45
66
53
34
21
36
17

46
56
60
48
58
59
35
47
58
24

56*
59*
53
46
62*
56*
34
29
45
20

42
45
44
30
42
31
36

58
64
62
60
58
34
42

52
48
42
44
49
31
35

63
54
54
46
47
42
55

57*
51
48
45
48
36
43

Code LLMs
DeepSeekCoder
Mistral Open
Phind
Magicoder
WizardLM
Code Llama
CodeGen2.5

DeepSeek-Coder-V2-Lite
Codestral-22B-v0.1
Phind-CodeLlama-34B-v2
Magicoder-S-CL-7B
WizardCoder-15B-V1.0
CodeLlama-13b-Instruct-hf
CodeGen2.5-7B-Instruct

16B
22B
34B
7B
15B
13B
7B

0.5
2.1
1.5
0.1
0.4
1.0
0.2

Table 2: Performance on System Model Generation. Bold indicates the best result, and an asterisk (*) marks the top-5.

Definition
Let Mp denote the generated system model to be evaluated,
and Mt the ground-truth system model written by human experts. SysMEval decomposes both Mp and Mt into sets of
atomic modeling claims, denoted as Sp and St , respectively.
The decomposition is performed via LLMs guided by a carefully designed prompt P . Based on the two sets, SysMEval
defines two core metrics:
SysMEval Precision (SysM-P): the proportion of atomic
claims in the generated system model (Sp ) that are semantically supported by the reference system model (St ).
SysMEval-P =

1 X
I[a is supported by St ]
|Sp |

(1)

a∈Sp

SysMEval Recall (SysM-R): the proportion of atomic
claims in the reference system model (St ) that are successfully recovered in the generated system model Sp .
1 X
SysMEval-R =
I[a is covered by Sp ]
|St |

(2)

a∈St

Based on the SysM-P and SysM-R, we can also calculate
the F1 score as the SysMEval-F1.

Implementation
We implement SysMEval using GPT-4 (i.e., gpt-4.1-202504-14), which is responsible for two core tasks: (1) decomposing both the generated and reference system models into
atomic modeling claim sets (Sp and St ), and (2) evaluating

the semantic alignment between claims across the two sets.
To guide the LLMs in performing these tasks, we adopt a
chain-of-thought prompting strategy. The prompt P for SysMEval and GPT-4 configuration details are provided in Appendix E.

Experiments
Base LLMs.
We selected 17 popular LLMs from different families and
evaluated them in SysMBench. They cover 10 general
LLMs (i.e., gpt-4.1-2025-04-14 and Qwen3-32B) and 7
Code LLMs (i.e., starcoder2-15b, DeepSeek Coder-16B and
CodeLLama-13B). The selected LLMs and their introduction can be found in Appendix F. We use official interfaces
or implementations to reproduce these LLMs. We run these
LLMs on 4 NVIDIA A6000-48G GPUs.

Selected Traditional Metrics.
To comprehensively evaluate the LLMs from multiple perspectives, we also selected three widely adopted traditional
metrics for domain-specific language generation.
BLEU. The BLEU score (Papineni et al. 2002) is used
to measure the token-level similarity between the generated
system model and the ground truth.
ROUGE. The ROUGE score (Lin 2004) is used to quantify how much of the token overlap between the generated
system model and the ground truth system model. Following common practice, ROUGE-L (F1) is selected to balance
coverage and exactness.
BertScore. BERTScore (Zhang et al. 2019) computes
token-level semantic similarity using contextual embeddings

zero−shot

CoT

grammar

zero−shot

8
6.16.3

6
4
2
0

3.1
2.6
1.9 2.2

GPT−4

2.6

2.42.4 2.1
1.9

Claude 3

Qwen 3

2.8
1.31.0

1.1

2.0
1.1 1.01.1

ROUGE−L (%)

10.2

10

BLUE (%)

few−shot

41 39 42

45

44

Claude 3

Qwen 3

72 69

71
58

70

68
56

66

CoT

50

56

53
40

10
GPT−4

zero−shot

59
52

45

41

18

GPT−4

Claude 3

Qwen 3

42 44 41 41

20

grammar

61 59

57

41 42

Gemma 2 DeepSeekCoder

LLM

Gemma 2DeepSeekCoder

LLM

SysM−R (%)

SysM−P (%)

80
70
60
50
40
30
20
10
0

few−shot

44 46

38

LLM

zero−shot

44 45

42 44 42

grammar

30

0

Gemma 2 DeepSeekCoder

CoT

50

50
40

few−shot

70
60
50
40
30
20
10
0

few−shot

58

56
50 50

46
38

47

58

CoT

63

50

grammar

59 60

60

65

63

54

50

43
35
22

GPT−4

Claude 3

Qwen 3

Gemma 2DeepSeekCoder

LLM

Figure 3: Average benchmark scores of top-5 LLMs when enhanced with differing strategies.
from a pretrained encoder. We use bert-base-uncased as the
pretrained encoder and report the F1 variant of BERTScore.

Evaluating LLMs Performance on SysMBench.
We first evaluate the selected LLMs within a zero-shot
prompting strategy to reflect their capability on our SysMBench. The prompt and experimental setting are provided in
Appendix G. Table 2 shows the evaluation results of different LLMs. We observe that DeepSeek R1 achieve best score
in terms of BLEU, ROUGE, and BertScore, indicating that
its peform better at both text and semantic levels. For our
metrics, GPT-4, DeepSeek R1 and Qwen3-32B achieve the
highest SysM-P, SysM-R, and SysM-F1 among all LLMs,
respectively. However, all LLMs exhibit relatively low metrics, especially for the BLUE score. For instance, DeepSeek
R1 only achieves a BLUE score of 0.04 on our SysMBench.
It suggests the difficulty of our dataset, and demonstrates
that current LLMs are ineffective at generating system models with the SysML language. We also observe a clear SysMP and SysM-R trade-off. GPT-4, DeepSeek R1, and Qwen 332B prioritize generating “clean” system models with higher
precision than recall (i.e., SysM-P > SysM-R), omitting
long-tail elements. The other LLMs favor generating “broad
coverage” system model at the cost of precision. Finally,
model size is not decisive for the quality of generated system
models. Smaller and well-aligned LLMs (e.g., Gemma-29b-it) can match or surpass much larger open-source LLMs.

Assessing Common Enhancement Strategies.
Prompt quality plays a pivotal role in an LLM’s ability to
generate accurate system models. To investigate whether
practical prompt engineering techniques can narrow this
sizeable performance gap observed in Table 2 and reveal latent capabilities of these LLMs, we examine three widely
adopted enhancement strategies (i.e., few-shot, chain-ofthought, and grammar prompting). The specific prompt templates are provided in Appendix H. Figure 3 shows the
BLUE, ROUGE-L, SysM-P, and SysM-R scores achieved
by the top-5 LLMs (ranked by SysM-F1 in Table 2) when
applying each strategy.
Few-shot Prompting. Few-shot prompting (Brown et al.
2020) involves providing a few examples to guide the LLMs.
In our experiment, we just provide one example in the
prompt. We observe that this technique consistently boosts
surface-level text similarity, but diminishes semantic and
structural accuracy. Specifically, BLEU rises slightly across
most LLMs, whereas both SysM-P and SysM-R decline
broadly. For example, Claude 3’s BLEU rises from 2.6%
to 6.1%, but its SysM-R falls from 56% to 47%. These results indicate that few-shot prompting can cause the LLMs
to overfit to text-level patterns and narrow its coverage.
Chain-of-thought (CoT) Prompting. Chain-of-thought
prompting (Wei et al. 2022) guides the LLMs through a stepby-step process to arrive at a solution, mimicking human
logical progress. In our experiment, we ask LLMs to reason

Performance (%)

SysM−P
100
75

85
79 81

SysM−R

86
76

61

50

72

71

54

69

68
66
66
60
60

47
35

31

25

65

20

35
20

1214 1112

0

ion ork ce rial ed rity hy ffic sis ent ing ion cal
ulat netwerospamatembeddsecutograp trdaiagnoagemgineerpor tat medi
a
calc
e
pho
man en trans

Domain

Figure 4: Performance in various application domains.

Correct Usage
package TrafficSignalSystem {
Hallucination: Missing
private import ScalarValues: Real;
enum def TrafficLightColor {
enum green;
enum yellow;
Correct Usage
enum red;
}
part def TrafficSignal {
attribute currentColor : TrafficLightColor;
}
part def TrafficSignalSystem {
Hallucination: Incorrect Usage
part trafficSignal : TrafficSignal;
Correct Usage
part greenSignal : TrafficSignal {
attribute redefines currentColor = TrafficLightColor::green;
}
}

Figure 5: Incorrect system model generated by Claude 3.
Difficulty Levels

Metrics
BLUE
ROUGE
SysMEval-P
SysMEval-R

L1

L2

L3

L4

L5

2.8
45
67
52

2.4
46
68
62

2.3
43
58
61

0.4
36
64
76

0.5
40
51
51

Table 3: Performance in various difficulty levels.

through extracting key elements and map them to the appropriate grammars in the SysML. Contrary to expectations,
we find that this strategy rarely yields performance gains and
can even degrade it. For instance, Claude 3’s SysM-R score
declines from 56% to 43%. Our error analysis (in Appendix
I) reveals that the intermediate rationales frequently introduce redundant or partially formed constructs, which propagate into the final output and lower recall. Nevertheless,
the explicit rationale produced by CoT remains valuable for
post-doc system model debugging.
Grammar Prompting. Grammar prompting (Wang et al.
2023) injects an explicit Backus–Naur Form (BNF) specification for SysML directly into the prompt, steering the
LLMs to follow the language’s formal syntax and production
rules. We observe that this grammar prompting can boost
surface-level metrics that reward syntactic fidelity. For instance, Claude 3’s BLEU score jumps from 2.6% to 10.2%.
However, this improvement carries a semantic cost. Because
the LLMs strives to satisfy every grammar rule, it tends to
over-generate optional constructs, lowering semantic precision. For example, Claude 3’s SysM-P drops from 70% to
57%. Thus, grammar prompting produces system models
that look more “complete” on the surface but are less semantically accurate in practice.

Performance across Different Domains and Levels.
The domains and complexity determine the performance of
LLMs on system model generation. To investigate how they
affect the performance, we perform a fine-grained decomposition of the best-performing model in our benchmark (i.e.,
Qwen 3-32B).
Domain Results. Figure 4 shows the SysMEval metrics

of Qwen3-32B across different domains. We can observe
that SysM-P is highest in calculation and network, with
aerospace close behind, whereas SysM-R peaks in security
and remains strong in calculation. Several domains exhibit
a large gap between SysM-P and SysM-R, such as materials(72% P vs. 31%R). Thus, recall-oriented strategies (e.g.,
explicit domain-knowledge infusion) are essential. Besides,
safety-critical domains such as transportation and medical
are much lower on both metrics, underscoring current limitations in high-reliability scenarios.
Levels Results. Table 3 shows the results across different levels. We can observe that the surface metrics (e.g.,
BLEU) show a monotonic decline from level 1 to level 5,
whereas SysMEval is not monotonically. Interestingly, the
precision–recall gap widens as the level grows. Balancing
these competing objectives may be a crucial question for
sustaining overall performance under complex scenarios.

Key Grammar Analysis.
To pinpoint the exact grammatical weaknesses that limit current LLMs, we manually inspect typical failure cases from
SysMBench. Figure 5 shows an incorrect system model
generated by Claude 3 for the fifth sample (the groundtruth in Appendix J). While the model correctly applies the
enumeration and attribute rules, two hallucination patterns
emerge: (1) Missing package import. The model omits a
required import for the Real type. (2) Misusing specialization grammar. A type-level specialization in the reference
model is collapsed into an instance-level construct, and the
redefines keyword is wrongly applied to that instance.
More grammar-level analysis (e.g., the performance across
different grammars) is in Appendix K.

Conclusion
We introduce SysMBench, the first dataset and benchmark
capable of evaluating system model generation from natural
language requirements by LLMs. SysMBench comprise 151
human-curated scenarios that cover diverse range of popular domains and varying difficulty levels. We also introduce
SysMEval, a semantics-aware metrics for assess the correctness and completeness of system models. Our evaluation re-

veals that current LLMs, including GPT-4 perform poorly on
SysMBench, with a SysM-F1 of 56%. This underscores the
need for advancements in LLM-based system model generation. We open-source SysMBench to facilitate future research in this domain.

References
Achiam, J.; Adler, S.; Agarwal, S.; Ahmad, L.; Akkaya, I.;
Aleman, F. L.; Almeida, D.; Altenschmidt, J.; Altman, S.;
Anadkat, S.; et al. 2023. Gpt-4 technical report. arXiv
preprint arXiv:2303.08774.
Ahlbrecht, A.; Lukić, B.; Zaeske, W.; and Durak, U.
2024. Exploring SysML v2 for Model-Based Engineering of Safety-Critical Avionics Systems. In 2024 AIAA
DATC/IEEE 43rd Digital Avionics Systems Conference, 1–8.
Austin, J.; Odena, A.; Nye, M.; Bosma, M.; Michalewski,
H.; Dohan, D.; Jiang, E.; Cai, C.; Terry, M.; Le, Q.; et al.
2021. Program synthesis with large language models. arXiv
preprint arXiv:2108.07732.
Basha, N. M. J.; Moiz, S. A.; and Rizwanullah, M. 2012.
Model based software development: issues & challenges.
Special Issue of International Journal of Computer Science
& Informatics, 2(1): 2.
Brown, T.; Mann, B.; Ryder, N.; Subbiah, M.; Kaplan, J. D.;
Dhariwal, P.; Neelakantan, A.; Shyam, P.; Sastry, G.; Askell,
A.; et al. 2020. Language models are few-shot learners. Advances in neural information processing systems, 33: 1877–
1901.
Cao, J.; Lu, Y.; Li, M.; Ma, H.; Li, H.; He, M.; Wen, C.; Sun,
L.; Zhang, H.; Qin, S.; et al. 2025. From Informal to Formal–
Incorporating and Evaluating LLMs on Natural Language
Requirements to Verifiable Formal Proofs. arXiv preprint
arXiv:2501.16207.
Cen, J.; Liu, J.; Li, Z.; and Wang, J. 2025. SQLFixAgent: Towards Semantic-Accurate Text-to-SQL Parsing via
Consistency-Enhanced Multi-Agent Collaboration. In Proceedings of the AAAI Conference on Artificial Intelligence,
volume 39, 49–57.
Community, S. M. 2025. SysML-v2-Release. https://github.
com/Systems-Modeling/SysML-v2-Release.
Feiler, P. H.; and Gluch, D. P. 2012. Model-based engineering with AADL: an introduction to the SAE architecture
analysis & design language. Addison-Wesley.
Fernandez, N.; Scarlatos, A.; and Lan, A. 2024. SyllabusQA: A Course Logistics Question Answering Dataset.
In Proceedings of the 62nd Annual Meeting of the Association for Computational Linguistics, 10344–10369.
Hahn, C.; Schmitt, F.; Tillman, J. J.; Metzger, N.; Siber, J.;
and Finkbeiner, B. 2022. Formal specifications from natural
language. arXiv preprint arXiv:2206.01962.
Hause, M.; et al. 2006. The SysML modelling language.
In Fifteenth European systems engineering conference, volume 9, 1–12.
Jin, D.; Zhao, S.; Jin, Z.; Chen, X.; Wang, C.; Fang, Z.;
and Xiao, H. 2024. An evaluation of requirements modeling for cyber-physical systems via llms. arXiv preprint
arXiv:2408.02450.

LeetCode. 2025. LeetCode Website. https://leetcode.com/.
Li, Q.; Cui, L.; Kong, L.; and Bi, W. 2023. Collaborative
evaluation: Exploring the synergy of large language models
and humans for open-ended generation evaluation. arXiv eprints, arXiv–2310.
Lin, C.-Y. 2004. ROUGE: A Package for Automatic Evaluation of Summaries. In Text Summarization Branches Out,
74–81.
Lindsey, N. J.; Alimardani, M.; and Gallo, L. D. 2020. Reliability analysis of complex NASA systems with model-based
engineering. In 2020 Annual reliability and maintainability
symposium (RAMS), 1–8.
Liu, J.; Xia, C. S.; Wang, Y.; and Zhang, L. 2023. Is
your code generated by chatgpt really correct? rigorous
evaluation of large language models for code generation.
Advances in Neural Information Processing Systems, 36:
21558–21572.
Luo, Z.; Xu, C.; Zhao, P.; Sun, Q.; Geng, X.; Hu, W.; Tao, C.;
Ma, J.; Lin, Q.; and Jiang, D. 2023. Wizardcoder: Empowering code large language models with evol-instruct. arXiv
preprint arXiv:2306.08568.
Min, S.; Krishna, K.; Lyu, X.; Lewis, M.; Yih, W.-t.; Koh,
P.; Iyyer, M.; Zettlemoyer, L.; and Hajishirzi, H. 2023.
FActScore: Fine-grained Atomic Evaluation of Factual Precision in Long Form Text Generation. In Proceedings of
the 2023 Conference on Empirical Methods in Natural Language Processing, 12076–12100.
Papineni, K.; Roukos, S.; Ward, T.; and Zhu, W.-J. 2002.
Bleu: a method for automatic evaluation of machine translation. In Proceedings of the 40th annual meeting of the
Association for Computational Linguistics, 311–318.
Ren, S.; Guo, D.; Lu, S.; Zhou, L.; Liu, S.; Tang, D.; Sundaresan, N.; Zhou, M.; Blanco, A.; and Ma, S. 2020. Codebleu: a method for automatic evaluation of code synthesis.
arXiv preprint arXiv:2009.10297.
Vijayaraghavan, P.; Shi, L.; Ambrogio, S.; Mackin, C.; Nitsure, A.; Beymer, D.; and Degan, E. 2024. Vhdl-eval: A
framework for evaluating large language models in vhdl
code generation. In 2024 IEEE LLM Aided Design Workshop (LAD), 1–6. IEEE.
Wang, B.; Wang, Z.; Wang, X.; Cao, Y.; A Saurous, R.; and
Kim, Y. 2023. Grammar prompting for domain-specific language generation with large language models. Advances in
Neural Information Processing Systems, 36: 65030–65055.
Wei, J.; Wang, X.; Schuurmans, D.; Bosma, M.; Xia, F.;
Chi, E.; Le, Q. V.; Zhou, D.; et al. 2022. Chain-ofthought prompting elicits reasoning in large language models. Advances in neural information processing systems, 35:
24824–24837.
Yu, T.; Zhang, R.; Yang, K.; Yasunaga, M.; Wang, D.; Li,
Z.; Ma, J.; Li, I.; Yao, Q.; Roman, S.; et al. 2018. Spider:
A large-scale human-labeled dataset for complex and crossdomain semantic parsing and text-to-sql task. arXiv preprint
arXiv:1809.08887.
Zhang, T.; Kishore, V.; Wu, F.; Weinberger, K. Q.; and Artzi,
Y. 2019. Bertscore: Evaluating text generation with bert.
arXiv preprint arXiv:1904.09675.

Zhu, Q.; Cao, J.; Lu, Y.; Lin, H.; Han, X.; Sun, L.; and Cheung, S.-C. 2025. Domaineval: An auto-constructed benchmark for multi-domain code generation. In Proceedings of
the AAAI Conference on Artificial Intelligence, volume 39,
26148–26156.

Appendix
Table of Contents
• Appendix A: Issues in the Origin System Model.
• Appendix B: Domain Taxonomy for our SysMBench.
• Appendix C: Grammar Taxonomy and its Distribution.
• Appendix D: Difficulty and its Distribution.
• Appendix E: SysMEval Metrics Calculation.
• Appendix F: Studied LLMs.
• Appendix G: Experimental Setting for Evaluation.
• Appendix H: Prompt for Enhancement Strategies.
• Appendix I: Error Analysis.
• Appendix J. Ground Truth of Case Study.
• Appendix K. More Analysis on Key Grammar.

A. Issues in the Origin System Model
To illustrate the quality issues that often appear in publicly
available teaching materials, we select three representative
snippets as shown in Figure 61 :
• Lack practical scenarios. The first snippet (Figure 13a)
is a self-contained package declaration whose sole purpose is to showcase import and alias syntax. It does not
correspond to any concrete use case or behavioural requirement, making it unsuitable for evaluating a model’s
ability to capture real-world system semantics.
• Cross reference. The second snippet (Figure 13b)
references elements (FuelOutPort, FuelInPort,
FuelTankAssembly, Engine) that are defined in external files. When such cross-file dependencies are unavailable, the model becomes syntactically incomplete
and cannot be parsed or analyzed in isolation.
• Name lacks semantics. The third snippet (Figure 6c) contains identifiers such as Fuel, Person,
and Vehicle, but its enclosing package is simply
called Items Example. Non-descriptive names (e.g.,
example1, demo) obscure the intent of the model and
hamper downstream tasks like retrieval and traceability
recovery.
These examples motivate the data-cleaning heuristics,
where we filter out grammar-only samples, resolve missing
cross references, and rename packages and parts to reflect
their functional roles.
1
All examples are taken from the raw corpus before any cleaning or refactoring.

package ’Package Example’ {
public import ISQ::TorqueValue;
private import ScalarValues::*;
private part def Automobile;
public alias Car for Automobile;
alias Torque for ISQ::TorqueValue;
}
(a) Lack practical scenarios

package ’Interface Example’ {
private import ’Port Example’::*;
part def Vehicle;
interface def FuelInterface {
end supplierPort : FuelOutPort;
end consumerPort : FuelInPort;
}
part vehicle : Vehicle {
part tankAssy : FuelTankAssembly;
part eng : Engine;
interface : FuelInterface connect
supplierPort ::¿ tankAssy.fuelTankPort to
consumerPort ::¿ eng.engineFuelPort;
}
}
(b) Cross reference

package ’Items Example’ {
private import ScalarValues::*;
item def Fuel;
item def Person;
part def Vehicle {
attribute mass : Real;
ref item driver : Person;
part fuelTank {
item fuel: Fuel;
}
}
}
(c) The name lacks semantics

Figure 6: Illustrations of three common issues in SysML
specification examples

B. Domain Taxonomy for our SysMBench.
Based on a careful review of the official SysML tutorial and
the distribution of our 161 raw samples, we distilled ten core
application domains that appear most frequently. During annotation, the team encountered five models that did not fit
any of these ten domains, prompting the inclusion of three
additional categories. Thus, the final taxonomy comprises
thirteen domains, listed below with a brief description of
the typical systems each domain covers.
• Vehicle Traffic: Road / rail vehicles, traffic-control systems, and autonomous-driving components.
• Photography Management: Camera devices, photoworkflow management, and image-processing pipelines.
• Information Management: Databases, document
repositories, and enterprise information systems.
• Simulation Calculation: Numerical simulators and
high-performance computing for physics or engineering.
• Energy Materials: Battery packs, fuel cells, and energystorage or material-processing subsystems.
• Network Communication: Wired/wireless network
stacks, protocol suites, and router/switch designs.
• Fault Diagnosis: Health-monitoring or diagnostic
frameworks for mechanical and electronic equipment.
• Aerospace: Aircraft, satellites, launch vehicles, and their
on-board subsystems or ground support.
• Confidentiality and Security: Cryptographic modules,
secure data flows, and access-control mechanisms.
• System Engineering: End-to-end system-of-systems architectures and generic SE process models.
• Embedded Device: Resource-constrained controllers,
IoT nodes, and real-time firmware architectures.
• Medical Health: Diagnostic devices, patient-monitoring
systems, and healthcare information flows.
• Water Resource Transportation: Water-distribution
networks, pipeline control, and hydraulic transport.
The last three domains were introduced specifically to accommodate samples that could not be meaningfully mapped
to the initial ten. For reproducibility, the full set of annotated
labels is released together with SysMBench.

C. Grammar Taxonomy and Its Distribution.
To characterise the syntactic scope of S YS MB ENCH, we followed the official SysML v2 Textual Notation training material and distilled a fine-grained grammar taxonomy. Each
category below corresponds to a language construct that appears in at least one of the 161 benchmark models. The same
taxonomy was used by the annotation team to label every
sample, enabling us to compute coverage statistics.
• Attribute: Declares a property whose value describes a
characteristic of a part, item, or package.
• Generalization: Specifies inheritance, allowing a definition to specialise and extend another.
• Subsetting: States that one feature’s value set is a subset
of another feature within the same context.

• Redefinition: Overrides an inherited feature by changing
its name, type, or multiplicity.
• Enumeration: Constrains an attribute to a predefined,
discrete set of literal values.
• Part: A composable structural element that exists in
space and time and may contain sub-parts.
• Item: A thing that can flow or be consumed/produced by
the system (e.g. fuel, data); every part is an item, but not
vice-versa.
• Connection: Establishes an explicit link between two
features; if no custom definition is provided, the generic
Connection is used.
• Port: An externally visible feature that exposes services
or flows; a conjugate port (˜) reverses direction for compatibility.
• Function-based Behavior: Captures behaviour in terms
of actions, their parameters, and the flow/ succession that
orders them.
• Interface: A reusable connection definition that binds
compatible supplier and consumer ports.
• State-based Behavior: Describes discrete states, transitions, guards, and entry/exit behaviours.
• Individual and Snapshot: An individual denotes exactly one instance; a snapshot freezes that instance at a
specific instant.
• Binding Connector: Asserts that the connected features
share the same value within a given context.
• Variant Configuration: Language primitives for modelling product-line variability and selectable options.
• Requirement: A statement of expected capability or
constraint that the system shall satisfy.
• Verification: Elements that define tests or analyses used
to demonstrate requirement satisfaction.
• Analysis and Trade: Uses calculations and constraints
to explore design alternatives and trade-offs.
• View and Viewpoint: A viewpoint declares stakeholder
concerns; a view realises a viewpoint by filtering and presenting model elements.
• Dependency: A generic relationship expressing usage,
ownership, or visibility between namespaces.
• Model Constrainment: Constraints—formal Boolean
expressions—that must hold for the model to be valid.
• Language Extension: Embeds or references other languages (e.g. OCL, Alf) to enrich behavioural or analytical descriptions.
• Expression: A chain of feature references and operators
that computes a value; also used in shorthand featurevalue bindings.
• SequenceModeling: Represents temporal interaction using messages and event occurrences.
• Flow Connection: Transfers items or energy from an
output feature to an input feature, optionally constrained
by a flow definition.

• Action Definition: Declares a reusable behavioural
primitive with typed parameters.
• Action: An invocation (usage) of an action definition
within a behaviour specification.
• Conditional Succession: Orders actions with a guard
that determines whether the successor executes.
• Control Structure: Higher-level constructs such as
loop, if, and until that orchestrate actions.
• Assignment Action: Sets the value of a property or parameter during behaviour execution.
• Message: A discrete piece of communication sent between behavioural entities in sequence modelling.
• Opaque Action: An action whose internal behaviour is
defined in an external language or left unspecified.
• State Definition: Declares the set of allowable states and
their sub-state hierarchy.
• State: A concrete condition during which specific invariants hold and activities may execute.
• Transition: A directed relationship that moves execution
from one state to another when its trigger and guard are
satisfied.
• Occurrence: A general term for an event or condition
that happens at a point in time.
• Individual: (Repeated for completeness) A unique instance distinguished from all others of its type.
• Calculation: A reusable computation that returns a
value, often referenced by constraints or analyses.
• Constraint: A Boolean expression that restricts values
or relationships within the model.
• Analysis: A structured evaluation, often quantitative,
performed on the model or its parameters.
• Use Case: Captures an external actor’s goal and the system behaviour required to achieve it.
• Variability: (Alias for Variant Configuration) Explicit
modelling of optional or alternative features.
• Functional Allocation: Maps behaviours (functions)
onto structural elements (parts or items).
• Metadata: Ancillary information—such as author, version, or tags—attached to model elements.
• Filtering: A view mechanism that selects a subset of
model elements based on criteria.
• View: (Alias listed for clarity) A concrete projection of
the model that conforms to a viewpoint.
• Package: A namespace that organises definitions and
controls their visibility and import.

D. Difficulty and Its Distribution.
We approximate the difficulty of a system model generation task by the Lines of Model (LoM) contained in its
SysML text file, which is the number of non-blank, noncomment lines after preprocessing. Although difficulty is inherently subjective, prior work on program synthesis benchmarks has demonstrated that source-length provides a practical first-order signal (e.g., LeetCode’s ”easy/medium/hard”

tags or the code length strata. We therefore partition the 151
samples into five levels via empirically chosen LoM breakpoints.
Table 4 summarises the resulting frequency of samples
in each difficulty tier. Over 79% of the corpus falls within
Levels 1–2, indicating that most textbook SysML examples
remain succinct. Nevertheless, we retain a modest number
of large-scale models (Levels 4–5) to ensure that S YS MB ENCH also assesses an LLM’s ability to handle longer,
more intricate inputs.
Difficulty Level

LoM Range

#Samples

1
2
3
4
5

LoM < 30
30 ≤ LoM < 60
60 ≤ LoM < 90
90 ≤ LoM < 120
LoM ≥ 120

63
64
12
6
6

Table 4: Difficulty-level distribution of the S YS MB ENCH
corpus.

E. SysMEval Metric Calculation.
SysMEval quantifies how closely a generated SysML model
matches a reference model along two complementary axes:
precision (SysM-P) and recall (SysM-R). Given a pair
⟨reference, generated⟩, GPT-4 is prompted to
1. decompose each model into a set of atomic modelling
claims
2. align the two claim sets semantically, ignoring purely
syntactic differences
3. return a score in the form Score: matches/total.
Figure 7 and Figure 8 list the complete user prompts for
SysM-P and SysM-R, respectively.

F. Studied LLMs.
• gpt-4.1-2025-04-14: OpenAI’s April-2025 flagship
model (API only); supports up to ≈1 M-token context
and improves coding and long-context reasoning over
GPT-4o.
• Claude 3 Opus: Anthropic’s top-tier Claude-3 variant
with a 200 K–1 M token window, optimised for complex
reasoning and code.
• DeepSeek R1: 671 B-parameter MoE model (37 B
active) released Jan 2025; open-source, math- and
reasoning-oriented.
• Mistral-7B-Instruct: Apache-2 licensed 7 B model
(Sept 2023) with sliding-window attention for efficient
long sequences.
• Qwen3-32B: Alibaba’s bilingual 32 B dense model
(2025) featuring enhanced reasoning and instruction following.
• gemma-2-9b-it: Google Gemma 2 instruction-tuned 9 B
checkpoint (May 2025), light-weight but strong in English generation.

Your task is to evaluate the precision of a generated
system model. You will be given a reference system
model and a generated system model. Please perform the following steps:
1. List all atomic modeling claims made by the
generated system model. Each atomic claim should
correspond to a minimal, meaningful modeling element (e.g., the definition of a part, the declaration of
an attribute, the use of types, or structural relations
like containment or reference).
2. For each atomic claim in the generated model,
determine whether it is supported by the reference
model (i.e., the reference model contains the same
or equivalent element).
3. Summarize the results using the format: Score:
number of supported claims/total number of claims
in the generated model
You should ignore formatting or identifier naming differences if the structure and semantics match.
Input:
Reference Model:
{reference model}
Generated Model:
{generated model}
Output:

Figure 7: Prompt template for SysM-P (precision) evaluation.

Your task is to evaluate the recall of a generated
system model. You will be given a reference system
model and a generated system model. Please perform the following steps:
1. List all atomic modeling claims made by the
reference system model. Each atomic claim should
correspond to a minimal, meaningful modeling element (e.g., the definition of a part, the declaration of
an attribute, the use of types, or structural relations
like containment or reference).
2. For each atomic claim in the reference model,
determine whether it is covered by the generated
model (i.e., the generated model contains the same
or equivalent element).
3. Summarize the results using the format: Score:
number of covered claims/total number of claims in
the reference model
You should ignore formatting or identifier naming differences if the structure and semantics match.
Input:
Reference Model:
{reference model}
Generated Model:
{generated model}
Output:

Figure 8: Prompt template for SysM-R (recall) evaluation.

• Llama-3.1-8B-Instruct: Meta’s June-2025 8 B release
from the Llama-3.1 line, instruction-tuned with improved
safety.
• internlm3-8b-instruct: Shanghai AI Lab’s third-gen 8 B
bilingual model (Jan 2025) licensed under Apache 2.0.
• Baichuan2-13B-Chat: Baichuan AI’s 13 B chat model
(2023) trained on 2.6 T tokens, strong on Chinese–English tasks.
• ChatGLM3-6B: Zhipu AI’s 6 B open model (Oct 2024)
adding function-calling and code-interpreter skills.
• DeepSeek-Coder-V2-Lite: 16 B MoE code model (Apr
2025) claiming GPT-4-Turbo-level code quality with 130
K context.
• Codestral-22B-v0.1: Mistral’s 22 B code LLM (May
2024) trained on 80 + languages with a 32 K context window.
• Phind-CodeLlama-34B-v2: Phind fine-tune of CodeLlama 34 B achieving 73.8% pass@1 on HumanEval.
• Magicoder-S-CL-7B: UIUC’s 7 B model built with
OSS-Instruct for low-bias, high-quality code instructions.
• WizardCoder-15B-V1.0: WizardLM family 15 B model
(Jan 2024) evol-instruct-tuned; strong on HumanEvalPlus.
• CodeLlama-13B-Instruct-hf: Meta’s official 13 B instruct variant for general code synthesis and understanding.
• CodeGen2.5-7B-Instruct: Salesforce’s 7 B instructiontuned CodeGen 2.5 checkpoint (late 2024) targeting
multi-language code generation.

You are a senior MBSE engineer.
Task:
Given the following natural-language requirements,
create an OMG SysML v2 textual model.
Return only valid SysML v2 code, no explanations
or commentary.
––––– FEW-SHOT EXAMPLES –––––
Input Requirements:
req
Output Model:
design
––––– YOUR TURN –––––
Input Requirement:
requirement
Output Model:

Figure 10: Prompt template for the few-shot strategy.

G. Experimental Setting for Evaluation.
Figure 9 shows the evaluation prompt.
You are a senior MBSE engineer.
Task:
Given the following natural-language requirements,
create an OMG SysML v2 textual model.
Return only valid SysML v2 code, no explanations
or commentary.
Input Requirement:
{requirement}
Output Model:

You are a senior MBSE engineer.
Task:
1. Think step-by-step in a hidden scratchpad (not
shown to user)
- Extract key functional/non-functional information.
- Map them to various grammars in the SysML v2
textual grammar.
2. After thinking, output only valid SysML v2
textual code—no explanations, no scratchpad.
Input Requirement:
requirement
Output Model:

Figure 9: Prompt template for evaluation.
Figure 11: Prompt template for the CoT strategy.

H. Prompt for Enhancement Strategies.
Figure 10, Figure 11 and Figure 12 show the prompts for the
three enhancement strategies, seperately.

You are a senior MBSE engineer.
Task:
Given the following natural-language requirements,
create an OMG SysML v2 textual model.
Your output must conform to the BNF grammar
below (subset of SysML v2).
Return only valid SysML v2 code, no explanations
or commentary.
––––– SysML v2 BNF (subset) –––––
{bnf grammar} ––––––––––––––––––––––––––––––––––
Input Requirement:
{requirement}
Output System Model:

Figure 12: Prompt template for the grammar strategy.

I. Error Cases for Claude 3.
Figure 13 shows the case to explain the error of Claude with
CoT prompting strategies.

J. Ground Truth of Case Study.

package VehicleStructure {
abstract part def VehicleComponent;
part def Engine : VehicleComponent;
part def Transmission : VehicleComponent;
part def Wheel : VehicleComponent;
abstract part def Vehicle {
part engine : Engine[1];
part transmission : Transmission[1];
part wheels : Wheel[4];
}
}
(a) The Generated System Model by Claude 3

package ’VehicleDefinition’
part def Vehicle
part parts : VehiclePart[*];
part eng : Engine subsets parts;
part trans : Transmission subsets parts;
part wheels : Wheel[4] : parts;
abstract part def VehiclePart;
part def Engine : VehiclePart;
part def Transmission :¿ VehiclePart;
part def Wheel : VehiclePart;

Figure 14 shows the ground truth of the case study.

K. More Analysis on Key Grammar.
Table 5 and Table 6 show the performance of Qwen 3-32B
on each key grammar.

(b) The Ground Truth System Model

Figure 13: Illustrations of the error of Claude with CoT
prompting strategies.

package ’TrafficLightDefinition’ {
private import ScalarValues::Real;
enum def TrafficLightColor {
enum green;
enum yellow;
enum red;
}
part def TrafficLight {
attribute currentColor : TrafficLightColor;
}
part def TrafficLightGo specializes TrafficLight {
attribute redefines currentColor = TrafficLightColor::green;
}
}

Figure 14: Groundtruth of the case study.

Table 5: Per-category evaluation scores (Part 1)

Category

BLEU

ROUGE

BERTScore

SysM P

SysM R

Attribute
Generalization
Subsetting
Redefinition
Enumeration
Part
Item
Connection
Port
Function-based Behavior
Interface
State-based Behavior
Individual & Snapshot
Variant Configuration
Requirement
Verification
Analysis and Trade
View and Viewpoint
Dependency
Model Constrainment
Binding Connector
Language Extension
Expression

0.058
0.015
0.066
0.061
0.027
0.014
0.019
0.036
0.034
0.034
0.022
0.004
0.002
0.044
0.013
0.012
0.021
0.023
0.011
0.017
0.009
0.015
0.024

0.438
0.443
0.504
0.616
0.478
0.441
0.368
0.481
0.431
0.477
0.458
0.405
0.293
0.457
0.408
0.386
0.413
0.467
0.479
0.493
0.363
0.432
0.430

0.723
0.610
0.695
0.736
0.683
0.668
0.675
0.708
0.699
0.654
0.672
0.563
0.625
0.723
0.659
0.643
0.681
0.699
0.627
0.651
0.669
0.654
0.669

0.700
1.000
0.200
0.769
1.000
0.702
0.625
0.778
0.671
0.763
0.250
0.754
0.662
0.951
0.328
0.606
0.643
0.875
0.826
0.589
0.188
0.517
0.697

0.455
1.000
0.778
0.923
0.813
0.675
0.100
0.818
0.331
0.572
0.571
0.391
0.857
0.905
0.453
0.591
0.643
0.688
0.476
0.968
0.283
0.363
0.670

Table 6: Per-category evaluation scores (Part 2)

Category

BLEU

ROUGE

BERTScore

SysM P

SysM R

Sequence Modeling
Flow Connection
Action Definition
Action
Conditional Succession
Control Structure
Assignment Action
Message
Opaque Action
State Definition
State
Transition
Occurrence
Individual
Calculation
Constraint
Analysis
Use Case
Variability
Functional Allocation
Metadata
Filtering
View
Package

0.017
0.033
0.011
0.060
0.023
0.023
0.016
0.056
0.041
0.012
0.019
0.020
0.021
0.042
0.007
0.032
0.011
0.014
0.044
0.051
0.015
0.033
0.010
0.048

0.418
0.496
0.399
0.464
0.393
0.448
0.421
0.492
0.321
0.510
0.509
0.473
0.450
0.504
0.421
0.464
0.404
0.368
0.529
0.558
0.317
0.529
0.428
0.371

0.615
0.732
0.565
0.704
0.643
0.682
0.622
0.710
0.700
0.619
0.681
0.671
0.663
0.686
0.592
0.678
0.613
0.573
0.668
0.760
0.612
0.728
0.539
0.570

0.652
0.566
0.542
0.938
0.583
0.590
0.917
0.664
0.714
1.000
0.752
0.784
0.692
0.623
0.696
0.563
0.512
0.806
0.719
0.563
0.895
0.593
0.221
0.633

0.407
0.629
0.513
0.600
0.495
0.308
0.657
0.828
0.200
0.841
0.628
0.623
0.609
0.721
0.611
0.446
0.638
0.472
0.755
0.418
0.699
0.825
0.241
0.282

