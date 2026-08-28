package MicroboticsSwarmSystem {
    import ScalarValues::*;

    // ============ Value Types ============
    value def Distance :> Real { unit 'm'; }
    value def Temperature :> Real { unit 'K'; }
    value def Energy :> Real { unit 'J'; }
    value def Power :> Real { unit 'W'; }
    value def Velocity :> Real { unit 'm/s'; }
    value def Angle :> Real { unit 'rad'; }
    value def Duration :> Real { unit 's'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def DataRate :> Real { unit 'bit/s'; }
    value def Mass :> Real { unit 'kg'; }
    value def Area :> Real { unit 'm^2'; }
    value def BatteryPct :> Real { unit '%'; }

    // ============ Enumerations ============
    enum def MissionType {
        literals areaCoverageMapping, objectManipulation, exploration, hazardDetection;
    }

    enum def BotStatus {
        literals idle, active, moving, sensing, communicating, fault, lowPower, returning;
    }

    enum def CommandType {
        literals deploy, holdPosition, returnToBase, spreadOut, converge, reportStatus, halt, searchPattern;
    }

    // ============ Item Definitions ============
    item def PositionData {
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
        attribute heading : Angle;
    }

    item def SensorData {
        attribute temperatureReading : Temperature;
        attribute obstacleDetected : Boolean;
        attribute obstacleDistance : Distance;
        attribute targetDetected : Boolean;
        attribute targetId : String[0..1];
        attribute timestamp : Duration;
    }

    item def HealthData {
        attribute batteryLevel : BatteryPct;
        attribute status : BotStatus;
        attribute errorCount : Integer;
        attribute internalTemp : Temperature;
    }

    item def BotReport {
        attribute botId : String;
        attribute position : PositionData;
        attribute sensor : SensorData;
        attribute health : HealthData;
        attribute timestamp : Duration;
    }

    item def CoordinatorCommand {
        attribute commandType : CommandType;
        attribute targetArea : Area[0..1];
        attribute waypoints : PositionData[0..*];
        attribute priority : Integer;
        attribute timestamp : Duration;
    }

    item def MotionCommand {
        attribute targetPosition : PositionData;
        attribute speed : Velocity;
        attribute heading : Angle;
        attribute estimatedDuration : Duration;
    }

    item def PowerStatus {
        attribute batteryLevel : BatteryPct;
        attribute powerDraw : Power;
        attribute estimatedRemainingTime : Duration;
    }

    item def SwarmMap {
        attribute coveredArea : Area;
        attribute totalArea : Area;
        attribute coverageRatio : Real;
        attribute obstacleLocations : PositionData[0..*];
        attribute targetLocations : PositionData[0..*];
        attribute temperatureReadings : Temperature[0..*];
    }

    item def MissionStatus {
        attribute missionType : MissionType;
        attribute coverageRatio : Real;
        attribute activeBotCount : Integer;
        attribute faultBotCount : Integer;
        attribute estimatedTimeRemaining : Duration;
        attribute missionComplete : Boolean;
    }

    // ============ Port Definitions ============
    port def PowerFeedPort {
        out item status : PowerStatus;
    }

    port def SensorFeedPort {
        out item data : SensorData;
    }

    port def LocomotionInterfacePort {
        in item cmd : MotionCommand;
        out item pos : PositionData;
    }

    port def CommInternalPort {
        out item cmd : CoordinatorCommand;
        out item neighborPos : PositionData;
        in item report : BotReport;
        in item ownPos : PositionData;
    }

    port def CoordinatorLinkPort {
        out item command : CoordinatorCommand;
        in item report : BotReport;
    }

    port def NeighborLinkPort {
        out item ownPosition : PositionData;
        in item neighborPosition : PositionData;
    }

    // ============ Action Definitions ============
    action def SenseEnvironment {
        in currentPosition : PositionData;
        out data : SensorData;
    }

    action def ProcessSensorData {
        in raw : SensorData;
        out processed : SensorData;
    }

    action def MakeNavigationDecision {
        in sensorData : SensorData;
        in neighborPositions : PositionData[0..*];
        in command : CoordinatorCommand;
        in powerStatus : PowerStatus;
        out motionCmd : MotionCommand;
    }

    action def ExecuteMotion {
        in cmd : MotionCommand;
        out updatedPosition : PositionData;
    }

    action def GenerateReport {
        in position : PositionData;
        in sensorData : SensorData;
        in health : HealthData;
        in botId : String;
        out report : BotReport;
    }

    action def TransmitReport {
        in report : BotReport;
    }

    action def ReceiveCommand {
        out command : CoordinatorCommand;
    }

    action def BroadcastPosition {
        in position : PositionData;
    }

    action def ReceiveNeighborPosition {
        out neighborPos : PositionData;
    }

    action def SupplyPower {
        in demand : Power;
        out status : PowerStatus;
    }

    action def AggregateReports {
        in reports : BotReport[0..*];
        out updatedMap : SwarmMap;
        out status : MissionStatus;
    }

    action def GenerateStrategicCommand {
        in currentMap : SwarmMap;
        in currentStatus : MissionStatus;
        out command : CoordinatorCommand;
    }

    action def DistributeCommand {
        in command : CoordinatorCommand;
        out distributedCommands : CoordinatorCommand[0..100];
    }

    action def MonitorSwarmHealth {
        in reports : BotReport[0..*];
        out healthSummary : HealthData[0..100];
    }

    action def DeploySwarm {
        in targetArea : Area;
        in mission : MissionType;
    }

    action def OperationalCycle {
        in missionCommand : CoordinatorCommand;
        out botReport : BotReport;

        action sense : SenseEnvironment;
        action process : ProcessSensorData;
        action navigate : MakeNavigationDecision;
        action move : ExecuteMotion;
        action report : GenerateReport;

        succession sense -> process;
        succession process -> navigate;
        succession navigate -> move;
        succession move -> report;

        flow sense.data to process.raw;
        flow process.processed to navigate.sensorData;
        flow navigate.motionCmd to move.cmd;
        flow move.updatedPosition to report.position;
        flow process.processed to report.sensorData;
    }

    action def ExecuteMission {
        in mission : MissionType;
        in duration : Duration;

        action deploy : DeploySwarm;
        action aggregate : AggregateReports;
        action strategize : GenerateStrategicCommand;
        action distribute : DistributeCommand;

        succession deploy -> aggregate;
        succession aggregate -> strategize;
        succession strategize -> distribute;
        succession distribute -> aggregate;
    }

    // ============ Part Definitions ============

    part def PowerModule {
        attribute maxCapacity : Energy = 500;
        attribute currentLevel : Energy = 500;
        attribute nominalVoltage : Real = 3.7;
        attribute criticalThreshold : Real = 0.05;
        attribute lowPowerThreshold : Real = 0.15;

        port powerOut : PowerFeedPort;

        perform action supplyPower : SupplyPower {
            in demand : Power;
            out status : PowerStatus;
        }

        exhibit state {
            entry; then discharging;
            state charging;
            state discharging;
            state lowPower;
            state critical;
            state depleted;

            transition discharging -> lowPower
                when currentLevel < lowPowerThreshold * maxCapacity;
            transition lowPower -> critical
                when currentLevel < criticalThreshold * maxCapacity;
            transition critical -> depleted
                when currentLevel <= 0;
            transition depleted -> charging
                when currentLevel > 0;
            transition charging -> discharging
                when currentLevel >= maxCapacity;
        }
    }

    part def SensorModule {
        attribute sensingRange : Distance = 0.3;
        attribute temperatureAccuracy : Real = 0.5;
        attribute samplingRate : Frequency = 10;
        attribute obstacleDetectionRange : Distance = 0.2;
        attribute missionStarted : Boolean = false;
        attribute errorDetected : Boolean = false;
        attribute errorCleared : Boolean = false;

        port sensorOut : SensorFeedPort;

        perform action senseEnvironment : SenseEnvironment {
            in currentPosition : PositionData;
            out data : SensorData;
        }

        exhibit state {
            entry; then idle;
            state idle;
            state active;
            state fault;

            transition idle -> active when missionStarted;
            transition active -> fault when errorDetected;
            transition fault -> idle when errorCleared;
        }
    }

    part def LocomotionModule {
        attribute maxSpeed : Velocity = 0.05;
        attribute maxAcceleration : Real = 0.05;
        attribute turnRate : Real = 1.0;
        attribute currentHeading : Angle = 0;
        attribute obstacleDetected : Boolean = false;
        attribute cmdSpeed : Velocity = 0;
        attribute cmdHeading : Angle = 0;

        port locInterface : LocomotionInterfacePort;

        perform action executeMotion : ExecuteMotion {
            in cmd : MotionCommand;
            out updatedPosition : PositionData;
        }

        exhibit state {
            entry; then stationary;
            state stationary;
            state moving;
            state turning;
            state blocked;

            transition stationary -> moving when cmdSpeed > 0;
            transition moving -> stationary when cmdSpeed == 0;
            transition moving -> turning when cmdHeading != currentHeading;
            transition turning -> moving when cmdHeading == currentHeading;
            transition moving -> blocked when obstacleDetected;
            transition blocked -> stationary when true;
        }
    }

    part def CommunicationModule {
        attribute communicationRange : Distance = 3.0;
        attribute dataRate : DataRate = 250000;
        attribute channel : Integer = 14;
        attribute encryptionEnabled : Boolean = true;
        attribute connectionEstablished : Boolean = false;
        attribute dataReady : Boolean = false;
        attribute transmissionComplete : Boolean = false;
        attribute timeout : Boolean = false;
        attribute retry : Boolean = false;

        port controlSide : CommInternalPort;
        port coordinatorLink : ~CoordinatorLinkPort;
        port neighborLink : NeighborLinkPort;

        perform action transmitReport : TransmitReport {
            in report : BotReport;
        }

        perform action receiveCommand : ReceiveCommand {
            out command : CoordinatorCommand;
        }

        perform action broadcastPosition : BroadcastPosition {
            in position : PositionData;
        }

        perform action receiveNeighborPosition : ReceiveNeighborPosition {
            out neighborPos : PositionData;
        }

        exhibit state {
            entry; then listening;
            state listening;
            state transmitting;
            state synchronized;
            state lostConnection;

            transition listening -> synchronized when connectionEstablished;
            transition synchronized -> transmitting when dataReady;
            transition transmitting -> listening when transmissionComplete;
            transition synchronized -> lostConnection when timeout;
            transition lostConnection -> listening when retry;
        }
    }

    part def ControlProcessor {
        attribute clockSpeed : Frequency = 8000000;
        attribute memorySize : Integer = 32768;
        attribute algorithmVersion : String = "v2.1";
        attribute ready : Boolean = false;
        attribute missionActive : Boolean = false;
        attribute sensorDataReceived : Boolean = false;
        attribute motionCommandGenerated : Boolean = false;
        attribute positionUpdated : Boolean = false;
        attribute reportTransmitted : Boolean = false;
        attribute errorDetected : Boolean = false;
        attribute errorCleared : Boolean = false;

        port powerIn : ~PowerFeedPort;
        port sensorIn : ~SensorFeedPort;
        port locInterface : ~LocomotionInterfacePort;
        port commSide : ~CommInternalPort;

        perform action processSensorData : ProcessSensorData {
            in raw : SensorData;
            out processed : SensorData;
        }

        perform action makeNavigationDecision : MakeNavigationDecision {
            in sensorData : SensorData;
            in neighborPositions : PositionData[0..*];
            in command : CoordinatorCommand;
            in powerStatus : PowerStatus;
            out motionCmd : MotionCommand;
        }

        perform action generateReport : GenerateReport {
            in position : PositionData;
            in sensorData : SensorData;
            in health : HealthData;
            in botId : String;
            out report : BotReport;
        }

        exhibit state {
            entry; then initializing;
            state initializing;
            state idle;
            state sensing;
            state processing;
            state moving;
            state reporting;
            state fault;

            transition initializing -> idle when ready;
            transition idle -> sensing when missionActive;
            transition sensing -> processing when sensorDataReceived;
            transition processing -> moving when motionCommandGenerated;
            transition moving -> reporting when positionUpdated;
            transition reporting -> sensing when reportTransmitted;
            transition processing -> fault when errorDetected;
            transition fault -> idle when errorCleared;
        }
    }

    part def Microbot {
        attribute botId : String;
        attribute mass : Mass = 0.05;
        attribute length : Distance = 0.02;
        attribute width : Distance = 0.02;
        attribute height : Distance = 0.01;
        attribute missionStarted : Boolean = false;
        attribute batteryLevel : Real = 1.0;
        attribute atBase : Boolean = false;
        attribute missionComplete : Boolean = false;

        part powerModule : PowerModule {
            attribute maxCapacity : Energy = 500;
        }

        part sensorModule : SensorModule {
            attribute sensingRange : Distance = 0.3;
        }

        part locomotionModule : LocomotionModule {
            attribute maxSpeed : Velocity = 0.05;
        }

        part communicationModule : CommunicationModule {
            attribute communicationRange : Distance = 3.0;
        }

        part controlProcessor : ControlProcessor {
            attribute clockSpeed : Frequency = 8000000;
        }

        // Internal connections
        connection powerToProcessor connect powerModule.powerOut to controlProcessor.powerIn;
        connection sensorToProcessor connect sensorModule.sensorOut to controlProcessor.sensorIn;
        connection processorToLocomotion connect controlProcessor.locInterface to locomotionModule.locInterface;
        connection processorToComm connect controlProcessor.commSide to communicationModule.controlSide;

        // External ports
        port coordinatorLink : ~CoordinatorLinkPort;
        port neighborLink : NeighborLinkPort;

        // Delegate external ports to communication module
        connection extCoordinatorLink connect coordinatorLink to communicationModule.coordinatorLink;
        connection extNeighborLink connect neighborLink to communicationModule.neighborLink;

        perform action operationalCycle : OperationalCycle {
            in missionCommand : CoordinatorCommand;
            out botReport : BotReport;
        }

        exhibit state {
            entry; then deployed;
            state deployed;
            state operational;
            state lowPower;
            state returning;
            state shutdown;

            transition deployed -> operational when missionStarted;
            transition operational -> lowPower when batteryLevel < 0.15;
            transition lowPower -> returning when batteryLevel < 0.05;
            transition returning -> shutdown when atBase;
            transition operational -> shutdown when missionComplete;
        }
    }

    part def SwarmCoordinator {
        attribute coordinatorId : String = "SC-001";
        attribute maxBots : Integer = 100;
        attribute activeBots : Integer = 0;
        attribute missionType : MissionType = areaCoverageMapping;
        attribute missionArea : Area = 100;
        attribute coverageThreshold : Real = 0.95;
        attribute missionReceived : Boolean = false;
        attribute planReady : Boolean = false;
        attribute allBotsDeployed : Boolean = false;
        attribute conditionsChanged : Boolean = false;
        attribute commandsDistributed : Boolean = false;
        attribute criticalFailure : Boolean = false;
        attribute resetCommand : Boolean = false;

        port botLinks : CoordinatorLinkPort[100];

        attribute swarmMap : SwarmMap;
        attribute missionStatus : MissionStatus;

        perform action aggregateReports : AggregateReports {
            in reports : BotReport[0..*];
            out updatedMap : SwarmMap;
            out status : MissionStatus;
        }

        perform action generateStrategicCommand : GenerateStrategicCommand {
            in currentMap : SwarmMap;
            in currentStatus : MissionStatus;
            out command : CoordinatorCommand;
        }

        perform action distributeCommand : DistributeCommand {
            in command : CoordinatorCommand;
            out distributedCommands : CoordinatorCommand[0..100];
        }

        perform action monitorSwarmHealth : MonitorSwarmHealth {
            in reports : BotReport[0..*];
            out healthSummary : HealthData[0..100];
        }

        exhibit state {
            entry; then boot;
            state boot;
            state missionPlanning;
            state deployment;
            state monitoring;
            state adapting;
            state missionCompleteState;
            state abort;

            transition boot -> missionPlanning when missionReceived;
            transition missionPlanning -> deployment when planReady;
            transition deployment -> monitoring when allBotsDeployed;
            transition monitoring -> adapting when conditionsChanged;
            transition adapting -> monitoring when commandsDistributed;
            transition monitoring -> missionCompleteState
                when missionStatus.missionComplete == true;
            transition monitoring -> abort when criticalFailure;
            transition abort -> boot when resetCommand;
        }
    }

    part def SwarmSystem {
        attribute systemName : String = "MicroboticsSwarm-Alpha";
        attribute deploymentTime : Duration;
        attribute missionObjective : MissionType = areaCoverageMapping;
        attribute deploymentCommandReceived : Boolean = false;
        attribute allBotsOperational : Boolean = false;
        attribute environmentChanged : Boolean = false;
        attribute adaptationComplete : Boolean = false;
        attribute criticalBotFailure : Boolean = false;
        attribute allBotsReturned : Boolean = false;
        attribute missionCompleteFlag : Boolean = false;

        part coordinator : SwarmCoordinator {
            attribute maxBots : Integer = 100;
        }

        part microbots : Microbot[100];

        connection swarmNetwork connect coordinator.botLinks to microbots.coordinatorLink;

        perform action deploySwarm : DeploySwarm {
            in targetArea : Area;
            in mission : MissionType;
        }

        perform action executeMission : ExecuteMission {
            in mission : MissionType;
            in duration : Duration;
        }

        exhibit state {
            entry; then initialized;
            state initialized;
            state deployed;
            state inMission;
            state adapting;
            state completed;
            state emergencyReturn;

            transition initialized -> deployed when deploymentCommandReceived;
            transition deployed -> inMission when allBotsOperational;
            transition inMission -> adapting when environmentChanged;
            transition adapting -> inMission when adaptationComplete;
            transition inMission -> completed when missionCompleteFlag;
            transition inMission -> emergencyReturn when criticalBotFailure;
            transition emergencyReturn -> initialized when allBotsReturned;
        }

        satisfy SwarmCoordinationRequirement by coordinator;
        satisfy MicrobotAutonomyRequirement by microbots;
        satisfy PowerEnduranceRequirement by microbots.powerModule;
        satisfy CommunicationReliabilityRequirement by microbots.communicationModule;
        satisfy MissionCoverageRequirement by SwarmSystem;
        satisfy SafetyReturnRequirement by microbots;
    }

    // ============ Requirements ============
    requirement def SwarmCoordinationRequirement {
        subject coordinator : SwarmCoordinator;
        objective
            "The Swarm Coordinator shall monitor the position, status, and health "
            + "of all microbots and issue strategic commands to guide collective behavior.";
        require coordinator.maxBots >= 100;
    }

    requirement def MicrobotAutonomyRequirement {
        subject microbot : Microbot;
        objective
            "Each Microbot shall operate autonomously, processing sensor data and "
            + "making local navigation decisions while coordinating with neighbors.";
        require microbot.controlProcessor.clockSpeed >= 8000000;
        require microbot.sensorModule.sensingRange >= 0.3 [m];
        require microbot.locomotionModule.maxSpeed >= 0.05 [m/s];
    }

    requirement def PowerEnduranceRequirement {
        subject powerModule : PowerModule;
        objective
            "The Power Module shall sustain microbot operation for at least "
            + "30 minutes under nominal load.";
        require powerModule.maxCapacity >= 500 [J];
    }

    requirement def CommunicationReliabilityRequirement {
        subject commModule : CommunicationModule;
        objective
            "The Communication Module shall maintain reliable contact with the "
            + "swarm coordinator and neighboring bots within the communication range.";
        require commModule.communicationRange >= 3.0 [m];
        require commModule.dataRate >= 250000 [bit/s];
    }

    requirement def MissionCoverageRequirement {
        subject system : SwarmSystem;
        objective
            "The swarm shall achieve at least 95% area coverage for mapping "
            + "missions within the designated operational area.";
        require system.coordinator.coverageThreshold >= 0.95;
    }

    requirement def SafetyReturnRequirement {
        subject microbot : Microbot;
        objective
            "Each Microbot shall autonomously return to base when battery level "
            + "falls below the critical threshold.";
    }

    requirement def SwarmSystemRequirement {
        subject system : SwarmSystem;
        objective
            "The Microbotics Swarm System shall consist of one Swarm Coordinator "
            + "and 100 Microbots working collectively to explore, map, or manipulate "
            + "environments inaccessible to larger robots or humans.";
        require system.coordinator.maxBots == 100;
    }
}
