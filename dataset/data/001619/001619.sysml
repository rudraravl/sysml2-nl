package 'Vehicular Automation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	doc /* 
		This model describes a comprehensive vehicular automation system capable of 
		autonomous driving. The primary function is to safely navigate a vehicle from 
		origin to destination by continuously sensing the environment, planning optimal 
		trajectories, and executing precise control commands while maintaining safety 
		constraints and adapting to dynamic road conditions.
	*/
	
	attribute def VehicleSpeed :> ISQ::SpeedValue;
	attribute def Distance :> ISQ::LengthValue;
	attribute def Acceleration :> ISQ::AccelerationValue;
	attribute def SteeringAngle :> Real;
	attribute def BrakePressure :> ISQ::PressureValue;
	attribute def ThrottlePosition :> Real;
	attribute def Confidence :> Real;
	
	item def SensorData {
		attribute timestamp : ISQ::TimeValue;
		attribute radarRange : Distance;
		attribute lidarPointCount : Integer;
		attribute cameraLaneOffset : Distance;
		attribute gpsLatitude : Distance;
		attribute gpsLongitude : Distance;
		attribute currentSpeed : VehicleSpeed;
		attribute currentHeading : Real;
	}
	
	item def EnvironmentModel {
		attribute obstacleCount : Integer;
		attribute lanePosition : Distance;
		attribute roadCurvature : Real;
		attribute signalCount : Integer;
	}
	
	item def ObstacleInfo {
		attribute range : Distance;
		attribute bearing : Real;
		attribute relativeVelocity : VehicleSpeed;
		attribute classification : Integer;
	}
	
	item def TrafficSignal {
		attribute signalType : Integer;
		attribute distance : Distance;
	}
	
	item def TrajectoryPlan {
		attribute waypointCount : Integer;
		attribute targetSpeed : VehicleSpeed;
		attribute steeringAngle : SteeringAngle;
		attribute planHorizon : ISQ::TimeValue;
	}
	
	item def ControlCommands {
		attribute throttle : ThrottlePosition;
		attribute brake : BrakePressure;
		attribute steering : SteeringAngle;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def VehicleState {
		attribute positionX : Distance;
		attribute positionY : Distance;
		attribute velocity : VehicleSpeed;
		attribute acceleration : Acceleration;
		attribute heading : Real;
		attribute steeringAngle : SteeringAngle;
	}
	
	enum def ObstacleType {
		vehicle;
		pedestrian;
		cyclist;
		staticObject;
		unknown;
	}
	
	enum def SignalType {
		stopSign;
		trafficLight;
		yieldSign;
		speedLimit;
	}
	
	enum def AutonomyLevel {
		manual;
		driverAssist;
		partialAutomation;
		conditionalAutomation;
		highAutomation;
		fullAutomation;
	}
	
	enum def SystemState {
		inactive;
		standby;
		active;
		degraded;
		emergency;
	}
	
	part def SensorFusionModule {
		in radarData : Distance;
		in lidarData : Integer;
		in cameraData : Distance;
		in gpsLat : Distance;
		in gpsLon : Distance;
		in speedData : VehicleSpeed;
		out fusedSensorData : SensorData;
		out dataQuality : Confidence;
	}
	
	part def PerceptionModule {
		in sensorInput : SensorData;
		out environmentModel : EnvironmentModel;
		out detectionConfidence : Confidence;
		
		part objectDetector {
			in rawSensorData : SensorData;
			out obstacleCount : Integer;
		}
		
		part laneDetector {
			in cameraInput : Distance;
			out laneOffset : Distance;
			out laneCurvature : Real;
		}
		
		part signRecognition {
			in cameraInput : Distance;
			out signalCount : Integer;
		}
	}
	
	part def LocalizationModule {
		in gpsLat : Distance;
		in gpsLon : Distance;
		in sensorData : SensorData;
		out estimatedState : VehicleState;
		out localizationAccuracy : Confidence;
	}
	
	part def PlanningModule {
		in currentState : VehicleState;
		in environmentModel : EnvironmentModel;
		in goalX : Distance;
		in goalY : Distance;
		in speedLimit : VehicleSpeed;
		out trajectory : TrajectoryPlan;
		out planningStatus : Boolean;
		
		part routePlanner {
			in originX : Distance;
			in originY : Distance;
			in destX : Distance;
			in destY : Distance;
			out pathLength : Integer;
		}
		
		part behaviorPlanner {
			in environment : EnvironmentModel;
			in pathLength : Integer;
			out maneuverDecision : Integer;
		}
		
		part motionPlanner {
			in maneuver : Integer;
			in obstacleCount : Integer;
			out localTrajectory : TrajectoryPlan;
		}
	}
	
	part def ControlModule {
		in desiredTrajectory : TrajectoryPlan;
		in currentState : VehicleState;
		out controlOutput : ControlCommands;
		
		part longitudinalController {
			in targetSpeed : VehicleSpeed;
			in currentSpeed : VehicleSpeed;
			out throttleCmd : ThrottlePosition;
			out brakeCmd : BrakePressure;
		}
		
		part lateralController {
			in targetSteering : SteeringAngle;
			in currentHeading : Real;
			out steeringCmd : SteeringAngle;
		}
	}
	
	part def SafetyMonitor {
		in vehicleState : VehicleState;
		in environmentModel : EnvironmentModel;
		in systemHealth : Confidence;
		out safetyStatus : Boolean;
		out emergencyBrake : BrakePressure;
		out warningLevel : Integer;
	}
	
	part def ActuationInterface {
		in commands : ControlCommands;
		out throttleActuation : ThrottlePosition;
		out brakeActuation : BrakePressure;
		out steeringActuation : SteeringAngle;
	}
	
	part def HumanMachineInterface {
		in systemStatus : SystemState;
		in safetyWarnings : Integer;
		out driverOverride : Boolean;
		out missionX : Distance;
		out missionY : Distance;
		out autonomyLevelRequest : AutonomyLevel;
	}
	
	action def AcquireSensorData {
		out radarMeasurement : Distance;
		out lidarMeasurement : Integer;
		out cameraMeasurement : Distance;
		out gpsLatMeasurement : Distance;
		out gpsLonMeasurement : Distance;
		out speedMeasurement : VehicleSpeed;
	}
	
	action def FuseSensorData {
		in radarInput : Distance;
		in lidarInput : Integer;
		in cameraInput : Distance;
		in gpsLatInput : Distance;
		in gpsLonInput : Distance;
		in speedInput : VehicleSpeed;
		out fusedData : SensorData;
		out quality : Confidence;
	}
	
	action def PerceiveEnvironment {
		in sensorData : SensorData;
		out environment : EnvironmentModel;
		out confidence : Confidence;
	}
	
	action def LocalizeVehicle {
		in sensors : SensorData;
		in gpsLat : Distance;
		in gpsLon : Distance;
		out state : VehicleState;
		out accuracy : Confidence;
	}
	
	action def PlanTrajectory {
		in state : VehicleState;
		in environment : EnvironmentModel;
		in goalX : Distance;
		in goalY : Distance;
		in speedLimit : VehicleSpeed;
		out plan : TrajectoryPlan;
		out success : Boolean;
	}
	
	action def ComputeControl {
		in trajectory : TrajectoryPlan;
		in state : VehicleState;
		out commands : ControlCommands;
	}
	
	action def MonitorSafety {
		in state : VehicleState;
		in environment : EnvironmentModel;
		in health : Confidence;
		out safe : Boolean;
		out emergencyCmd : BrakePressure;
		out warning : Integer;
	}
	
	action def ExecuteActuation {
		in controlCommands : ControlCommands;
		out throttle : ThrottlePosition;
		out brake : BrakePressure;
		out steering : SteeringAngle;
	}
	
	action def AutonomousDrive {
		in destinationX : Distance;
		in destinationY : Distance;
		in maxSpeed : VehicleSpeed;
		in safetyMargin : Distance;
		out finalState : VehicleState;
		out missionComplete : Boolean;
		
		first start;
		then merge drivingLoop;
		
		then action sense : AcquireSensorData {
			out radarMeasurement : Distance;
			out lidarMeasurement : Integer;
			out cameraMeasurement : Distance;
			out gpsLatMeasurement : Distance;
			out gpsLonMeasurement : Distance;
			out speedMeasurement : VehicleSpeed;
		}
		
		then action fuse : FuseSensorData {
			in radarInput = sense.radarMeasurement;
			in lidarInput = sense.lidarMeasurement;
			in cameraInput = sense.cameraMeasurement;
			in gpsLatInput = sense.gpsLatMeasurement;
			in gpsLonInput = sense.gpsLonMeasurement;
			in speedInput = sense.speedMeasurement;
			out fusedData : SensorData;
			out quality : Confidence;
		}
		
		then action perceive : PerceiveEnvironment {
			in sensorData = fuse.fusedData;
			out environment : EnvironmentModel;
			out confidence : Confidence;
		}
		
		then action localize : LocalizeVehicle {
			in sensors = fuse.fusedData;
			in gpsLat = sense.gpsLatMeasurement;
			in gpsLon = sense.gpsLonMeasurement;
			out state : VehicleState;
			out accuracy : Confidence;
		}
		
		then action monitor : MonitorSafety {
			in state = localize.state;
			in environment = perceive.environment;
			in health = fuse.quality;
			out safe : Boolean;
			out emergencyCmd : BrakePressure;
			out warning : Integer;
		}
		
		then decide;
			if monitor.safe then normalOperation;
			else emergencyStop;
		
		action emergencyStop {
			action applyEmergencyBrake : ExecuteActuation {
				in controlCommands : ControlCommands;
				out throttle : ThrottlePosition;
				out brake : BrakePressure;
				out steering : SteeringAngle;
			}
		}
		then done;
		
		action normalOperation {
			action plan : PlanTrajectory {
				in state = localize.state;
				in environment = perceive.environment;
				in goalX = destinationX;
				in goalY = destinationY;
				in speedLimit = maxSpeed;
				out plan : TrajectoryPlan;
				out success : Boolean;
			}
			
			then action control : ComputeControl {
				in trajectory = plan.plan;
				in state = localize.state;
				out commands : ControlCommands;
			}
			
			then action actuate : ExecuteActuation {
				in controlCommands = control.commands;
				out throttle : ThrottlePosition;
				out brake : BrakePressure;
				out steering : SteeringAngle;
			}
		}
		then drivingLoop;
	}
	
	state machine def AutonomousSystemStateMachine {
		initial state Inactive;
		
		state Standby;
		
		state Active {
			state Cruising;
			state Following;
			state LaneChanging;
			state Stopping;
			
			transition from Cruising to Following;
			transition from Cruising to LaneChanging;
			transition from Following to Cruising;
			transition from LaneChanging to Cruising;
			transition from Cruising to Stopping;
		}
		
		state Degraded;
		state Emergency;
		
		transition from Inactive to Standby;
		transition from Standby to Active;
		transition from Active to Standby;
		transition from Active to Degraded;
		transition from Active to Emergency;
		transition from Degraded to Active;
		transition from Degraded to Emergency;
		transition from Emergency to Standby;
		transition from Standby to Inactive;
	}
	
	part autonomousVehicleSystem {
		attribute currentAutonomyLevel : AutonomyLevel = AutonomyLevel::highAutomation;
		attribute maxOperatingSpeed : VehicleSpeed;
		attribute minSafeDistance : Distance;
		attribute targetDestinationX : Distance;
		attribute targetDestinationY : Distance;
		
		part sensorFusion : SensorFusionModule {
			in radarData : Distance;
			in lidarData : Integer;
			in cameraData : Distance;
			in gpsLat : Distance;
			in gpsLon : Distance;
			in speedData : VehicleSpeed;
			out fusedSensorData : SensorData;
			out dataQuality : Confidence;
		}
		
		part perception : PerceptionModule {
			in sensorInput : SensorData;
			out environmentModel : EnvironmentModel;
			out detectionConfidence : Confidence;
		}
		
		part localization : LocalizationModule {
			in gpsLat : Distance;
			in gpsLon : Distance;
			in sensorData : SensorData;
			out estimatedState : VehicleState;
			out localizationAccuracy : Confidence;
		}
		
		part planning : PlanningModule {
			in currentState : VehicleState;
			in environmentModel : EnvironmentModel;
			in goalX : Distance;
			in goalY : Distance;
			in speedLimit : VehicleSpeed;
			out trajectory : TrajectoryPlan;
			out planningStatus : Boolean;
		}
		
		part control : ControlModule {
			in desiredTrajectory : TrajectoryPlan;
			in currentState : VehicleState;
			out controlOutput : ControlCommands;
		}
		
		part safety : SafetyMonitor {
			in vehicleState : VehicleState;
			in environmentModel : EnvironmentModel;
			in systemHealth : Confidence;
			out safetyStatus : Boolean;
			out emergencyBrake : BrakePressure;
			out warningLevel : Integer;
		}
		
		part actuation : ActuationInterface {
			in commands : ControlCommands;
			out throttleActuation : ThrottlePosition;
			out brakeActuation : BrakePressure;
			out steeringActuation : SteeringAngle;
		}
		
		part hmi : HumanMachineInterface {
			in systemStatus : SystemState;
			in safetyWarnings : Integer;
			out driverOverride : Boolean;
			out missionX : Distance;
			out missionY : Distance;
			out autonomyLevelRequest : AutonomyLevel;
		}
		
		connection fusionToPerception connect sensorFusion.fusedSensorData to perception.sensorInput;
		connection fusionToLocalization connect sensorFusion.fusedSensorData to localization.sensorData;
		connection perceptionToPlanning connect perception.environmentModel to planning.environmentModel;
		connection localizationToPlanning connect localization.estimatedState to planning.currentState;
		connection planningToControl connect planning.trajectory to control.desiredTrajectory;
		connection localizationToControl connect localization.estimatedState to control.currentState;
		connection controlToActuation connect control.controlOutput to actuation.commands;
		connection localizationToSafety connect localization.estimatedState to safety.vehicleState;
		connection perceptionToSafety connect perception.environmentModel to safety.environmentModel;
		connection fusionToSafety connect sensorFusion.dataQuality to safety.systemHealth;
		connection safetyToHMI connect safety.warningLevel to hmi.safetyWarnings;
		
		exhibit state systemBehavior : AutonomousSystemStateMachine;
		
		perform action autonomousDriving[*] ordered references AutonomousDrive {
			in destinationX = targetDestinationX;
			in destinationY = targetDestinationY;
			in maxSpeed = maxOperatingSpeed;
			in safetyMargin = minSafeDistance;
		}
	}
	
	requirement <'AV-REQ-001'> primaryFunctionRequirement {
		doc /* 
			The autonomous vehicle system shall navigate from origin to destination 
			without human intervention while ensuring passenger safety and comfort.
		*/
		
		subject vehicle : autonomousVehicleSystem;
		
		require constraint autonomousNavigation {
			vehicle.planning.planningStatus == true
		}
	}
	
	requirement <'AV-REQ-002'> safetyRequirement {
		doc /* 
			The system shall maintain safe distances from obstacles and execute 
			emergency braking when collision risk exceeds acceptable threshold.
		*/
		
		subject vehicle : autonomousVehicleSystem;
		
		require constraint collisionAvoidance {
			vehicle.safety.safetyStatus == true
		}
	}
	
	requirement <'AV-REQ-003'> perceptionRequirement {
		doc /* 
			The perception system shall detect and classify obstacles, lane boundaries, 
			and traffic signals with minimum 95% confidence under normal conditions.
		*/
		
		subject perceptionSys : PerceptionModule;
		
		require constraint detectionConfidence {
			perceptionSys.detectionConfidence >= 0.95
		}
	}
	
	requirement <'AV-REQ-004'> localizationRequirement {
		doc /* 
			The localization system shall estimate vehicle position with accuracy 
			better than 0.5 meters in all operating conditions.
		*/
		
		subject localizationSys : LocalizationModule;
		
		require constraint positionAccuracy {
			localizationSys.localizationAccuracy >= 0.95
		}
	}
	
	requirement <'AV-REQ-005'> controlRequirement {
		doc /* 
			The control system shall execute trajectory commands with maximum 
			lateral deviation of 0.3 meters and speed error less than 2 m/s.
		*/
		
		subject controlSys : ControlModule;
	}
	
	requirement <'AV-REQ-006'> systemIntegrationRequirement {
		doc /* 
			All subsystems shall operate in coordinated fashion with end-to-end 
			latency not exceeding 100 milliseconds from sensing to actuation.
		*/
		
		subject vehicle : autonomousVehicleSystem;
		
		satisfy primaryFunctionRequirement by vehicle.autonomousDriving;
		satisfy safetyRequirement by vehicle.safety;
		satisfy perceptionRequirement by vehicle.perception;
		satisfy localizationRequirement by vehicle.localization;
		satisfy controlRequirement by vehicle.control;
	}
}
