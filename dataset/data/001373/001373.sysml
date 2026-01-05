package BostonDynamicsSpotRobotSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import ModelingMetadata::*;
	
	attribute def TerrainClassification;
	attribute def ObstacleCategory;
	attribute def MissionStatus;
	
	attribute def JointAngle :> ISQ::AngleValue;
	attribute def JointTorque :> ISQ::TorqueValue;
	attribute def JointVelocity :> ISQ::AngularVelocityValue;
	
	item def ElectricalPower {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	item def ControlCommand {
		attribute timestamp : Real;
		attribute commandType : String;
	}
	
	item def SensorData {
		attribute timestamp : Real;
		attribute dataQuality : Real;
	}
	
	item def LidarPointCloud :> SensorData {
		attribute pointCount : Integer;
		attribute scanRange : ISQ::LengthValue;
	}
	
	item def VisualImage :> SensorData {
		attribute resolution : String;
		attribute frameRate : ISQ::FrequencyValue;
	}
	
	item def InertialMeasurement :> SensorData {
		attribute acceleration : ISQ::AccelerationValue[3];
		attribute angularVelocity : ISQ::AngularVelocityValue[3];
		attribute orientation : ISQ::AngleValue[3];
	}
	
	port def PowerPort {
		in item powerSupply : ElectricalPower;
	}
	
	port def ControlPort {
		in item commands : ControlCommand;
		out item feedback : SensorData;
	}
	
	port def SensorPort {
		out item measurements : SensorData;
	}
	
	port def ActuatorPort {
		in item controlSignal : ControlCommand;
		out item jointState : SensorData;
	}
	
	part def BatteryPack {
		attribute capacity : ISQ::EnergyValue;
		attribute voltage : ISQ::VoltageValue;
		attribute currentCharge : ISQ::EnergyValue;
		attribute maxDischargeCurrent : ISQ::ElectricCurrentValue;
		
		port powerOut : PowerPort;
	}
	
	part def ActuatorUnit {
		attribute maxTorque : ISQ::TorqueValue;
		attribute maxVelocity : ISQ::AngularVelocityValue;
		attribute gearRatio : Real;
		
		port power : PowerPort;
		port control : ActuatorPort;
	}
	
	part def LegAssembly {
		attribute legIdentifier : String;
		
		part hipActuator : ActuatorUnit {
			attribute :>> maxTorque = 90.0 [N*m];
		}
		part shoulderActuator : ActuatorUnit {
			attribute :>> maxTorque = 90.0 [N*m];
		}
		part kneeActuator : ActuatorUnit {
			attribute :>> maxTorque = 60.0 [N*m];
		}
		
		port legPower : PowerPort;
		port legControl : ControlPort;
	}
	
	part def PerceptionModule {
		part frontLidar : LidarUnit {
			attribute :>> scanRange = 100.0 [m];
			attribute :>> scanRate = 20.0 [Hz];
		}
		part rearLidar : LidarUnit {
			attribute :>> scanRange = 100.0 [m];
			attribute :>> scanRate = 20.0 [Hz];
		}
		part stereoCameras : CameraUnit {
			attribute :>> resolution = "1280x720";
			attribute :>> frameRate = 30.0 [Hz];
		}
		part depthCamera : CameraUnit {
			attribute :>> resolution = "640x480";
			attribute :>> frameRate = 30.0 [Hz];
		}
		part imuSensor : ImuUnit {
			attribute :>> updateRate = 100.0 [Hz];
		}
		
		port sensorPower : PowerPort;
		port sensorOutput : SensorPort;
	}
	
	part def LidarUnit {
		attribute scanRange : ISQ::LengthValue;
		attribute scanRate : ISQ::FrequencyValue;
		attribute angularResolution : ISQ::AngleValue;
		
		port power : PowerPort;
		port dataOut : SensorPort;
	}
	
	part def CameraUnit {
		attribute resolution : String;
		attribute frameRate : ISQ::FrequencyValue;
		attribute fieldOfView : ISQ::AngleValue;
		
		port power : PowerPort;
		port imageOut : SensorPort;
	}
	
	part def ImuUnit {
		attribute updateRate : ISQ::FrequencyValue;
		attribute accelerometerRange : ISQ::AccelerationValue;
		attribute gyroscopeRange : ISQ::AngularVelocityValue;
		
		port power : PowerPort;
		port measurementOut : SensorPort;
	}
	
	part def ComputeModule {
		attribute processorCores : Integer;
		attribute memoryCapacity : Real;
		attribute computePower : ISQ::PowerValue;
		
		port computePowerPort : PowerPort;
		port sensorInput : SensorPort;
		port actuatorOutput : ControlPort;
	}
	
	action def PerceiveEnvironment {
		in lidarData : LidarPointCloud;
		in visualData : VisualImage;
		in inertialData : InertialMeasurement;
		out terrainMap : Real[*];
		out obstacleList : Real[*];
		out bodyPose : Real[6];
	}
	
	action def PlanTrajectory {
		in currentPose : Real[6];
		in targetWaypoint : ISQ::LengthValue[3];
		in terrainMap : Real[*];
		in obstacleList : Real[*];
		out plannedPath : Real[*];
		out safetyScore : Real;
	}
	
	action def GenerateGaitPattern {
		in desiredVelocity : ISQ::SpeedValue;
		in terrainType : TerrainClassification;
		in bodyOrientation : Real[3];
		out legTrajectories : Real[12];
		out footContacts : Boolean[4];
	}
	
	action def ComputeJointCommands {
		in legTrajectories : Real[12];
		in currentJointAngles : JointAngle[12];
		in currentJointVelocities : JointVelocity[12];
		out jointTorqueCommands : JointTorque[12];
	}
	
	action def ExecuteBalanceControl {
		in bodyOrientation : Real[3];
		in targetOrientation : Real[3];
		in footContacts : Boolean[4];
		out balanceCorrection : Real[12];
	}
	
	state def RobotOperationStates {
		entry;
		then powerOff;
		
		state powerOff;
		
		state initialization {
			state calibratingSensors;
			state checkingActuators;
			state loadingMaps;
			
			transition calibratingSensors_to_checkingActuators
				first calibratingSensors
				accept sensorsReady
				then checkingActuators;
				
			transition checkingActuators_to_loadingMaps
				first checkingActuators
				accept actuatorsReady
				then loadingMaps;
		}
		
		state standby;
		
		state operational {
			state autonomousNavigation {
				state mapping;
				state pathPlanning;
				state locomoting;
				
				transition mapping_to_pathPlanning
					first mapping
					accept mapUpdated
					then pathPlanning;
					
				transition pathPlanning_to_locomoting
					first pathPlanning
					accept pathComputed
					then locomoting;
					
				transition locomoting_to_mapping
					first locomoting
					accept needMapUpdate
					then mapping;
			}
			
			state obstacleAvoidance;
			
			state manualControl;
			
			transition autonomousNavigation_to_obstacleAvoidance
				first autonomousNavigation
				accept obstacleDetected
				then obstacleAvoidance;
				
			transition obstacleAvoidance_to_autonomousNavigation
				first obstacleAvoidance
				accept pathClear
				then autonomousNavigation;
				
			transition autonomousNavigation_to_manualControl
				first autonomousNavigation
				accept operatorTakeover
				then manualControl;
		}
		
		state emergency {
			state emergencyStop;
			state safeMode;
			
			transition emergencyStop_to_safeMode
				first emergencyStop
				accept stabilized
				then safeMode;
		}
		
		transition powerOff_to_initialization
			first powerOff
			accept powerButton
			then initialization;
			
		transition initialization_to_standby
			first initialization.loadingMaps
			accept initComplete
			then standby;
			
		transition standby_to_operational
			first standby
			accept startMission
			then operational.autonomousNavigation;
			
		transition operational_to_standby
			first operational
			accept missionComplete
			then standby;
			
		transition operational_to_emergency
			first operational
			accept criticalFault
			then emergency.emergencyStop;
			
		transition emergency_to_standby
			first emergency.safeMode
			accept systemRecovered
			then standby;
			
		transition standby_to_powerOff
			first standby
			accept shutdown
			then powerOff;
	}
	
	action def AutonomousMissionExecution {
		in missionWaypoints : ISQ::LengthValue[*][3] ordered;
		in maxMissionDuration : ISQ::TimeValue;
		out missionResult : MissionStatus;
		out dataCollected : SensorData[*];
		
		first start;
		then merge missionLoop;
		
		for waypoint in missionWaypoints {
			action perceive : PerceiveEnvironment {
				in lidarData;
				in visualData;
				in inertialData;
				out terrainMap;
				out obstacleList;
				out bodyPose;
			}
			
			then action plan : PlanTrajectory {
				in currentPose = perceive.bodyPose;
				in targetWaypoint = waypoint;
				in terrainMap = perceive.terrainMap;
				in obstacleList = perceive.obstacleList;
				out plannedPath;
				out safetyScore;
			}
			
			then decide;
				if plan.safetyScore > 0.7 then proceedWithMotion;
				if plan.safetyScore <= 0.7 then replan;
			
			action replan : PlanTrajectory {
				in currentPose = perceive.bodyPose;
				in targetWaypoint = waypoint;
				in terrainMap = perceive.terrainMap;
				in obstacleList = perceive.obstacleList;
				out plannedPath;
				out safetyScore;
			}
			then proceedWithMotion;
			
			merge proceedWithMotion;
			
			action generateGait : GenerateGaitPattern {
				in desiredVelocity;
				in terrainType;
				in bodyOrientation;
				out legTrajectories;
				out footContacts;
			}
			
			then action computeCommands : ComputeJointCommands {
				in legTrajectories = generateGait.legTrajectories;
				in currentJointAngles;
				in currentJointVelocities;
				out jointTorqueCommands;
			}
			
			then action balance : ExecuteBalanceControl {
				in bodyOrientation;
				in targetOrientation;
				in footContacts = generateGait.footContacts;
				out balanceCorrection;
			}
			
			then accept {
				assign dataCollected := dataCollected->including(perceive.lidarData);
			}
		}
		
		then assign missionResult := "completed";
		then done;
	}
	
	part def SpotQuadrupedRobot {
		attribute robotMass : ISQ::MassValue;
		attribute maxPayloadMass : ISQ::MassValue;
		attribute maxSpeed : ISQ::SpeedValue;
		attribute operatingTemperatureRange : ISQ::TemperatureValue[2];
		
		part battery : BatteryPack {
			attribute :>> capacity = 605.0 [W*h];
			attribute :>> voltage = 58.8 [V];
			attribute :>> currentCharge = 605.0 [W*h];
		}
		
		part frontLeftLeg : LegAssembly {
			attribute :>> legIdentifier = "FL";
		}
		part frontRightLeg : LegAssembly {
			attribute :>> legIdentifier = "FR";
		}
		part rearLeftLeg : LegAssembly {
			attribute :>> legIdentifier = "RL";
		}
		part rearRightLeg : LegAssembly {
			attribute :>> legIdentifier = "RR";
		}
		
		part perception : PerceptionModule;
		part compute : ComputeModule {
			attribute :>> processorCores = 8;
			attribute :>> memoryCapacity = 16.0;
		}
		
		connection batteryToPowerDistribution connect battery.powerOut to compute.computePowerPort;
		connection batteryToPerception connect battery.powerOut to perception.sensorPower;
		connection batteryToLegs_FL connect battery.powerOut to frontLeftLeg.legPower;
		connection batteryToLegs_FR connect battery.powerOut to frontRightLeg.legPower;
		connection batteryToLegs_RL connect battery.powerOut to rearLeftLeg.legPower;
		connection batteryToLegs_RR connect battery.powerOut to rearRightLeg.legPower;
		
		connection perceptionToCompute connect perception.sensorOutput to compute.sensorInput;
		connection computeToLegs_FL connect compute.actuatorOutput to frontLeftLeg.legControl;
		connection computeToLegs_FR connect compute.actuatorOutput to frontRightLeg.legControl;
		connection computeToLegs_RL connect compute.actuatorOutput to rearLeftLeg.legControl;
		connection computeToLegs_RR connect compute.actuatorOutput to rearRightLeg.legControl;
		
		perform action autonomousMission[*] ordered : AutonomousMissionExecution;
		
		exhibit state operationStateMachine : RobotOperationStates;
	}
	
	requirement def MobilityCapability {
		doc /* The robot shall traverse complex terrain including stairs, slopes, and obstacles 
		       while maintaining stability and balance. */
	}
	
	requirement def EnduranceCapability {
		doc /* The robot shall operate continuously for a minimum duration on a single battery charge. */
	}
	
	requirement def PayloadCapability {
		doc /* The robot shall carry sensor payloads and equipment up to a specified mass. */
	}
	
	requirement def PerceptionCapability {
		doc /* The robot shall perceive its environment with sufficient fidelity to enable 
		       autonomous navigation and obstacle avoidance. */
	}
	
	requirement def SafetyCapability {
		doc /* The robot shall detect hazardous conditions and execute emergency stop procedures 
		       to prevent damage or injury. */
	}
	
	requirement <'SPOT-REQ-001'> mobilityRequirement : MobilityCapability {
		subject spot : SpotQuadrupedRobot;
		
		@StatusInfo {
			status = StatusKind::approved;
			owner = "Locomotion Team";
			originator = "Systems Engineering";
		}
		
		require constraint { spot.maxSpeed >= 1.6 [m/s] }
	}
	
	requirement <'SPOT-REQ-002'> enduranceRequirement : EnduranceCapability {
		subject spot : SpotQuadrupedRobot;
		
		@StatusInfo {
			status = StatusKind::approved;
			owner = "Power Systems Team";
		}
		
		require constraint { spot.battery.capacity >= 600.0 [W*h] }
	}
	
	requirement <'SPOT-REQ-003'> payloadRequirement : PayloadCapability {
		subject spot : SpotQuadrupedRobot;
		
		require constraint { spot.maxPayloadMass >= 14.0 [kg] }
	}
	
	requirement <'SPOT-REQ-004'> perceptionRequirement : PerceptionCapability {
		subject spot : SpotQuadrupedRobot;
		
		@StatusInfo {
			status = StatusKind::approved;
			owner = "Perception Team";
		}
		
		require constraint { spot.perception.frontLidar.scanRange >= 100.0 [m] }
		require constraint { spot.perception.stereoCameras.frameRate >= 30.0 [Hz] }
	}
	
	requirement <'SPOT-REQ-005'> safetyRequirement : SafetyCapability {
		subject spot : SpotQuadrupedRobot;
		
		@StatusInfo {
			status = StatusKind::approved;
			owner = "Safety Team";
		}
	}
	
	requirement primaryMissionCapability {
		doc /* The Spot quadruped robot shall autonomously navigate industrial and outdoor environments, 
		       performing inspection, surveillance, and data collection missions while avoiding obstacles, 
		       maintaining balance on varied terrain, and operating safely around people and equipment. */
		       
		subject spot : SpotQuadrupedRobot;
		
		assume constraint operatingEnvironment {
			doc /* The robot operates in structured and semi-structured environments including 
			       industrial facilities, construction sites, and outdoor terrain with slopes up to 30 degrees. */
		}
		
		assume constraint communicationAvailability {
			doc /* Wireless communication infrastructure is available for mission updates and telemetry. */
		}
		
		require mobilityRequirement;
		require enduranceRequirement;
		require payloadRequirement;
		require perceptionRequirement;
		require safetyRequirement;
	}
	
	part spotRobot : SpotQuadrupedRobot {
		attribute :>> robotMass = 32.5 [kg];
		attribute :>> maxPayloadMass = 14.0 [kg];
		attribute :>> maxSpeed = 1.6 [m/s];
		
		satisfy primaryMissionCapability;
	}
}
