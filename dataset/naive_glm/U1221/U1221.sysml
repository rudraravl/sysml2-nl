package SwarmRoboticsSystem {

    import ScalarValues::*;
    import SI::*;

    // ===== Units =====
    unit m;
    unit m_per_s;
    unit deg;
    unit deg_per_s;
    unit s;
    unit Wh;
    unit pct;

    // ===== Value Types =====
    value def Distance :> Real { unit m; }
    value def Speed :> Real { unit m_per_s; }
    value def HeadingAngle :> Real { unit deg; }
    value def TurnRate :> Real { unit deg_per_s; }
    value def TimeDuration :> Real { unit s; }
    value def Energy :> Real { unit Wh; }
    value def BatteryPercent :> Real { unit pct; }
    value def SurveyCoverage :> Real { unit pct; }
    value def Weight :> Real;

    // ===== Item Definitions =====
    item def Position {
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
    }

    item def VelocityVector {
        attribute vx : Speed;
        attribute vy : Speed;
        attribute vz : Speed;
    }

    item def Pose {
        attribute position : Position;
        attribute heading : HeadingAngle;
    }

    item def ObstacleDetection {
        attribute position : Position;
        attribute radius : Distance;
        attribute detectedAt : TimeDuration;
    }

    item def TargetDetection {
        attribute targetId : String;
        attribute position : Position;
        attribute confidence : Real;
    }

    item def NeighborInfo {
        attribute agentId : String;
        attribute position : Position;
        attribute velocity : VelocityVector;
        attribute heading : HeadingAngle;
        attribute batteryLevel : BatteryPercent;
    }

    item def MissionObjective {
        attribute objectiveId : String;
        attribute targetPosition : Position;
        attribute surveyRadius : Distance;
        attribute priority : Real;
    }

    item def FormationPattern {
        attribute patternName : String;
        attribute spacing : Distance;
        attribute agentCount : Integer;
    }

    item def StatusMessage {
        attribute agentId : String;
        attribute pose : Pose;
        attribute batteryLevel : BatteryPercent;
        attribute agentState : String;
        attribute timestamp : TimeDuration;
        attribute targetsFound : TargetDetection[0..*];
    }

    item def MissionAssignment {
        attribute missionId : String;
        attribute objectives : MissionObjective[0..*];
        attribute formation : FormationPattern;
        attribute coverageThreshold : SurveyCoverage;
        attribute basePosition : Position;
    }

    item def CommandMessage {
        attribute commandType : String;
        attribute mission : MissionAssignment;
        attribute timestamp : TimeDuration;
    }

    item def SensorReading {
        attribute obstacles : ObstacleDetection[0..*];
        attribute targets : TargetDetection[0..*];
        attribute neighbors : NeighborInfo[0..*];
        attribute selfPose : Pose;
        attribute timestamp : TimeDuration;
    }

    item def MovementCommand {
        attribute velocity : VelocityVector;
        attribute heading : HeadingAngle;
    }

    // ===== Port Definitions =====
    port def RadioPort {
        in commandIn : CommandMessage;
        in neighborIn : NeighborInfo;
        out neighborOut : NeighborInfo;
        out statusOut : StatusMessage;
    }

    port def SensorOutPort {
        out reading : SensorReading;
    }

    port def SensorInPort {
        in reading : SensorReading;
    }

    port def MotorCommandPort {
        in command : MovementCommand;
    }

    port def MotorReceivePort {
        in command : MovementCommand;
    }

    port def PowerOutPort {
        out batteryLevel : BatteryPercent;
        out chargingComplete : Boolean;
    }

    port def PowerInPort {
        in batteryLevel : BatteryPercent;
        in chargingComplete : Boolean;
    }

    port def MissionOutPort {
        out assignment : MissionAssignment;
        out recall : Boolean;
    }

    port def MissionInPort {
        in assignment : MissionAssignment;
        in recall : Boolean;
    }

    port def StatusInPort {
        in status : StatusMessage;
    }

    port def StatusOutPort {
        out status : StatusMessage;
    }

    // ===== Interface Definitions =====
    interface def SensorDataLink {
        end source : SensorOutPort;
        end target : SensorInPort;
    }

    interface def MotorCommandLink {
        end source : MotorCommandPort;
        end target : MotorReceivePort;
    }

    interface def PowerLink {
        end source : PowerOutPort;
        end target : PowerInPort;
    }

    interface def RadioMeshLink {
        end nodeA : RadioPort;
        end nodeB : RadioPort;
    }

    interface def MissionAssignmentLink {
        end station : MissionOutPort;
        end agent : MissionInPort;
    }

    interface def StatusReportLink {
        end agent : StatusOutPort;
        end station : StatusInPort;
    }

    // ===== Action Definitions =====
    action def ComputeCohesion {
        in neighbors : NeighborInfo[0..*];
        in selfPose : Pose;
        out cohesionVector : VelocityVector;
    }

    action def ComputeSeparation {
        in neighbors : NeighborInfo[0..*];
        in selfPose : Pose;
        in minDistance : Distance;
        out separationVector : VelocityVector;
    }

    action def ComputeAlignment {
        in neighbors : NeighborInfo[0..*];
        out alignmentVector : VelocityVector;
    }

    action def ComputeObstacleAvoidance {
        in obstacles : ObstacleDetection[0..*];
        in selfPose : Pose;
        out avoidanceVector : VelocityVector;
    }

    action def ComputeTargetSeeking {
        in targets : TargetDetection[0..*];
        in objectives : MissionObjective[0..*];
        in selfPose : Pose;
        out seekVector : VelocityVector;
    }

    action def CombineMovementVectors {
        in cohesion : VelocityVector;
        in separation : VelocityVector;
        in alignment : VelocityVector;
        in avoidance : VelocityVector;
        in seeking : VelocityVector;
        in batteryLevel : BatteryPercent;
        attribute wCohesion : Weight = 1.0;
        attribute wSeparation : Weight = 1.5;
        attribute wAlignment : Weight = 1.0;
        attribute wAvoidance : Weight = 2.0;
        attribute wSeeking : Weight = 1.2;
        out movement : MovementCommand;
    }

    action def BehaviorLoop {
        in sensorReading : SensorReading;
        in objectives : MissionObjective[0..*];
        in minSeparation : Distance;
        in batteryLevel : BatteryPercent;
        out movement : MovementCommand;

        action computeCohesion : ComputeCohesion;
        action computeSeparation : ComputeSeparation;
        action computeAlignment : ComputeAlignment;
        action computeAvoidance : ComputeObstacleAvoidance;
        action computeSeeking : ComputeTargetSeeking;
        action combine : CombineMovementVectors;

        flow sensorReading.neighbors to computeCohesion.neighbors;
        flow sensorReading.selfPose to computeCohesion.selfPose;
        flow sensorReading.neighbors to computeSeparation.neighbors;
        flow sensorReading.selfPose to computeSeparation.selfPose;
        flow minSeparation to computeSeparation.minDistance;
        flow sensorReading.neighbors to computeAlignment.neighbors;
        flow sensorReading.obstacles to computeAvoidance.obstacles;
        flow sensorReading.selfPose to computeAvoidance.selfPose;
        flow sensorReading.targets to computeSeeking.targets;
        flow objectives to computeSeeking.objectives;
        flow sensorReading.selfPose to computeSeeking.selfPose;
        flow computeCohesion.cohesionVector to combine.cohesion;
        flow computeSeparation.separationVector to combine.separation;
        flow computeAlignment.alignmentVector to combine.alignment;
        flow computeAvoidance.avoidanceVector to combine.avoidance;
        flow computeSeeking.seekVector to combine.seeking;
        flow batteryLevel to combine.batteryLevel;
        flow combine.movement to movement;
    }

    action def CheckBattery {
        in batteryLevel : BatteryPercent;
        in lowThreshold : BatteryPercent;
        out returnToBase : Boolean;
    }

    action def BroadcastStatus {
        in pose : Pose;
        in batteryLevel : BatteryPercent;
        in agentState : String;
        out status : StatusMessage;
    }

    action def EvaluateMissionProgress {
        in statusReports : StatusMessage[0..*];
        in coverageThreshold : SurveyCoverage;
        out currentCoverage : SurveyCoverage;
        out missionComplete : Boolean;
        out activeAgentCount : Integer;
    }

    action def ReplanMission {
        in originalMission : MissionAssignment;
        in activeAgentCount : Integer;
        in expectedAgentCount : Integer;
        out revisedMission : MissionAssignment;
        out replanNeeded : Boolean;
    }

    // ===== Part Definitions: Subsystems =====
    part def SensorArray {
        port sensorOut : SensorOutPort;
        attribute detectionRange : Distance = 10 [m];
        attribute fieldOfView : HeadingAngle = 360 [deg];
        attribute updateRate : TimeDuration = 0.1 [s];

        action def sense {
            out reading : SensorReading;
        }
    }

    part def MotorActuator {
        port motorIn : MotorReceivePort;
        attribute maxSpeed : Speed = 2.0 [m_per_s];
        attribute maxTurnRate : TurnRate = 180 [deg_per_s];
        attribute wheelbase : Distance = 0.5 [m];
    }

    part def RadioTransceiver {
        port radioPort : RadioPort;
        attribute range : Distance = 100 [m];
        attribute bandwidth : Real = 1.0;
        attribute updateInterval : TimeDuration = 0.5 [s];
    }

    part def BatteryPack {
        port powerOut : PowerOutPort;
        attribute capacity : Energy = 100 [Wh];
        attribute currentLevel : BatteryPercent = 100 [pct];
        attribute lowThreshold : BatteryPercent = 20 [pct];
        attribute criticalThreshold : BatteryPercent = 10 [pct];
        attribute chargeRate : BatteryPercent = 5 [pct];
    }

    part def ProcessingUnit {
        port sensorIn : SensorInPort;
        port motorOut : MotorCommandPort;
        port radioIf : RadioPort;
        port powerIn : PowerInPort;

        attribute minSeparation : Distance = 1.5 [m];
        attribute neighborRange : Distance = 20 [m];
        attribute selfPose : Pose;
        attribute currentObjectives : MissionObjective[0..*];
        attribute batteryLevel : BatteryPercent;

        action behaviorLoop : BehaviorLoop;
        action checkBattery : CheckBattery;
        action broadcastStatus : BroadcastStatus;
    }

    // ===== State Machine: Swarm Agent =====
    state def SwarmAgentStates {
        attribute returnToBase : Boolean = false;
        attribute missionActive : Boolean = false;
        attribute batteryLow : Boolean = false;
        attribute recallReceived : Boolean = false;
        attribute atBase : Boolean = false;
        attribute batteryFull : Boolean = false;

        state idle {
            entry;
        }

        transition init_to_idle first then idle;

        transition idle_to_deployed
            first idle then deployed
            when missionActive;

        state deployed {
            entry;
        }

        transition deployed_to_surveying
            first deployed then surveying
            when currentObjectives->size() > 0;

        state surveying {
            entry;
            do behaviorLoop;
        }

        transition surveying_to_returning_lowbattery
            first surveying then returning
            when batteryLow;

        transition surveying_to_returning_recall
            first surveying then returning
            when recallReceived;

        state returning {
            entry;
        }

        transition returning_to_charging
            first returning then charging
            when atBase;

        state charging {
            entry;
        }

        transition charging_to_idle
            first charging then idle
            when batteryFull;

        state faulted {
            entry;
        }

        transition surveying_to_faulted
            first surveying then faulted
            when batteryLevel <= 5 [pct];

        transition faulted_to_charging
            first faulted then charging
            when atBase;
    }

    // ===== Swarm Agent Part Definition =====
    part def SwarmAgent {
        attribute agentId : String;
        attribute agentPose : Pose;

        part sensorArray : SensorArray;
        part motorActuator : MotorActuator;
        part radio : RadioTransceiver;
        part battery : BatteryPack;
        part processor : ProcessingUnit;

        connection sensorLink : SensorDataLink
            connect sensorArray.sensorOut to processor.sensorIn;
        connection motorLink : MotorCommandLink
            connect processor.motorOut to motorActuator.motorIn;
        connection powerLink : PowerLink
            connect battery.powerOut to processor.powerIn;

        port externalRadio : RadioPort = radio.radioPort;

        exhibit state agentBehavior : SwarmAgentStates;

        satisfaction satisfyLocalBehavior : LocalBehaviorRequirement;
        satisfaction satisfyCohesion : CohesionRequirement;
        satisfaction satisfySeparation : SeparationRequirement;
        satisfaction satisfyAlignment : AlignmentRequirement;
        satisfaction satisfyObstacleAvoidance : ObstacleAvoidanceRequirement;
        satisfaction satisfyTargetSeeking : TargetSeekingRequirement;
        satisfaction satisfyBatteryMonitoring : BatteryMonitoringRequirement;
    }

    // ===== State Machine: Control Station =====
    state def ControlStationStates {
        attribute missionReady : Boolean = false;
        attribute allAgentsDeployed : Boolean = false;
        attribute agentLost : Boolean = false;
        attribute replanComplete : Boolean = false;
        attribute missionComplete : Boolean = false;
        attribute allAgentsReturned : Boolean = false;
        attribute operatorStart : Boolean = false;
        attribute currentCoverage : SurveyCoverage = 0 [pct];
        attribute activeAgents : Integer = 0;
        attribute expectedAgents : Integer = 0;

        state standby {
            entry;
        }

        transition init_to_standby first then standby;

        transition standby_to_planning
            first standby then missionPlanning
            when operatorStart;

        state missionPlanning {
            entry;
        }

        transition planning_to_deploying
            first missionPlanning then deploying
            when missionReady;

        state deploying {
            entry;
        }

        transition deploying_to_monitoring
            first deploying then monitoring
            when allAgentsDeployed;

        state monitoring {
            entry;
            do evaluateProgress : EvaluateMissionProgress;
        }

        transition monitoring_to_replanning
            first monitoring then replanning
            when agentLost;

        state replanning {
            entry;
            do replan : ReplanMission;
        }

        transition replanning_to_monitoring
            first replanning then monitoring
            when replanComplete;

        transition monitoring_to_complete
            first monitoring then missionComplete
            when missionComplete;

        state missionComplete {
            entry;
        }

        transition complete_to_standby
            first missionComplete then standby
            when allAgentsReturned;
    }

    // ===== Control Station Part Definition =====
    part def ControlStation {
        attribute stationId : String;
        attribute stationPosition : Position;
        attribute expectedAgents : Integer = 10;
        attribute coverageThreshold : SurveyCoverage = 95 [pct];

        port missionOut : MissionOutPort;
        port statusIn : StatusInPort;
        port stationRadio : RadioPort;

        attribute currentMission : MissionAssignment;

        action evaluateProgress : EvaluateMissionProgress;
        action replan : ReplanMission;

        exhibit state stationBehavior : ControlStationStates;

        satisfaction satisfyMissionCommand : MissionCommandRequirement;
        satisfaction satisfyMonitoring : MonitoringRequirement;
        satisfaction satisfyFaultTolerance : FaultToleranceRequirement;
        satisfaction satisfyMissionCompletion : MissionCompletionRequirement;
    }

    // ===== Wireless Mesh Network =====
    part def WirelessMeshNetwork {
        attribute networkId : String;
        attribute coverageRadius : Distance = 500 [m];
        attribute maxNodes : Integer = 50;
        attribute activeNodes : Integer = 0;

        port meshPorts : RadioPort[0..*];

        action def routeMessage {
            in message : StatusMessage;
            in sourceId : String;
            out routed : StatusMessage;
        }

        action def routeCommand {
            in command : CommandMessage;
            in targetId : String;
            out routed : CommandMessage;
        }

        satisfaction satisfyCommunication : CommunicationRequirement;
    }

    // ===== Top-Level System =====
    part def SwarmSystem {
        attribute systemId : String;
        attribute systemPosition : Position;

        part controlStation : ControlStation;
        part agents : SwarmAgent[3..*];
        part meshNetwork : WirelessMeshNetwork;

        connection agentToMesh : RadioMeshLink
            connect agents.externalRadio to meshNetwork.meshPorts;

        connection stationToMesh : RadioMeshLink
            connect controlStation.stationRadio to meshNetwork.meshPorts;

        satisfaction satisfySwarmCoordination : SwarmCoordinationRequirement;
    }

    // ===== Requirements =====
    requirement def SwarmCoordinationRequirement {
        subject system : SwarmSystem;
        requirement {
            The system shall coordinate multiple Swarm Agents to achieve common mission goals without direct centralized control of individual agent movements.
        }
    }

    requirement def LocalBehaviorRequirement {
        subject agent : SwarmAgent;
        requirement {
            Each Swarm Agent shall autonomously compute its movement by balancing cohesion, separation, alignment, obstacle avoidance, and target seeking behaviors.
        }
    }

    requirement def CohesionRequirement {
        subject agent : SwarmAgent;
        requirement {
            The agent shall move toward the average position of its sensed neighbors to maintain group cohesion.
        }
    }

    requirement def SeparationRequirement {
        subject agent : SwarmAgent;
        requirement {
            The agent shall maintain a minimum separation distance of 1.5 m from its neighbors to avoid collisions.
        }
    }

    requirement def AlignmentRequirement {
        subject agent : SwarmAgent;
        requirement {
            The agent shall steer to match the average heading direction of its sensed neighbors.
        }
    }

    requirement def ObstacleAvoidanceRequirement {
        subject agent : SwarmAgent;
        requirement {
            The agent shall maneuver to avoid detected obstacles within its sensor detection range of 10 m.
        }
    }

    requirement def TargetSeekingRequirement {
        subject agent : SwarmAgent;
        requirement {
            The agent shall move toward identified mission objectives and detected targets according to their priority.
        }
    }

    requirement def BatteryMonitoringRequirement {
        subject agent : SwarmAgent;
        requirement {
            The agent shall continuously monitor its battery level and automatically return to base when the battery level falls below 20 percent.
        }
    }

    requirement def MissionCommandRequirement {
        subject station : ControlStation;
        requirement {
            The Control Station shall define mission objectives, desired formation pattern, and deploy Swarm Agents to execute the mission.
        }
    }

    requirement def MonitoringRequirement {
        subject station : ControlStation;
        requirement {
            The Control Station shall monitor overall swarm progress by receiving status messages from agents without commanding individual robot movements.
        }
    }

    requirement def FaultToleranceRequirement {
        subject station : ControlStation;
        requirement {
            The Control Station shall dynamically re-plan the mission for remaining agents when agents fail or are lost, ensuring system robustness and fault tolerance.
        }
    }

    requirement def MissionCompletionRequirement {
        subject station : ControlStation;
        requirement {
            The Control Station shall recall the entire swarm when 95 percent of the survey area has been covered.
        }
    }

    requirement def CommunicationRequirement {
        subject network : WirelessMeshNetwork;
        requirement {
            The wireless mesh network shall provide communication among all Swarm Agents and the Control Station within a coverage radius of 500 m.
        }
    }

    requirement def AutonomousReturnRequirement {
        subject agent : SwarmAgent;
        requirement {
            The agent shall autonomously navigate to the base position when its battery level is low or when a recall command is received.
        }
    }

    requirement def DeploymentRequirement {
        subject system : SwarmSystem;
        requirement {
            The system shall deploy a minimum of 3 Swarm Agents for any mission to ensure coordinated swarm behavior.
        }
    }

}
