package SwarmRoboticsSystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Distance :> Real {
        unit = "m";
    }

    attribute def Area :> Real {
        unit = "m^2";
    }

    attribute def Speed :> Real {
        unit = "m/s";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    attribute def Energy :> Real {
        unit = "Wh";
    }

    attribute def Power :> Real {
        unit = "W";
    }

    attribute def Frequency :> Real {
        unit = "Hz";
    }

    attribute def Probability :> Real {
        range = "0..1";
    }

    attribute def Percent :> Real {
        unit = "%";
        range = "0..100";
    }

    item def MissionPlan {
        attribute missionId : String;
        attribute targetArea : Area;
        attribute requiredCoverage : Percent;
        attribute maximumMissionTime : TimeDuration;
        attribute robotSpacing : Distance;
        attribute priority : Integer;
    }

    item def SwarmCommand {
        attribute commandId : String;
        attribute commandType : String;
        attribute issuedTime : TimeDuration;
        attribute validityDuration : TimeDuration;
    }

    item def RobotStatus {
        attribute robotId : String;
        attribute positionX : Distance;
        attribute positionY : Distance;
        attribute heading : Real;
        attribute batteryStateOfCharge : Percent;
        attribute healthState : String;
        attribute assignedTask : String;
    }

    item def MapTile {
        attribute tileId : String;
        attribute originX : Distance;
        attribute originY : Distance;
        attribute tileArea : Area;
        attribute confidence : Probability;
        attribute explored : Boolean;
    }

    item def LocalObstacleMap {
        attribute robotId : String;
        attribute updateRate : Frequency;
        attribute obstacleCount : Integer;
        attribute mapConfidence : Probability;
    }

    item def SwarmMap {
        attribute coveredArea : Area;
        attribute totalArea : Area;
        attribute coverageRatio : Probability;
        attribute mapConfidence : Probability;
    }

    item def MissionReport {
        attribute missionId : String;
        attribute completed : Boolean;
        attribute achievedCoverage : Percent;
        attribute elapsedTime : TimeDuration;
        attribute robotsUsed : Integer;
        attribute faultsObserved : Integer;
    }

    item def EnergyPacket {
        attribute availableEnergy : Energy;
        attribute chargingPower : Power;
    }

    port def CommandPort {
        out item command : SwarmCommand;
    }

    port def StatusPort {
        in item status : RobotStatus;
    }

    port def MissionPlanPort {
        out item plan : MissionPlan;
    }

    port def MapPort {
        in item mapIn : LocalObstacleMap;
        out item mapOut : SwarmMap;
    }

    port def RobotDataPort {
        in item command : SwarmCommand;
        out item status : RobotStatus;
        out item localMap : LocalObstacleMap;
    }

    port def PeerCoordinationPort {
        in item peerStatusIn : RobotStatus;
        out item peerStatusOut : RobotStatus;
        in item peerMapIn : LocalObstacleMap;
        out item peerMapOut : LocalObstacleMap;
    }

    port def ChargingPort {
        in item energy : EnergyPacket;
    }

    port def OperatorPort {
        in item missionReport : MissionReport;
        out item missionPlan : MissionPlan;
        out item operatorCommand : SwarmCommand;
    }

    part def OperatorInterface {
        port operator : OperatorPort;
        attribute displayedCoverage : Percent;
        attribute displayedRobotCount : Integer;
        attribute emergencyStopEnabled : Boolean;
    }

    part def MissionControlStation {
        port operatorLink : OperatorPort;
        port missionPlanOut : MissionPlanPort;
        port commandOut : CommandPort;
        port statusIn : StatusPort;
        port mapIn : MapPort;

        attribute activeMissionId : String;
        attribute missionCoverage : Percent;
        attribute healthyRobotCount : Integer;
        attribute faultedRobotCount : Integer;
    }

    part def CommunicationGateway {
        port commandIn : CommandPort;
        port statusOut : StatusPort;
        port mapOut : MapPort;
        port robotNetwork[1..200] : RobotDataPort;

        attribute carrierFrequency : Frequency = 2400000000;
        attribute nominalRange : Distance = 300;
        attribute packetDeliveryProbability : Probability = 0.98;
        attribute maximumRobotLinks : Integer = 200;
    }

    part def SafetyMonitor {
        port statusIn : StatusPort;
        port commandOut : CommandPort;

        attribute minimumSafeBattery : Percent = 15;
        attribute maximumAllowedFaultedRobots : Integer = 5;
        attribute emergencyStopActive : Boolean;
    }

    part def ChargingDock {
        port charge[1..50] : ChargingPort;

        attribute dockCapacity : Integer = 50;
        attribute storedEnergy : Energy = 20000;
        attribute maximumChargePowerPerRobot : Power = 120;
    }

    part def RobotSwarm {
        part robot[10..100] : MobileRobot;

        attribute nominalRobotCount : Integer = 40;
        attribute availableRobotCount : Integer;
        attribute assignedRobotCount : Integer;
        attribute collectiveCoverage : Percent;
        attribute redundancyLevel : Integer = 3;
    }

    part def MobileRobot {
        port network : RobotDataPort;
        port peer[0..12] : PeerCoordinationPort;
        port charger : ChargingPort;

        part mobility : DifferentialDrive;
        part perception : PerceptionSuite;
        part localization : LocalizationModule;
        part compute : OnboardAutonomyComputer;
        part radio : MeshRadio;
        part battery : BatteryPack;
        part payload : SurveyPayload;

        attribute robotId : String;
        attribute maximumSpeed : Speed = 1.5;
        attribute nominalMissionSpeed : Speed = 0.8;
        attribute sensingRadius : Distance = 12;
        attribute localCoverage : Area;
        attribute role : String;
    }

    part def DifferentialDrive {
        attribute wheelBase : Distance = 0.42;
        attribute wheelRadius : Distance = 0.09;
        attribute maximumLinearSpeed : Speed = 1.5;
        attribute maximumAngularSpeed : Real = 2.2;
    }

    part def PerceptionSuite {
        attribute lidarRange : Distance = 25;
        attribute cameraFrameRate : Frequency = 30;
        attribute obstacleDetectionProbability : Probability = 0.97;
    }

    part def LocalizationModule {
        attribute positionAccuracy : Distance = 0.15;
        attribute updateRate : Frequency = 20;
        attribute supportsRelativeLocalization : Boolean = true;
    }

    part def OnboardAutonomyComputer {
        attribute processorPower : Power = 18;
        attribute taskAllocationCycle : TimeDuration = 2;
        attribute pathPlanningCycle : TimeDuration = 0.5;
    }

    part def MeshRadio {
        attribute radioRange : Distance = 120;
        attribute heartbeatRate : Frequency = 2;
        attribute peerLimit : Integer = 12;
    }

    part def BatteryPack {
        attribute capacity : Energy = 520;
        attribute stateOfCharge : Percent = 100;
        attribute lowPowerThreshold : Percent = 20;
    }

    part def SurveyPayload {
        attribute sensorSweepWidth : Distance = 8;
        attribute measurementRate : Frequency = 10;
        attribute payloadPower : Power = 22;
    }

    part swarmRoboticsSystem : SwarmRoboticsSystem;

    part def SwarmRoboticsSystem {
        part operatorInterface : OperatorInterface;
        part missionControl : MissionControlStation;
        part gateway : CommunicationGateway;
        part safetyMonitor : SafetyMonitor;
        part chargingDock : ChargingDock;
        part swarm : RobotSwarm;

        attribute missionCoverage : Percent;
        attribute missionElapsedTime : TimeDuration;
        attribute operationalArea : Area;
        attribute primaryFunction : String = "Autonomously coordinate multiple mobile robots to explore, map, and survey a defined area while maintaining communication, safety, and energy constraints.";

        connect operatorInterface.operator to missionControl.operatorLink;
        connect missionControl.commandOut to gateway.commandIn;
        connect missionControl.statusIn to gateway.statusOut;
        connect missionControl.mapIn to gateway.mapOut;
        connect safetyMonitor.statusIn to gateway.statusOut;
        connect safetyMonitor.commandOut to gateway.commandIn;

        connect gateway.robotNetwork to swarm.robot.network;
        connect chargingDock.charge to swarm.robot.charger;
    }

    action def ExecuteSwarmMission {
        in item plan : MissionPlan;
        out item report : MissionReport;

        action initializeMission {
            in item plan : MissionPlan;
            out item initialCommand : SwarmCommand;
        }

        action assignRobots {
            in item plan : MissionPlan;
            in item statusSet : RobotStatus;
            out item allocationCommand : SwarmCommand;
        }

        action coordinateDistributedCoverage {
            in item allocationCommand : SwarmCommand;
            in item peerStatus : RobotStatus;
            out item coverageCommand : SwarmCommand;
        }

        action exploreAndSurveyArea {
            in item coverageCommand : SwarmCommand;
            out item tileMap : LocalObstacleMap;
        }

        action fuseSwarmMap {
            in item tileMap : LocalObstacleMap;
            out item globalMap : SwarmMap;
        }

        action monitorHealthAndEnergy {
            in item status : RobotStatus;
            out item safetyCommand : SwarmCommand;
        }

        action returnAndDock {
            in item safetyCommand : SwarmCommand;
            out item finalStatus : RobotStatus;
        }

        action generateMissionReport {
            in item globalMap : SwarmMap;
            in item finalStatus : RobotStatus;
            out item report : MissionReport;
        }

        flow initializeMission.initialCommand to assignRobots.plan;
        flow assignRobots.allocationCommand to coordinateDistributedCoverage.allocationCommand;
        flow coordinateDistributedCoverage.coverageCommand to exploreAndSurveyArea.coverageCommand;
        flow exploreAndSurveyArea.tileMap to fuseSwarmMap.tileMap;
        flow fuseSwarmMap.globalMap to generateMissionReport.globalMap;
        flow monitorHealthAndEnergy.safetyCommand to returnAndDock.safetyCommand;
        flow returnAndDock.finalStatus to generateMissionReport.finalStatus;
    }

    action def RobotAutonomousCycle {
        in item command : SwarmCommand;
        in item peerStatus : RobotStatus;
        out item status : RobotStatus;
        out item localMap : LocalObstacleMap;

        action interpretCommand;
        action selectLocalTask;
        action planCollisionFreePath;
        action moveAndSense;
        action updateLocalMap;
        action broadcastStatus;
        action evaluateBattery;
    }

    state def RobotOperationalStateMachine {
        state poweredOff;
        state booting;
        state idle;
        state assigned;
        state navigating;
        state sensing;
        state sharingMap;
        state avoidingObstacle;
        state returningToDock;
        state charging;
        state faulted;

        transition initial then poweredOff;
        transition poweredOff to booting accept PowerOn;
        transition booting to idle when bootComplete;
        transition idle to assigned accept MissionAssignment;
        transition assigned to navigating when pathAvailable;
        transition navigating to sensing when targetCellReached;
        transition sensing to sharingMap when measurementComplete;
        transition sharingMap to navigating when nextCellAssigned;
        transition navigating to avoidingObstacle when obstacleDetected;
        transition avoidingObstacle to navigating when avoidancePathClear;
        transition navigating to returningToDock when batteryLow;
        transition sensing to returningToDock when missionComplete;
        transition sharingMap to returningToDock when recallCommandReceived;
        transition returningToDock to charging when docked;
        transition charging to idle when batteryStateOfCharge >= 95;
        transition idle to faulted when criticalFaultDetected;
        transition navigating to faulted when criticalFaultDetected;
        transition sensing to faulted when criticalFaultDetected;
        transition faulted to idle when faultCleared;
    }

    state def SwarmMissionStateMachine {
        state awaitingMission;
        state validatingPlan;
        state formingSwarm;
        state executingCoverage;
        state replanning;
        state degradedOperation;
        state returningRobots;
        state reportingComplete;
        state emergencyStopped;

        transition initial then awaitingMission;
        transition awaitingMission to validatingPlan accept MissionPlanReceived;
        transition validatingPlan to formingSwarm when planValid;
        transition formingSwarm to executingCoverage when minimumRobotsReady;
        transition executingCoverage to replanning when coverageGapDetected;
        transition replanning to executingCoverage when updatedAllocationPublished;
        transition executingCoverage to degradedOperation when robotFaultCount > 0;
        transition degradedOperation to executingCoverage when coverageMaintained;
        transition executingCoverage to returningRobots when requiredCoverageAchieved;
        transition executingCoverage to returningRobots when maximumMissionTimeReached;
        transition returningRobots to reportingComplete when allAvailableRobotsDocked;
        transition validatingPlan to emergencyStopped when emergencyStopActive;
        transition formingSwarm to emergencyStopped when emergencyStopActive;
        transition executingCoverage to emergencyStopped when emergencyStopActive;
        transition degradedOperation to emergencyStopped when emergencyStopActive;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : SwarmRoboticsSystem;

        doc "The swarm robotics system shall autonomously coordinate multiple mobile robots to explore, map, and survey a defined operational area with minimal operator intervention.";

        require constraint {
            system.missionCoverage >= 95
        }
    }

    requirement def CoverageRequirement {
        subject system : SwarmRoboticsSystem;

        doc "The system shall achieve the mission plan required coverage before the maximum mission time expires.";

        require constraint {
            system.missionCoverage >= 95 and system.missionElapsedTime <= 7200
        }
    }

    requirement def ScalabilityRequirement {
        subject swarm : RobotSwarm;

        doc "The swarm shall support coordinated operation of at least ten and up to one hundred mobile robots.";

        require constraint {
            swarm.nominalRobotCount >= 10 and swarm.nominalRobotCount <= 100
        }
    }

    requirement def CommunicationRequirement {
        subject gateway : CommunicationGateway;

        doc "The communication gateway shall maintain reliable command and telemetry exchange between mission control and the robot swarm.";

        require constraint {
            gateway.packetDeliveryProbability >= 0.95 and gateway.maximumRobotLinks >= 100
        }
    }

    requirement def SafetyRequirement {
        subject monitor : SafetyMonitor;

        doc "The safety monitor shall issue recall or stop commands when robot health, energy, or operator emergency constraints are violated.";

        require constraint {
            monitor.minimumSafeBattery >= 15 and monitor.maximumAllowedFaultedRobots <= 5
        }
    }

    requirement def EnergyRequirement {
        subject robot : MobileRobot;

        doc "Each mobile robot shall monitor battery state and return to the charging dock before reaching reserve energy.";

        require constraint {
            robot.battery.lowPowerThreshold >= 20
        }
    }

    requirement def MappingQualityRequirement {
        subject system : SwarmRoboticsSystem;

        doc "The generated swarm map shall represent explored space with sufficient confidence for high-level survey decisions.";

        require constraint {
            system.missionCoverage >= 95
        }
    }

    satisfy PrimaryFunctionRequirement by swarmRoboticsSystem;
    satisfy CoverageRequirement by swarmRoboticsSystem;
    satisfy ScalabilityRequirement by swarmRoboticsSystem.swarm;
    satisfy CommunicationRequirement by swarmRoboticsSystem.gateway;
    satisfy SafetyRequirement by swarmRoboticsSystem.safetyMonitor;
    satisfy EnergyRequirement by swarmRoboticsSystem.swarm.robot;
    satisfy MappingQualityRequirement by swarmRoboticsSystem;
}