package SemiconductorEcosystemModel {
    import ScalarValues::*;

    // ============================================================
    // Value Types (semantic units noted)
    // ============================================================
    value type TransistorCount :> Real;          // count
    value type FeatureSize :> Real;              // nanometers
    value type Power :> Real;                    // watts
    value type Frequency :> Real;                // gigahertz
    value type DieArea :> Real;                  // square millimeters
    value type YieldFraction :> Real;            // dimensionless 0..1
    value type ProductionCapacity :> Integer;    // units per month
    value type CostUSD :> Real;                  // US dollars
    value type YearNumber :> Integer;            // calendar year
    value type LithographyNode :> Real;          // nanometers
    value type CycleCount :> Integer;            // count
    value type RiskScore :> Real;                // dimensionless 0..1
    value type PerformancePriority :> Real;     // dimensionless 0..1
    value type ShrinkFactor :> Real;             // dimensionless

    // ============================================================
    // Item Definitions
    // ============================================================
    item def ProcessorSpec {
        attribute transistorCount : TransistorCount;
        attribute featureSize : FeatureSize;
        attribute power : Power;
        attribute frequency : Frequency;
        attribute dieArea : DieArea;
        attribute targetYear : YearNumber;
    }

    item def RoadmapEntry {
        attribute year : YearNumber;
        attribute spec : ProcessorSpec;
        attribute projectedTransistorCount : TransistorCount;
        attribute generationIndex : Integer;
    }

    item def Roadmap {
        attribute entries : RoadmapEntry[0..*];
        attribute planningHorizonYears : Integer;
        attribute moorePeriodYears : Integer := 2;
    }

    item def MarketDemand {
        attribute year : YearNumber;
        attribute desiredTransistorCount : TransistorCount;
        attribute desiredFrequency : Frequency;
        attribute maxAcceptablePower : Power;
        attribute maxAcceptableFeatureSize : FeatureSize;
        attribute performancePriority : PerformancePriority;
    }

    item def ManufacturingPlan {
        attribute targetSpec : ProcessorSpec;
        attribute node : LithographyNode;
        attribute capacity : ProductionCapacity;
        attribute yield : YieldFraction;
        attribute unitCost : CostUSD;
        attribute feasible : Boolean;
        attribute riskScore : RiskScore;
    }

    item def YieldOptimizationResult {
        attribute initialYield : YieldFraction;
        attribute optimizedYield : YieldFraction;
        attribute optimizedUnitCost : CostUSD;
        attribute cyclesApplied : CycleCount;
        attribute targetReached : Boolean;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def ProcessorSpecIn {
        in spec : ProcessorSpec;
    }

    port def ProcessorSpecOut {
        out spec : ProcessorSpec;
        out lifecyclePhase : String;
    }

    port def ForecastIn {
        in marketDemand : MarketDemand;
        in baselineSpec : ProcessorSpec;
    }

    port def ForecastOut {
        out roadmap : Roadmap;
    }

    port def ManufacturingIn {
        in targetSpec : ProcessorSpec;
        in roadmap : Roadmap;
    }

    port def ManufacturingOut {
        out plan : ManufacturingPlan;
        out optimization : YieldOptimizationResult;
    }

    // ============================================================
    // State Machines
    // ============================================================
    state def ProcessorLifecycle {
        state research;
        state design;
        state prototyping;
        state massProduction;
        state endOfLife;

        transition research -> design;
        transition design -> prototyping;
        transition prototyping -> massProduction;
        transition massProduction -> endOfLife;
    }

    state def ForecasterState {
        state idle;
        state collectingDemand;
        state generatingRoadmap;
        state distributingRoadmap;

        transition idle -> collectingDemand;
        transition collectingDemand -> generatingRoadmap;
        transition generatingRoadmap -> distributingRoadmap;
        transition distributingRoadmap -> idle;
    }

    state def FabricationState {
        state idle;
        state receivingSpec;
        state assessingFeasibility;
        state optimizingYield;
        state reporting;

        transition idle -> receivingSpec;
        transition receivingSpec -> assessingFeasibility;
        transition assessingFeasibility -> optimizingYield;
        transition optimizingYield -> reporting;
        transition reporting -> idle;
    }

    // ============================================================
    // Action Definitions
    // ============================================================
    action def GenerateRoadmapAction {
        in baselineSpec : ProcessorSpec;
        in marketDemand : MarketDemand;
        in horizonYears : Integer;
        out roadmap : Roadmap;

        attribute moorePeriodYears : Integer := 2;
        attribute transistorDoubling : Real := 2.0;
        attribute featureSizeShrink : ShrinkFactor := 0.707107;
        attribute powerScale : ShrinkFactor := 0.85;
        attribute frequencyGrowth : Real := 1.15;
        attribute dieAreaGrowth : Real := 1.05;

        action collectBaseline;
        action computeGenerations;
        action assembleEntries;
        action emitRoadmap;
    }

    action def AssessManufacturingAction {
        in spec : ProcessorSpec;
        in currentNode : LithographyNode;
        in currentCapacity : ProductionCapacity;
        in baseYield : YieldFraction;
        out plan : ManufacturingPlan;

        attribute yieldModelSensitivity : Real := 0.5;
        attribute costPerWaferUSD : CostUSD := 15000;
        attribute diesPerWafer : Integer;
        attribute riskTolerance : Real := 0.4;

        action evaluateNodeCompatibility;
        action computeYield;
        action computeCost;
        action assessRisk;
        action assemblePlan;
    }

    action def OptimizeYieldAction {
        in initialPlan : ManufacturingPlan;
        in maxCycles : Integer;
        in yieldTarget : YieldFraction;
        out optimizedPlan : ManufacturingPlan;
        out result : YieldOptimizationResult;

        attribute learningRate : Real := 0.05;
        attribute costReductionPerCycle : Real := 0.03;

        action applyLearning;
        action recomputeCost;
        action checkConvergence;
        action finalizeOptimization;
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def EcosystemForecastingRequirement {
        doc "The system shall forecast the evolution of computer processors based on the principles of Moore's Law to support strategic planning, investment decisions, and manufacturing optimization.";
        subject s : EcosystemSystem;
    }

    requirement def MooreLawConformanceRequirement {
        doc "The Technology Forecaster shall project that the number of transistors on a chip doubles approximately every two years.";
        subject s : TechnologyForecaster;
        constraint { moorePeriodYears == 2; }
    }

    requirement def LifecycleTrackingRequirement {
        doc "The Semiconductor Processor shall be tracked through research, design, prototyping, mass production, and end-of-life phases.";
        subject s : SemiconductorProcessor;
    }

    requirement def ManufacturingFeasibilityRequirement {
        doc "The Fabrication Facility shall assess the practical and economic feasibility of manufacturing projected processor designs considering node, capacity, yield, and cost.";
        subject s : FabricationFacility;
    }

    requirement def YieldOptimizationRequirement {
        doc "The Fabrication Facility shall simulate yield optimization to improve yield and reduce unit cost.";
        subject s : FabricationFacility;
    }

    requirement def CycleIntegrationRequirement {
        doc "The system shall complete the forecast-manufacture-product evolution cycle so that successful fab output defines the next-generation processor specification.";
        subject s : EcosystemSystem;
    }

    // ============================================================
    // Part Definitions
    // ============================================================
    part def SemiconductorProcessor {
        attribute spec : ProcessorSpec;
        attribute lifecyclePhase : String := "research";
        port specIn : ProcessorSpecIn;
        port specOut : ProcessorSpecOut;
        perform ProcessorLifecycle;
    }

    part def TechnologyForecaster {
        attribute currentRoadmap : Roadmap;
        attribute moorePeriodYears : Integer := 2;
        attribute baselineYear : YearNumber := 2024;
        attribute planningHorizonYears : Integer := 10;
        port forecastIn : ForecastIn;
        port forecastOut : ForecastOut;
        perform ForecasterState;
        perform GenerateRoadmapAction;
    }

    part def FabricationFacility {
        attribute currentNode : LithographyNode;
        attribute capacity : ProductionCapacity;
        attribute currentYield : YieldFraction;
        attribute unitCostBaseline : CostUSD;
        port mfgIn : ManufacturingIn;
        port mfgOut : ManufacturingOut;
        perform FabricationState;
        perform AssessManufacturingAction;
        perform OptimizeYieldAction;
    }

    // ============================================================
    // Top-Level Ecosystem System
    // ============================================================
    part def EcosystemSystem {
        part processor : SemiconductorProcessor {
            attribute spec : ProcessorSpec = ProcessorSpec {
                transistorCount = 1.0e9;
                featureSize = 5.0;
                power = 125.0;
                frequency = 3.5;
                dieArea = 300.0;
                targetYear = 2024;
            };
        }

        part forecaster : TechnologyForecaster {
            attribute moorePeriodYears := 2;
            attribute baselineYear := 2024;
            attribute planningHorizonYears := 10;
        }

        part fab : FabricationFacility {
            attribute currentNode := 3.0;
            attribute capacity := 100000;
            attribute currentYield := 0.85;
            attribute unitCostBaseline := 80.0;
        }

        // Integrated cycle flows: forecast -> manufacture -> product evolution
        flow of ProcessorSpec from processor.specOut.spec to forecaster.forecastIn.baselineSpec;
        flow of Roadmap from forecaster.forecastOut.roadmap to fab.mfgIn.roadmap;
        flow of ProcessorSpec from fab.mfgOut.plan.targetSpec to processor.specIn.spec;

        // Requirement usages and satisfaction
        requirement req1 : EcosystemForecastingRequirement;
        requirement req2 : MooreLawConformanceRequirement;
        requirement req3 : LifecycleTrackingRequirement;
        requirement req4 : ManufacturingFeasibilityRequirement;
        requirement req5 : YieldOptimizationRequirement;
        requirement req6 : CycleIntegrationRequirement;

        satisfy req1;
        satisfy req2 by forecaster;
        satisfy req3 by processor;
        satisfy req4 by fab;
        satisfy req5 by fab;
        satisfy req6;
    }
}
