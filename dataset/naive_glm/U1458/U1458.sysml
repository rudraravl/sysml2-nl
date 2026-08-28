package OffshoreOilPlatformModel {
    import ScalarValues::*;

    // ========================================
    // Value Types with Units
    // ========================================
    value type PressureValue :> Real { unit = "bar"; }
    value type FlowRateValue :> Real { unit = "m3/s"; }
    value type TemperatureValue :> Real { unit = "degC"; }
    value type PowerValue :> Real { unit = "MW"; }
    value type VoltageValue :> Real { unit = "kV"; }
    value type FrequencyValue :> Real { unit = "Hz"; }
    value type VolumeValue :> Real { unit = "m3"; }
    value type LengthValue :> Real { unit = "m"; }
    value type FractionValue :> Real;
    value type ApiGravityValue :> Real;
    value type ConcentrationValue :> Real { unit = "mg/L"; }
    value type LevelValue :> Real { unit = "%"; }
    value type EfficiencyValue :> Real { unit = "%"; }
    value type SpeedValue :> Real { unit = "rpm"; }

    // ========================================
    // Item Definitions
    // ========================================
    item def RawFluid {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute oilFraction : FractionValue;
        attribute gasFraction : FractionValue;
        attribute waterFraction : FractionValue;
    }

    item def CrudeOil {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute apiGravity : ApiGravityValue;
    }

    item def NaturalGas {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute methaneFraction : FractionValue;
    }

    item def ProducedWater {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute oilContent : ConcentrationValue;
    }

    item def StabilizedOil {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute apiGravity : ApiGravityValue;
        attribute vaporPressure : PressureValue;
    }

    item def CompressedGas {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }

    item def TreatedWater {
        attribute flowRate : FlowRateValue;
        attribute temperature : TemperatureValue;
        attribute oilContent : ConcentrationValue;
        attribute disposalReady : Boolean;
    }

    item def ExportOil {
        attribute volume : VolumeValue;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute apiGravity : ApiGravityValue;
    }

    item def ElectricalPower {
        attribute power : PowerValue;
        attribute voltage : VoltageValue;
        attribute frequency : FrequencyValue;
    }

    item def ControlSignal {
        attribute command : String;
        attribute targetSystem : String;
        attribute parameterValue : Real;
        attribute active : Boolean;
    }

    item def SafetySignal {
        attribute hazardType : String;
        attribute severity : Integer;
        attribute shutdownRequired : Boolean;
        attribute location : String;
    }

    // ========================================
    // Port Definitions
    // ========================================
    port def RawFluidOutPort {
        out rawFluid : RawFluid;
    }

    port def RawFluidInPort {
        in rawFluid : RawFluid;
    }

    port def CrudeOilOutPort {
        out crudeOil : CrudeOil;
    }

    port def CrudeOilInPort {
        in crudeOil : CrudeOil;
    }

    port def NaturalGasOutPort {
        out naturalGas : NaturalGas;
    }

    port def NaturalGasInPort {
        in naturalGas : NaturalGas;
    }

    port def ProducedWaterOutPort {
        out producedWater : ProducedWater;
    }

    port def ProducedWaterInPort {
        in producedWater : ProducedWater;
    }

    port def StabilizedOilOutPort {
        out stabilizedOil : StabilizedOil;
    }

    port def StabilizedOilInPort {
        in stabilizedOil : StabilizedOil;
    }

    port def CompressedGasOutPort {
        out compressedGas : CompressedGas;
    }

    port def CompressedGasInPort {
        in compressedGas : CompressedGas;
    }

    port def TreatedWaterOutPort {
        out treatedWater : TreatedWater;
    }

    port def ExportOilOutPort {
        out exportOil : ExportOil;
    }

    port def ElectricalPowerOutPort {
        out power : ElectricalPower;
    }

    port def ElectricalPowerInPort {
        in power : ElectricalPower;
    }

    port def ControlOutPort {
        out command : ControlSignal;
    }

    port def ControlInPort {
        in command : ControlSignal;
    }

    port def SafetyOutPort {
        out command : SafetySignal;
    }

    port def SafetyInPort {
        in command : SafetySignal;
    }

    // ========================================
    // Part Definitions – Subsea Components
    // ========================================
    part def SubseaWell {
        port rawFluidOut : RawFluidOutPort;

        attribute wellId : String;
        attribute reservoirPressure : PressureValue;
        attribute bottomholeTemperature : TemperatureValue;
        attribute productionRate : FlowRateValue;
        attribute active : Boolean;
        attribute waterCut : FractionValue;
        attribute gasOilRatio : FractionValue;

        action def Extract {
            in reservoirFluid : RawFluid;
            out extractedFluid : RawFluid;
        }
    }

    part def SubseaManifold {
        port wellFluid1 : RawFluidInPort;
        port wellFluid2 : RawFluidInPort;
        port wellFluid3 : RawFluidInPort;
        port wellFluid4 : RawFluidInPort;
        port wellFluid5 : RawFluidInPort;
        port wellFluid6 : RawFluidInPort;
        port rawFluidOut : RawFluidOutPort;

        attribute manifoldPressure : PressureValue;
        attribute manifoldTemperature : TemperatureValue;
        attribute totalFlowRate : FlowRateValue;
        attribute numActiveWells : Integer;
        attribute manifoldId : String;

        action def CollectAndCombine {
            in well1Fluid : RawFluid;
            in well2Fluid : RawFluid;
            in well3Fluid : RawFluid;
            in well4Fluid : RawFluid;
            in well5Fluid : RawFluid;
            in well6Fluid : RawFluid;
            out combinedFluid : RawFluid;
        }
    }

    part def Riser {
        port rawFluidIn : RawFluidInPort;
        port rawFluidOut : RawFluidOutPort;

        attribute riserLength : LengthValue;
        attribute riserDiameter : LengthValue;
        attribute designPressure : PressureValue;
        attribute flowPressure : PressureValue;
        attribute riserId : String;

        action def TransportFluid {
            in incomingFluid : RawFluid;
            out outgoingFluid : RawFluid;
        }
    }

    // ========================================
    // Part Definitions – Processing Systems
    // ========================================
    part def SeparationSystem {
        port rawFluidIn : RawFluidInPort;
        port crudeOilOut : CrudeOilOutPort;
        port naturalGasOut : NaturalGasOutPort;
        port producedWaterOut : ProducedWaterOutPort;
        port controlIn : ControlInPort;
        port safetyIn : SafetyInPort;
        port powerIn : ElectricalPowerInPort;

        attribute separatorPressure : PressureValue;
        attribute separatorTemperature : TemperatureValue;
        attribute oilWaterInterfaceLevel : LevelValue;
        attribute gasPhaseLevel : LevelValue;
        attribute separationEfficiency : EfficiencyValue;
        attribute vesselCapacity : VolumeValue;
        attribute numSeparators : Integer;
        attribute activeSeparators : Integer;

        action def Separate {
            in rawFluidIn : RawFluid;
            out crudeOilOut : CrudeOil;
            out naturalGasOut : NaturalGas;
            out producedWaterOut : ProducedWater;
        }
    }

    part def OilTreatment {
        port crudeOilIn : CrudeOilInPort;
        port stabilizedOilOut : StabilizedOilOutPort;
        port controlIn : ControlInPort;
        port safetyIn : SafetyInPort;
        port powerIn : ElectricalPowerInPort;

        attribute operatingPressure : PressureValue;
        attribute operatingTemperature : TemperatureValue;
        attribute targetVaporPressure : PressureValue;
        attribute treatmentEfficiency : EfficiencyValue;
        attribute throughput : FlowRateValue;
        attribute numStabilizerTrains : Integer;

        action def Stabilize {
            in crudeOilIn : CrudeOil;
            out stabilizedOilOut : StabilizedOil;
        }
    }

    part def GasCompression {
        port naturalGasIn : NaturalGasInPort;
        port compressedGasOut : CompressedGasOutPort;
        port controlIn : ControlInPort;
        port safetyIn : SafetyInPort;
        port powerIn : ElectricalPowerInPort;

        attribute suctionPressure : PressureValue;
        attribute dischargePressure : PressureValue;
        attribute compressorSpeed : SpeedValue;
        attribute compressionRatio : Real;
        attribute numStages : Integer;
        attribute powerConsumption : PowerValue;
        attribute throughput : FlowRateValue;
        attribute numCompressors : Integer;
        attribute activeCompressors : Integer;

        action def Compress {
            in naturalGasIn : NaturalGas;
            out compressedGasOut : CompressedGas;
        }
    }

    part def WaterTreatment {
        port producedWaterIn : ProducedWaterInPort;
        port treatedWaterOut : TreatedWaterOutPort;
        port controlIn : ControlInPort;
        port safetyIn : SafetyInPort;
        port powerIn : ElectricalPowerInPort;

        attribute inletOilContent : ConcentrationValue;
        attribute outletOilContent : ConcentrationValue;
        attribute treatmentCapacity : FlowRateValue;
        attribute disposalStandard : ConcentrationValue;
        attribute throughput : FlowRateValue;
        attribute numTreatmentTrains : Integer;

        action def Treat {
            in producedWaterIn : ProducedWater;
            out treatedWaterOut : TreatedWater;
        }
    }

    // ========================================
    // Part Definitions – Support Systems
    // ========================================
    part def PowerGeneration {
        port compressedGasIn : CompressedGasInPort;
        port powerOut : ElectricalPowerOutPort;
        port controlIn : ControlInPort;
        port safetyIn : SafetyInPort;

        attribute fuelConsumption : FlowRateValue;
        attribute generatedPower : PowerValue;
        attribute targetPower : PowerValue;
        attribute outputVoltage : VoltageValue;
        attribute outputFrequency : FrequencyValue;
        attribute thermalEfficiency : EfficiencyValue;
        attribute numGenerators : Integer;
        attribute activeGenerators : Integer;

        action def Generate {
            in compressedGasIn : CompressedGas;
            out powerOut : ElectricalPower;
        }
    }

    part def PowerDistribution {
        port powerIn : ElectricalPowerInPort;
        port powerOut1 : ElectricalPowerOutPort;
        port powerOut2 : ElectricalPowerOutPort;
        port powerOut3 : ElectricalPowerOutPort;
        port powerOut4 : ElectricalPowerOutPort;
        port powerOut5 : ElectricalPowerOutPort;
        port powerOut6 : ElectricalPowerOutPort;
        port powerOut7 : ElectricalPowerOutPort;
        port powerOut8 : ElectricalPowerOutPort;

        attribute totalInputPower : PowerValue;
        attribute busVoltage : VoltageValue;
        attribute busFrequency : FrequencyValue;
        attribute totalLoad : PowerValue;
        attribute loadBalance : Real;
    }

    part def StorageTank {
        port stabilizedOilIn : StabilizedOilInPort;
        port stabilizedOilOut : StabilizedOilOutPort;
        port controlIn : ControlInPort;
        port safetyIn : SafetyInPort;
        port powerIn : ElectricalPowerInPort;

        attribute tankCapacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute fillLevel : LevelValue;
        attribute tankPressure : PressureValue;
        attribute tankTemperature : TemperatureValue;
        attribute maxOperatingPressure : PressureValue;
        attribute numTanks : Integer;
        attribute tankType : String;

        action def Store {
            in stabilizedOilIn : StabilizedOil;
            attribute fillLevel : LevelValue;
        }

        action def Dispatch {
            in storedOil : StabilizedOil;
            out stabilizedOilOut : StabilizedOil;
        }
    }

    part def ExportSystem {
        port stabilizedOilIn : StabilizedOilInPort;
        port exportOilOut : ExportOilOutPort;
        port controlIn : ControlInPort;
        port safetyIn : SafetyInPort;
        port powerIn : ElectricalPowerInPort;

        attribute exportPressure : PressureValue;
        attribute exportFlowRate : FlowRateValue;
        attribute exportDestination : String;
        attribute pumpStatus : Boolean;
        attribute maxExportRate : FlowRateValue;
        attribute numPumps : Integer;
        attribute activePumps : Integer;

        action def Export {
            in stabilizedOilIn : StabilizedOil;
            out exportOilOut : ExportOil;
        }
    }

    // ========================================
    // Control System
    // ========================================
    part def ControlSystem {
        port controlSeparation : ControlOutPort;
        port controlOilTreatment : ControlOutPort;
        port controlGasCompression : ControlOutPort;
        port controlWaterTreatment : ControlOutPort;
        port controlPowerGeneration : ControlOutPort;
        port controlStorage : ControlOutPort;
        port controlExport : ControlOutPort;
        port safetyIn : SafetyInPort;
        port powerIn : ElectricalPowerInPort;

        attribute productionRate : FlowRateValue;
        attribute targetProductionRate : FlowRateValue;
        attribute systemStatus : String;
        attribute activeAlerts : Integer;
        attribute uptime : LevelValue;
        attribute operatorMode : String;
        attribute shutdownReceived : Boolean;

        action def MonitorProduction {
            in productionData : FlowRateValue;
            out controlAdjustment : ControlSignal;
        }

        action def CoordinateOperations {
            in separationFeedback : FlowRateValue;
            in storageLevel : LevelValue;
            in powerDemand : PowerValue;
            out separationCommand : ControlSignal;
            out gasCompressionCommand : ControlSignal;
            out powerGenerationCommand : ControlSignal;
            out exportCommand : ControlSignal;
        }

        state machine ControlStateMachine {
            state Stopped {
                entry;
            }
            state Starting {
                entry;
            }
            state Operating {
                entry;
            }
            state PlannedShutdown {
                entry;
            }
            state Maintenance {
                entry;
            }

            transition Stopped to Starting when startupCommandReceived;
            transition Starting to Operating when allSystemsOnline;
            transition Operating to PlannedShutdown when shutdownCommandReceived;
            transition Operating to Stopped when shutdownReceived;
            transition PlannedShutdown to Stopped when shutdownComplete;
            transition Stopped to Maintenance when maintenanceRequested;
            transition Maintenance to Stopped when maintenanceComplete;
            transition Starting to Stopped when startupFailure;
        }
    }

    // ========================================
    // Safety System
    // ========================================
    part def SafetySystem {
        port safetySeparation : SafetyOutPort;
        port safetyOilTreatment : SafetyOutPort;
        port safetyGasCompression : SafetyOutPort;
        port safetyWaterTreatment : SafetyOutPort;
        port safetyPowerGeneration : SafetyOutPort;
        port safetyStorage : SafetyOutPort;
        port safetyExport : SafetyOutPort;
        port safetyControl : SafetyOutPort;
        port powerIn : ElectricalPowerInPort;

        attribute gasLeakDetected : Boolean;
        attribute fireDetected : Boolean;
        attribute pressureLeakDetected : Boolean;
        attribute hazardLevel : Integer;
        attribute numActiveSensors : Integer;
        attribute numTriggeredAlarms : Integer;
        attribute esdActivated : Boolean;
        attribute lastInspectionTime : String;
        attribute gasConcentration : ConcentrationValue;
        attribute flameDetectorStatus : Boolean;
        attribute smokeDetectorStatus : Boolean;
        attribute fireWaterSystemReady : Boolean;

        action def MonitorHazard {
            in sensorReading : Real;
            out hazardDetected : Boolean;
            out severity : Integer;
        }

        action def InitiateESD {
            out manifoldShutdown : SafetySignal;
            out separationShutdown : SafetySignal;
            out gasCompressionShutdown : SafetySignal;
            out powerShutdown : SafetySignal;
            out exportShutdown : SafetySignal;
            out controlShutdown : SafetySignal;
        }

        action def IssueWarning {
            out warningSignal : SafetySignal;
        }

        action def ClearHazard {
            out normalSignal : SafetySignal;
        }

        state machine SafetyStateMachine {
            state Normal {
                entry;
            }
            state Warning {
                entry;
            }
            state Emergency {
                entry;
                exit;
            }

            transition Normal to Warning when gasLeakDetected;
            transition Normal to Warning when fireDetected;
            transition Normal to Warning when pressureLeakDetected;
            transition Warning to Normal when hazardLevel == 0;
            transition Warning to Emergency when hazardLevel >= 3;
            transition Emergency to Normal when esdReset;
        }
    }

    // ========================================
    // Platform Assembly
    // ========================================
    part def OffshoreOilPlatform {
        // --- Subsea Components ---
        part well1 : SubseaWell {
            attribute wellId = "WELL-01";
            attribute reservoirPressure = 250.0;
            attribute bottomholeTemperature = 90.0;
            attribute productionRate = 0.15;
            attribute active = true;
        }
        part well2 : SubseaWell {
            attribute wellId = "WELL-02";
            attribute reservoirPressure = 240.0;
            attribute bottomholeTemperature = 88.0;
            attribute productionRate = 0.14;
            attribute active = true;
        }
        part well3 : SubseaWell {
            attribute wellId = "WELL-03";
            attribute reservoirPressure = 230.0;
            attribute bottomholeTemperature = 85.0;
            attribute productionRate = 0.13;
            attribute active = true;
        }
        part well4 : SubseaWell {
            attribute wellId = "WELL-04";
            attribute reservoirPressure = 220.0;
            attribute bottomholeTemperature = 82.0;
            attribute productionRate = 0.12;
            attribute active = true;
        }
        part well5 : SubseaWell {
            attribute wellId = "WELL-05";
            attribute reservoirPressure = 210.0;
            attribute bottomholeTemperature = 80.0;
            attribute productionRate = 0.11;
            attribute active = true;
        }
        part well6 : SubseaWell {
            attribute wellId = "WELL-06";
            attribute reservoirPressure = 200.0;
            attribute bottomholeTemperature = 78.0;
            attribute productionRate = 0.10;
            attribute active = true;
        }

        part manifold : SubseaManifold {
            attribute manifoldId = "MANIFOLD-01";
            attribute manifoldPressure = 180.0;
            attribute manifoldTemperature = 85.0;
            attribute numActiveWells = 6;
        }

        part riser : Riser {
            attribute riserId = "RISER-01";
            attribute riserLength = 300.0;
            attribute riserDiameter = 0.5;
            attribute designPressure = 250.0;
        }

        // --- Processing Systems ---
        part separationSystem : SeparationSystem {
            attribute separatorPressure = 30.0;
            attribute separatorTemperature = 60.0;
            attribute separationEfficiency = 98.5;
            attribute vesselCapacity = 500.0;
            attribute numSeparators = 3;
            attribute activeSeparators = 2;
        }

        part oilTreatment : OilTreatment {
            attribute operatingPressure = 15.0;
            attribute operatingTemperature = 65.0;
            attribute targetVaporPressure = 0.5;
            attribute treatmentEfficiency = 99.0;
            attribute throughput = 0.5;
            attribute numStabilizerTrains = 2;
        }

        part gasCompression : GasCompression {
            attribute suctionPressure = 10.0;
            attribute dischargePressure = 150.0;
            attribute compressorSpeed = 12000;
            attribute compressionRatio = 15.0;
            attribute numStages = 4;
            attribute numCompressors = 3;
            attribute activeCompressors = 2;
        }

        part waterTreatment : WaterTreatment {
            attribute inletOilContent = 800.0;
            attribute outletOilContent = 29.0;
            attribute treatmentCapacity = 0.3;
            attribute disposalStandard = 30.0;
            attribute numTreatmentTrains = 2;
        }

        // --- Support Systems ---
        part powerGeneration : PowerGeneration {
            attribute fuelConsumption = 0.05;
            attribute generatedPower = 45.0;
            attribute targetPower = 40.0;
            attribute outputVoltage = 11.0;
            attribute outputFrequency = 60.0;
            attribute thermalEfficiency = 38.0;
            attribute numGenerators = 3;
            attribute activeGenerators = 2;
        }

        part powerDistribution : PowerDistribution {
            attribute totalInputPower = 45.0;
            attribute busVoltage = 11.0;
            attribute busFrequency = 60.0;
        }

        part storageTank : StorageTank {
            attribute tankCapacity = 100000.0;
            attribute currentVolume = 45000.0;
            attribute fillLevel = 45.0;
            attribute tankPressure = 5.0;
            attribute tankTemperature = 55.0;
            attribute maxOperatingPressure = 10.0;
            attribute numTanks = 4;
            attribute tankType = "CrudeOilStorage";
        }

        part exportSystem : ExportSystem {
            attribute exportPressure = 80.0;
            attribute exportFlowRate = 0.4;
            attribute exportDestination = "Pipeline";
            attribute pumpStatus = true;
            attribute maxExportRate = 0.8;
            attribute numPumps = 3;
            attribute activePumps = 2;
        }

        // --- Management Systems ---
        part controlSystem : ControlSystem {
            attribute productionRate = 0.75;
            attribute targetProductionRate = 0.8;
            attribute systemStatus = "Operating";
            attribute activeAlerts = 0;
            attribute operatorMode = "Auto";
            attribute shutdownReceived = false;
        }

        part safetySystem : SafetySystem {
            attribute gasLeakDetected = false;
            attribute fireDetected = false;
            attribute pressureLeakDetected = false;
            attribute hazardLevel = 0;
            attribute numActiveSensors = 24;
            attribute numTriggeredAlarms = 0;
            attribute esdActivated = false;
            attribute fireWaterSystemReady = true;
        }

        // ============================================
        // Connections – Fluid Flow
        // ============================================
        connect well1.rawFluidOut to manifold.wellFluid1;
        connect well2.rawFluidOut to manifold.wellFluid2;
        connect well3.rawFluidOut to manifold.wellFluid3;
        connect well4.rawFluidOut to manifold.wellFluid4;
        connect well5.rawFluidOut to manifold.wellFluid5;
        connect well6.rawFluidOut to manifold.wellFluid6;

        connect manifold.rawFluidOut to riser.rawFluidIn;
        connect riser.rawFluidOut to separationSystem.rawFluidIn;

        connect separationSystem.crudeOilOut to oilTreatment.crudeOilIn;
        connect separationSystem.naturalGasOut to gasCompression.naturalGasIn;
        connect separationSystem.producedWaterOut to waterTreatment.producedWaterIn;

        connect oilTreatment.stabilizedOilOut to storageTank.stabilizedOilIn;
        connect storageTank.stabilizedOilOut to exportSystem.stabilizedOilIn;
        connect gasCompression.compressedGasOut to powerGeneration.compressedGasIn;

        // ============================================
        // Connections – Power Distribution
        // ============================================
        connect powerGeneration.powerOut to powerDistribution.powerIn;

        connect powerDistribution.powerOut1 to separationSystem.powerIn;
        connect powerDistribution.powerOut2 to oilTreatment.powerIn;
        connect powerDistribution.powerOut3 to gasCompression.powerIn;
        connect powerDistribution.powerOut4 to waterTreatment.powerIn;
        connect powerDistribution.powerOut5 to storageTank.powerIn;
        connect powerDistribution.powerOut6 to exportSystem.powerIn;
        connect powerDistribution.powerOut7 to controlSystem.powerIn;
        connect powerDistribution.powerOut8 to safetySystem.powerIn;

        // ============================================
        // Connections – Control Signals
        // ============================================
        connect controlSystem.controlSeparation to separationSystem.controlIn;
        connect controlSystem.controlOilTreatment to oilTreatment.controlIn;
        connect controlSystem.controlGasCompression to gasCompression.controlIn;
        connect controlSystem.controlWaterTreatment to waterTreatment.controlIn;
        connect controlSystem.controlPowerGeneration to powerGeneration.controlIn;
        connect controlSystem.controlStorage to storageTank.controlIn;
        connect controlSystem.controlExport to exportSystem.controlIn;

        // ============================================
        // Connections – Safety Signals
        // ============================================
        connect safetySystem.safetySeparation to separationSystem.safetyIn;
        connect safetySystem.safetyOilTreatment to oilTreatment.safetyIn;
        connect safetySystem.safetyGasCompression to gasCompression.safetyIn;
        connect safetySystem.safetyWaterTreatment to waterTreatment.safetyIn;
        connect safetySystem.safetyPowerGeneration to powerGeneration.safetyIn;
        connect safetySystem.safetyStorage to storageTank.safetyIn;
        connect safetySystem.safetyExport to exportSystem.safetyIn;
        connect safetySystem.safetyControl to controlSystem.safetyIn;
    }

    // ========================================
    // Requirements
    // ========================================
    requirement def HydrocarbonExtractionRequirement {
        doc "The platform shall extract raw hydrocarbon fluid from six subsea wells via a subsea manifold and transport it to the surface through risers.";
        subject platform : OffshoreOilPlatform;
        attribute numWells : Integer = 6;
    }

    requirement def SeparationRequirement {
        doc "The separation system shall separate raw fluid into crude oil, natural gas, and produced water streams with a separation efficiency of at least 98%.";
        subject separationSystem : SeparationSystem;
        attribute minEfficiency : EfficiencyValue = 98.0;
    }

    requirement def OilTreatmentRequirement {
        doc "The oil treatment system shall stabilize crude oil to a vapor pressure of 0.5 bar or below for safe storage and export.";
        subject oilTreatment : OilTreatment;
        attribute maxVaporPressure : PressureValue = 0.5;
    }

    requirement def GasCompressionRequirement {
        doc "The gas compression system shall compress natural gas to a minimum discharge pressure of 150 bar for use as power generation fuel.";
        subject gasCompression : GasCompression;
        attribute minDischargePressure : PressureValue = 150.0;
    }

    requirement def WaterTreatmentRequirement {
        doc "The water treatment system shall clean produced water to an oil content of 30 mg/L or below before disposal.";
        subject waterTreatment : WaterTreatment;
        attribute maxOilContent : ConcentrationValue = 30.0;
    }

    requirement def PowerGenerationRequirement {
        doc "The power generation system shall produce all electricity needed for platform operation using compressed natural gas as fuel, achieving at least 38% thermal efficiency.";
        subject powerGeneration : PowerGeneration;
        attribute minThermalEfficiency : EfficiencyValue = 38.0;
    }

    requirement def StorageRequirement {
        doc "The storage system shall hold at least 100000 cubic meters of stabilized crude oil prior to export.";
        subject storageTank : StorageTank;
        attribute minCapacity : VolumeValue = 100000.0;
    }

    requirement def ExportRequirement {
        doc "The export system shall pump stabilized oil at a maximum rate of 0.8 cubic meters per second to a pipeline or tanker.";
        subject exportSystem : ExportSystem;
        attribute maxExportRate : FlowRateValue = 0.8;
    }

    requirement def ControlSystemRequirement {
        doc "The central control system shall automate the production process and coordinate all subsystem operations.";
        subject controlSystem : ControlSystem;
        attribute automationLevel : String = "Full";
    }

    requirement def SafetySystemRequirement {
        doc "The safety system shall continuously monitor for gas leaks and fires, operate in normal, warning, and emergency states, and initiate an emergency shutdown of all operations when a critical hazard is detected.";
        subject safetySystem : SafetySystem;
        attribute numHazardStates : Integer = 3;
        attribute esdCapability : Boolean = true;
    }

    requirement def PlatformSelfSufficiencyRequirement {
        doc "The platform shall be self-sufficient in power generation, using compressed natural gas produced from the reservoir as fuel for all electrical needs.";
        subject platform : OffshoreOilPlatform;
        attribute powerSelfSufficient : Boolean = true;
    }
}
