package SwarmRoboticsMissionSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;
    import CauseAndEffect::*;
    import Requirements::*;

    attribute def Meter :> ISQ::length;
    attribute def SquareMeter :> ISQ::area;
    attribute def Second :> ISQ::time;
    attribute def MeterPerSecond :> ISQ::speed;
    attribute def Joule :> ISQ::energy;
    attribute def Watt :> ISQ::power;
    attribute def Percent;
    attribute def Hertz :> ISQ::frequency;
    attribute def BitPerSecond;
    attribute def Degree;
    attribute def Volt :> ISQ::electricPotential;
    attribute def Ampere :> ISQ::electricCurrent;
    attribute def Kilogram :> ISQ::mass;
    attribute def MeterAccuracy :> Meter;
    attribute def Probability;

    enum def RobotMode {
        enum idle;
        enum selfTest;
        enum localizing;
        enum exploring;
        enum mapping;
        enum assisting;
        enum returning;
        enum charging;
        enum faulted;
    }

    enum def MissionPhase {
        enum planned;
        enum deploying;
        enum surveying;
        enum converging;
        enum complete;
        enum aborting;
    }

    enum def HealthLevel {
        enum nominal;
        enum degraded;
        enum critical;
        enum failed;
    }

    enum def TerrainClass {
        enum unknown;
        enum open;
        enum obstacle;
        enum rough;
        enum noGo;
        enum target;
    }

    enum def CommandKind {
        enum startMission;
        enum stopMission;
        enum assignRegion;
        enum rendezvous;
        enum returnToBase;
        enum recharge;
        enum shareMap;
        enum avoidHazard;
    }

    item def Position2D {
        attribute x : Meter;
        attribute y : Meter;
        attribute covarianceRadius : MeterAccuracy;
    }

    item def Velocity2D {
        attribute vx : MeterPerSecond;
        attribute vy : MeterPerSecond;
        attribute speed : MeterPerSecond;
    }

    item def RegionAssignment {
        attribute regionId : Integer;
        attribute centroid : Position2D;
        attribute boundaryArea : SquareMeter;
        attribute priority : Integer;
        attribute requiredRobots : Integer;
    }

    item def TerrainCell {
        attribute cellId : Integer;
        attribute center : Position2D;
        attribute resolution : Meter;
        attribute classification : TerrainClass;
        attribute occupancyProbability : Probability;
        attribute lastUpdated : Second;
    }

    item def LocalMapFragment {
        attribute fragmentId : Integer;
        attribute producerRobotId : Integer;
        attribute coveredArea : SquareMeter;
        attribute resolution : Meter;
        attribute cellCount : Integer;
        item cells[0..*] : TerrainCell;
    }

    item def GlobalMap {
        attribute mapId : Integer;
        attribute totalArea : SquareMeter;
        attribute coveredArea : SquareMeter;
        attribute coverageRatio : Percent;
        attribute resolution : Meter;
        attribute obstacleCount : Integer;
        attribute targetCount : Integer;
        item cells[0..*] : TerrainCell;
    }

    item def SwarmCommand {
        attribute commandId : Integer;
        attribute kind : CommandKind;
        attribute issueTime : Second;
        attribute targetRobotId : Integer;
        attribute targetRegion : RegionAssignment;
        attribute validityDuration : Second;
    }

    item def RobotStatus {
        attribute robotId : Integer;
        attribute mode : RobotMode;
        attribute health : HealthLevel;
        attribute position : Position2D;
        attribute velocity : Velocity2D;
        attribute batteryStateOfCharge : Percent;
        attribute remainingEnergy : Joule;
        attribute localCoverage : SquareMeter;
        attribute faultCode : Integer;
        attribute timeStamp : Second;
    }

    item def MissionPlan {
        attribute missionId : Integer;
        attribute plannedArea : SquareMeter;
        attribute requiredCoverageRatio : Percent;
        attribute maximumMissionTime : Second;
        attribute minimumActiveRobots : Integer;
        attribute mapResolution : Meter;
        item initialAssignments[1..*] : RegionAssignment;
    }

    item def MissionSummary {
        attribute missionId : Integer;
        attribute achievedCoverageRatio : Percent;
        attribute elapsedTime : Second;
        attribute robotsDeployed : Integer;
        attribute robotsRecovered : Integer;
        attribute targetsDetected : Integer;
        attribute globalMap : GlobalMap;
    }

    port def WirelessMeshPort {
        in item inboundCommand : SwarmCommand;
        in item inboundStatus : RobotStatus;
        in item inboundMap : LocalMapFragment;
        out item outboundCommand : SwarmCommand;
        out item outboundStatus : RobotStatus;
        out item outboundMap : LocalMapFragment;
        attribute carrierFrequency : Hertz;
        attribute dataRate : BitPerSecond;
        attribute nominalRange : Meter;
        attribute packetLossProbability : Probability;
    }

    port def OperatorPort {
        in item plan : MissionPlan;
        out item summary : MissionSummary;
        out item liveMap : GlobalMap;
        out item fleetStatus[0..*] : RobotStatus;
    }

    port def SensorDataPort {
        out item position : Position2D;
        out item terrainCell : TerrainCell;
        out item localMap : LocalMapFragment;
    }

    port def MotionPowerPort {
        in item drivePower : Watt;
        out item tractionVelocity : Velocity2D;
    }

    port def ChargingPort {
        in item electricalPower : Watt;
        out item chargeStatus : RobotStatus;
        attribute voltage : Volt;
        attribute currentLimit : Ampere;
    }

    port def MapFusionPort {
        in item fragment : LocalMapFragment;
        out item fusedMap : GlobalMap;
    }

    action def PerformSelfTest {
        in item currentStatus : RobotStatus;
        out item verifiedStatus : RobotStatus;
        attribute maximumDuration : Second = 10;
    }

    action def LocalizeRobot {
        in item priorPosition : Position2D;
        out item estimatedPosition : Position2D;
        attribute updateRate : Hertz = 10;
        attribute targetAccuracy : MeterAccuracy = 0.25;
    }

    action def SenseTerrain {
        in item robotPosition : Position2D;
        out item terrainObservation : TerrainCell;
        attribute sensingRadius : Meter = 8;
        attribute scanRate : Hertz = 5;
    }

    action def BuildLocalMap {
        in item observations[1..*] : TerrainCell;
        out item mapFragment : LocalMapFragment;
        attribute mapResolution : Meter = 0.5;
    }

    action def ShareLocalMap {
        in item mapFragment : LocalMapFragment;
        out item transmittedMap : LocalMapFragment;
        attribute maximumLatency : Second = 2;
    }

    action def AllocateRegions {
        in item plan : MissionPlan;
        in item statuses[1..*] : RobotStatus;
        out item assignments[1..*] : RegionAssignment;
        attribute rebalancePeriod : Second = 15;
    }

    action def NavigateToRegion {
        in item currentPosition : Position2D;
        in item assignedRegion : RegionAssignment;
        out item commandedVelocity : Velocity2D;
        attribute maximumSpeed : MeterPerSecond = 1.2;
        attribute obstacleClearance : Meter = 0.4;
    }

    action def AvoidCollision {
        in item ownStatus : RobotStatus;
        in item neighborStatuses[0..*] : RobotStatus;
        out item safeVelocity : Velocity2D;
        attribute minimumSeparation : Meter = 1.0;
        attribute reactionTime : Second = 0.2;
    }

    action def FuseSwarmMap {
        in item fragments[1..*] : LocalMapFragment;
        out item map : GlobalMap;
        attribute fusionPeriod : Second = 5;
        attribute targetResolution : Meter = 0.5;
    }

    action def ReturnToBase {
        in item currentPosition : Position2D;
        out item recoveryVelocity : Velocity2D;
        attribute reserveEnergyThreshold : Percent = 15;
    }

    action def ExecuteSwarmSurvey {
        in item plan : MissionPlan;
        out item summary : MissionSummary;

        action deploySwarm {
            in item missionPlan : MissionPlan;
            out item deployedStatuses[1..*] : RobotStatus;
        }

        action assignCoverageRegions : AllocateRegions {
            in item plan = deploySwarm.missionPlan;
            in item statuses = deploySwarm.deployedStatuses;
        }

        action distributedExplore {
            in item assignments[1..*] = assignCoverageRegions.assignments;
            out item localFragments[1..*] : LocalMapFragment;
            out item currentStatuses[1..*] : RobotStatus;
        }

        action fuseMaps : FuseSwarmMap {
            in item fragments = distributedExplore.localFragments;
        }

        action recoverRobots {
            in item finalStatuses[1..*] = distributedExplore.currentStatuses;
            out item recoveredStatuses[1..*] : RobotStatus;
        }

        action produceMissionSummary {
            in item globalMap : GlobalMap = fuseMaps.map;
            in item recoveredStatuses[1..*] = recoverRobots.recoveredStatuses;
            out item completedSummary : MissionSummary;
        }

        bind summary = produceMissionSummary.completedSummary;
    }

    part def BatteryPack {
        attribute nominalVoltage : Volt = 24;
        attribute capacity : Joule = 720000;
        attribute stateOfCharge : Percent;
        attribute maximumDischargePower : Watt = 180;
        attribute maximumChargePower : Watt = 120;
        port chargePort : ChargingPort;
    }

    part def DriveModule {
        attribute maximumSpeed : MeterPerSecond = 1.2;
        attribute maximumSlope : Degree = 20;
        attribute continuousPower : Watt = 90;
        attribute wheelBase : Meter = 0.32;
        port motionPort : MotionPowerPort;
    }

    part def PerceptionModule {
        attribute lidarRange : Meter = 12;
        attribute cameraFieldOfView : Degree = 120;
        attribute localizationAccuracy : MeterAccuracy = 0.25;
        attribute scanRate : Hertz = 5;
        port sensorPort : SensorDataPort;
    }

    part def MeshRadio {
        attribute carrierFrequency : Hertz = 2400000000;
        attribute dataRate : BitPerSecond = 1000000;
        attribute nominalRange : Meter = 80;
        attribute transmitPower : Watt = 1;
        port meshPort : WirelessMeshPort;
    }

    part def RobotComputer {
        attribute processorPower : Watt = 18;
        attribute mapMemoryCapacity : Integer = 2000000;
        attribute controlCyclePeriod : Second = 0.1;
        port commPort : WirelessMeshPort;
        port sensorInput : SensorDataPort;
        port motionCommand : MotionPowerPort;

        action localize : LocalizeRobot;
        action sense : SenseTerrain;
        action buildMap : BuildLocalMap;
        action avoidCollision : AvoidCollision;
        action navigate : NavigateToRegion;
        action shareMap : ShareLocalMap;
    }

    state def RobotOperationalStateMachine {
        state inactive;
        state selfTesting;
        state localizing;
        state awaitingAssignment;
        state transitingToRegion;
        state exploringRegion;
        state sharingMap;
        state assistingNeighbor;
        state returningToBase;
        state charging;
        state safeFault;

        transition initialize first inactive then selfTesting;
        transition selfTestPassed first selfTesting then localizing;
        transition localizationReady first localizing then awaitingAssignment;
        transition assignmentReceived first awaitingAssignment then transitingToRegion;
        transition arrivedAtAssignedRegion first transitingToRegion then exploringRegion;
        transition mapFragmentReady first exploringRegion then sharingMap;
        transition continueExploration first sharingMap then exploringRegion;
        transition neighborRequestsSupport first exploringRegion then assistingNeighbor;
        transition supportComplete first assistingNeighbor then exploringRegion;
        transition lowBattery first exploringRegion then returningToBase;
        transition missionComplete first exploringRegion then returningToBase;
        transition arrivedAtBase first returningToBase then charging;
        transition chargeComplete first charging then awaitingAssignment;
        transition unrecoverableFault first inactive then safeFault;
        transition faultDuringSelfTest first selfTesting then safeFault;
        transition faultDuringMission first exploringRegion then safeFault;
        transition faultDuringTransit first transitingToRegion then safeFault;
    }

    part def SwarmRobot {
        attribute robotId : Integer;
        attribute mass : Kilogram = 6.5;
        attribute mode : RobotMode;
        attribute health : HealthLevel;
        attribute nominalEndurance : Second = 5400;
        attribute minimumReserveEnergy : Joule = 108000;
        attribute coverageRate : SquareMeter = 45;
        attribute currentPosition : Position2D;
        attribute currentVelocity : Velocity2D;
        attribute assignedRegion : RegionAssignment;
        attribute localCoverage : SquareMeter;
        attribute minimumSeparation : Meter = 1.0;

        part battery : BatteryPack;
        part drive : DriveModule;
        part perception : PerceptionModule;
        part radio : MeshRadio;
        part computer : RobotComputer;

        port mesh : WirelessMeshPort;
        port charging : ChargingPort;

        connection radioToComputer connect radio.meshPort to computer.commPort;
        connection perceptionToComputer connect perception.sensorPort to computer.sensorInput;
        connection computerToDrive connect computer.motionCommand to drive.motionPort;
        connection externalMesh connect mesh to radio.meshPort;
        connection externalCharging connect charging to battery.chargePort;

        state operationalStates : RobotOperationalStateMachine;

        action selfTest : PerformSelfTest;
        action localize : LocalizeRobot;
        action senseTerrain : SenseTerrain;
        action buildLocalMap : BuildLocalMap;
        action navigateToRegion : NavigateToRegion;
        action avoidCollision : AvoidCollision;
        action shareLocalMap : ShareLocalMap;
        action returnHome : ReturnToBase;
    }

    part def MissionControlStation {
        attribute planningHorizon : Second = 7200;
        attribute operatorUpdatePeriod : Second = 1;
        attribute maximumManagedRobots : Integer = 60;
        attribute globalMapResolution : Meter = 0.5;

        port operatorInterface : OperatorPort;
        port meshGateway : WirelessMeshPort;
        port fusionInterface : MapFusionPort;

        action allocateRegions : AllocateRegions;
        action fuseSwarmMap : FuseSwarmMap;
    }

    part def ChargingDock {
        attribute dockId : Integer;
        attribute availablePower : Watt = 600;
        attribute chargeVoltage : Volt = 24;
        attribute maximumSlots : Integer = 6;
        port chargePorts[6] : ChargingPort;
    }

    part def DeploymentZone {
        attribute zoneId : Integer;
        attribute center : Position2D;
        attribute stagingArea : SquareMeter = 25;
        part docks[2] : ChargingDock;
    }

    part def SurveyEnvironment {
        attribute environmentId : Integer;
        attribute totalSurveyArea : SquareMeter = 12000;
        attribute nominalObstacleDensity : Percent = 18;
        attribute communicationShadowRatio : Percent = 8;
        attribute targetCountEstimate : Integer = 10;
        item globalTerrain[0..*] : TerrainCell;
    }

    state def SwarmMissionStateMachine {
        state notConfigured;
        state planning;
        state deploying;
        state distributedSurvey;
        state mapConvergence;
        state recovery;
        state missionComplete;
        state missionAbort;

        transition receiveMission first notConfigured then planning;
        transition planValidated first planning then deploying;
        transition robotsReleased first deploying then distributedSurvey;
        transition coverageThresholdReached first distributedSurvey then mapConvergence;
        transition mapStable first mapConvergence then recovery;
        transition allRobotsRecovered first recovery then missionComplete;
        transition operatorAbortFromPlanning first planning then missionAbort;
        transition operatorAbortFromSurvey first distributedSurvey then missionAbort;
        transition insufficientRobots first deploying then missionAbort;
        transition safetyAbort first distributedSurvey then missionAbort;
    }

    part def SwarmRoboticsSystem {
        doc
        /*
         Primary high-level function: cooperatively deploy a fleet of autonomous mobile robots that self-organize through mesh communication to survey an assigned area, maintain safe separation, share local observations, fuse a global map, detect targets or hazards, and return all recoverable robots to the deployment zone.
        */

        attribute systemId : Integer = 1001;
        attribute primaryFunction : String = "Distributed cooperative area survey and mapping by a self-organizing robot swarm";
        attribute nominalRobotCount : Integer = 24;
        attribute minimumOperationalRobots : Integer = 16;
        attribute maximumMissionDuration : Second = 3600;
        attribute requiredCoverageRatio : Percent = 95;
        attribute targetMapResolution : Meter = 0.5;
        attribute minimumRobotSeparation : Meter = 1.0;
        attribute requiredCommunicationRange : Meter = 50;
        attribute achievedCoverageRatio : Percent;
        attribute elapsedMissionTime : Second;

        part controlStation : MissionControlStation;
        part environment : SurveyEnvironment;
        part deploymentZone : DeploymentZone;
        part robots[24] : SwarmRobot;

        port operatorPort : OperatorPort;
        port swarmMesh : WirelessMeshPort;
        port mapFusion : MapFusionPort;

        connection operatorToControl connect operatorPort to controlStation.operatorInterface;
        connection controlToSwarmMesh connect controlStation.meshGateway to swarmMesh;
        connection controlToFusion connect controlStation.fusionInterface to mapFusion;
        connection swarmMeshToRobots connect swarmMesh to robots.mesh;
        connection robotDockCharging connect deploymentZone.docks.chargePorts to robots.charging;

        state missionStates : SwarmMissionStateMachine;

        action executeMission : ExecuteSwarmSurvey;
        action allocateRegions : AllocateRegions;
        action fuseMap : FuseSwarmMap;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         The system shall provide distributed cooperative area survey and mapping using multiple autonomous robots that coordinate through a wireless mesh network without requiring continuous operator control.
        */
        subject system : SwarmRoboticsSystem;
        require constraint {
            system.nominalRobotCount >= system.minimumOperationalRobots
        }
    }

    requirement def CoverageRequirement {
        doc
        /*
         The swarm shall cover at least 95 percent of the planned survey area during a nominal mission.
        */
        subject system : SwarmRoboticsSystem;
        require constraint {
            system.achievedCoverageRatio >= system.requiredCoverageRatio
        }
    }

    requirement def MissionDurationRequirement {
        doc
        /*
         The swarm shall complete the nominal survey mission within one hour.
        */
        subject system : SwarmRoboticsSystem;
        require constraint {
            system.elapsedMissionTime <= system.maximumMissionDuration
        }
    }

    requirement def MinimumSwarmSizeRequirement {
        doc
        /*
         The mission shall continue while at least 16 robots remain operational.
        */
        subject system : SwarmRoboticsSystem;
        require constraint {
            system.minimumOperationalRobots >= 16
        }
    }

    requirement def SafeSeparationRequirement {
        doc
        /*
         Each robot shall maintain at least one meter separation from neighboring robots during transit and exploration except while docked.
        */
        subject robot : SwarmRobot;
        require constraint {
            robot.minimumSeparation >= 1.0
        }
    }

    requirement def CommunicationRangeRequirement {
        doc
        /*
         Each robot radio shall support mesh communication over at least 50 meters in nominal open terrain.
        */
        subject system : SwarmRoboticsSystem;
        require constraint {
            system.requiredCommunicationRange >= 50
        }
    }

    requirement def EnergyReserveRequirement {
        doc
        /*
         Each robot shall begin return-to-base behavior before battery reserve energy falls below the defined minimum reserve.
        */
        subject robot : SwarmRobot;
        require constraint {
            robot.minimumReserveEnergy >= 108000
        }
    }

    requirement def MapResolutionRequirement {
        doc
        /*
         The fused global map shall provide a target spatial resolution of 0.5 meters or finer.
        */
        subject system : SwarmRoboticsSystem;
        require constraint {
            system.targetMapResolution <= 0.5
        }
    }

    requirement def FaultToleranceRequirement {
        doc
        /*
         The system shall tolerate loss or failure of up to one third of deployed robots while preserving mission continuation capability.
        */
        subject system : SwarmRoboticsSystem;
        require constraint {
            system.minimumOperationalRobots <= 16
        }
    }

    satisfy PrimaryFunctionRequirement by SwarmRoboticsSystem;
    satisfy CoverageRequirement by SwarmRoboticsSystem;
    satisfy MissionDurationRequirement by SwarmRoboticsSystem;
    satisfy MinimumSwarmSizeRequirement by SwarmRoboticsSystem;
    satisfy CommunicationRangeRequirement by SwarmRoboticsSystem;
    satisfy MapResolutionRequirement by SwarmRoboticsSystem;
    satisfy SafeSeparationRequirement by SwarmRobot;
    satisfy EnergyReserveRequirement by SwarmRobot;
    satisfy FaultToleranceRequirement by SwarmRoboticsSystem;

    part swarmSurveySystem : SwarmRoboticsSystem {
        attribute achievedCoverageRatio = 0;
        attribute elapsedMissionTime = 0;

        part redefines environment {
            attribute totalSurveyArea = 12000;
            attribute nominalObstacleDensity = 18;
            attribute communicationShadowRatio = 8;
        }

        part redefines robots[24] {
            attribute mode = RobotMode::idle;
            attribute health = HealthLevel::nominal;
            attribute localCoverage = 0;
        }
    }
}
