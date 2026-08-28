package MicroboticsSwarmSystem {
	private import ScalarValues::*;
	private import SI::*;
	
	attribute def Temperature :> Real { unit 'K'; }
	attribute def Distance :> Real { unit 'm'; }
	attribute def Speed :> Real { unit 'm/s'; }
	attribute def BatteryLevel :> Real { unit '%'; }
	attribute def Heading :> Real { unit 'rad'; }
	attribute def Duration :> Real { unit 's'; }
	
	enum def HealthStatus { nominal; degraded; critical; }
	enum def MissionObjective { explore; map; manipulate; }
	
	item def Position {
		attribute x : Distance;
		attribute y : Distance;
	}
	
	item def ObstacleData {
		attribute distance : Distance;
		attribute direction : Heading;
	}
	
	item def TargetData {
		attribute targetType : String;
		attribute position : Position;
	}
	
	item def SensorReading {
		attribute temperature : Temperature;
		attribute obstacles : ObstacleData[0..*];
		attribute targets : TargetData[0..*];
	}
	
	item def MotionCommand {
		attribute targetX : Distance;
		attribute targetY : Distance;
		attribute speed : Speed;
	}
	
	item def BotStatus {
		attribute botId : String;
		attribute position : Position;
		attribute heading : Heading;
		attribute battery : BatteryLevel;
		attribute health : HealthStatus;
	}
	
	item def StrategicCommand {
		attribute commandId : String;
		attribute objective : MissionObjective;
		attribute waypoint : Position;
		attribute priority : Integer;
	}
	
	item def NeighborMessage {
		attribute sourceBotId : String;
		attribute position : Position;
		attribute heading : Heading;
	}
	
	port def PowerOutPort { out power : BatteryLevel; }
	port def PowerInPort { in power : BatteryLevel; }
	port def SensorOutPort { out reading : SensorReading; }
	port def SensorInPort { in reading : SensorReading; }
	port def MotionInPort { in command : MotionCommand; }
	port def MotionOutPort { out command : MotionCommand; }
	port def CommandInPort { in command : StrategicCommand; }
	port def CommandOutPort { out command : StrategicCommand; }
	port def StatusOutPort { out status : BotStatus; }
	port def StatusInPort { in status : BotStatus; }
	port def NeighborOutPort { out message : NeighborMessage; }
	port def NeighborInPort { in message : NeighborMessage; }
	
	part def PowerModule {
		attribute batteryLevel : BatteryLevel = 100;
		port powerOut : PowerOutPort;
		perform action supplyPower {
			first start;
			then action discharge { out level : BatteryLevel; }
			then done;
		}
	}
	
	part def SensorModule {
		port powerIn : PowerInPort;
		port sensorDataOut : SensorOutPort;
		perform action senseEnvironment {
			out reading : SensorReading;
			first start;
			then action measureTemperature;
			then action detectObstacles;
			then action identifyTargets;
			then done;
		}
	}
	
	part def LocomotionModule {
		port powerIn : PowerInPort;
		port motionIn : MotionInPort;
		perform action executeMotion {
			in cmd : MotionCommand;
			first start;
			then action computeTrajectory;
			then action move;
			then done;
		}
	}
	
	part def CommunicationModule {
		port powerIn : PowerInPort;
		port commandIn : CommandInPort;
		port commandOut : CommandOutPort;
		port statusIn : StatusInPort;
		port statusOut : StatusOutPort;
		port neighborOut : NeighborOutPort;
		port neighborIn : NeighborInPort;
		perform action transmitStatus {
			out status : BotStatus;
			first start;
			then action packageData;
			then action send;
			then done;
		}
		perform action receiveCommand {
			in cmd : StrategicCommand;
			first start;
			then action decode;
			then done;
		}
	}
	
	part def ControlProcessor {
		port powerIn : PowerInPort;
		port sensorIn : SensorInPort;
		port motionOut : MotionOutPort;
		port commandIn : CommandInPort;
		port statusOut : StatusOutPort;
		port neighborIn : NeighborInPort;
		port neighborOut : NeighborOutPort;
		
		perform action makeNavigationDecision {
			in reading : SensorReading;
			in neighborInfo : NeighborMessage;
			out cmd : MotionCommand;
			first start;
			then action assessObstacles;
			then action coordinateWithNeighbors;
			then action generateMotionCommand;
			then done;
		}
		
		state machine def ControlProcessorBehavior {
			entry action initialize;
			state Deploying;
			state Sensing;
			state Processing;
			state Moving;
			state Communicating;
			transition first initial to Deploying;
			transition Deploying to Sensing do action acceptMission;
			transition Sensing to Processing do action ingestSensorData;
			transition Processing to Moving do action planLocalMotion;
			transition Moving to Communicating do action updatePosition;
			transition Communicating to Sensing do action broadcastStatus;
		}
	}
	
	part def Microbot {
		attribute microbotId : String;
		attribute position : Position;
		attribute heading : Heading;
		attribute batteryLevel : BatteryLevel;
		attribute healthStatus : HealthStatus = HealthStatus::nominal;
		
		port commandIn : CommandInPort;
		port statusOut : StatusOutPort;
		
		part powerModule : PowerModule;
		part sensorModule : SensorModule;
		part locomotionModule : LocomotionModule;
		part communicationModule : CommunicationModule;
		part controlProcessor : ControlProcessor;
		
		bind commandIn = communicationModule.commandIn;
		bind statusOut = communicationModule.statusOut;
		
		connect powerModule.powerOut to sensorModule.powerIn;
		connect powerModule.powerOut to locomotionModule.powerIn;
		connect powerModule.powerOut to communicationModule.powerIn;
		connect powerModule.powerOut to controlProcessor.powerIn;
		
		connect sensorModule.sensorDataOut to controlProcessor.sensorIn;
		connect controlProcessor.motionOut to locomotionModule.motionIn;
		connect communicationModule.commandOut to controlProcessor.commandIn;
		connect controlProcessor.statusOut to communicationModule.statusIn;
		connect controlProcessor.neighborOut to communicationModule.neighborOut;
		connect controlProcessor.neighborIn to communicationModule.neighborIn;
	}
	
	part def SwarmCoordinator {
		attribute coordinatorId : String;
		attribute missionStatus : String;
		attribute swarmSize : Integer = 100;
		
		port commandOut : CommandOutPort;
		port statusIn : StatusInPort;
		
		perform action generateStrategicCommands {
			out commands : StrategicCommand;
			first start;
			then action analyzeObjective;
			then action partitionArea;
			then action assignWaypoints;
			then done;
		}
		
		perform action aggregateStatus {
			in status : BotStatus;
			first start;
			then action collectBotStatus;
			then action fusePositionData;
			then action updateEnvironmentMap;
			then done;
		}
		
		state machine def CoordinatorBehavior {
			entry action initializeMission;
			state Planning;
			state Distributing;
			state Monitoring;
			state Adapting;
			state MissionComplete;
			transition first initial to Planning;
			transition Planning to Distributing do action generateStrategicCommands;
			transition Distributing to Monitoring do action broadcastCommands;
			transition Monitoring to Adapting do action aggregateStatus;
			transition Adapting to Planning do action reassessObjective;
			transition Adapting to MissionComplete do action finalizeMission;
		}
	}
	
	requirement def SwarmMissionRequirement {
		doc "The swarm shall collectively explore, map, or manipulate objects in hazardous environments.";
		attribute requiredBots : Integer = 100;
		subject swarm : Microbot[*];
	}
	
	requirement def MicrobotAutonomyRequirement {
		doc "Each microbot shall operate autonomously with onboard power, sensing, locomotion, communication, and control.";
		subject bot : Microbot;
	}
	
	requirement def CommunicationReliabilityRequirement {
		doc "Each microbot shall maintain communication with the swarm coordinator and immediate neighbors.";
		subject comm : CommunicationModule;
	}
	
	requirement def PowerEnduranceRequirement {
		doc "Each microbot shall sustain operation for the minimum mission duration on a single charge.";
		subject power : PowerModule;
		attribute minBatteryLevel : BatteryLevel = 0;
	}
	
	part microboticsSystem {
		part swarmCoordinator : SwarmCoordinator;
		part microbots : Microbot[100];
		
		connect swarmCoordinator.commandOut to microbots.commandIn;
		connect microbots.statusOut to swarmCoordinator.statusIn;
		
		requirement missionReq : SwarmMissionRequirement;
		requirement autonomyReq : MicrobotAutonomyRequirement;
		requirement commReq : CommunicationReliabilityRequirement;
		requirement powerReq : PowerEnduranceRequirement;
		
		satisfy missionReq by microbots;
		satisfy autonomyReq by microbots;
		satisfy commReq by microbots.communicationModule;
		satisfy powerReq by microbots.powerModule;
	}
}
