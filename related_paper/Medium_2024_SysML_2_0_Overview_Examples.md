https://medium.com/model-driven-product-management-and-innovation/overview-of-sysml-2-0-with-examples-c0a047dc1ac4

Sidebar menu

Write

Creatixchu
Home
Library
Profile
Stories
Stats
Following
Benedict Neo
Benedict Neo
Kai Bu
Kai Bu
Discover more writers and publications to follow.
See suggestions
Get unlimited access to the best of Medium for less than $1/week.
Become a member

Model-Driven Product Management and Innovation
Overview of SysML 2.0 with Examples

Laurent Balmelli
Laurent Balmelli

Follow
6 min read
·
Oct 21, 2024
13





Product Management and Innovation Series (7)
This series of articles explores the conceptual design and management of technology products, their features and their associated services, with a focus on evaluating feasibility during the early stages of design. I present a methodology for product management that provides a structured approach to assess the viability of new features, product iterations, or entirely new designs. This methodology emphasizes testing product ideas using visual, textual models, and Generative AI to create Minimal Viable Models (MVM) of new features and designs. For support, I use SysML 2.0, a language to model products, features and systems before their physical realization. The articles serve as material for a graduate course on Product Management and Innovation, which I teach yearly at Keio University in Japan.
All articles in this series
(1) Assessing Tech Product Feasibility with Minimal Viable Models
(2) The Use of SysML and GenAI for Product Innovation
(3) AI-Aided Analysis of Product Features and Designs
(4) Building a Minimal Viable Model for a Technology Product
(5) Reaping Benefits from Your Minimum Viable Models
(6) How the Use of SysML 2.0 Benefits Innovative Product Management
(7) Overview of SysML 2.0 with Examples
SysML 2.0 and the Use for Conceptual Design
SysML 2.0 is the latest iteration of the Systems Modeling Language (SysML), built to support the modeling of complex systems. This version introduces several new features and improvements, addressing limitations in SysML 1.0, such as better scalability, clearer model semantics, and integration with modern digital engineering environments. The key changes make SysML 2.0 more versatile, user-friendly, and aligned with current design and engineering practices.

The SysML 2.0 logo.
SysML 2.0 plays a crucial role in modeling early prototypes during the conceptual design phase by enabling engineers to create structured, high-level representations of a product before physical development begins. This allows for the definition of components (parts), their interactions (ports and interfaces), and behaviors (state transitions or actions). For example, engineers can define key subsystems like sensors, processors, or motors, and model their interactions through ports such as data flow or control signals. By simulating system states — like “idle” or “active” — design teams can evaluate performance, identify potential issues, and refine the design iteratively. This early modeling helps capture system structure and behavior, providing valuable feedback for the next stages of development.
The Key Features of SysML 2.0 for Conceptual Design
SysML 2.0 integrates textual and graphical representations in a unified framework. The ability to model systems using both formats provides flexibility for engineers who may prefer different views depending on the task. Text-based notation also improves integration into software development pipelines, making SysML 2.0 compatible with DevOps practices.
To illustrate the use of SysML, I will visit the early design of a vehicle, its different states of the functionalities.
Press enter or click to view image in full size

The example used in this article are the different modes of a car.
Part Definitions and Usages SysML 2.0 clarifies the distinction between part definitions (general templates or types) and part usages (specific instances of those types). This is crucial for handling large models where different instances of the same part might behave differently depending on their context within the system.
In the example below, the Engine is a defined part, while vehicleEngine is a specific usage of that part with a power attribute set to 200 kW.
Press enter or click to view image in full size

Below, Vehicle defines a generic vehicle with four wheels, while SportsCar is a specialized subset of the vehicle that specifies the front two wheels.
Press enter or click to view image in full size

The model elements are easily reusable. This allows designers to create specialized versions of existing parts. SysML 2.0 enables reusing parts with new configurations or attributes, reducing redundancy and promoting modularity in model-based designs. This is especially helpful when managing product variants or creating customized systems from standard components.
Port and Connection Modeling Ports in SysML 2.0 allow parts to interact with one another. Ports define the communication points for parts, while connections model the flow of information, materials, or energy between them. This aspect of SysML 2.0 is especially useful for modeling the physical and functional interdependencies within a system.
The example below demonstrates how an engine’s power port can be connected to a transmission’s drive input, illustrating the interaction between the two parts through a defined interface.
Press enter or click to view image in full size

Product and System States SysML 2.0 extends the ability to model system behaviors through action-based and state-based modeling. Actions represent tasks or operations performed by the system, while states describe the different configurations or operational modes the system can be in. This makes it easier to model dynamic systems.
The example below models a simple state machine for a vehicle, transitioning from an ‘off’ state to an ‘on’ state upon receiving a start signal.
Press enter or click to view image in full size

SysML also provides a structured representation of a vehicle’s fundamental operations — starting, driving, and stopping — by modeling these actions and their interactions.
Each action, such as starting the engine or applying the brake, is defined through action usages and connected by an action sequence that specifies the order of execution.
Ports on the vehicle part define control signals (e.g., for the engine or accelerator) that trigger the actions. The model enables engineers to simulate and verify these critical behaviors early in the design process, ensuring functionality before physical prototyping.
The example below models the basic vehicle functionalities (starting, driving, and stopping) using actions in SysML 2.0.

In this example the ports: engineSignal, brakeSignal, and acceleratorSignal represent the control inputs for the vehicle’s engine, brake, and accelerator. Then the actions startEngine, drive, and stop are used to model specific tasks that the vehicle can perform.
Each action (like starting the engine) is linked in sequence through an action sequence, which defines the flow of behaviors during vehicle operation. The snipet of code below will be contained in the same package as the one defined in the above figure.

Integration of SysML 2.0 in the Modern Engineering Settings
SysML 2.0 is designed with continuous integration/continuous deployment (CI/CD) in mind, making it easier to integrate into software engineering workflows.
The text-based representation allows for easier version control, collaborative development, and automated testing. This aligns with modern DevOps practices, bringing systems engineering closer to software engineering disciplines.
SysML 2.0’s flexibility and power make it suitable for industries where system complexity is a major challenge, such as:
Aerospace and Defense: Modeling aircraft systems, mission planning, and simulation.
Automotive: Managing the intricate relationships between hardware, software, and mechanical systems.
Healthcare: Designing medical devices and health informatics systems.
Electronics and Telecommunications: Developing complex product lines with significant integration of software, hardware, and networks.
Example: Automotive Brake System Modeling
An example of SysML 2.0 usage in the automotive industry is the modeling of a braking system. The system consists of an engine, brakes, sensors, and control software, all of which interact to ensure safety and functionality.
Press enter or click to view image in full size

A break system is an example of part that can be created using SysML during conceptual design stages
The model represents a simplified version of a brake system, where the ControlSystem sends signals to the brakes, and the engine provides the necessary power for braking.
Press enter or click to view image in full size

A simplified version of a brake system usingt the textual notation in SysML.
Conclusion
SysML 2.0 significantly enhances the ability to model and manage complex systems, offering tools for conceptual designers, system architects and engineers to collaborate effectively. By improving reusability, scalability, and cross-domain integration, SysML 2.0 is set to become the go-to standard for model-based systems engineering. Its flexibility to handle both graphical and textual models makes it ideal for modern engineering environments, aligning with the shift toward digital engineering and automated workflows.
Sysml
Conceptual Design
Engineering
Unified Modeling Language
13




Model-Driven Product Management and Innovation
Published in Model-Driven Product Management and Innovation
12 followers
·
Last published Oct 21, 2024
A publication dedicated to a AI-aided, model-based product management approach named the Minimal Viable Model methodology. These articles are provided in support to my graduate class and product management research delivered at Keio Uni, Tokyo, Japan.

Follow
Laurent Balmelli
Written by Laurent Balmelli
332 followers
·
15 following
Professional in cyber-security, innovation, life-long learner; startups with successful exits;check my profile on LinkedIn for details.

Follow
No responses yet
Creatixchu
Creatixchu
What are your thoughts?﻿
Cancel
Respond
More from Laurent Balmelli and Model-Driven Product Management and Innovation
The AI-Cheating Fallacy
Laurent Balmelli
Laurent Balmelli
The AI-Cheating Fallacy
How Not to Abdicate the Contruction of your Own knowledge
Sep 7
53


How the Use of SysML 2.0 Benefits Innovative Product Management
Model-Driven Product Management and Innovation
In
Model-Driven Product Management and Innovation
by
Laurent Balmelli
How the Use of SysML 2.0 Benefits Innovative Product Management
Product Management and Innovation Series (6)
Oct 21, 2024
2


AI-Aided Analysis of Product Features and Designs
Model-Driven Product Management and Innovation
In
Model-Driven Product Management and Innovation
by
Laurent Balmelli
AI-Aided Analysis of Product Features and Designs
Product Management and Innovation Series (3)
Oct 21, 2024
2


The Emotional Firewall
Laurent Balmelli
Laurent Balmelli
The Emotional Firewall
Can We Detect When Machines Hack Our Emotions?
6d ago
1


See all from Laurent Balmelli
See all from Model-Driven Product Management and Innovation
Recommended from Medium
I’ll Instantly Know You Used Chat Gpt If I See This
Long. Sweet. Valuable.
In
Long. Sweet. Valuable.
by
Ossai Chinedum
I’ll Instantly Know You Used Chat Gpt If I See This
Trust me you’re not as slick as you think

May 16
24K
1402


This is not hype — Claude Code proved the future is already Here
Realworld AI Use Cases
In
Realworld AI Use Cases
by
Chris Dunlop
This is not hype — Claude Code proved the future is already Here
This little screenshot for me represents a turning point in AI. I can’t believe what we are witnessing

Sep 9
1.4K
80


Docker Is Dead — And It’s About Time
Abhinav
Abhinav
Docker Is Dead — And It’s About Time
Docker changed the game when it launched in 2013, making containers accessible and turning “Dockerize it” into a developer catchphrase.

Jun 8
6.4K
173


I Handed ChatGPT $100 to Trade Stocks — Here’s What Happened in 2 Months.
Coding Nexus
In
Coding Nexus
by
Civil Learning
I Handed ChatGPT $100 to Trade Stocks — Here’s What Happened in 2 Months.
What happens when you let a chatbot play Wall Street? It’s up 29% while the S&P 500 lags at 4%.

Sep 2
3K
75


The Smartest People I Know Are Obsessed With a Skill Many Were Told Is Useless
Eva Keiffenheim
Eva Keiffenheim
The Smartest People I Know Are Obsessed With a Skill Many Were Told Is Useless
The same technology promising to make us smarter is preventing the one thing our brains need to think.

Aug 11
19.5K
382


A middle-aged man with short dark hair, a beard, and glasses looks surprised and upset, surprised and angry. He wears a beige sweater and is positioned on the right side of the image against a light background. On the left, bold white text on a black rectangle reads, “YOUR CHATGPT HISTORY IS SHOWING UP ON GOOGLE. Here’s what to do.” Ask ChatGPT
How To Profit AI
In
How To Profit AI
by
Mohamed Bakry
Your ChatGPT History Just Went Public on Google. Here’s What I Did in 10 Mins to Fix It.
Safety/Privacy Check Prompt Template Is Included

3d ago
9.6K
287


See more recommendations
Help
Status
About
Careers
Press
Blog
Privacy
Rules
Terms
Text to speech
All your favorite parts of Medium are now in one sidebar for easy access.
Okay, got it
