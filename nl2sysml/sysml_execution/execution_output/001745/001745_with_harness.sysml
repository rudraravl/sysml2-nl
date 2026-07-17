package AquariumFilterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def WaterQuality {
        attribute ammoniaConcentration : Real;
        attribute nitriteConcentration : Real;
        attribute nitrateConcentration : Real;
        attribute dissolvedOxygen : Real;
        attribute pH : Real;
        attribute turbidity : Real;
    }

    attribute def FlowRate :> ISQ::VolumeFlowValue;
    attribute def WaterVolume :> ISQ::VolumeValue;
    attribute def Power :> ISQ::PowerValue;
    attribute def Pressure :> ISQ::PressureValue;
    attribute def FilterEfficiency :> Real;

    item def WaterStream {
        attribute flowRate : FlowRate;
        attribute quality : WaterQuality;
        attribute pressure : Pressure;
    }

    port def WaterInletPort {
        in item waterIn : WaterStream;
    }

    port def WaterOutletPort {
        out item waterOut : WaterStream;
    }

    port def PowerPort {
        in attribute power : Power;
    }

    action def PumpWater {
        in rawWater : WaterStream;
        in requiredPressure : Pressure;
        out pressurizedWater : WaterStream;
    }

    action def MechanicalFiltration {
        in incomingWater : WaterStream;
        out particulateFiltered : WaterStream;
    }

    action def BiologicalFiltration {
        in incomingWater : WaterStream;
        out bioProcessed : WaterStream;
    }

    action def ChemicalFiltration {
        in incomingWater : WaterStream;
        out chemicallyFiltered : WaterStream;
    }

    action def MonitorQuality {
        in waterSample : WaterStream;
        out qualityReading : WaterQuality;
        out isAcceptable : Boolean;
    }

    part def Pump {
        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
        port powerIn : PowerPort;

        attribute maxFlowRate : FlowRate;
        attribute maxPressure : Pressure;
        attribute powerConsumption : Power;

        perform action pumpAction : PumpWater;
    }

    part def MechanicalFilterStage {
        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;

        attribute mediaType : String;
        attribute poreSize : ISQ::LengthValue;
        attribute efficiency : FilterEfficiency;

        perform action mechanicalFilter : MechanicalFiltration;
    }

    part def BiologicalFilterStage {
        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;

        attribute mediaSurfaceArea : ISQ::AreaValue;
        attribute bacteriaColonyDensity : Real;
        attribute nitrificationRate : Real;

        perform action biologicalFilter : BiologicalFiltration;
    }

    part def ChemicalFilterStage {
        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;

        attribute activatedCarbonMass : ISQ::MassValue;
        attribute adsorptionCapacity : Real;
        attribute ionExchangeCapacity : Real;

        perform action chemicalFilter : ChemicalFiltration;
    }

    part def QualitySensor {
        port samplePort : WaterInletPort;

        attribute measurementAccuracy : Real;
        attribute calibrationDate : String;

        perform action measure : MonitorQuality;
    }

    part def ControlModule {
        port powerIn : PowerPort;

        attribute targetFlowRate : FlowRate;
        attribute maintenanceInterval : ISQ::TimeValue;
        attribute operatingHours : ISQ::TimeValue;
    }

    action def FilterWaterCycle {
        in rawWater : WaterStream;
        out cleanWater : WaterStream;

        first start;
        then merge continueCycle;

        then action pump : PumpWater {
            in rawWater;
            out pressurizedWater : WaterStream;
        }

        flow pump.pressurizedWater to mechanical.incomingWater;

        then action mechanical : MechanicalFiltration {
            in incomingWater : WaterStream;
            out particulateFiltered : WaterStream;
        }

        flow mechanical.particulateFiltered to biological.incomingWater;

        then action biological : BiologicalFiltration {
            in incomingWater : WaterStream;
            out bioProcessed : WaterStream;
        }

        flow biological.bioProcessed to chemical.incomingWater;

        then action chemical : ChemicalFiltration {
            in incomingWater : WaterStream;
            out chemicallyFiltered : WaterStream;
        }

        then action monitor : MonitorQuality {
            in waterSample = chemical.chemicallyFiltered;
            out qualityReading : WaterQuality;
            out isAcceptable : Boolean;
        }

        then decide;
            if monitor.isAcceptable then outputClean;
            if not monitor.isAcceptable then adjustParameters;

        action adjustParameters {
        }
        then continueCycle;

        action outputClean {
            out finalWater : WaterStream = chemical.chemicallyFiltered;
        }
        then done;
    }

    state def FilterOperationStates {
        entry; then off;

        state off;
        accept PowerOnSignal;
        then startup;

        state startup;
        then normalOperation;

        state normalOperation {
            state standardFlow;
            accept HighLoadDetected;
            then highLoadOperation;

            state highLoadOperation;
            accept LoadNormalized;
            then standardFlow;
        }

        accept PowerOffSignal;
        then shutdown;

        accept MaintenanceSignal;
        then maintenance;

        state maintenance;
        accept MaintenanceComplete;
        then startup;

        state shutdown;
        then off;
    }

    part def AquariumFilterSystem {
        attribute tankVolume : WaterVolume;
        attribute targetTurnoverRate : Real;
        attribute isRunning : Boolean;

        part waterPump : Pump {
            attribute :>> maxFlowRate = 1200.0 [SI::L / SI::h];
            attribute :>> maxPressure = 50000.0 [SI::Pa];
            attribute :>> powerConsumption = 18.0 [SI::W];
        }

        part mechanicalStage : MechanicalFilterStage {
            attribute :>> mediaType = "foam and sponge";
            attribute :>> poreSize = 25.0 [SI::um];
            attribute :>> efficiency = 0.95;
        }

        part biologicalStage : BiologicalFilterStage {
            attribute :>> mediaSurfaceArea = 3.0 [SI::m2];
            attribute :>> bacteriaColonyDensity = 1.5e9;
            attribute :>> nitrificationRate = 0.85;
        }

        part chemicalStage : ChemicalFilterStage {
            attribute :>> activatedCarbonMass = 600.0 [SI::g];
            attribute :>> adsorptionCapacity = 0.90;
            attribute :>> ionExchangeCapacity = 0.75;
        }

        part sensor : QualitySensor {
            attribute :>> measurementAccuracy = 0.98;
            attribute :>> calibrationDate = "2024-01-15";
        }

        part controller : ControlModule {
            attribute :>> targetFlowRate = 1000.0 [SI::L / SI::h];
            attribute :>> maintenanceInterval = 720.0 [SI::h];
            attribute :>> operatingHours = 0.0 [SI::h];
        }

        port tankInlet : WaterInletPort;
        port tankOutlet : WaterOutletPort;
        port mainPower : PowerPort;

        connect mainPower to waterPump.powerIn;
        connect mainPower to controller.powerIn;

        connect tankInlet to waterPump.inlet;
        connect waterPump.outlet to mechanicalStage.inlet;
        connect mechanicalStage.outlet to biologicalStage.inlet;
        connect biologicalStage.outlet to chemicalStage.inlet;
        connect chemicalStage.outlet to sensor.samplePort;
        connect chemicalStage.outlet to tankOutlet;

        perform action filterOperation : FilterWaterCycle;

        exhibit state operationStateMachine : FilterOperationStates;
    }

    requirement def WaterQualityRequirement {
        doc /* The filter system shall maintain water quality parameters within safe ranges for aquatic life. */

        subject filter : AquariumFilterSystem;

        require constraint ammoniaLimit {
            filter.sensor.measure.qualityReading.ammoniaConcentration <= 0.25
        }

        require constraint nitriteLimit {
            filter.sensor.measure.qualityReading.nitriteConcentration <= 0.5
        }

        require constraint nitrateLimit {
            filter.sensor.measure.qualityReading.nitrateConcentration <= 40.0
        }

        require constraint pHRange {
            filter.sensor.measure.qualityReading.pH >= 6.5 and
            filter.sensor.measure.qualityReading.pH <= 8.0
        }

        require constraint dissolvedOxygenMinimum {
            filter.sensor.measure.qualityReading.dissolvedOxygen >= 5.0
        }
    }

    requirement def FlowRateRequirement {
        doc /* The filter system shall circulate the entire tank volume at least 5 times per hour. */

        subject filter : AquariumFilterSystem;

        require constraint minimumTurnover {
            filter.waterPump.maxFlowRate >= filter.tankVolume * 5.0
        }
    }

    requirement def FiltrationEfficiencyRequirement {
        doc /* The filter system shall achieve minimum efficiency levels for each filtration stage. */

        subject filter : AquariumFilterSystem;

        require constraint mechanicalEfficiency {
            filter.mechanicalStage.efficiency >= 0.90
        }

        require constraint biologicalEfficiency {
            filter.biologicalStage.nitrificationRate >= 0.80
        }

        require constraint chemicalEfficiency {
            filter.chemicalStage.adsorptionCapacity >= 0.85
        }
    }

    requirement def ReliabilityRequirement {
        doc /* The filter system shall operate continuously for at least 720 hours between maintenance cycles. */

        subject filter : AquariumFilterSystem;

        attribute minimumMTBM : ISQ::TimeValue = 720.0 [SI::h];

        require constraint maintenanceInterval {
            filter.controller.maintenanceInterval >= minimumMTBM
        }
    }

    requirement def EnergyEfficiencyRequirement {
        doc /* The filter system shall consume no more than 25 watts during normal operation. */

        subject filter : AquariumFilterSystem;

        require constraint powerLimit {
            filter.waterPump.powerConsumption <= 25.0 [SI::W]
        }
    }

    requirement primaryFilterFunction {
        doc /* The aquarium filter system shall continuously circulate and purify aquarium water through mechanical, biological, and chemical filtration stages to maintain optimal water quality for aquatic life. */

        subject filter : AquariumFilterSystem;

        require waterQuality : WaterQualityRequirement;
        require flowRate : FlowRateRequirement;
        require efficiency : FiltrationEfficiencyRequirement;
        require reliability : ReliabilityRequirement;
        require energyEfficiency : EnergyEfficiencyRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import AquariumFilterSystem::*;

    part testSubject : AquariumFilterSystem {
        exhibit state operationStateMachine : FilterOperationStates;
    }

    action orchestrator {
        item testRawWater : WaterStream {
            attribute flowRate : FlowRate;
            attribute quality : WaterQuality {
                attribute ammoniaConcentration = 0.0;
                attribute nitriteConcentration = 0.0;
                attribute nitrateConcentration = 0.0;
                attribute dissolvedOxygen = 0.0;
                attribute pH = 0.0;
                attribute turbidity = 0.0;
            }
            attribute pressure : Pressure;
        }
        attribute testRequiredPressure : Pressure;
        action actionProbe : PumpWater {
            in rawWater = testRawWater;
            in requiredPressure = testRequiredPressure;
        }
        first actionProbe;
    }
}
