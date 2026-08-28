package TechnologyGovernanceSystem {
    private import ScalarValues::*;

    attribute def MaturityLevel :> Real {
        doc /* Degree of technological maturity from concept (0.0) to full deployment (1.0). */
        assert constraint { that >= 0.0 and that <= 1.0 }
    }

    attribute def AdoptionRate :> Real {
        doc /* Rate of public adoption, measured as new adopters per thousand per month. */
    }

    attribute def IntegrationDepth :> Real {
        doc /* Degree of integration into existing infrastructure (0.0 none, 1.0 fully embedded). */
        assert constraint { that >= 0.0 and that <= 1.0 }
    }

    attribute def ImpactSeverity :> Real {
        doc /* Severity of an impact on a societal dimension (0.0 negligible, 1.0 catastrophic). */
        assert constraint { that >= 0.0 and that <= 1.0 }
    }

    attribute def KnowledgeCompleteness :> Real {
        doc /* Completeness of available knowledge about impacts (0.0 unknown, 1.0 complete). */
        assert constraint { that >= 0.0 and that <= 1.0 }
    }

    attribute def KnowledgeReliability :> Real {
        doc /* Reliability of available knowledge about impacts (0.0 unreliable, 1.0 certain). */
        assert constraint { that >= 0.0 and that <= 1.0 }
    }

    attribute def CertaintyLevel :> Real {
        doc /* Overall certainty about the technology's effects (0.0 uncertain, 1.0 certain). */
        assert constraint { that >= 0.0 and that <= 1.0 }
    }

    attribute def ControlLevel :> Real {
        doc /* Degree of societal control remaining over the technology trajectory (0.0 none, 1.0 total). */
        assert constraint { that >= 0.0 and that <= 1.0 }
    }

    attribute def Priority :> Real {
        doc /* Priority of an intervention (0.0 low, 1.0 urgent). */
        assert constraint { that >= 0.0 and that <= 1.0 }
    }

    item def TechnologyStatus {
        doc /* Snapshot of a technology's current state. */
        attribute maturity : MaturityLevel;
        attribute adoptionRate : AdoptionRate;
        attribute integrationDepth : IntegrationDepth;
    }

    item def ImpactAssessment {
        doc /* Assessment of societal impacts and knowledge quality. */
        attribute environmentalImpact : ImpactSeverity;
        attribute economicImpact : ImpactSeverity;
        attribute socialImpact : ImpactSeverity;
        attribute ethicalImpact : ImpactSeverity;
        attribute knowledgeCompleteness : KnowledgeCompleteness;
        attribute knowledgeReliability : KnowledgeReliability;
    }

    item def CycleTrigger {
        doc /* Signal to restart the monitoring cycle. */
    }

    enum def InterventionType {
        doc /* Types of interventions available to the governance system. */
        monitor;
        research;
        regulate;
        restrict;
        redirect;
    }

    item def InterventionDirective {
        doc /* Directive specifying the intervention to be executed. */
        attribute interventionType : InterventionType;
        attribute priority : Priority;
        attribute description : String;
    }

    port def StatusOut {
        out status : TechnologyStatus;
    }

    port def StatusIn {
        in status : TechnologyStatus;
    }

    port def AssessmentOut {
        out assessment : ImpactAssessment;
    }

    port def AssessmentIn {
        in assessment : ImpactAssessment;
    }

    port def DirectiveOut {
        out directive : InterventionDirective;
    }

    port def DirectiveIn {
        in directive : InterventionDirective;
    }

    port def TriggerOut {
        out trigger : CycleTrigger;
    }

    port def TriggerIn {
        in trigger : CycleTrigger;
    }

    action def ScanTechnology {
        doc /* Continuously scan the technological landscape. */
        out maturity : MaturityLevel;
        out adoption : AdoptionRate;
        out integration : IntegrationDepth;
    }

    action def AnalyzeImpacts {
        doc /* Evaluate societal impacts and knowledge quality. */
        in status : TechnologyStatus;
        out assessment : ImpactAssessment;
    }

    action def ResolveDilemma {
        doc /* Weigh certainty against control and decide intervention. */
        in assessment : ImpactAssessment;
        out certainty : CertaintyLevel;
        out control : ControlLevel;
        out directive : InterventionDirective;
    }

    action def ExecuteIntervention {
        doc /* Implement the chosen intervention directive. */
        in directive : InterventionDirective;
    }

    part def TechnologyMonitor {
        doc /* Surveillance unit tracking emerging technology progress. */
        port statusOut : StatusOut;
        port triggerIn : TriggerIn;
        attribute observedMaturity : MaturityLevel;
        attribute observedAdoption : AdoptionRate;
        attribute observedIntegration : IntegrationDepth;

        state MonitorBehavior {
            entry send new TechnologyStatus(
                maturity = observedMaturity,
                adoptionRate = observedAdoption,
                integrationDepth = observedIntegration
            ) via statusOut;
            then Idle;
            state Idle;
            accept t : CycleTrigger via triggerIn
            do action {
                first start;
                then send new TechnologyStatus(
                    maturity = observedMaturity,
                    adoptionRate = observedAdoption,
                    integrationDepth = observedIntegration
                ) via statusOut;
            }
            then Idle;
        }
    }

    part def ImpactAnalyzer {
        doc /* Analytical core evaluating societal impacts and knowledge quality. */
        port statusIn : StatusIn;
        port assessmentOut : AssessmentOut;
        attribute environmentalImpact : ImpactSeverity;
        attribute economicImpact : ImpactSeverity;
        attribute socialImpact : ImpactSeverity;
        attribute ethicalImpact : ImpactSeverity;
        attribute knowledgeCompleteness : KnowledgeCompleteness;
        attribute knowledgeReliability : KnowledgeReliability;

        state AnalyzeBehavior {
            entry send new ImpactAssessment(
                environmentalImpact = environmentalImpact,
                economicImpact = economicImpact,
                socialImpact = socialImpact,
                ethicalImpact = ethicalImpact,
                knowledgeCompleteness = knowledgeCompleteness,
                knowledgeReliability = knowledgeReliability
            ) via assessmentOut;
            then Idle;
            state Idle;
            accept s : TechnologyStatus via statusIn
            do action {
                first start;
                then send new ImpactAssessment(
                    environmentalImpact = environmentalImpact,
                    economicImpact = economicImpact,
                    socialImpact = socialImpact,
                    ethicalImpact = ethicalImpact,
                    knowledgeCompleteness = knowledgeCompleteness,
                    knowledgeReliability = knowledgeReliability
                ) via assessmentOut;
            }
            then Idle;
        }
    }

    part def DilemmaResolver {
        doc /* Decision-making unit balancing certainty and control. */
        port assessmentIn : AssessmentIn;
        port directiveOut : DirectiveOut;
        attribute certainty : CertaintyLevel;
        attribute control : ControlLevel;
        attribute chosenIntervention : InterventionType;
        attribute calculatedPriority : Priority;

        state ResolveBehavior {
            entry send new InterventionDirective(
                interventionType = chosenIntervention,
                priority = calculatedPriority,
                description = "Intervention determined by Collingridge balance."
            ) via directiveOut;
            then Idle;
            state Idle;
            accept a : ImpactAssessment via assessmentIn
            do action {
                first start;
                then send new InterventionDirective(
                    interventionType = chosenIntervention,
                    priority = calculatedPriority,
                    description = "Intervention determined by Collingridge balance."
                ) via directiveOut;
            }
            then Idle;
        }
    }

    part def InterventionExecutor {
        doc /* Action arm implementing intervention directives. */
        port directiveIn : DirectiveIn;
        port triggerOut : TriggerOut;

        state ExecuteBehavior {
            entry send new CycleTrigger() via triggerOut;
            then Idle;
            state Idle;
            accept d : InterventionDirective via directiveIn
            do action {
                first start;
                then send new CycleTrigger() via triggerOut;
            }
            then Idle;
        }
    }

    part def TechnologyGovernanceSystemAssembly {
        doc /* Strategic oversight process addressing the Collingridge Dilemma. */
        part monitor : TechnologyMonitor;
        part analyzer : ImpactAnalyzer;
        part resolver : DilemmaResolver;
        part executor : InterventionExecutor;

        connect monitor.statusOut to analyzer.statusIn;
        connect analyzer.assessmentOut to resolver.assessmentIn;
        connect resolver.directiveOut to executor.directiveIn;
        connect executor.triggerOut to monitor.triggerIn;
    }

    requirement def AddressCollingridgeDilemma {
        doc /*
         * The governance system shall continuously observe emerging technologies,
         * analyze their societal impacts, and intervene at the optimal window:
         * after enough is known to make an informed decision, but before control is lost.
         */
        subject sys : TechnologyGovernanceSystemAssembly;
        require constraint {
            sys.resolver.certainty >= 0.0 and sys.resolver.certainty <= 1.0 and
            sys.resolver.control >= 0.0 and sys.resolver.control <= 1.0
        }
    }

    requirement def MaximizeSocietalBenefit {
        doc /*
         * The system shall guide technological innovation to maximize societal benefits
         * while preemptively mitigating potential harm.
         */
        subject sys : TechnologyGovernanceSystemAssembly;
    }

    requirement def ContinuousMonitoring {
        doc /* The Technology Monitor shall continuously track technology maturity, adoption, and integration. */
        subject monitor : TechnologyMonitor;
    }

    requirement def ComprehensiveImpactAnalysis {
        doc /* The Impact Analyzer shall evaluate environmental, economic, social, and ethical impacts with knowledge quality. */
        subject analyzer : ImpactAnalyzer;
    }

    requirement def TimelyIntervention {
        doc /* Interventions must occur after sufficient knowledge is gained but before societal control is lost. */
        subject resolver : DilemmaResolver;
    }

    requirement def EffectiveExecution {
        doc /* The Intervention Executor shall implement directives and provide feedback to restart the cycle. */
        subject executor : InterventionExecutor;
    }

    part governanceSystem : TechnologyGovernanceSystemAssembly {
        satisfy AddressCollingridgeDilemma;
        satisfy MaximizeSocietalBenefit;
        satisfy ContinuousMonitoring;
        satisfy ComprehensiveImpactAnalysis;
        satisfy TimelyIntervention;
        satisfy EffectiveExecution;
    }
}
