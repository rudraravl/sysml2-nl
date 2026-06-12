package UtilityFogSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def LengthValue :> Real;
    value def AreaValue :> Real;
    value def VolumeValue :> Real;
    value def MassValue :> Real;
    value def ForceValue :> Real;
    value def PowerValue :> Real;
    value def EnergyValue :> Real;
    value def TimeValue :> Real;
    value def TemperatureValue :> Real;
    value def PressureValue :> Real;
    value def DataRateValue :> Real;
    value def PercentageValue :> Real;
    value def CountValue :> Integer;

    attribute def Length {
        value : LengthValue;
        unit : String = "m";
    }

    attribute def Area {
        value : AreaValue;
        unit : String = "m^2";
    }

    attribute def Volume {
        value : VolumeValue;
        unit : String = "m^3";
    }

    attribute def Mass {
        value : MassValue;
        unit : String = "kg";
    }

    attribute def Force {
        value : ForceValue;
        unit : String = "N";
    }

    attribute def Power {
        value : PowerValue;
        unit : String = "W";
    }

    attribute def Energy {
        value : EnergyValue;
        unit : String = "J";
    }

    attribute def Duration {
        value : TimeValue;
        unit : String = "s";
    }

    attribute def Temperature {
        value : TemperatureValue;
        unit : String = "K";
    }

    attribute def Pressure {
        value : PressureValue;
        unit : String = "Pa";
    }

    attribute def DataRate {
        value : DataRateValue;
        unit : String = "Mb/s";
    }

    attribute def Availability {
        value : PercentageValue;
        unit : String = "%";
    }

    attribute def Count {
        value : CountValue;
        unit : String = "1";
    }

    enum def FogOperatingMode {
        enum idle;
        enum distributedSensing;
        enum shapeFormation;
        enum loadBearing;
        enum manipulation;
        enum protectiveShielding;
        enum safeShutdown;
        enum degraded;
    }

    enum def FogNodeState {
        enum dormant;
        enum awake;
        enum linked;
        enum positioned;
        enum actuating;
        enum faulted;
        enum isolated;
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute power : Power;
    }

    item def ControlCommand {
        attribute commandId : Integer;
        attribute targetMode : FogOperatingMode;
        attribute priority : Integer;
        attribute issuedTime : Duration;
    }

    item def NodeTelemetry {
        attribute nodeId : Integer;
        attribute positionX : Length;
        attribute positionY : Length;
        attribute positionZ : Length;
        attribute batteryEnergy : Energy;
        attribute temperature : Temperature;
        attribute linkQuality : Availability;
        attribute state : FogNodeState;
    }

    item def SpatialFieldMap {
        attribute mapId : Integer;
        attribute coveredVolume : Volume;
        attribute resolution : Length;
        attribute occupiedCellCount : Count;
        attribute updatePeriod : Duration;
    }

    item def ShapeIntent {
        attribute shapeId : Integer;
        attribute targetVolume : Volume;
        attribute surfaceArea : Area;
        attribute stiffnessTarget : Pressure;
        attribute maximumFormationTime : Duration;
    }

    item def MechanicalLoad {
        attribute loadId : Integer;
        attribute forceX : Force;
        attribute forceY : Force;
        attribute forceZ : Force;
        attribute contactArea : Area;
    }

    item def HumanInteractionCue {
        attribute cueId : Integer;
        attribute requestedForceLimit : Force;
        attribute requestedSurfaceTemperature : Temperature;
        attribute intendedMotionSpeed : Real;
    }

    port def PowerInPort {
        in item power : ElectricalPower;
    }

    port def PowerOutPort {
        out item power : ElectricalPower;
    }

    port def CommandInPort {
        in item command : ControlCommand;
    }

    port def CommandOutPort {
        out item command : ControlCommand;
    }

    port def TelemetryInPort {
        in item telemetry : NodeTelemetry;
    }

    port def TelemetryOutPort {
        out item telemetry : NodeTelemetry;
    }

    port def FieldMapOutPort {
        out item map : SpatialFieldMap;
    }

    port def FieldMapInPort {
        in item map : SpatialFieldMap;
    }

    port def ShapeIntentInPort {
        in item intent : ShapeIntent;
    }

    port def ShapeIntentOutPort {
        out item intent : ShapeIntent;
    }

    port def LoadInPort {
        in item load : MechanicalLoad;
    }

    port def LoadOutPort {
        out item load : MechanicalLoad;
    }

    port def HumanCueInPort {
        in item cue : HumanInteractionCue;
    }

    action def SenseEnvironment {
        in item previousMap : SpatialFieldMap;
        out item updatedMap : SpatialFieldMap;
    }

    action def AllocateFoglets {
        in item intent : ShapeIntent;
        in item map : SpatialFieldMap;
        out item command : ControlCommand;
    }

    action def FormMacroscopicShape {
        in item command : ControlCommand;
        out item telemetry : NodeTelemetry;
    }

    action def SupportExternalLoad {
        in item load : MechanicalLoad;
        out item command : ControlCommand;
    }

    action def MaintainSafeContact {
        in item cue : HumanInteractionCue;
        out item command : ControlCommand;
    }

    action def IsolateFaultedNode {
        in item telemetry : NodeTelemetry;
        out item command : ControlCommand;
    }

    state def FogNodeLifecycle {
        state dormant;
        state awake;
        state linked;
        state positioned;
        state actuating;
        state faulted;
        state isolated;

        transition first dormant;
        transition wakeUp from dormant to awake;
        transition joinMesh from awake to linked;
        transition receivePositionAssignment from linked to positioned;
        transition beginActuation from positioned to actuating;
        transition holdPosition from actuating to positioned;
        transition detectFault from awake to faulted;
        transition detectLinkedFault from linked to faulted;
        transition detectPositionedFault from positioned to faulted;
        transition detectActuatingFault from actuating to faulted;
        transition quarantine from faulted to isolated;
        transition reset from isolated to dormant;
    }

    state def UtilityFogMissionLifecycle {
        state standby;
        state sensing;
        state planning;
        state forming;
        state bearingLoad;
        state interacting;
        state degradedOperation;
        state emergencyShutdown;

        transition first standby;
        transition commandReceived from standby to sensing;
        transition mapReady from sensing to planning;
        transition allocationReady from planning to forming;
        transition shapeStable from forming to bearingLoad;
        transition humanCueDetected from bearingLoad to interacting;
        transition interactionComplete from interacting to bearingLoad;
        transition replanRequested from bearingLoad to planning;
        transition faultDetected from forming to degradedOperation;
        transition degradedRecovered from degradedOperation to sensing;
        transition criticalHazard from standby to emergencyShutdown;
        transition criticalHazardDuringSensing from sensing to emergencyShutdown;
        transition criticalHazardDuringPlanning from planning to emergencyShutdown;
        transition criticalHazardDuringForming from forming to emergencyShutdown;
        transition criticalHazardDuringLoadBearing from bearingLoad to emergencyShutdown;
        transition restartAuthorized from emergencyShutdown to standby;
    }

    part def FogletNode {
        attribute nodeIdentifier : Integer;
        attribute diameter : Length = (value = 0.00001, unit = "m");
        attribute dryMass : Mass = (value = 0.00000000001, unit = "kg");
        attribute maximumAdhesiveForce : Force = (value = 0.000001, unit = "N");
        attribute maximumActuationForce : Force = (value = 0.000002, unit = "N");
        attribute storedEnergy : Energy = (value = 0.00001, unit = "J");
        attribute nominalTemperature : Temperature = (value = 298.15, unit = "K");
        attribute state : FogNodeState = FogNodeState::dormant;

        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        port telemetryOut : TelemetryOutPort;
        port loadIn : LoadInPort;
    }

    part def FogletCluster {
        attribute clusterIdentifier : Integer;
        attribute nodeCount : Count = (value = 1000000, unit = "1");
        attribute clusterVolume : Volume = (value = 0.001, unit = "m^3");
        attribute averageNodeSpacing : Length = (value = 0.0001, unit = "m");
        attribute localAvailability : Availability = (value = 99.9, unit = "%");
        attribute aggregateForceCapacity : Force = (value = 1.0, unit = "N");

        part foglets : FogletNode[1000000];

        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        port telemetryOut : TelemetryOutPort;
        port loadIn : LoadInPort;
        port loadOut : LoadOutPort;
    }

    part def DistributedMeshNetwork {
        attribute nominalDataRate : DataRate = (value = 10000.0, unit = "Mb/s");
        attribute maximumLatency : Duration = (value = 0.005, unit = "s");
        attribute routingAvailability : Availability = (value = 99.99, unit = "%");

        port commandIn : CommandInPort;
        port commandOut : CommandOutPort;
        port telemetryIn : TelemetryInPort;
        port telemetryOut : TelemetryOutPort;
    }

    part def EnvironmentalSensorLayer {
        attribute sensingRange : Length = (value = 5.0, unit = "m");
        attribute spatialResolution : Length = (value = 0.001, unit = "m");
        attribute updatePeriod : Duration = (value = 0.02, unit = "s");

        port telemetryIn : TelemetryInPort;
        port fieldMapOut : FieldMapOutPort;

        perform action sense : SenseEnvironment;
    }

    part def ShapePlanner {
        attribute maximumPlanningPeriod : Duration = (value = 0.1, unit = "s");
        attribute minimumSurfaceResolution : Length = (value = 0.001, unit = "m");
        attribute maximumSupportedVolume : Volume = (value = 100.0, unit = "m^3");

        port shapeIntentIn : ShapeIntentInPort;
        port fieldMapIn : FieldMapInPort;
        port commandOut : CommandOutPort;

        perform action allocate : AllocateFoglets;
    }

    part def LoadManager {
        attribute maximumDistributedLoad : Force = (value = 10000.0, unit = "N");
        attribute maximumContactPressure : Pressure = (value = 5000.0, unit = "Pa");
        attribute loadUpdatePeriod : Duration = (value = 0.01, unit = "s");

        port loadIn : LoadInPort;
        port commandOut : CommandOutPort;

        perform action support : SupportExternalLoad;
    }

    part def HumanSafetyManager {
        attribute maximumHumanContactForce : Force = (value = 20.0, unit = "N");
        attribute maximumSurfaceTemperature : Temperature = (value = 310.15, unit = "K");
        attribute minimumClearance : Length = (value = 0.05, unit = "m");

        port cueIn : HumanCueInPort;
        port commandOut : CommandOutPort;

        perform action maintainContact : MaintainSafeContact;
    }

    part def FaultManagementController {
        attribute maximumFaultIsolationTime : Duration = (value = 0.05, unit = "s");
        attribute minimumOperationalAvailability : Availability = (value = 99.0, unit = "%");

        port telemetryIn : TelemetryInPort;
        port commandOut : CommandOutPort;

        perform action isolate : IsolateFaultedNode;
    }

    part def EnergyDistributionSystem {
        attribute availablePower : Power = (value = 50000.0, unit = "W");
        attribute storedReserveEnergy : Energy = (value = 5000000.0, unit = "J");
        attribute maximumBrownoutDuration : Duration = (value = 2.0, unit = "s");

        port externalPowerIn : PowerInPort;
        port clusterPowerOut : PowerOutPort;
        port controllerPowerOut : PowerOutPort;
    }

    part def UtilityFogSystem {
        attribute operatingMode : FogOperatingMode = FogOperatingMode::idle;
        attribute controllableVolume : Volume = (value = 100.0, unit = "m^3");
        attribute nominalFormationTime : Duration = (value = 1.0, unit = "s");
        attribute totalNodeCount : Count = (value = 100000000000, unit = "1");
        attribute systemAvailability : Availability = (value = 99.9, unit = "%");
        attribute primaryFunction : String =
            "A utility fog system forms a programmable, reconfigurable cloud of microscopic robotic nodes that can sense, occupy, shape, and mechanically interact with a local volume of space to create temporary objects, surfaces, supports, barriers, and manipulation interfaces on demand.";

        part energySystem : EnergyDistributionSystem;
        part meshNetwork : DistributedMeshNetwork;
        part sensorLayer : EnvironmentalSensorLayer;
        part shapePlanner : ShapePlanner;
        part loadManager : LoadManager;
        part safetyManager : HumanSafetyManager;
        part faultManager : FaultManagementController;
        part clusters : FogletCluster[100000];

        port externalPowerIn : PowerInPort;
        port operatorCommandIn : CommandInPort;
        port shapeIntentIn : ShapeIntentInPort;
        port humanCueIn : HumanCueInPort;
        port externalLoadIn : LoadInPort;
        port telemetryOut : TelemetryOutPort;
        port fieldMapOut : FieldMapOutPort;

        connect externalPowerIn to energySystem.externalPowerIn;
        connect energySystem.clusterPowerOut to clusters.powerIn;
        connect energySystem.controllerPowerOut to meshNetwork.commandIn;

        connect operatorCommandIn to meshNetwork.commandIn;
        connect shapeIntentIn to shapePlanner.shapeIntentIn;
        connect humanCueIn to safetyManager.cueIn;
        connect externalLoadIn to loadManager.loadIn;

        connect clusters.telemetryOut to meshNetwork.telemetryIn;
        connect meshNetwork.telemetryOut to sensorLayer.telemetryIn;
        connect meshNetwork.telemetryOut to faultManager.telemetryIn;
        connect meshNetwork.telemetryOut to telemetryOut;

        connect sensorLayer.fieldMapOut to shapePlanner.fieldMapIn;
        connect sensorLayer.fieldMapOut to fieldMapOut;

        connect shapePlanner.commandOut to meshNetwork.commandIn;
        connect loadManager.commandOut to meshNetwork.commandIn;
        connect safetyManager.commandOut to meshNetwork.commandIn;
        connect faultManager.commandOut to meshNetwork.commandIn;

        connect meshNetwork.commandOut to clusters.commandIn;
        connect clusters.loadOut to loadManager.loadIn;
        connect externalLoadIn to clusters.loadIn;

        exhibit state missionLifecycle : UtilityFogMissionLifecycle;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The system shall provide a programmable utility fog that creates temporary physical structures and interfaces by coordinating large populations of microscopic foglet nodes. */

        subject system : UtilityFogSystem;

        require constraint {
            system.controllableVolume.value >= 10.0
        }
    }

    requirement def ShapeFormationRequirement {
        doc
        /* The system shall form a requested macroscopic shape within the commanded volume within the maximum specified formation time. */

        subject system : UtilityFogSystem;
        attribute maximumFormationTime : Duration = (value = 2.0, unit = "s");

        require constraint {
            system.nominalFormationTime.value <= maximumFormationTime.value
        }
    }

    requirement def LoadBearingRequirement {
        doc
        /* The system shall distribute external loads across many foglet clusters to provide stable temporary surfaces, supports, and barriers. */

        subject system : UtilityFogSystem;
        attribute requiredLoadCapacity : Force = (value = 5000.0, unit = "N");

        require constraint {
            system.loadManager.maximumDistributedLoad.value >= requiredLoadCapacity.value
        }
    }

    requirement def HumanSafetyRequirement {
        doc
        /* The system shall limit contact force and surface temperature during human interaction. */

        subject system : UtilityFogSystem;
        attribute allowedContactForce : Force = (value = 20.0, unit = "N");
        attribute allowedSurfaceTemperature : Temperature = (value = 310.15, unit = "K");

        require constraint {
            system.safetyManager.maximumHumanContactForce.value <= allowedContactForce.value and
            system.safetyManager.maximumSurfaceTemperature.value <= allowedSurfaceTemperature.value
        }
    }

    requirement def FaultToleranceRequirement {
        doc
        /* The system shall detect and isolate failed foglet nodes or clusters fast enough to preserve safe degraded operation. */

        subject system : UtilityFogSystem;
        attribute requiredIsolationTime : Duration = (value = 0.1, unit = "s");
        attribute requiredAvailability : Availability = (value = 99.0, unit = "%");

        require constraint {
            system.faultManager.maximumFaultIsolationTime.value <= requiredIsolationTime.value and
            system.systemAvailability.value >= requiredAvailability.value
        }
    }

    requirement def EnvironmentalAwarenessRequirement {
        doc
        /* The system shall maintain a spatial field map of the controlled volume for collision avoidance, shape planning, and human-safe operation. */

        subject system : UtilityFogSystem;
        attribute requiredMapUpdatePeriod : Duration = (value = 0.05, unit = "s");
        attribute requiredSpatialResolution : Length = (value = 0.005, unit = "m");

        require constraint {
            system.sensorLayer.updatePeriod.value <= requiredMapUpdatePeriod.value and
            system.sensorLayer.spatialResolution.value <= requiredSpatialResolution.value
        }
    }

    satisfy PrimaryFunctionRequirement by UtilityFogSystem;
    satisfy ShapeFormationRequirement by UtilityFogSystem;
    satisfy LoadBearingRequirement by UtilityFogSystem;
    satisfy HumanSafetyRequirement by UtilityFogSystem;
    satisfy FaultToleranceRequirement by UtilityFogSystem;
    satisfy EnvironmentalAwarenessRequirement by UtilityFogSystem;
}