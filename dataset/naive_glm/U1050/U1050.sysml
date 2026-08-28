package EphemeralizationFramework {

    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types ----

    value type MassFlow :> Real {
        :>> unit = MassUnit;
    }

    value type EnergyFlow :> Real {
        :>> unit = EnergyUnit;
    }

    value type PowerFlow :> Real {
        :>> unit = PowerUnit;
    }

    value type ResourceConsumptionIndex :> Real {
        :>> unit = 1;
        doc /* Normalized aggregate of material and energy consumption per unit output. Lower is better. */
    }

    value type CapabilityIndex :> Real {
        :>> unit = 1;
        doc /* Normalized aggregate of performance, quality, and capacity. Higher is better. */
    }

    value type EphemeralizationRatio :> Real {
        :>> unit = 1;
        doc /* CapabilityIndex divided by ResourceConsumptionIndex. Must increase across generations. */
    }

    value type GenerationNumber :> Integer {
        :>> unit = 1;
    }

    value type EfficiencyFactor :> Real {
        :>> unit = 1;
    }

    // ---- Item Definitions ----

    item def ResourceProfile {
        attribute materialMass : MassFlow;
        attribute energyUse : EnergyFlow;
        attribute operatingPower : PowerFlow;
        attribute consumptionIndex : ResourceConsumptionIndex;
    }

    item def CapabilityProfile {
        attribute performance : CapabilityIndex;
        attribute quality : CapabilityIndex;
        attribute capacity : CapabilityIndex;
        attribute aggregateCapability : CapabilityIndex;
    }

    item def TechnologyGeneration {
        attribute generationId : GenerationNumber;
        attribute resourceProfile : ResourceProfile;
        attribute capabilityProfile : CapabilityProfile;
        attribute ephemeralizationRatio : EphemeralizationRatio;
    }

    item def OptimizationDirective {
        attribute targetReduction : EfficiencyFactor;
        attribute justification : String;
    }

    item def EvolutionProposal {
        attribute proposedGenerationId : GenerationNumber;
        attribute projectedResourceProfile : ResourceProfile;
        attribute projectedCapabilityProfile : CapabilityProfile;
        attribute projectedRatio : EphemeralizationRatio;
    }

    item def EnhancementPlan {
        attribute performanceGain : CapabilityIndex;
        attribute qualityGain : CapabilityIndex;
        attribute capacityGain : CapabilityIndex;
    }

    // ---- Port Definitions ----

    port def ResourceProfilePort {
        out resourceProfile : ResourceProfile;
    }

    port def CapabilityProfilePort {
        out capabilityProfile : CapabilityProfile;
    }

    port def GenerationPort {
        out generation : TechnologyGeneration;
    }

    port def OptimizationDirectivePort {
        out directive : OptimizationDirective;
    }

    port def EvolutionProposalPort {
        out proposal : EvolutionProposal;
    }

    port def EnhancementPlanPort {
        out plan : EnhancementPlan;
    }

    port def MonitoringSignalPort {
        out ratio : EphemeralizationRatio;
        out generationId : GenerationNumber;
    }

    // ---- Requirements ----

    requirement def EphemeralizationRequirement {
        doc /* The system shall achieve progressively greater capability while consuming progressively fewer physical resources across successive generations. */
        subject framework : EphemeralizationFramework;
        objective {
            doc /* Each successive generation must exhibit a higher EphemeralizationRatio than its predecessor. */
        }
    }

    requirement def ResourceReductionRequirement {
        doc /* Each generation shall reduce aggregate resource consumption relative to the previous generation. */
        subject minimizer : ResourceMinimizer;
        attribute minimumReduction : EfficiencyFactor = 0.05;
        objective {
            doc /* ResourceConsumptionIndex of generation N+1 shall be less than that of generation N by at least minimumReduction. */
        }
    }

    requirement def CapabilityGrowthRequirement {
        doc /* Each generation shall increase aggregate capability relative to the previous generation. */
        subject maximizer : CapabilityMaximizer;
        attribute minimumGrowth : CapabilityIndex = 0.05;
        objective {
            doc /* CapabilityIndex of generation N+1 shall exceed that of generation N by at least minimumGrowth. */
        }
    }

    requirement def ContinuousCycleRequirement {
        doc /* The system shall operate in a continuous self-improving cycle without external intervention. */
        subject framework : EphemeralizationFramework;
        objective {
            doc /* The cycle shall repeat indefinitely, transitioning through Optimize, Evolve, and Enhance phases. */
        }
    }

    // ---- Parts ----

    part def ResourceMinimizer {
        port currentResourceIn : ResourceProfilePort;
        port directiveOut : OptimizationDirectivePort;
        port optimizedResourceOut : ResourceProfilePort;

        attribute efficiencyThreshold : EfficiencyFactor = 0.10;
        attribute accumulatedEfficiency : EfficiencyFactor = 0.0;

        action analyzeConsumption {
            in current : ResourceProfile;
            out analysis : ResourceProfile;
        }

        action reduceConsumption {
            in analysis : ResourceProfile;
            out optimized : ResourceProfile;
            out directive : OptimizationDirective;
        }

        action evaluateThreshold {
            in optimized : ResourceProfile;
            out thresholdMet : Boolean;
        }

        perform analyzeConsumption then reduceConsumption then evaluateThreshold;
    }

    part def TechnologyEvolver {
        port currentGenerationIn : GenerationPort;
        port optimizedResourceIn : ResourceProfilePort;
        port proposalOut : EvolutionProposalPort;
        port newGenerationOut : GenerationPort;

        attribute innovationFactor : EfficiencyFactor = 1.0;

        action designNextGeneration {
            in current : TechnologyGeneration;
            in optimizedResource : ResourceProfile;
            out proposal : EvolutionProposal;
        }

        action validateImprovement {
            in proposal : EvolutionProposal;
            in current : TechnologyGeneration;
            out isValid : Boolean;
        }

        action instantiateGeneration {
            in proposal : EvolutionProposal;
            out newGeneration : TechnologyGeneration;
        }

        perform designNextGeneration then validateImprovement then instantiateGeneration;
    }

    part def CapabilityMaximizer {
        port generationIn : GenerationPort;
        port planOut : EnhancementPlanPort;
        port enhancedGenerationOut : GenerationPort;

        action assessCapability {
            in generation : TechnologyGeneration;
            out baseline : CapabilityProfile;
        }

        action formulateEnhancement {
            in baseline : CapabilityProfile;
            out plan : EnhancementPlan;
        }

        action applyEnhancement {
            in generation : TechnologyGeneration;
            in plan : EnhancementPlan;
            out enhancedGeneration : TechnologyGeneration;
        }

        perform assessCapability then formulateEnhancement then applyEnhancement;
    }

    part def EphemeralizationMonitor {
        port generationIn : GenerationPort;
        port signalOut : MonitoringSignalPort;

        attribute previousRatio : EphemeralizationRatio = 0.0;
        attribute currentGenerationId : GenerationNumber = 0;

        action recordGeneration {
            in generation : TechnologyGeneration;
        }

        action computeTrend {
            in generation : TechnologyGeneration;
            out ratio : EphemeralizationRatio;
            out trendPositive : Boolean;
        }

        action emitSignal {
            in ratio : EphemeralizationRatio;
            in generationId : GenerationNumber;
        }

        perform recordGeneration then computeTrend then emitSignal;
    }

    // ---- State Machine for the Continuous Cycle ----

    state def EphemeralizationCycle {
        entry action {
            doc /* Initialize the cycle with the current generation. */
        }

        state OptimizeResources {
            entry action {
                doc /* ResourceMinimizer analyzes and reduces consumption of the current generation. */
            }
            do action {
                send currentGeneration.resourceProfile to resourceMinimizer.currentResourceIn;
            }
            exit action {
                doc /* Emit optimization directive and optimized resource profile. */
            }
        }

        state EvolveTechnology {
            entry action {
                doc /* TechnologyEvolver designs and validates the next generation. */
            }
            do action {
                send currentGeneration to technologyEvolver.currentGenerationIn;
                send optimizedResource to technologyEvolver.optimizedResourceIn;
            }
            exit action {
                doc /* Instantiate and commit the new generation. */
            }
        }

        state EnhanceCapability {
            entry action {
                doc /* CapabilityMaximizer amplifies the output of the new generation. */
            }
            do action {
                send newGeneration to capabilityMaximizer.generationIn;
            }
            exit action {
                doc /* Produce the enhanced generation ready for the next cycle. */
            }
        }

        state MonitorProgress {
            entry action {
                doc /* EphemeralizationMonitor verifies the ratio trend is positive. */
            }
            do action {
                send enhancedGeneration to monitor.generationIn;
            }
            exit action {
                doc /* Update currentGeneration to enhancedGeneration and restart cycle. */
            }
        }

        transition OptimizeResources_to_EvolveTechnology
            first OptimizeResources then EvolveTechnology
            if resourceMinimizer.evaluateThreshold.thresholdMet;

        transition EvolveTechnology_to_EnhanceCapability
            first EvolveTechnology then EnhanceCapability
            if technologyEvolver.validateImprovement.isValid;

        transition EnhanceCapability_to_MonitorProgress
            first EnhanceCapability then MonitorProgress
            accept enhancedGeneration;

        transition MonitorProgress_to_OptimizeResources
            first MonitorProgress then OptimizeResources
            if monitor.computeTrend.trendPositive;
    }

    // ---- Top-Level Framework ----

    part def EphemeralizationFramework {
        satisfy EphemeralizationRequirement;
        satisfy ContinuousCycleRequirement;

        port externalGenerationOut : GenerationPort;
        port externalSignalOut : MonitoringSignalPort;

        part resourceMinimizer : ResourceMinimizer {
            satisfy ResourceReductionRequirement;
        }

        part technologyEvolver : TechnologyEvolver;
        part capabilityMaximizer : CapabilityMaximizer {
            satisfy CapabilityGrowthRequirement;
        }
        part monitor : EphemeralizationMonitor;

        attribute currentGeneration : TechnologyGeneration;
        attribute optimizedResource : ResourceProfile;
        attribute newGeneration : TechnologyGeneration;
        attribute enhancedGeneration : TechnologyGeneration;

        // Internal connections
        connection resourceMinimizerToEvolver
            connect resourceMinimizer.optimizedResourceOut to technologyEvolver.optimizedResourceIn;

        connection evolverToMaximizer
            connect technologyEvolver.newGenerationOut to capabilityMaximizer.generationIn;

        connection maximizerToMonitor
            connect capabilityMaximizer.enhancedGenerationOut to monitor.generationIn;

        connection monitorToExternal
            connect monitor.signalOut to externalSignalOut;

        connection maximizerToExternal
            connect capabilityMaximizer.enhancedGenerationOut to externalGenerationOut;

        exhibit EphemeralizationCycle;
    }

    // ---- Requirement Satisfaction Bindings ----

    requirement ephemeralizationRequirement : EphemeralizationRequirement {
        subject framework : EphemeralizationFramework;
        assert framework.monitor.computeTrend.trendPositive;
    }

    requirement resourceReductionRequirement : ResourceReductionRequirement {
        subject minimizer : ResourceMinimizer;
        assert minimizer.accumulatedEfficiency >= minimizer.efficiencyThreshold;
    }

    requirement capabilityGrowthRequirement : CapabilityGrowthRequirement {
        subject maximizer : CapabilityMaximizer;
        assert maximizer.applyEnhancement.enhancedGeneration.capabilityProfile.aggregateCapability
               > maximizer.assessCapability.baseline.aggregateCapability;
    }

    requirement continuousCycleRequirement : ContinuousCycleRequirement {
        subject framework : EphemeralizationFramework;
        assert framework.EphemeralizationCycle.isActive;
    }

}
