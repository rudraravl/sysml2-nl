package 'Swarm Robotics System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RobotID;
	attribute def TaskType;
	attribute def FormationPattern;
	
	attribute def Position {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}
	
	attribute def Velocity {
		attribute vx : SpeedValue;
		attribute vy : SpeedValue;
		attribute vz : SpeedValue;
	}
	
	attribute def SwarmMessage {
		attribute senderId : RobotID;
		attribute position : Position;
		attribute velocity : Velocity;
		attribute taskStatus : TaskType;
		attribute timestamp : TimeValue;
	}
	
	attribute def SensorReading {
		attribute proximity : LengthValue[*];
		attribute obstacles : Position[*];
		attribute targets : Position[*];
	}
	
	port def CommunicationPort {
		out txMessage : SwarmMessage;
		in rxMessages : SwarmMessage[*];
	}
	
	port def SensorPort {
		out readings : SensorReading;
	}
	
	port def ActuatorPort {
		in velocityCommand : Velocity;
		in positionCommand : Position;
	}
	
	part def SwarmAgent {
		attribute agentId : RobotID;
		attribute currentPosition : Position;
		attribute currentVelocity : Velocity;
		attribute batteryLevel : Real;
		attribute assignedTask : TaskType;
		
		port commPort : CommunicationPort;
		port sensorPort : SensorPort;
		port actuatorPort : ActuatorPort;
		
		part processor : ComputeUnit;
		part sensors : SensorArray;
		part motors : ActuatorSystem;
		part radio : CommunicationModule;
		part power : BatteryPack;
		
		perform action agentBehavior : SwarmAgentBehavior;
	}
	
	part def ComputeUnit;
	part def SensorArray;
	part def ActuatorSystem;
	part def CommunicationModule;
	part def BatteryPack;
	
	part def ControlStation {
		attribute missionObjectives : Position[*];
		attribute formationConfig : FormationPattern;
		
		port controlPort : CommunicationPort;
		
		part planner : MissionPlanner;
		part monitor : SystemMonitor;
		
		perform action coordinateSwarm : SwarmCoordination;
	}
	
	part def MissionPlanner;
	part def SystemMonitor;
	
	action def SenseLocal {
		in sensorPort : SensorPort;
		out localReadings : SensorReading;
	}
	
	action def CommunicateState {
		in ownId : RobotID;
		in ownPosition : Position;
		in ownVelocity : Velocity;
		in ownTask : TaskType;
		out message : SwarmMessage;
		in neighborMessages : SwarmMessage[*];
	}
	
	action def ComputeCohesion {
		in neighborPositions : Position[*];
		in ownPosition : Position;
		out cohesionForce : Velocity;
	}
	
	action def ComputeSeparation {
		in neighborPositions : Position[*];
		in ownPosition : Position;
		in minDistance : LengthValue;
		out separationForce : Velocity;
	}
	
	action def ComputeAlignment {
		in neighborVelocities : Velocity[*];
		in ownVelocity : Velocity;
		out alignmentForce : Velocity;
	}
	
	action def ObstacleAvoidance {
		in obstacles : Position[*];
		in ownPosition : Position;
		in ownVelocity : Velocity;
		out avoidanceForce : Velocity;
	}
	
	action def TargetSeeking {
		in targets : Position[*];
		in ownPosition : Position;
		out seekingForce : Velocity;
	}
	
	action def IntegrateForces {
		in cohesion : Velocity;
		in separation : Velocity;
		in alignment : Velocity;
		in avoidance : Velocity;
		in seeking : Velocity;
		out resultantVelocity : Velocity;
	}
	
	action def ApplyControl {
		in commandVelocity : Velocity;
		out actuatorCommand : ActuatorPort;
	}
	
	action def SwarmAgentBehavior {
		in agentBatteryLevel : Real;
		
		first start;
		then merge behaviorLoop;
		
		then action sense : SenseLocal {
			in sensorPort;
			out localReadings;
		}
		
		then action communicate : CommunicateState {
			in ownId;
			in ownPosition;
			in ownVelocity;
			in ownTask;
			out message;
			in neighborMessages;
		}
		
		then action cohesion : ComputeCohesion {
			in neighborPositions;
			in ownPosition;
			out cohesionForce;
		}
		
		action separation : ComputeSeparation {
			in neighborPositions;
			in ownPosition;
			in minDistance;
			out separationForce;
		}
		
		action alignment : ComputeAlignment {
			in neighborVelocities;
			in ownVelocity;
			out alignmentForce;
		}
		
		action avoidance : ObstacleAvoidance {
			in obstacles = sense.localReadings.obstacles;
			in ownPosition;
			in ownVelocity;
			out avoidanceForce;
		}
		
		action seeking : TargetSeeking {
			in targets = sense.localReadings.targets;
			in ownPosition;
			out seekingForce;
		}
		
		then action integrate : IntegrateForces {
			in cohesion = cohesion.cohesionForce;
			in separation = separation.separationForce;
			in alignment = alignment.alignmentForce;
			in avoidance = avoidance.avoidanceForce;
			in seeking = seeking.seekingForce;
			out resultantVelocity;
		}
		
		then action control : ApplyControl {
			in commandVelocity = integrate.resultantVelocity;
			out actuatorCommand;
		}
		
		then decide;
			if agentBatteryLevel > 15.0 then behaviorLoop;
			if agentBatteryLevel <= 15.0 then returnBase;
		
		action returnBase;
		then done;
	}
	
	action def PlanMission {
		in swarmSize : Integer;
		in objectives : Position[*];
		in formation : FormationPattern;
		out taskAssignments : TaskType[*];
	}
	
	action def MonitorProgress {
		in agentReports : SwarmMessage[*];
		out coveragePercent : Real;
		out activeAgents : Integer;
	}
	
	action def SwarmCoordination {
		first start;
		
		then action initialize {
			action deployAgents;
			then action establishNetwork;
			then action assignTasks : PlanMission {
				in swarmSize;
				in objectives;
				in formation;
				out taskAssignments;
			}
		}
		
		then merge coordinationLoop;
		
		then action coordinationCycle {
			action monitor : MonitorProgress {
				in agentReports;
				out coveragePercent;
				out activeAgents;
			}
			
			then action replan : PlanMission {
				in swarmSize = monitor.activeAgents;
				in objectives;
				in formation;
				out taskAssignments;
			}
		}
		
		then decide;
			if coordinationCycle.monitor.coveragePercent < 95.0 then coordinationLoop;
			if coordinationCycle.monitor.coveragePercent >= 95.0 then finalize;
		
		action finalize {
			action recallAgents;
			then action aggregateData;
		}
		
		then done;
	}
	
	connection def WirelessMesh {
		end agents : CommunicationPort[*];
		end station : CommunicationPort;
	}
	
	part swarmRoboticsSystem : SwarmSystem {
		doc /* 
		A distributed autonomous system composed of multiple mobile robotic agents
		that coordinate through local sensing and inter-agent communication to achieve
		collective objectives such as area coverage, target search, environmental monitoring,
		and adaptive formation control without centralized command.
		*/
		
		attribute numberOfAgents : Integer = 25;
		attribute missionDuration : TimeValue;
		attribute operationalArea : AreaValue;
		
		part agents : SwarmAgent[25];
		part controlStation : ControlStation;
		
		connection network : WirelessMesh connect
			agents.commPort to controlStation.controlPort;
		
		perform action executeMission : controlStation.coordinateSwarm;
	}
	
	part def SwarmSystem {
		part agents : SwarmAgent[*];
		part controlStation : ControlStation;
	}
	
	requirement def SwarmCoordinationCapability {
		doc /* 
		The swarm system shall enable decentralized coordination among autonomous agents
		through local sensing and peer-to-peer communication to achieve emergent collective behavior.
		*/
		
		require constraint {
			swarmRoboticsSystem.numberOfAgents >= 10
		}
	}
	
	requirement def CollectiveIntelligence {
		doc /* 
		Individual agents shall exhibit simple behaviors that combine to produce
		intelligent swarm-level capabilities including flocking, formation control,
		and distributed search patterns.
		*/
	}
	
	requirement def MissionEffectiveness {
		doc /* 
		The swarm shall complete area coverage and target acquisition missions
		with fault tolerance, scalability, and adaptability to dynamic environments.
		*/
		
		require constraint {
			swarmRoboticsSystem.executeMission.coordinationCycle.monitor.coveragePercent >= 95.0
		}
	}
	
	requirement def RobustOperation {
		doc /* 
		The swarm system shall maintain operational capability despite individual
		agent failures through redundancy and dynamic task reallocation.
		*/
	}
	
	requirement swarmSystemRequirements {
		doc /* 
		Top-level requirements governing swarm robotics system design and operation
		to ensure coordinated autonomous behavior and mission success.
		*/
		
		require requirement coordinationReq : SwarmCoordinationCapability;
		require requirement intelligenceReq : CollectiveIntelligence;
		require requirement effectivenessReq : MissionEffectiveness;
		require requirement robustnessReq : RobustOperation;
	}
}
