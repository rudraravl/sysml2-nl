package SwarmRoboticsSystem {
    private import ScalarValues::*;

    package Definitions {
        attribute def BatteryLevelValue :> Real;
        attribute def CoverageRatioValue :> Real;
        attribute def DistanceValue :> Real;

        attribute def PositionValue {
            attribute x : Real;
            attribute y : Real;
        }

        attribute def VelocityValue {
            attribute speed : Real;
            attribute heading : Real;
        }

        item def NeighborData {
            attribute agentId : String;
            attribute position : PositionValue;
            attribute velocity : VelocityValue;
        }

        item def ObstacleData {
            attribute position : PositionValue;
            attribute distance : DistanceValue;
        }

        item def TargetData {
            attribute position : PositionValue;
            attribute identified : Boolean;
        }

        item def StatusMessage {
            attribute agentId : String;
            attribute position : PositionValue;
            attribute batteryLevel : BatteryLevelValue;
            attribute currentState : String;
        }

        item def MissionObjective {
            attribute targetLocation : PositionValue;
            attribute surveyArea : Real;
            attribute priority : Real;
        }

        item def MissionPlan {
            attribute objectives : MissionObjective[0..*];
            attribute formationPattern : String;
            attribute coverageThreshold : Real = 0.95;
        }

        item def MovementCommand {
            attribute velocity : VelocityValue;
        }

        attribute def DeployCommand;
        attribute def DeploySignal;
        attribute def RecallSignal;
        attribute def LowBatterySignal;
        attribute def AgentLostSignal;
        attribute def MissionCompleteSignal;
        attribute def ReplanCompleteSignal;

        port def CommPort {
            out deploySignal : DeploySignal;
            out missionPlan : MissionPlan;
            out recallSignal : RecallSignal;
            in statusMessage : StatusMessage;
        }

        port def SensorPort {
            out obstacles : ObstacleData[0..*];
            out targets : TargetData[0..*];
        }

        port def MotorPort {
            in command : MovementCommand;
        }

        port def PowerPort {
            out batteryLevel : BatteryLevelValue;
        }

        part def SensorArray {
            port sensorPort : SensorPort;
            attribute detectedObstacles : ObstacleData[0..*];
            attribute detectedTargets : TargetData[0..*];
        }

        part def MotorAssembly {
            port motorPort : MotorPort;
            attribute currentCommand : MovementCommand;
        }

        part def Radio {
            port commPort : ~CommPort;
            attribute receivedNeighbors : NeighborData[0..*];
        }

        part def BatteryPack {
            port powerPort : PowerPort;
            attribute chargeLevel : BatteryLevelValue;
        }

        part def ProcessingUnit;
        part def MissionPlanner;
        part def ProgressMonitor;

        action def ComputeCohesion {
            in neighbors : NeighborData[0..*];
            in selfPosition : PositionValue;
            out vector : VelocityValue;
        }

        action def ComputeSeparation {
            in neighbors : NeighborData[0..*];
            in selfPosition : PositionValue;
            in minDistance : DistanceValue;
            out vector : VelocityValue;
        }

        action def ComputeAlignment {
            in neighbors : NeighborData[0..*];
            out vector : VelocityValue;
        }

        action def ComputeObstacleAvoidance {
            in obstacles : ObstacleData[0..*];
            in selfPosition : PositionValue;
            out vector : VelocityValue;
        }

        action def ComputeTargetSeeking {
            in targets : TargetData[0..*];
            in selfPosition : PositionValue;
            out vector : VelocityValue;
        }

        action def CombineVectors {
            in cohesionVector : VelocityValue;
            in separationVector : VelocityValue;
            in alignmentVector : VelocityValue;
            in avoidanceVector : VelocityValue;
            in targetVector : VelocityValue;
            out movement : MovementCommand;
        }

        action def ComputeMovement {
            in neighbors : NeighborData[0..*];
            in obstacles : ObstacleData[0..*];
            in targets : TargetData[0..*];
            in selfPosition : PositionValue;
            in selfVelocity : VelocityValue;
            out movement : MovementCommand;

            first start;
            then action computeCohesion : ComputeCohesion;
            then action computeSeparation : ComputeSeparation;
            then action computeAlignment : ComputeAlignment;
            then action computeObstacleAvoidance : ComputeObstacleAvoidance;
            then action computeTargetSeeking : ComputeTargetSeeking;
            then action combineVectors : CombineVectors;
            then done;
        }

        action def SenseEnvironment {
            out obstacles : ObstacleData[0..*];
            out targets : TargetData[0..*];
        }

        action def MonitorBattery {
            out level : BatteryLevelValue;
        }

        action def BroadcastStatus {
            out status : StatusMessage;
        }

        action def PlanMission {
            out plan : MissionPlan;
        }

        action def MonitorProgress {
            in statusMessages : StatusMessage[0..*];
            out coverage : CoverageRatioValue;
        }

        action def ReplanMission {
            in remainingAgents : Integer;
            out plan : MissionPlan;
        }

        state def AgentStates;
        state def StationStates;

        part def SwarmAgent {
            attribute agentId : String;
            attribute position : PositionValue;
            attribute velocity : VelocityValue;
            attribute batteryLevel : BatteryLevelValue;
            attribute lowBatteryThreshold : BatteryLevelValue = 20.0;
            attribute criticalBatteryThreshold : BatteryLevelValue = 5.0;
            attribute minSeparationDistance : DistanceValue;
            attribute neighborSensingRange : DistanceValue;

            port commPort : ~CommPort;
            port sensorPort : SensorPort;
            port motorPort : MotorPort;
            port powerPort : PowerPort;

            part sensorArray : SensorArray;
            part motorAssembly : MotorAssembly;
            part radio : Radio;
            part batteryPack : BatteryPack;
            part processingUnit : ProcessingUnit;

            bind commPort = radio.commPort;
            bind sensorPort = sensorArray.sensorPort;
            bind motorPort = motorAssembly.motorPort;
            bind powerPort = batteryPack.powerPort;

            perform action 'compute movement' : ComputeMovement;
            perform action 'sense environment' : SenseEnvironment;
            perform action 'monitor battery' : MonitorBattery;
            perform action 'broadcast status' : BroadcastStatus;

            exhibit state agentBehavior : AgentStates parallel {
                state 'mission states' {
                    entry; then idle;
                    state idle;
                    accept DeploySignal
                        then deployed;
                    state deployed {
                        entry 'sense environment';
                        do 'compute movement';
                    }
                    accept LowBatterySignal
                        then returning;
                    state returning {
                        do 'compute movement';
                    }
                    accept RecallSignal
                        then idle;
                }
                state 'battery states' {
                    entry; then batteryNormal;
                    do 'monitor battery';
                    state batteryNormal;
                    accept when batteryLevel < lowBatteryThreshold
                        do send new LowBatterySignal() to self
                        then batteryLow;
                    state batteryLow;
                    accept when batteryLevel < criticalBatteryThreshold
                        then batteryCritical;
                    state batteryCritical;
                }
            }
        }

        part def ControlStation {
            attribute missionCoverage : CoverageRatioValue;
            attribute coverageThreshold : Real = 0.95;
            attribute activeAgentCount : Integer;

            port commPort : CommPort;

            part missionPlanner : MissionPlanner;
            part progressMonitor : ProgressMonitor;

            perform action 'plan mission' : PlanMission;
            perform action 'monitor progress' : MonitorProgress;
            perform action 'replan mission' : ReplanMission;

            exhibit state stationBehavior : StationStates {
                entry; then standby;
                state standby;
                accept DeployCommand
                    do send new DeploySignal() to commPort
                    then monitoring;
                state monitoring {
                    entry 'plan mission';
                    do 'monitor progress';
                }
                accept AgentLostSignal
                    then replanning;
                state replanning {
                    entry 'replan mission';
                }
                accept ReplanCompleteSignal
                    then monitoring;
                accept when missionCoverage >= coverageThreshold
                    do send new RecallSignal() to commPort
                    then recalling;
                state recalling;
                accept MissionCompleteSignal
                    then standby;
            }
        }

        part def WirelessMeshNetwork {
            port stationIF : ~CommPort;
            port agentIF : CommPort;
        }
    }

    package Usages {
        private import Definitions::*;

        part swarmSystem {
            attribute systemId : String = "Swarm-001";

            part controlStation : ControlStation;
            part meshNetwork : WirelessMeshNetwork;
            part agents : SwarmAgent[6];

            connect controlStation.commPort to meshNetwork.stationIF;
            connect agents.commPort to meshNetwork.agentIF;

            flow deploySignalFlow of DeploySignal
                from controlStation.commPort.deploySignal to meshNetwork.stationIF.deploySignal;
            flow missionPlanFlow of MissionPlan
                from controlStation.commPort.missionPlan to meshNetwork.stationIF.missionPlan;
            flow recallSignalFlow of RecallSignal
                from controlStation.commPort.recallSignal to meshNetwork.stationIF.recallSignal;
            flow statusToStationFlow of StatusMessage
                from meshNetwork.stationIF.statusMessage to controlStation.commPort.statusMessage;

            flow agentDeployFlow of DeploySignal
                from meshNetwork.agentIF.deploySignal to agents.commPort.deploySignal;
            flow agentMissionPlanFlow of MissionPlan
                from meshNetwork.agentIF.missionPlan to agents.commPort.missionPlan;
            flow agentRecallFlow of RecallSignal
                from meshNetwork.agentIF.recallSignal to agents.commPort.recallSignal;
            flow agentStatusFlow of StatusMessage
                from agents.commPort.statusMessage to meshNetwork.agentIF.statusMessage;
        }
    }

    package Requirements {
        private import Definitions::*;

        requirement def SwarmCoordinationRequirement {
            subject agent : SwarmAgent;
            doc /* Each swarm agent shall compute its movement by balancing cohesion, separation, alignment, obstacle avoidance, and target seeking behaviors. */;
        }

        requirement def FaultToleranceRequirement {
            subject station : ControlStation;
            doc /* The control station shall dynamically re-plan the mission when agents are lost or fail, ensuring continued operation with remaining agents. */;
        }

        requirement def BatteryReturnRequirement {
            subject agent : SwarmAgent;
            doc /* Each agent shall monitor its battery level and automatically return to base when power falls below the low battery threshold of 20 percent. */;
        }

        requirement def MissionCompletionRequirement {
            subject station : ControlStation;
            doc /* The control station shall recall the entire swarm when survey coverage reaches or exceeds 95 percent. */;
        }

        requirement def MeshCommunicationRequirement {
            subject network : WirelessMeshNetwork;
            doc /* The wireless mesh network shall enable bidirectional communication between all swarm agents and the control station without centralized routing. */;
        }

        requirement def LocalRulesRequirement {
            subject agent : SwarmAgent;
            doc /* Each agent shall operate autonomously based on local rules and neighbor communication, without direct centralized control of individual movements. */;
        }

        requirement swarmCoordinationReq : SwarmCoordinationRequirement;
        requirement faultToleranceReq : FaultToleranceRequirement;
        requirement batteryReturnReq : BatteryReturnRequirement;
        requirement missionCompletionReq : MissionCompletionRequirement;
        requirement meshCommReq : MeshCommunicationRequirement;
        requirement localRulesReq : LocalRulesRequirement;
    }
}
