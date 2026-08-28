package SemiconductorEcosystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import SequenceFunctions::*;

    item def ProcessorSpec {
        attribute transistorCount : Integer;
        attribute featureSize : LengthValue;
        attribute powerConsumption : PowerValue;
        attribute clockFrequency : FrequencyValue;
    }

    item def RoadmapEntry {
        attribute generation : Natural;
        attribute targetYear : Natural;
        attribute specs : ProcessorSpec;
        attribute projectedDemand : Real;
    }

    item def ManufacturingResult {
        attribute feasible : Boolean;
        attribute achievedYield : Real;
        attribute unitCost : Real;
        attribute producedSpecs : ProcessorSpec;
    }

    state machine def ProcessorLifecycle {
        initial state Research;
        transition from Research to Design;
        state Design;
        transition from Design to Prototyping;
        state Prototyping;
        transition from Prototyping to MassProduction;
        state MassProduction;
        transition from MassProduction to EndOfLife;
        state EndOfLife;
    }

    part def SemiconductorProcessor {
        attribute specs : ProcessorSpec;
        port in specInput : ProcessorSpec;
        port out processorOutput : ProcessorSpec;
        exhibit state lifecycle : ProcessorLifecycle;
    }

    part def TechnologyForecaster {
        attribute moorePeriod : TimeValue = 2 [a];
        attribute baseSpecs : ProcessorSpec;
        port in marketDemand : Real;
        port out roadmap : RoadmapEntry[*];

        calc def ForecastTransistors {
            in baseCount : Integer;
            in generations : Natural;
            in period : TimeValue;
            return : Integer = baseCount * 2 ^ generations;
        }

        calc def ForecastFeatureSize {
            in baseSize : LengthValue;
            in generations : Natural;
            return : LengthValue = baseSize / (1.5 ^ generations);
        }

        calc def ForecastPower {
            in basePower : PowerValue;
            in generations : Natural;
            return : PowerValue = basePower * (0.85 ^ generations);
        }

        calc def ForecastFrequency {
            in baseFreq : FrequencyValue;
            in generations : Natural;
            return : FrequencyValue = baseFreq * (1.2 ^ generations);
        }

        action def GenerateRoadmap {
            in base : ProcessorSpec;
            in demand : Real;
            in numGenerations : Natural;
            in period : TimeValue;
            out entries : RoadmapEntry[*] := ();
            for gen in 1..numGenerations {
                attribute projectedCount = ForecastTransistors(base.transistorCount, gen, period);
                attribute projectedSize = ForecastFeatureSize(base.featureSize, gen);
                attribute projectedPower = ForecastPower(base.powerConsumption, gen);
                attribute projectedFreq = ForecastFrequency(base.clockFrequency, gen);
                attribute entryObj : RoadmapEntry {
                    attribute generation = gen;
                    attribute targetYear = 2024 + gen * 2;
                    attribute specs : ProcessorSpec {
                        attribute transistorCount = projectedCount;
                        attribute featureSize = projectedSize;
                        attribute powerConsumption = projectedPower;
                        attribute clockFrequency = projectedFreq;
                    }
                    attribute projectedDemand = demand;
                }
                then assign entries := entries->including(entryObj);
            }
        }
    }

    part def FabricationFacility {
        attribute currentNode : LengthValue;
        attribute capacity : Real;
        attribute yield : Real;
        attribute costPerWafer : Real;
        port in designInput : RoadmapEntry;
        port out manufacturingOutput : ManufacturingResult;

        calc def AssessFeasibility {
            in requiredSize : LengthValue;
            in node : LengthValue;
            in cap : Real;
            in demand : Real;
            return : Boolean = requiredSize <= node and cap >= demand;
        }

        calc def ComputeYield {
            in requiredSize : LengthValue;
            in node : LengthValue;
            in baseYield : Real;
            return : Real = baseYield * (requiredSize / node);
        }

        calc def ComputeCost {
            in yieldVal : Real;
            in costPerWaferVal : Real;
            in transistorCount : Integer;
            return : Real = costPerWaferVal / (yieldVal * transistorCount);
        }

        action def OptimizeManufacturing {
            in entry : RoadmapEntry;
            in node : LengthValue;
            in cap : Real;
            in baseYield : Real;
            in waferCost : Real;
            out result : ManufacturingResult;
            attribute isFeasible = AssessFeasibility(entry.specs.featureSize, node, cap, entry.projectedDemand);
            attribute achievedYieldVal = ComputeYield(entry.specs.featureSize, node, baseYield);
            attribute unitCostVal = ComputeCost(achievedYieldVal, waferCost, entry.specs.transistorCount);
            attribute resultObj : ManufacturingResult {
                attribute feasible = isFeasible;
                attribute achievedYield = achievedYieldVal;
                attribute unitCost = unitCostVal;
                attribute producedSpecs = entry.specs;
            }
            then assign result := resultObj;
        }
    }

    part def SemiconductorEcosystemSystem {
        part forecaster : TechnologyForecaster {
            attribute baseSpecs : ProcessorSpec {
                attribute transistorCount = 1000000000;
                attribute featureSize = 7e-9 [m];
                attribute powerConsumption = 100 [W];
                attribute clockFrequency = 3 [GHz];
            }
        }
        part fab : FabricationFacility {
            attribute currentNode = 5e-9 [m];
            attribute capacity = 1000000;
            attribute yield = 0.90;
            attribute costPerWafer = 10000;
        }
        part processor : SemiconductorProcessor;

        connect forecaster.roadmap to fab.designInput;
        connect fab.manufacturingOutput to processor.specInput;

        action def EcosystemCycle {
            in demand : Real;
            in generations : Natural;
            out nextGenProcessor : ProcessorSpec;
            perform action generate : TechnologyForecaster::GenerateRoadmap {
                in base = forecaster.baseSpecs;
                in demand = demand;
                in numGenerations = generations;
                in period = forecaster.moorePeriod;
                out entries;
            }
            then for entry in generate.entries {
                perform action manufacture : FabricationFacility::OptimizeManufacturing {
                    in entry = entry;
                    in node = fab.currentNode;
                    in cap = fab.capacity;
                    in baseYield = fab.yield;
                    in waferCost = fab.costPerWafer;
                    out result;
                }
                then if manufacture.result.feasible {
                    then assign nextGenProcessor := manufacture.result.producedSpecs;
                }
            }
        }
    }

    requirement def MooresLawRequirement {
        subject processor : SemiconductorProcessor;
        attribute actualTransistorCount : Integer;
        attribute expectedTransistorCount : Integer;
        require constraint { actualTransistorCount >= expectedTransistorCount }
    }

    requirement def ManufacturingFeasibilityRequirement {
        subject fab : FabricationFacility;
        attribute requiredYield : Real;
        attribute actualYield : Real;
        require constraint { actualYield >= requiredYield }
    }

    requirement def CostRequirement {
        subject fab : FabricationFacility;
        attribute maxCost : Real;
        attribute actualCost : Real;
        require constraint { actualCost <= maxCost }
    }

    analysis def EcosystemForecastAnalysis {
        subject system : SemiconductorEcosystemSystem;
        in attribute marketDemand : Real;
        in attribute generations : Natural;
        out attribute projectedProcessor : ProcessorSpec;
        perform action cycle : SemiconductorEcosystemSystem::EcosystemCycle {
            in demand = marketDemand;
            in generations = generations;
            out nextGenProcessor = projectedProcessor;
        }
        requirement mooresLaw : MooresLawRequirement {
            subject processor = system.processor;
            attribute actualTransistorCount = projectedProcessor.transistorCount;
            attribute expectedTransistorCount = system.forecaster.baseSpecs.transistorCount * 2 ^ generations;
        }
        requirement feasibility : ManufacturingFeasibilityRequirement {
            subject fab = system.fab;
            attribute requiredYield = 0.80;
            attribute actualYield = system.fab.yield;
        }
    }
}
