package UnmannedGroundVehicleSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	enum def NavigationMode {
		manual;
		waypoint;
		patrol;
		followPath;
	}
	
	enum def VehicleState {
		idle;
		navigating;
		avoiding;
		stopped;
		emergency;
	}
	
	attribute def GPSCoordinate {
		attribute latitude : Real;
		attribute longitude : Real;
		attribute altitude : LengthValue;
	}
	
	attribute def Waypoint {
		attribute position : GPSCoordinate;
		attribute tolerance : LengthValue;
	}
	
	item def ObstacleData {
		attribute distance : LengthValue;
		attribute bearing : Real;
		attribute size : LengthValue;
	}
	
	item def NavigationCommand {
		attribute targetWaypoint : Waypoint;
		attribute maxSpeed : SpeedValue;
		attribute mode : NavigationMode;
	}
	
	item def TelemetryPacket {
		attribute position : GPSCoordinate;
		attribute velocity : SpeedValue;
		attribute heading : Real;
		attribute batteryLevel : Real;
		attribute timestamp : TimeValue;
	}
	
	port def PowerPort {
		out voltage : Real;
		out current : Real;
	}
	
	port def SensorPort {
		out data : Real;
		out valid : Boolean;
	}
	
	port def NavigationPort {
		in command : NavigationCommand;
		out telemetry : TelemetryPacket;
	}
	
	port def DrivePort {
		in speedCommand : SpeedValue;
		in steeringAngle : Real;
	}
	
	interface def SensorToControllerInterface {
		end sensorEnd : SensorPort;
		end controllerEnd : SensorPort;
	}
	
	interface def ControllerToDriveInterface {
		end controllerEnd : DrivePort;
		end driveEnd : DrivePort;
	}
	
	part def LidarSensor {
		attribute range : LengthValue;
		attribute resolution : Real;
		attribute scanRate : Real;
		port dataPort : SensorPort;
		
		action scanEnvironment {
			out obstacles : ObstacleData[0..*];
		}
	}
	
	part def CameraSensor {
		attribute resolution : Real;
		attribute frameRate : Real;
		attribute fieldOfView : Real;
		port dataPort : SensorPort;
		
		action captureFrame {
			out imageData : String;
		}
	}
	
	part def GPSReceiver {
		attribute accuracy : LengthValue;
		attribute updateRate : Real;
		port dataPort : SensorPort;
		
		action getPosition {
			out currentPosition : GPSCoordinate;
		}
	}
	
	part def IMU {
		attribute gyroRange : Real;
		attribute accelRange : Real;
		port dataPort : SensorPort;
		
		action measureMotion {
			out roll : Real;
			out pitch : Real;
			out yaw : Real;
		}
	}
	
	part def DriveMotor {
		attribute maxTorque : Real;
		attribute maxRPM : Real;
		attribute efficiency : Real;
		port powerPort : PowerPort;
		port controlPort : DrivePort;
		
		action applyTorque {
			in targetSpeed : SpeedValue;
			out actualTorque : Real;
		}
	}
	
	part def SteeringActuator {
		attribute maxAngle : Real;
		attribute responseTime : TimeValue;
		port controlPort : DrivePort;
		
		action setAngle {
			in angle : Real;
		}
	}
	
	part def BatteryPack {
		attribute capacity : Real;
		attribute voltage : Real;
		attribute currentCharge : Real;
		port powerPort : PowerPort;
		
		action dischargePower {
			out powerOutput : Real;
		}
	}
	
	part def NavigationController {
		attribute processingPower : Real;
		attribute memorySize : Real;
		port sensorInput : SensorPort[*];
		port driveOutput : DrivePort;
		port navPort : NavigationPort;
		
		action processSensorData {
			in sensorReadings : Real[*];
			out environmentModel : String;
		}
		
		action computePath {
			in currentPos : GPSCoordinate;
			in targetWaypoint : Waypoint;
			in obstacles : ObstacleData[0..*];
			out plannedPath : Waypoint[*];
		}
		
		action generateDriveCommands {
			in path : Waypoint[*];
			out speedCmd : SpeedValue;
			out steeringCmd : Real;
		}
	}
	
	part def CommunicationModule {
		attribute frequency : Real;
		attribute bandwidth : Real;
		attribute range : LengthValue;
		port navPort : NavigationPort;
		
		action transmitTelemetry {
			in telemetry : TelemetryPacket;
		}
		
		action receiveCommand {
			out command : NavigationCommand;
		}
	}
	
	action def NavigateToWaypoint {
		in startPosition : GPSCoordinate;
		in targetWaypoint : Waypoint;
		out success : Boolean;
	}
	
	action def AvoidObstacle {
		in obstacle : ObstacleData;
		in currentPath : Waypoint[*];
		out modifiedPath : Waypoint[*];
	}
	
	action def AutonomousMission {
		in missionWaypoints : Waypoint[*];
		out missionStatus : VehicleState;
		
		first start;
		then merge waypointLoop;
		
		action checkWaypoints {
			in waypoints : Waypoint[*];
			out hasNext : Boolean;
			out nextWaypoint : Waypoint;
		}
		
		then decide;
			if checkWaypoints.hasNext then navigateSegment;
			if !checkWaypoints.hasNext then missionComplete;
		
		action navigateSegment : NavigateToWaypoint {
			in startPosition;
			in targetWaypoint = checkWaypoints.nextWaypoint;
		}
		
		then merge obstacleCheck;
		
		action detectObstacle {
			out obstaclePresent : Boolean;
			out obstacleInfo : ObstacleData;
		}
		
		then decide;
			if detectObstacle.obstaclePresent then performAvoidance;
			if !detectObstacle.obstaclePresent then continueNavigation;
		
		action performAvoidance : AvoidObstacle {
			in obstacle = detectObstacle.obstacleInfo;
		}
		
		then continueNavigation;
		action continueNavigation;
		then waypointLoop;
		
		action missionComplete {
			out :>> missionStatus = VehicleState::stopped;
		}
		
		then done;
	}
	
	state def UGVStateMachine {
		entry; then idle;
		
		state idle;
		
		transition idle_to_navigating
			first idle
			accept startMission
			then navigating;
		
		state navigating {
			do action mission : AutonomousMission;
			
			state following;
			state adjusting;
			
			transition following_to_adjusting
				first following
				accept obstacleDetected
				then adjusting;
			
			transition adjusting_to_following
				first adjusting
				accept pathClear
				then following;
		}
		
		transition navigating_to_stopped
			first navigating
			accept waypointReached
			then stopped;
		
		state stopped;
		
		transition stopped_to_idle
			first stopped
			accept reset
			then idle;
		
		transition any_to_emergency
			first idle, navigating, stopped
			accept emergencySignal
			then emergency;
		
		state emergency;
		
		transition emergency_to_idle
			first emergency
			accept clearEmergency
			then idle;
	}
	
	part def UnmannedGroundVehicle {
		attribute totalMass : MassValue;
		attribute maxSpeed : SpeedValue;
		attribute currentPosition : GPSCoordinate;
		attribute currentState : VehicleState;
		attribute batteryLevel : Real;
		
		part sensorSuite {
			part lidar : LidarSensor {
				attribute :>> range = 100.0 [m];
				attribute :>> resolution = 0.1;
				attribute :>> scanRate = 10.0;
			}
			part camera : CameraSensor {
				attribute :>> resolution = 1920.0;
				attribute :>> frameRate = 30.0;
				attribute :>> fieldOfView = 110.0;
			}
			part gps : GPSReceiver {
				attribute :>> accuracy = 1.0 [m];
				attribute :>> updateRate = 5.0;
			}
			part imu : IMU {
				attribute :>> gyroRange = 2000.0;
				attribute :>> accelRange = 16.0;
			}
		}
		
		part controller : NavigationController {
			attribute :>> processingPower = 150.0;
			attribute :>> memorySize = 64.0;
		}
		
		part driveSystem {
			part leftMotor : DriveMotor {
				attribute :>> maxTorque = 250.0;
				attribute :>> maxRPM = 3000.0;
				attribute :>> efficiency = 0.88;
			}
			part rightMotor : DriveMotor {
				attribute :>> maxTorque = 250.0;
				attribute :>> maxRPM = 3000.0;
				attribute :>> efficiency = 0.88;
			}
			part steering : SteeringActuator {
				attribute :>> maxAngle = 40.0;
				attribute :>> responseTime = 0.2 [s];
			}
		}
		
		part power {
			part battery : BatteryPack {
				attribute :>> capacity = 150.0;
				attribute :>> voltage = 48.0;
				attribute :>> currentCharge = 150.0;
			}
		}
		
		part comms : CommunicationModule {
			attribute :>> frequency = 2400.0;
			attribute :>> bandwidth = 20.0;
			attribute :>> range = 10000.0 [m];
		}
		
		interface lidarToController : SensorToControllerInterface
			connect sensorSuite.lidar.dataPort to controller.sensorInput;
		
		interface cameraToController : SensorToControllerInterface
			connect sensorSuite.camera.dataPort to controller.sensorInput;
		
		interface gpsToController : SensorToControllerInterface
			connect sensorSuite.gps.dataPort to controller.sensorInput;
		
		interface imuToController : SensorToControllerInterface
			connect sensorSuite.imu.dataPort to controller.sensorInput;
		
		interface controllerToLeftMotor : ControllerToDriveInterface
			connect controller.driveOutput to driveSystem.leftMotor.controlPort;
		
		interface controllerToRightMotor : ControllerToDriveInterface
			connect controller.driveOutput to driveSystem.rightMotor.controlPort;
		
		interface controllerToSteering : ControllerToDriveInterface
			connect controller.driveOutput to driveSystem.steering.controlPort;
		
		perform action autonomousOperation : AutonomousMission;
		
		exhibit state operationalStates : UGVStateMachine;
	}
	
	requirement def <'UGV-REQ-001'> AutonomousNavigationCapability {
		doc /* The UGV shall autonomously navigate to designated waypoints without human intervention. */
		
		subject ugv : UnmannedGroundVehicle;
		
		require constraint {
			ugv.currentState == VehicleState::navigating
		}
	}
	
	requirement def <'UGV-REQ-002'> ObstacleDetectionRange {
		doc /* The UGV shall detect obstacles at a minimum range of 50 meters. */
		
		subject ugv : UnmannedGroundVehicle;
		
		attribute minRange : LengthValue;
		
		require constraint {
			ugv.sensorSuite.lidar.range >= minRange
		}
	}
	
	requirement def <'UGV-REQ-003'> VehicleMassLimit {
		doc /* The total mass of the UGV shall not exceed 600 kg. */
		
		subject ugv : UnmannedGroundVehicle;
		
		attribute maxMass : MassValue;
		
		require constraint {
			ugv.totalMass <= maxMass
		}
	}
	
	requirement def <'UGV-REQ-004'> CommunicationRange {
		doc /* The UGV shall maintain communication with the control station at ranges up to 10 km. */
		
		subject ugv : UnmannedGroundVehicle;
		
		attribute minCommRange : LengthValue;
		
		require constraint {
			ugv.comms.range >= minCommRange
		}
	}
	
	requirement def <'UGV-REQ-005'> OperationalEndurance {
		doc /* The UGV shall operate continuously for at least 6 hours on a single battery charge. */
		
		subject ugv : UnmannedGroundVehicle;
		
		attribute minOperatingTime : TimeValue;
		attribute avgPowerConsumption : Real;
		
		require constraint {
			ugv.power.battery.capacity / avgPowerConsumption >= minOperatingTime
		}
	}
	
	requirement <'UGV-REQ-001-INST'> ugvAutonomousNav : AutonomousNavigationCapability {
		subject ugv : UnmannedGroundVehicle;
	}
	
	requirement <'UGV-REQ-002-INST'> ugvObstacleDetection : ObstacleDetectionRange {
		subject ugv : UnmannedGroundVehicle;
		attribute :>> minRange = 50.0 [m];
	}
	
	requirement <'UGV-REQ-003-INST'> ugvMassLimit : VehicleMassLimit {
		subject ugv : UnmannedGroundVehicle;
		attribute :>> maxMass = 600.0 [kg];
	}
	
	requirement <'UGV-REQ-004-INST'> ugvCommRange : CommunicationRange {
		subject ugv : UnmannedGroundVehicle;
		attribute :>> minCommRange = 10000.0 [m];
	}
	
	requirement <'UGV-REQ-005-INST'> ugvEndurance : OperationalEndurance {
		subject ugv : UnmannedGroundVehicle;
		attribute :>> minOperatingTime = 21600.0 [s];
		attribute :>> avgPowerConsumption = 25.0;
	}
	
	requirement <'UGV-SYS-REQ'> ugvSystemRequirement {
		doc /* The UGV system shall autonomously navigate to mission waypoints, detect and avoid obstacles,
		       maintain communication with the control station, and operate within specified mass and endurance limits. */
		
		subject ugv : UnmannedGroundVehicle;
		
		require ugvAutonomousNav;
		require ugvObstacleDetection;
		require ugvMassLimit;
		require ugvCommRange;
		require ugvEndurance;
	}
	
	part missionUGV : UnmannedGroundVehicle {
		attribute :>> totalMass = 550.0 [kg];
		attribute :>> maxSpeed = 15.0 [m/s];
		attribute :>> currentState = VehicleState::idle;
		attribute :>> batteryLevel = 100.0;
	}
}
