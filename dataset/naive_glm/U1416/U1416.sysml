package HydraulicFracturingSystem {

    import ScalarValues::*;

    // =========================================================================
    // Value Types with Units
    // =========================================================================

    value type Pressure :> Real {
        attribute unitName : String = "Pa";
    }

    value type HighPressure :> Pressure {
        attribute unitName : String = "Pa";
    }

    value type FlowRate :> Real {
        attribute unitName : String = "m3/s";
    }

    value type Volume :> Real {
        attribute unitName : String = "m3";
    }

    value type Temperature :> Real {
        attribute unitName : String = "K";
    }

    value type Depth :> Real {
        attribute unitName : String = "m";
    }

    value type Mass :> Real {
        attribute unitName : String = "kg";
    }

    value type Duration :> Real {
        attribute unitName : String = "s";
    }

    value type MassFraction :> Real {
        attribute unitName : String = "kg/kg";
    }

    value type Concentration :> Real {
        attribute unitName : String = "kg/m3";
    }

    value type Percent :> Real {
        attribute min : Real = 0;
        attribute max : Real = 100;
        attribute unitName : String = "%";
    }

    value type SeismicAmplitude :> Real {
        attribute unitName : String = "m/s2";
    }

    value type Power :> Real {
        attribute unitName : String = "W";
    }

    // =========================================================================
    // Item Definitions (Materials flowing through the system)
    // =========================================================================

    item def Water {
        attribute volume : Volume;
        attribute temperature : Temperature;
        attribute pH : Real;
    }

    item def Proppant {
        attribute mass : Mass;
        attribute particleSize : Depth;
        attribute material : String;
        attribute sphericity : Percent;
    }

    item def ChemicalAdditive {
        attribute mass : Mass;
        attribute additiveType : String;
        attribute concentration : Concentration;
        attribute hazardClass : Integer;
    }

    item def FracturingFluid {
        attribute waterVolume : Volume;
        attribute proppantMass : Mass;
        attribute additiveMass : Mass;
        attribute totalVolume : Volume;
        attribute proppantFraction : MassFraction;
        attribute viscosity : Real;
    }

    item def PressurizedFluid :> FracturingFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }

    item def GasWaterMixture {
        attribute gasVolume : Volume;
        attribute waterVolume : Volume;
        attribute contaminantMass : Mass;
        attribute contaminantFraction : MassFraction;
        attribute pressure : Pressure;
    }

    item def NaturalGas {
        attribute volume : Volume;
        attribute methaneContent : Percent;
        attribute ethaneContent : Percent;
        attribute pressure : Pressure;
        attribute heatingValue : Real;
    }

    item def ProducedWater {
        attribute volume : Volume;
        attribute salinity : Concentration;
        attribute contaminantLevel : MassFraction;
        attribute dissolvedSolids : Mass;
    }

    item def Contaminant {
        attribute mass : Mass;
        attribute contaminantType : String;
        attribute toxicityLevel : Integer;
    }

    item def SensorReading {
        attribute value : Real;
        attribute timestamp : Duration;
        attribute sensorType : String;
        attribute sensorId : Integer;
    }

    item def ControlCommand {
        attribute commandType : String;
        attribute targetSubsystem : String;
        attribute priority : Integer;
    }

    // =========================================================================
    // Port Definitions
    // =========================================================================

    port def WaterOutPort {
        out water : Water;
    }

    port def WaterInPort {
        in water : Water;
    }

    port def ProppantOutPort {
        out proppant : Proppant;
    }

    port def ProppantInPort {
        in proppant : Proppant;
    }

    port def ChemicalOutPort {
        out chemical : ChemicalAdditive;
    }

    port def ChemicalInPort {
        in chemical : ChemicalAdditive;
    }

    port def FluidOutPort {
        out fluid : FracturingFluid;
    }

    port def FluidInPort {
        in fluid : FracturingFluid;
    }

    port def PressurizedFluidOutPort {
        out fluid : PressurizedFluid;
    }

    port def PressurizedFluidInPort {
        in fluid : PressurizedFluid;
    }

    port def MixtureOutPort {
        out mixture : GasWaterMixture;
    }

    port def MixtureInPort {
        in mixture : GasWaterMixture;
    }

    port def GasOutPort {
        out gas : NaturalGas;
    }

    port def ProducedWaterOutPort {
        out producedWater : ProducedWater;
    }

    port def ContaminantOutPort {
        out contaminant : Contaminant;
    }

    port def SignalOutPort {
        out reading : SensorReading;
    }

    port def SignalInPort {
        in reading : SensorReading;
    }

    port def CommandOutPort {
        out command : ControlCommand;
    }

    port def CommandInPort {
        in command : ControlCommand;
    }

    // =========================================================================
    // Part Definitions — Subsystem Components
    // =========================================================================

    part def WaterSource {
        port waterOut : WaterOutPort;
        attribute capacity : Volume;
        attribute currentLevel : Volume;
        attribute minOperationalLevel : Volume;
        attribute refillRate : FlowRate;
        attribute isAvailable : Boolean;

        action def supply {
            out waterSupplied : Water;
        }
    }

    part def ProppantStorage {
        port proppantOut : ProppantOutPort;
        attribute storageCapacity : Mass;
        attribute currentLoad : Mass;
        attribute proppantType : String;
        attribute particleSizeRange : Depth;
        attribute isAvailable : Boolean;

        action def discharge {
            out proppantDischarged : Proppant;
        }
    }

    part def ChemicalStorage {
        port chemicalOut : ChemicalOutPort;
        attribute storageCapacity : Mass;
        attribute currentInventory : Mass;
        attribute additiveTypes : String;
        attribute meteringAccuracy : Percent;
        attribute isAvailable : Boolean;

        action def meter {
            out additive : ChemicalAdditive;
        }
    }

    part def BlendingUnit {
        port waterIn : WaterInPort;
        port proppantIn : ProppantInPort;
        port chemicalIn : ChemicalInPort;
        port fluidOut : FluidOutPort;
        port signalOut : SignalOutPort;

        attribute targetProppantFraction : MassFraction;
        attribute targetAdditiveConcentration : Concentration;
        attribute blendRate : FlowRate;
        attribute blendingActive : Boolean;
        attribute totalBlended : Volume;

        action def mix {
            in water : Water;
            in proppant : Proppant;
            in additive : ChemicalAdditive;
            out fluid : FracturingFluid;
        }

        action def calibrate {
            attribute targetViscosity : Real;
        }
    }

    part def HighPressurePump {
        port fluidIn : FluidInPort;
        port pressurizedOut : PressurizedFluidOutPort;
        port signalOut : SignalOutPort;
        port commandIn : CommandInPort;

        attribute maxPressure : HighPressure;
        attribute currentPressure : Pressure;
        attribute pumpRate : FlowRate;
        attribute powerRating : Power;
        attribute isOperational : Boolean;
        attribute pumpId : Integer;
        attribute operatingHours : Duration;

        action def pressurize {
            in fluidIn : FracturingFluid;
            out fluidOut : PressurizedFluid;
        }

        action def startup {
            attribute rampTime : Duration;
        }

        action def shutdown {
            attribute safeDepressurizeTime : Duration;
        }
    }

    part def WellheadAssembly {
        port pressurizedIn : PressurizedFluidInPort;
        port downholeOut : PressurizedFluidOutPort;
        port mixtureIn : MixtureInPort;
        port surfaceMixtureOut : MixtureOutPort;
        port signalOut : SignalOutPort;
        port commandIn : CommandInPort;

        attribute maxWorkingPressure : HighPressure;
        attribute currentPressure : Pressure;
        attribute masterValveOpen : Boolean;
        attribute safetyValveStatus : String;
        attribute wingValveOpen : Boolean;
        attribute emergencyShutdownActive : Boolean;

        action def regulate {
            in fluid : PressurizedFluid;
            out downhole : PressurizedFluid;
        }

        action def emergencyShutdown {
            attribute responseTime : Duration;
        }

        action def openValves {
            attribute sequence : String;
        }
    }

    part def WellboreAssembly {
        port surfaceIn : PressurizedFluidInPort;
        port perforationOut : PressurizedFluidOutPort;
        port mixtureReturn : MixtureOutPort;
        port signalOut : SignalOutPort;

        attribute totalDepth : Depth;
        attribute casingDiameter : Depth;
        attribute casingThickness : Depth;
        attribute perforationCount : Integer;
        attribute targetZoneDepth : Depth;
        attribute formationType : String;
        attribute casingMaterial : String;
        attribute formationPressure : Pressure;

        action def convey {
            in fluid : PressurizedFluid;
            out downhole : PressurizedFluid;
        }

        action def fracture {
            in fluid : PressurizedFluid;
            attribute fractureLength : Depth;
            attribute fractureWidth : Depth;
        }

        action def produce {
            out mixture : GasWaterMixture;
        }
    }

    part def SeparationFacility {
        port mixtureIn : MixtureInPort;
        port gasOut : GasOutPort;
        port waterOut : ProducedWaterOutPort;
        port contaminantOut : ContaminantOutPort;
        port signalOut : SignalOutPort;

        attribute processingCapacity : FlowRate;
        attribute gasSeparationEfficiency : Percent;
        attribute waterTreatmentLevel : Percent;
        attribute isOperational : Boolean;
        attribute throughput : FlowRate;

        action def separate {
            in mixture : GasWaterMixture;
            out gas : NaturalGas;
            out water : ProducedWater;
            out contaminant : Contaminant;
        }

        action def treat {
            in water : ProducedWater;
            out treatedWater : ProducedWater;
        }
    }

    part def PressureSensor {
        port signalOut : SignalOutPort;
        attribute measurementRange : Pressure;
        attribute accuracy : Percent;
        attribute isCalibrated : Boolean;
        attribute samplingRate : Duration;
        attribute sensorId : Integer;

        action def measure {
            out reading : SensorReading;
        }
    }

    part def FlowMeter {
        port signalOut : SignalOutPort;
        attribute measurementRange : FlowRate;
        attribute accuracy : Percent;
        attribute isCalibrated : Boolean;
        attribute sensorId : Integer;

        action def measure {
            out reading : SensorReading;
        }
    }

    part def SeismicMonitor {
        port signalOut : SignalOutPort;
        attribute detectionRange : Depth;
        attribute sensitivity : SeismicAmplitude;
        attribute isCalibrated : Boolean;
        attribute sensorId : Integer;

        action def detect {
            out reading : SensorReading;
        }
    }

    part def MonitoringSystem {
        port pressureSignals : SignalInPort;
        port flowSignals : SignalInPort;
        port seismicSignals : SignalInPort;
        port commandOut : CommandOutPort;
        port systemStatus : SignalOutPort;

        part pressureSensors[4] : PressureSensor;
        part flowMeters[3] : FlowMeter;
        part seismicMonitors[6] : SeismicMonitor;

        attribute alarmThreshold : Pressure;
        attribute seismicAlarmThreshold : SeismicAmplitude;
        attribute dataLoggingEnabled : Boolean;
        attribute realTimeUpdateRate : Duration;
        attribute systemHealthy : Boolean;

        action def monitor {
            in pressureData : SensorReading;
            in flowData : SensorReading;
            in seismicData : SensorReading;
            out alert : ControlCommand;
        }

        action def log {
            in reading : SensorReading;
            attribute storagePath : String;
        }

        action def diagnose {
            out alert : ControlCommand;
        }
    }

    // =========================================================================
    // State Machine — Operational Phases
    // =========================================================================

    state def OperationalPhase {
        attribute phaseStartTime : Duration;
        attribute phaseDuration : Duration;
        attribute currentPhase : String;

        state idle {
            attribute systemReady : Boolean;
            attribute preflightChecksComplete : Boolean;
        }

        state mixing {
            attribute blendTargetVolume : Volume;
            attribute currentBlendVolume : Volume;
            attribute blendComplete : Boolean;
        }

        state pressurizing {
            attribute targetPressure : Pressure;
            attribute currentPumpPressure : Pressure;
            attribute pressurizationComplete : Boolean;
        }

        state injecting {
            attribute targetInjectionVolume : Volume;
            attribute currentInjectionVolume : Volume;
            attribute fracturePressure : Pressure;
            attribute injectionRate : FlowRate;
        }

        state soaking {
            attribute soakDuration : Duration;
            attribute soakElapsed : Duration;
            attribute soakComplete : Boolean;
        }

        state flowback {
            attribute flowbackRate : FlowRate;
            attribute cumulativeFlowback : Volume;
            attribute flowbackComplete : Boolean;
        }

        state production {
            attribute productionRate : FlowRate;
            attribute cumulativeProduction : Volume;
            attribute productionComplete : Boolean;
            attribute wellheadPressure : Pressure;
        }

        state emergency {
            attribute shutdownInitiated : Boolean;
            attribute rootCause : String;
            attribute containmentActive : Boolean;
        }

        transition idle -> mixing when startCommandReceived and preflightChecksComplete;
        transition mixing -> pressurizing when blendComplete;
        transition mixing -> emergency when blendAlarm;
        transition pressurizing -> injecting when pressurizationComplete;
        transition pressurizing -> emergency when overpressureDetected;
        transition injecting -> soaking when currentInjectionVolume >= targetInjectionVolume;
        transition injecting -> emergency when overpressureDetected or seismicAlarmTriggered;
        transition soaking -> flowback when soakComplete;
        transition flowback -> production when flowbackComplete;
        transition production -> idle when productionComplete;
        transition emergency -> idle when resetComplete and containmentActive;
    }

    // =========================================================================
    // Requirement Definitions
    // =========================================================================

    requirement def FrackingSystemRequirement {
        doc
        /* The hydraulic fracturing system shall extract natural gas from deep
           underground shale formations by creating and propping open fractures
           in rock layers to release trapped gas, which is then brought to the
           surface for collection. */;
    }

    requirement def WaterSourceRequirement {
        doc
        /* The Water Source shall provide a continuous supply of water at a
           minimum flow rate sufficient to sustain fracturing operations. */;
        attribute minFlowRate : FlowRate;
        attribute minReserveVolume : Volume;
    }

    requirement def ProppantStorageRequirement {
        doc
        /* The Proppant Storage unit shall hold sufficient proppant material
           (e.g., sand) to maintain propped fractures throughout the target
           formation. */;
        attribute minProppantMass : Mass;
        attribute maxParticleSize : Depth;
    }

    requirement def ChemicalStorageRequirement {
        doc
        /* The Chemical Storage unit shall store and meter various chemical
           additives used in the fracturing fluid formulation with specified
           accuracy. */;
        attribute minAdditiveTypes : Integer;
        attribute meteringAccuracy : Percent;
    }

    requirement def BlendingUnitRequirement {
        doc
        /* The Blending Unit shall mix water, proppant, and chemical additives
           into a homogeneous fracturing fluid with the specified proppant
           concentration and additive concentration. */;
        attribute targetProppantConcentration : MassFraction;
        attribute mixingTolerance : Percent;
    }

    requirement def HighPressurePumpRequirement {
        doc
        /* The High-Pressure Pumps shall pressurize the fracturing fluid to a
           level sufficient to fracture the target shale formation at the
           specified depth. Multiple pumps shall provide redundancy. */;
        attribute requiredFracturePressure : HighPressure;
        attribute minPumpCount : Integer;
        attribute totalPumpPower : Power;
    }

    requirement def WellheadRequirement {
        doc
        /* The Wellhead Assembly shall serve as the control and safety interface
           at the top of the well, regulating fluid injection and providing
           emergency shutoff capability within the specified response time. */;
        attribute maxWorkingPressure : HighPressure;
        attribute emergencyResponseTime : Duration;
    }

    requirement def WellboreRequirement {
        doc
        /* The Wellbore Assembly shall convey pressurized fracturing fluid from
           the surface to the target shale formation through perforations in the
           steel casing at the target depth. */;
        attribute minDepth : Depth;
        attribute perforationDensity : Integer;
        attribute casingPressureRating : HighPressure;
    }

    requirement def SeparationRequirement {
        doc
        /* The Separation Facility shall separate the returned mixture of
           natural gas, produced water, and contaminants into distinct output
           streams for collection and disposal. */;
        attribute minSeparationEfficiency : Percent;
        attribute processingCapacity : FlowRate;
    }

    requirement def MonitoringRequirement {
        doc
        /* The Monitoring System shall use pressure sensors, flow meters, and
           seismic monitors to track subsurface conditions and equipment
           performance in real-time throughout all operational phases. */;
        attribute updateRate : Duration;
        attribute alarmLatency : Duration;
        attribute minSensorCount : Integer;
    }

    requirement def OperationalPhaseRequirement {
        doc
        /* The system shall transition through the operational phases of idle,
           mixing, pressurizing, injecting, soaking, flowback, and long-term
           gas production in a coordinated sequence with defined transition
           criteria. */;
        attribute phaseSequence : String;
    }

    requirement def SafetyRequirement {
        doc
        /* The system shall detect and respond to abnormal pressure or seismic
           conditions by entering an emergency state and initiating a
           controlled shutdown. */;
        attribute maxResponseTime : Duration;
        attribute overpressureThreshold : Pressure;
    }

    // =========================================================================
    // Top-Level System Composition
    // =========================================================================

    part def HydraulicFracturingSystem {

        attribute systemName : String = "HydraulicFracturingSystem";
        attribute systemStatus : String;
        attribute targetInjectionVolume : Volume;
        attribute targetSoakTime : Duration;
        attribute thresholdFlowbackRate : FlowRate;
        attribute pressureAlarm : Boolean;
        attribute seismicAlarm : Boolean;
        attribute currentPressure : Pressure;

        // -- Surface storage components --
        part waterSource : WaterSource {
            attribute capacity = 5000;
            attribute currentLevel = 4500;
            attribute minOperationalLevel = 500;
            attribute refillRate = 0.1;
            attribute isAvailable = true;
        }

        part proppantStorage : ProppantStorage {
            attribute storageCapacity = 2000000;
            attribute currentLoad = 1800000;
            attribute proppantType = "silica sand, 20/40 mesh";
            attribute isAvailable = true;
        }

        part chemicalStorage : ChemicalStorage {
            attribute storageCapacity = 50000;
            attribute currentInventory = 45000;
            attribute additiveTypes = "gelling agent, breaker, biocide, corrosion inhibitor, friction reducer";
            attribute meteringAccuracy = 99.5;
            attribute isAvailable = true;
        }

        // -- Blending unit --
        part blendingUnit : BlendingUnit {
            attribute targetProppantFraction = 0.3;
            attribute targetAdditiveConcentration = 5.0;
            attribute blendRate = 0.8;
            attribute blendingActive = false;
            attribute totalBlended = 0;
        }

        // -- High-pressure pump array --
        part highPressurePumps[4] : HighPressurePump {
            attribute maxPressure = 140000000;
            attribute currentPressure = 0;
            attribute pumpRate = 0.2;
            attribute powerRating = 2250000;
            attribute isOperational = true;
        }

        // -- Wellhead assembly --
        part wellheadAssembly : WellheadAssembly {
            attribute maxWorkingPressure = 105000000;
            attribute currentPressure = 0;
            attribute masterValveOpen = false;
            attribute safetyValveStatus = "closed";
            attribute wingValveOpen = false;
            attribute emergencyShutdownActive = false;
        }

        // -- Wellbore assembly --
        part wellboreAssembly : WellboreAssembly {
            attribute totalDepth = 3200;
            attribute casingDiameter = 0.1397;
            attribute casingThickness = 0.00965;
            attribute perforationCount = 60;
            attribute targetZoneDepth = 2950;
            attribute formationType = "Marcellus shale";
            attribute casingMaterial = "API P-110 steel";
            attribute formationPressure = 28000000;
        }

        // -- Separation facility --
        part separationFacility : SeparationFacility {
            attribute processingCapacity = 0.3;
            attribute gasSeparationEfficiency = 99.5;
            attribute waterTreatmentLevel = 95;
            attribute isOperational = true;
            attribute throughput = 0;
        }

        // -- Monitoring system --
        part monitoringSystem : MonitoringSystem {
            attribute alarmThreshold = 120000000;
            attribute seismicAlarmThreshold = 0.05;
            attribute dataLoggingEnabled = true;
            attribute realTimeUpdateRate = 1;
            attribute systemHealthy = true;
        }

        // -- Material flow connections --
        connection waterToBlender
            connect waterSource.waterOut to blendingUnit.waterIn;

        connection proppantToBlender
            connect proppantStorage.proppantOut to blendingUnit.proppantIn;

        connection chemicalToBlender
            connect chemicalStorage.chemicalOut to blendingUnit.chemicalIn;

        connection blenderToPumps
            connect blendingUnit.fluidOut to highPressurePumps.fluidIn;

        connection pumpsToWellhead
            connect highPressurePumps.pressurizedOut to wellheadAssembly.pressurizedIn;

        connection wellheadToWellbore
            connect wellheadAssembly.downholeOut to wellboreAssembly.surfaceIn;

        connection wellboreReturnToWellhead
            connect wellboreAssembly.mixtureReturn to wellheadAssembly.mixtureIn;

        connection wellheadToSeparator
            connect wellheadAssembly.surfaceMixtureOut to separationFacility.mixtureIn;

        // -- Sensor signal connections to monitoring system --
        connection blenderSignal
            connect blendingUnit.signalOut to monitoringSystem.pressureSignals;

        connection pumpSignal
            connect highPressurePumps.signalOut to monitoringSystem.pressureSignals;

        connection wellheadSignal
            connect wellheadAssembly.signalOut to monitoringSystem.pressureSignals;

        connection wellboreSeismicSignal
            connect wellboreAssembly.signalOut to monitoringSystem.seismicSignals;

        connection separatorFlowSignal
            connect separationFacility.signalOut to monitoringSystem.flowSignals;

        // -- Control command connections from monitoring system --
        connection monitorToPumps
            connect monitoringSystem.commandOut to highPressurePumps.commandIn;

        connection monitorToWellhead
            connect monitoringSystem.commandOut to wellheadAssembly.commandIn;

        // -- Operational state machine --
        state operationalPhase : OperationalPhase;

        // -- Satisfied requirements --
        satisfy FrackingSystemRequirement;
        satisfy WaterSourceRequirement;
        satisfy ProppantStorageRequirement;
        satisfy ChemicalStorageRequirement;
        satisfy BlendingUnitRequirement;
        satisfy HighPressurePumpRequirement;
        satisfy WellheadRequirement;
        satisfy WellboreRequirement;
        satisfy SeparationRequirement;
        satisfy MonitoringRequirement;
        satisfy OperationalPhaseRequirement;
        satisfy SafetyRequirement;
    }

}
