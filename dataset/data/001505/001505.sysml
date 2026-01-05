package MooresLawSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import SequenceFunctions::*;

    attribute def TransistorCount :> Real;
    attribute def YearValue :> Real;
    attribute def DoublingPeriodValue :> DurationValue;
    attribute def PerformanceMetric :> Real;

    item def ChipSpecification {
        attribute year : YearValue;
        attribute transistorCount : TransistorCount;
        attribute featureSize : ISQ::LengthValue;
        attribute powerConsumption : ISQ::PowerValue;
        attribute clockFrequency : ISQ::FrequencyValue;
    }

    item def MarketDemand {
        attribute targetPerformance : PerformanceMetric;
        attribute budgetConstraint : Real;
    }

    attribute def TechnologyNode :> ISQ::LengthValue;

    part def SemiconductorProcessor {
        attribute currentSpec : ChipSpecification;
        attribute baselineYear : YearValue;
        attribute baselineTransistorCount : TransistorCount;
        attribute doublingPeriod : DoublingPeriodValue;

        port performancePort {
            out computeCapability : PerformanceMetric;
            out transistorDensity : TransistorCount;
        }

        state processorLifecycle {
            entry; then researchPhase;

            state researchPhase {
                entry action designNewArchitecture {
                    in targetTransistors : TransistorCount;
                    out designReady : Boolean;
                }
            }

            transition researchPhase_to_developmentPhase
                first researchPhase
                accept designNewArchitecture.designReady
                then developmentPhase;

            state developmentPhase {
                entry action buildPrototype {
                    in specification : ChipSpecification;
                    out prototypeValidated : Boolean;
                }
            }

            transition developmentPhase_to_productionPhase
                first developmentPhase
                accept buildPrototype.prototypeValidated
                then productionPhase;

            state productionPhase {
                entry action massProduction {
                    in spec : ChipSpecification;
                    out volumeShipped : Real;
                }
            }

            transition productionPhase_to_endOfLife
                first productionPhase
                accept when massProduction.volumeShipped > 5000000.0
                then endOfLife;

            state endOfLife;
        }
    }

    part def TechnologyForecaster {
        attribute forecastHorizon : DurationValue;
        attribute confidenceLevel : Real;

        port forecastPort {
            in marketRequirements : MarketDemand;
            out projectedSpecs : ChipSpecification[*];
            out feasibilityAssessment : Real;
        }
    }

    part def FabricationFacility {
        attribute currentNode : TechnologyNode;
        attribute manufacturingYield : Real;
        attribute productionCapacity : Real;

        port fabricationPort {
            in designInput : ChipSpecification;
            out manufacturedChips : TransistorCount;
            out qualityMetric : Real;
        }
    }

    action def ComputeMooresLawProjection {
        in baseYear : YearValue;
        in baseCount : TransistorCount;
        in targetYear : YearValue;
        in doublingPeriod : DoublingPeriodValue;
        out projectedTransistorCount : TransistorCount;

        calc performProjection {
            in bYear : YearValue = baseYear;
            in bCount : TransistorCount = baseCount;
            in tYear : YearValue = targetYear;
            in dPeriod : DoublingPeriodValue = doublingPeriod;

            attribute yearsElapsed : Real = tYear - bYear;
            attribute doublingCycles : Real = yearsElapsed / dPeriod;
            attribute exponentialFactor : Real = 2.0 ** doublingCycles;

            return : TransistorCount = bCount * exponentialFactor;
        }

        then assign projectedTransistorCount := performProjection.return;
    }

    action def GenerateTechnologyRoadmap {
        in initialSpec : ChipSpecification;
        in projectionYears : DurationValue;
        in doublingPeriod : DoublingPeriodValue;
        out roadmapGenerations : ChipSpecification[*];

        private attribute generationList := ();
        private attribute stepInterval : Real := 2.0;
        private attribute currentYear := initialSpec.year;
        private attribute endYear := currentYear + projectionYears;
        private attribute currentTransistors := initialSpec.transistorCount;
        private attribute currentFeatureSize := initialSpec.featureSize;

        first start;
        then merge continueGeneration;

        then action evaluateContinuation {
            out shouldProceed : Boolean;
        }

        then decide;
            if evaluateContinuation.shouldProceed then generateNextGeneration;
            if not evaluateContinuation.shouldProceed then finalizeRoadmap;

        action generateNextGeneration {
            action projectTransistors : ComputeMooresLawProjection {
                in baseYear = initialSpec.year;
                in baseCount = initialSpec.transistorCount;
                in targetYear = currentYear + stepInterval;
                in doublingPeriod = doublingPeriod;
                out projectedTransistorCount;
            }

            then action constructGeneration {
                attribute nextGen : ChipSpecification {
                    :>> year = currentYear + stepInterval;
                    :>> transistorCount = projectTransistors.projectedTransistorCount;
                    :>> featureSize = currentFeatureSize * 0.7;
                    :>> powerConsumption = initialSpec.powerConsumption * 1.2;
                    :>> clockFrequency = initialSpec.clockFrequency * 1.3;
                }
            }

            then assign currentYear := currentYear + stepInterval;
            then assign currentTransistors := projectTransistors.projectedTransistorCount;
            then assign currentFeatureSize := currentFeatureSize * 0.7;
            then assign generationList := generationList->including(constructGeneration.nextGen);
        }

        then continueGeneration;

        action finalizeRoadmap {
            then assign roadmapGenerations := generationList;
        }

        then done;
    }

    action def OptimizeManufacturingProcess {
        in targetSpec : ChipSpecification;
        in currentYield : Real;
        out optimizedYield : Real;
        out costPerUnit : Real;

        calc computeOptimization {
            in spec : ChipSpecification = targetSpec;
            in yield : Real = currentYield;

            attribute complexityFactor : Real = spec.transistorCount / 1.0e9;
            attribute yieldImprovement : Real = 0.95 / (1.0 + complexityFactor * 0.1);
            attribute unitCost : Real = 100.0 * complexityFactor / yieldImprovement;

            return yieldValue : Real = yieldImprovement;
            return costValue : Real = unitCost;
        }

        then assign optimizedYield := computeOptimization.yieldValue;
        then assign costPerUnit := computeOptimization.costValue;
    }

    part context : SemiconductorEcosystem {
        part processor2024 : SemiconductorProcessor {
            :>> currentSpec {
                :>> year = 2024.0;
                :>> transistorCount = 100.0e9;
                :>> featureSize = 3.0e-9 [SI::m];
                :>> powerConsumption = 150.0 [SI::W];
                :>> clockFrequency = 4.0e9 [SI::Hz];
            }
            :>> baselineYear = 2024.0;
            :>> baselineTransistorCount = 100.0e9;
            :>> doublingPeriod = 2.0 [SI::yr];
        }

        part forecaster : TechnologyForecaster {
            :>> forecastHorizon = 10.0 [SI::yr];
            :>> confidenceLevel = 0.85;

            action forecastingBehavior : GenerateTechnologyRoadmap {
                in initialSpec = processor2024.currentSpec;
                in projectionYears = forecastHorizon;
                in doublingPeriod = processor2024.doublingPeriod;
                out roadmapGenerations;
            }
        }

        part fabricationPlant : FabricationFacility {
            :>> currentNode = 3.0e-9 [SI::m];
            :>> manufacturingYield = 0.80;
            :>> productionCapacity = 10000000.0;

            action manufacturingBehavior : OptimizeManufacturingProcess {
                in targetSpec = processor2024.currentSpec;
                in currentYield = manufacturingYield;
                out optimizedYield;
                out costPerUnit;
            }
        }

        flow forecaster.forecastPort.projectedSpecs 
            to fabricationPlant.fabricationPort.designInput;

        flow fabricationPlant.fabricationPort.manufacturedChips 
            to processor2024.performancePort.transistorDensity;
    }

    requirement <'ML-REQ-001'> mooresLawProjectionAccuracy {
        doc /* The system shall project transistor counts according to Moore's Law 
                with a doubling period between 18 and 30 months from a validated baseline. */

        subject ecosystem : SemiconductorEcosystem;

        require constraint doublingPeriodBounds {
            ecosystem.processor2024.doublingPeriod >= 1.5 [SI::yr] and
            ecosystem.processor2024.doublingPeriod <= 2.5 [SI::yr]
        }
    }

    requirement <'ML-REQ-002'> technologyRoadmapGeneration {
        doc /* The system shall generate a comprehensive technology roadmap projecting 
                semiconductor evolution over a minimum 5-year planning horizon. */

        subject forecaster : TechnologyForecaster;

        require constraint minimumForecastHorizon {
            forecaster.forecastHorizon >= 5.0 [SI::yr]
        }

        require constraint confidenceThreshold {
            forecaster.confidenceLevel >= 0.75
        }
    }

    requirement <'ML-REQ-003'> manufacturingViability {
        doc /* The fabrication facility shall maintain a minimum yield rate to ensure 
                economically sustainable production of advanced semiconductor nodes. */

        subject facility : FabricationFacility;

        require constraint minimumYield {
            facility.manufacturingYield >= 0.65
        }

        require constraint productionCapacityMinimum {
            facility.productionCapacity >= 1000000.0
        }
    }

    requirement <'ML-REQ-004'> performanceScaling {
        doc /* Processor performance shall scale proportionally with transistor count 
                increases predicted by Moore's Law. */

        subject processor : SemiconductorProcessor;

        require constraint transistorPerformanceCorrelation {
            processor.currentSpec.transistorCount >= processor.baselineTransistorCount
        }
    }

    requirement <'ML-SYS-PRIMARY'> systemPrimaryFunction {
        doc /* The Moore's Law projection system shall accurately forecast semiconductor 
                technology evolution to enable strategic planning, investment decisions, 
                and manufacturing optimization in the semiconductor industry. The system 
                integrates technology forecasting, manufacturing feasibility analysis, 
                and performance projection to support multi-year roadmap development. */

        assume requirement mooresLawProjectionAccuracy;
        assume requirement technologyRoadmapGeneration;
        require requirement manufacturingViability;
        require requirement performanceScaling;
    }
}
