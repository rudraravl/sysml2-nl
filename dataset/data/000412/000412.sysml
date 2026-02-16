package TerabotSSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	item def NavigationCommand {
		attribute targetPosition : LengthValue[3];
		attribute targetVelocity : SpeedValue;
		attribute heading : Real;
	}
	
	item def SensorData {
		attribute obstacleDistance : LengthValue;
		attribute terrainType : String;
		attribute visualData : Real[*];
		attribute timestamp : TimeValue;
	}
	
	item def ManipulatorCommand {
		attribute jointAngles : Real[6];
		attribute gripperState : Real;
		attribute targetForce : ForceValue;
	}
	
	item def SystemStatus {
		attribute batteryLevel : Real;
		attribute position : LengthValue[3];
		attribute operationalState : String;
		attribute errorCode : Integer;
	}
	
	port def PowerPort {
		in attribute powerSupply : PowerValue;
		out attribute powerDemand : PowerValue;
	}
	
	port def DataPort {
		in item commandData : NavigationCommand;
		out item statusData : SystemStatus;
	}
	
	port def SensorPort {
		out item sensorOutput : SensorData;
	}
	
	port def ControlPort {
		in item controlInput : ManipulatorCommand;
		out item feedbackData : SystemStatus;
	}
	
	part def LidarSensor {
		attribute scanRate : FrequencyValue = 10.0 [Hz];
		attribute maxRange : LengthValue = 50.0 [m];
		attribute angularResolution : Real = 0.25;
		attribute mass : MassValue = 1.2 [kg];
		port sensorOut : SensorPort;
		port powerIn : PowerPort;
	}
	
	part def VisionSystem {
		attribute resolution : Real[2] = (1920.0, 1080.0);
		attribute frameRate : FrequencyValue = 30.0 [Hz];
		attribute fieldOfView : Real = 90.0;
		attribute mass : MassValue = 0.8 [kg];
		port sensorOut : SensorPort;
		port powerIn : PowerPort;
	}
	
	part def NavigationUnit {
		attribute maxSpeed : SpeedValue = 3.0 [m/s];
		attribute pathPlanningRate : FrequencyValue = 5.0 [Hz];
		attribute mass : MassValue = 2.5 [kg];
		port navigationIn : DataPort;
		port sensorIn : SensorPort;
		port powerIn : PowerPort;
	}
	
	part def ManipulatorArm {
		attribute degreesOfFreedom : Integer = 6;
		attribute maxReach : LengthValue = 1.0 [m];
		attribute maxPayload : MassValue = 8.0 [kg];
		attribute mass : MassValue = 12.0 [kg];
		port controlIn : ControlPort;
		port powerIn : PowerPort;
	}
	
	part def MobilePlatform {
		attribute wheelDiameter : LengthValue = 0.25 [m];
		attribute trackWidth : LengthValue = 0.6 [m];
		attribute maxVelocity : SpeedValue = 3.5 [m/s];
		attribute mass : MassValue = 35.0 [kg];
		port navigationIn : DataPort;
		port powerIn : PowerPort;
	}
	
	part def BatteryPack {
		attribute capacity : Real = 5000.0;
		attribute voltage : Real = 48.0;
		attribute currentCharge : Real = 100.0;
		attribute mass : MassValue = 18.0 [kg];
		port powerOut : PowerPort;
	}
	
	part def ProcessingUnit {
		attribute computePower : Real = 4.0;
		attribute memory : Real = 32.0;
		attribute mass : MassValue = 1.5 [kg];
		port mainControl : DataPort;
		port manipulatorControl : ControlPort;
		port powerIn : PowerPort;
	}
	
	part def TerabotS {
		doc /* 
		The Terabot-S is an autonomous mobile manipulation robot designed for 
		industrial inspection, material handling, and remote operation tasks.
		Its primary function is to autonomously navigate complex environments,
		perceive obstacles and objects using multi-sensor fusion, and perform
		precision manipulation tasks with its robotic arm while maintaining
		safe operation and reporting status to operators.
		*/
		
		attribute totalMass : MassValue;
		attribute operationalMode : String;
		
		part lidar : LidarSensor {
			attribute :>> scanRate = 10.0 [Hz];
			attribute :>> maxRange = 50.0 [m];
			attribute :>> mass = 1.2 [kg];
		}
		
		part visionSys : VisionSystem {
			attribute :>> resolution = (1920.0, 1080.0);
			attribute :>> frameRate = 30.0 [Hz];
			attribute :>> mass = 0.8 [kg];
		}
		
		part navUnit : NavigationUnit {
			attribute :>> maxSpeed = 3.0 [m/s];
			attribute :>> mass = 2.5 [kg];
		}
		
		part arm : ManipulatorArm {
			attribute :>> degreesOfFreedom = 6;
			attribute :>> maxReach = 1.0 [m];
			attribute :>> maxPayload = 8.0 [kg];
			attribute :>> mass = 12.0 [kg];
		}
		
		part platform : MobilePlatform {
			attribute :>> wheelDiameter = 0.25 [m];
			attribute :>> maxVelocity = 3.5 [m/s];
			attribute :>> mass = 35.0 [kg];
		}
		
		part battery : BatteryPack {
			attribute :>> capacity = 5000.0;
			attribute :>> voltage = 48.0;
			attribute :>> currentCharge = 100.0;
			attribute :>> mass = 18.0 [kg];
		}
		
		part processor : ProcessingUnit {
			attribute :>> computePower = 4.0;
			attribute :>> memory = 32.0;
			attribute :>> mass = 1.5 [kg];
		}
		
		connection lidarToPower connect lidar.powerIn to battery.powerOut;
		connection visionToPower connect visionSys.powerIn to battery.powerOut;
		connection navToPower connect navUnit.powerIn to battery.powerOut;
		connection armToPower connect arm.powerIn to battery.powerOut;
		connection platformToPower connect platform.powerIn to battery.powerOut;
		connection processorToPower connect processor.powerIn to battery.powerOut;
		
		connection lidarToNav connect lidar.sensorOut to navUnit.sensorIn;
		connection visionToNav connect visionSys.sensorOut to navUnit.sensorIn;
		connection processorToNav connect processor.mainControl to navUnit.navigationIn;
		connection navToPlatform connect navUnit.navigationIn to platform.navigationIn;
		connection processorToArm connect processor.manipulatorControl to arm.controlIn;
		
		assert constraint massCalculation {
			totalMass == lidar.mass + visionSys.mass + navUnit.mass + 
			             arm.mass + platform.mass + battery.mass + processor.mass
		}
		
		assert constraint massLimit {
			totalMass <= 100.0 [kg]
		}
	}
	
	state def TerabotOperationalBehavior {
		entry;
		then initialization;
		
		state initialization;
		then idle;
		
		state idle;
		accept at idle
			if missionReceived then autonomousOperation
			if manualCommand then teleoperation;
		
		state autonomousOperation {
			entry;
			then perceiveEnvironment;
			
			state perceiveEnvironment;
			then planNavigation;
			
			state planNavigation;
			then executeMotion;
			
			state executeMotion {
				entry;
				then parallel executionState;
				
				parallel state executionState {
					state navigating;
					state manipulating;
				}
			}
			then evaluateCompletion;
			
			state evaluateCompletion;
			accept at evaluateCompletion
				if missionComplete then idle
				if missionContinue then perceiveEnvironment
				if batteryLow then charging;
		}
		
		state teleoperation;
		accept at teleoperation
			if autonomousMode then autonomousOperation
			if stopCommand then idle;
		
		state charging;
		accept at charging
			if fullyCharged then idle;
		
		then done;
	}
	
	action def CollectSensorData {
		in lidarInput : SensorData;
		in visionInput : SensorData;
		out fusedData : SensorData;
	}
	
	action def ComputePath {
		in environmentData : SensorData;
		in targetLocation : LengthValue[3];
		out navigationPath : NavigationCommand;
	}
	
	action def MoveToTarget {
		in pathCommand : NavigationCommand;
		in currentPosition : LengthValue[3];
		out velocityCommand : SpeedValue;
	}
	
	action def PerformManipulation {
		in targetObject : LengthValue[3];
		in graspType : String;
		out manipulatorCmd : ManipulatorCommand;
	}
	
	action def AutonomousMissionExecution {
		in missionParameters : String;
		out missionResult : SystemStatus;
		
		first start;
		then merge operationLoop;
		
		then action sense : CollectSensorData {
			in lidarInput;
			in visionInput;
			out fusedData;
		}
		
		then action plan : ComputePath {
			in environmentData = sense.fusedData;
			in targetLocation;
			out navigationPath;
		}
		
		then decide;
			if obstacleDetected then avoidObstacle;
			if pathClear then executeNavigation;
		
		action executeNavigation : MoveToTarget {
			in pathCommand = plan.navigationPath;
			in currentPosition;
			out velocityCommand;
		}
		then executeTask;
		
		action avoidObstacle : ComputePath {
			in environmentData = sense.fusedData;
			in targetLocation;
			out navigationPath;
		}
		then executeNavigation;
		
		action executeTask : PerformManipulation {
			in targetObject;
			in graspType;
			out manipulatorCmd;
		}
		
		then decide;
			if taskComplete then reportCompletion;
			if taskIncomplete then operationLoop;
		
		action reportCompletion {
			out status : SystemStatus;
		}
		then done;
	}
	
	requirement def MobilityRequirement {
		doc /* The Terabot-S shall navigate autonomously in structured and unstructured environments. */
		
		subject terabot : TerabotS;
		
		require constraint speedCapability {
			terabot.platform.maxVelocity >= 2.0 [m/s]
		}
		
		require constraint navigationAccuracy {
			terabot.navUnit.pathPlanningRate >= 5.0 [Hz]
		}
	}
	
	requirement def ManipulationRequirement {
		doc /* The Terabot-S shall manipulate objects with precision and adequate payload capacity. */
		
		subject terabot : TerabotS;
		
		require constraint payloadCapacity {
			terabot.arm.maxPayload >= 5.0 [kg]
		}
		
		require constraint reachDistance {
			terabot.arm.maxReach >= 0.8 [m]
		}
	}
	
	requirement def PerceptionRequirement {
		doc /* The Terabot-S shall perceive its environment with sufficient range and resolution. */
		
		subject terabot : TerabotS;
		
		require constraint lidarRange {
			terabot.lidar.maxRange >= 30.0 [m]
		}
		
		require constraint visionQuality {
			terabot.visionSys.frameRate >= 20.0 [Hz]
		}
	}
	
	requirement def EnduranceRequirement {
		doc /* The Terabot-S shall operate for extended periods without recharging. */
		
		subject terabot : TerabotS;
		
		require constraint batteryCapacity {
			terabot.battery.capacity >= 4000.0
		}
	}
	
	requirement <'TBOT-SYS-001'> primaryFunctionRequirement {
		doc /* 
		The Terabot-S system shall autonomously navigate complex environments,
		perceive obstacles and objects using integrated sensors, and perform
		precision manipulation tasks while maintaining operational safety and
		providing real-time status reporting.
		*/
		
		subject system : TerabotS {
			attribute :>> operationalMode = "autonomous";
			attribute :>> totalMass = 71.0 [kg];
		}
		
		require mobility : MobilityRequirement;
		require manipulation : ManipulationRequirement;
		require perception : PerceptionRequirement;
		require endurance : EnduranceRequirement;
	}
}
