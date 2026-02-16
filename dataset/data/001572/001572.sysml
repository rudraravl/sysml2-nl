package 'Service Robot System' {
	private import ScalarValues::*;
	private import SI::*;
	private import ISQ::*;
	
	package ValueTypes {
		attribute def BatteryLevel :> Real;
		
		attribute def Position3D {
			attribute x : ISQ::length;
			attribute y : ISQ::length;
			attribute z : ISQ::length;
		}
		
		attribute def Velocity3D {
			attribute vx : ISQ::speed;
			attribute vy : ISQ::speed;
			attribute vz : ISQ::speed;
		}
		
		enum def RobotState {
			enum idle;
			enum navigating;
			enum executing;
			enum charging;
			enum error;
		}
		
		enum def TaskType {
			enum delivery;
			enum cleaning;
			enum inspection;
			enum assistance;
		}
		
		enum def GripperState {
			enum open;
			enum closed;
			enum gripping;
		}
	}
	
	package ItemTypes {
		private import ValueTypes::*;
		
		item def ElectricalPower;
		item def SensorData;
		item def ControlSignal;
		item def TaskCommand;
		item def StatusReport;
		
		item def Cargo {
			attribute mass : ISQ::mass;
			attribute dimensions : Real[3];
		}
	}
	
	package InterfaceDefinitions {
		private import ItemTypes::*;
		
		port def PowerPort {
			in item powerSupply : ElectricalPower;
			out attribute powerDemand : ISQ::power;
		}
		
		port def SensorPort {
			out item sensorData : SensorData;
			out attribute obstacleDistance : ISQ::length;
		}
		
		port def ActuatorPort {
			in item controlSignal : ControlSignal;
			in attribute commandValue : Real;
		}
		
		port def CommunicationPort {
			in item taskCmd : TaskCommand;
			out item statusReport : StatusReport;
		}
	}
	
	package BehaviorModel {
		private import ValueTypes::*;
		private import ItemTypes::*;
		
		action def MonitorBattery {
			in currentCharge : ISQ::energy;
			in capacity : ISQ::energy;
			out batteryLevel : BatteryLevel;
		}
		
		action def DetectObstacles {
			in sensorInput : Real;
			out obstacleDetected : Boolean;
			out obstacleDistance : ISQ::length;
		}
		
		action def Navigate {
			in currentPos : Position3D;
			in targetPos : Position3D;
			out pathCommands : Real[3];
			out positionError : ISQ::length;
		}
		
		action def GraspObject {
			in targetForce : ISQ::force;
			out gripperState : GripperState;
			out graspSuccess : Boolean;
		}
		
		action def ReleaseObject {
			out gripperState : GripperState;
		}
		
		action def PerformPrimaryTask {
			in taskType : TaskType;
			in targetLocation : Position3D;
			out taskSuccess : Boolean;
			out completionTime : ISQ::time;
			
			first start;
			
			then action initialize {
				in task = taskType;
				out initialized : Boolean;
			}
			
			then action navigate : Navigate {
				in currentPos : Position3D;
				in targetPos = targetLocation;
				out pathCommands : Real[3];
				out positionError : ISQ::length;
			}
			
			then action detectTarget {
				out targetDetected : Boolean;
			}
			
			then decide;
				if detectTarget.targetDetected then graspSequence;
				if not detectTarget.targetDetected then retryDetection;
			
			action graspSequence {
				action grasp : GraspObject {
					in targetForce = 50.0 [N];
					out gripperState : GripperState;
					out graspSuccess : Boolean;
				}
			}
			then navigateToDelivery;
			
			action retryDetection;
			then detectTarget;
			
			action navigateToDelivery : Navigate {
				in currentPos : Position3D;
				in targetPos : Position3D;
				out pathCommands : Real[3];
				out positionError : ISQ::length;
			}
			
			then action release : ReleaseObject {
				out gripperState : GripperState;
			}
			
			then action verifyCompletion {
				out success : Boolean;
			}
			
			then done;
		}
		
		state def RobotStateMachine {
			entry; then idle;
			
			state idle {
				entry assign currentState = RobotState::idle;
			}
			then navigating
				if taskReceived and batteryLevel > 20.0;
			then charging
				if batteryLevel <= 20.0;
			
			state navigating {
				entry assign currentState = RobotState::navigating;
				do action moveToTarget;
			}
			then executing
				if targetReached;
			then error
				if obstacleBlocking;
			
			state executing {
				entry assign currentState = RobotState::executing;
				do action executeTask;
			}
			then idle
				if taskCompleted;
			then error
				if taskFailed;
			
			state charging {
				entry assign currentState = RobotState::charging;
				do action chargeProcess;
			}
			then idle
				if batteryLevel >= 95.0;
			
			state error {
				entry assign currentState = RobotState::error;
			}
			then idle
				if errorCleared;
		}
	}
	
	package ComponentModel {
		private import ValueTypes::*;
		private import ItemTypes::*;
		private import InterfaceDefinitions::*;
		
		part def Battery {
			attribute capacity : ISQ::energy;
			attribute currentCharge : ISQ::energy;
			attribute voltage : ISQ::voltage;
			attribute current : ISQ::electricCurrent;
			
			port powerOutput : PowerPort;
		}
		
		part def LidarSensor {
			attribute range : ISQ::length;
			attribute scanRate : ISQ::frequency;
			attribute angularResolution : Real;
			
			port sensorOutput : SensorPort;
			port powerInput : ~PowerPort;
		}
		
		part def VisionSensor {
			attribute resolution : Real[2];
			attribute frameRate : ISQ::frequency;
			attribute fieldOfView : Real;
			
			port sensorOutput : SensorPort;
			port powerInput : ~PowerPort;
		}
		
		part def ProximitySensor {
			attribute detectionRange : ISQ::length;
			attribute sensitivity : Real;
			
			port sensorOutput : SensorPort;
			port powerInput : ~PowerPort;
		}
		
		part def DriveMotor {
			attribute maxSpeed : ISQ::angularVelocity;
			attribute maxTorque : ISQ::torque;
			attribute efficiency : Real;
			
			port motorControl : ~ActuatorPort;
			port powerInput : ~PowerPort;
		}
		
		part def SteeringActuator {
			attribute maxAngle : Real;
			attribute responseTime : ISQ::time;
			
			port actuatorControl : ~ActuatorPort;
			port powerInput : ~PowerPort;
		}
		
		part def GripperActuator {
			attribute maxGripForce : ISQ::force;
			attribute openingWidth : ISQ::length;
			attribute gripperState : GripperState;
			
			port gripperControl : ~ActuatorPort;
			port powerInput : ~PowerPort;
		}
		
		part def ArmActuator {
			attribute reach : ISQ::length;
			attribute maxPayload : ISQ::mass;
			attribute degreesOfFreedom : Integer;
			
			port armControl : ~ActuatorPort;
			port powerInput : ~PowerPort;
		}
		
		part def NavigationController {
			attribute currentPosition : Position3D;
			attribute targetPosition : Position3D;
			attribute velocity : Velocity3D;
			
			port sensorInput : ~SensorPort;
			port driveOutput : ActuatorPort;
			port steeringOutput : ActuatorPort;
			port powerInput : ~PowerPort;
			
			perform action navigate : BehaviorModel::Navigate;
		}
		
		part def TaskController {
			attribute assignedTask : TaskType;
			attribute taskProgress : Real;
			
			port armOutput : ActuatorPort;
			port gripperOutput : ActuatorPort;
			port sensorInput : ~SensorPort;
			port powerInput : ~PowerPort;
			
			perform action executeTask : BehaviorModel::PerformPrimaryTask;
		}
		
		part def MainController {
			attribute systemState : RobotState;
			attribute batteryMonitor : BatteryLevel;
			
			port commPort : CommunicationPort;
			port powerInput : ~PowerPort;
			
			perform action monitorBattery : BehaviorModel::MonitorBattery;
		}
		
		part def MobilePlatform {
			attribute wheelDiameter : ISQ::length;
			attribute wheelBase : ISQ::length;
			attribute maxSpeed : ISQ::speed;
			
			part leftDriveMotor : DriveMotor {
				attribute redefines maxSpeed = 300.0 [rad/s];
				attribute redefines maxTorque = 10.0 [N*m];
				attribute redefines efficiency = 0.85;
			}
			
			part rightDriveMotor : DriveMotor {
				attribute redefines maxSpeed = 300.0 [rad/s];
				attribute redefines maxTorque = 10.0 [N*m];
				attribute redefines efficiency = 0.85;
			}
			
			part steeringActuator : SteeringActuator {
				attribute redefines maxAngle = 45.0;
				attribute redefines responseTime = 0.2 [s];
			}
		}
		
		part def ManipulatorSystem {
			attribute armLength : ISQ::length;
			attribute workspaceVolume : Real;
			
			part armActuator : ArmActuator {
				attribute redefines reach = 0.8 [m];
				attribute redefines maxPayload = 15.0 [kg];
				attribute redefines degreesOfFreedom = 6;
			}
			
			part gripperActuator : GripperActuator {
				attribute redefines maxGripForce = 100.0 [N];
				attribute redefines openingWidth = 0.15 [m];
				attribute redefines gripperState = GripperState::open;
			}
		}
		
		part def SensorSuite {
			part lidar : LidarSensor {
				attribute redefines range = 30.0 [m];
				attribute redefines scanRate = 10.0 [Hz];
				attribute redefines angularResolution = 0.25;
			}
			
			part frontCamera : VisionSensor {
				attribute redefines resolution = (1920.0, 1080.0);
				attribute redefines frameRate = 30.0 [Hz];
				attribute redefines fieldOfView = 90.0;
			}
			
			part gripperCamera : VisionSensor {
				attribute redefines resolution = (640.0, 480.0);
				attribute redefines frameRate = 60.0 [Hz];
				attribute redefines fieldOfView = 60.0;
			}
			
			part proximitySensor : ProximitySensor {
				attribute redefines detectionRange = 2.0 [m];
				attribute redefines sensitivity = 0.95;
			}
		}
	}
	
	package LogicalModel {
		private import ValueTypes::*;
		private import BehaviorModel::*;
		
		part def ServiceRobotLogical {
			attribute batteryLevel : BatteryLevel;
			attribute currentState : RobotState;
			attribute currentPosition : Position3D;
			
			perform action performPrimaryTask : PerformPrimaryTask;
			exhibit state robotBehavior : RobotStateMachine;
		}
		
		part serviceRobotLogical : ServiceRobotLogical {
			attribute redefines batteryLevel = 100.0;
			attribute redefines currentState = RobotState::idle;
			attribute redefines currentPosition {
				attribute x = 0.0 [m];
				attribute y = 0.0 [m];
				attribute z = 0.0 [m];
			}
		}
	}
	
	package RequirementModel {
		private import ValueTypes::*;
		private import LogicalModel::*;
		private import ItemTypes::*;
		
		requirement def ServiceRobotRequirements {
			doc /* Service robot system requirements */
		}
		
		requirement batteryEndurance : ServiceRobotRequirements {
			subject robot : ServiceRobotLogical;
			doc /* Robot shall maintain minimum battery level during operation */
			require constraint {
				robot.batteryLevel > 15.0
			}
		}
		
		requirement taskCompletionReliability : ServiceRobotRequirements {
			subject robot : ServiceRobotLogical;
			doc /* Robot shall successfully complete assigned tasks */
			require constraint {
				robot.performPrimaryTask.taskSuccess == true
			}
		}
		
		requirement navigationAccuracy : ServiceRobotRequirements {
			subject robot : ServiceRobotLogical;
			doc /* Robot shall navigate to target within acceptable tolerance */
			require constraint {
				robot.performPrimaryTask.navigate.positionError < 0.1 [m]
			}
		}
		
		requirement payloadCapacity : ServiceRobotRequirements {
			subject cargo : Cargo;
			doc /* Robot shall handle cargo up to maximum capacity */
			require constraint {
				cargo.mass <= 15.0 [kg]
			}
		}
	}
	
	package PhysicalModel {
		private import LogicalModel::*;
		private import ComponentModel::*;
		private import InterfaceDefinitions::*;
		private import ItemTypes::*;
		
		part def ServiceRobotPhysical {
			attribute robotMass : ISQ::mass;
			attribute overallDimensions : Real[3];
			
			part battery : Battery {
				attribute redefines capacity = 10000.0 [W*h];
				attribute redefines currentCharge = 10000.0 [W*h];
				attribute redefines voltage = 48.0 [V];
				attribute redefines current = 0.0 [A];
			}
			
			part mainController : MainController {
				attribute redefines systemState = RobotState::idle;
				attribute redefines batteryMonitor = 100.0;
			}
			
			part navigationController : NavigationController {
				attribute redefines currentPosition {
					attribute x = 0.0 [m];
					attribute y = 0.0 [m];
					attribute z = 0.0 [m];
				}
				attribute redefines targetPosition {
					attribute x = 0.0 [m];
					attribute y = 0.0 [m];
					attribute z = 0.0 [m];
				}
			}
			
			part taskController : TaskController {
				attribute redefines assignedTask = TaskType::delivery;
				attribute redefines taskProgress = 0.0;
			}
			
			part mobilePlatform : MobilePlatform {
				attribute redefines wheelDiameter = 0.2 [m];
				attribute redefines wheelBase = 0.5 [m];
				attribute redefines maxSpeed = 2.0 [m/s];
			}
			
			part manipulator : ManipulatorSystem {
				attribute redefines armLength = 0.8 [m];
				attribute redefines workspaceVolume = 1.5;
			}
			
			part sensors : SensorSuite;
			
			connection powerToMain connect battery.powerOutput to mainController.powerInput;
			connection powerToNav connect battery.powerOutput to navigationController.powerInput;
			connection powerToTask connect battery.powerOutput to taskController.powerInput;
			connection powerToLeftMotor connect battery.powerOutput to mobilePlatform.leftDriveMotor.powerInput;
			connection powerToRightMotor connect battery.powerOutput to mobilePlatform.rightDriveMotor.powerInput;
			connection powerToSteering connect battery.powerOutput to mobilePlatform.steeringActuator.powerInput;
			connection powerToArm connect battery.powerOutput to manipulator.armActuator.powerInput;
			connection powerToGripper connect battery.powerOutput to manipulator.gripperActuator.powerInput;
			connection powerToLidar connect battery.powerOutput to sensors.lidar.powerInput;
			connection powerToFrontCam connect battery.powerOutput to sensors.frontCamera.powerInput;
			connection powerToGripperCam connect battery.powerOutput to sensors.gripperCamera.powerInput;
			connection powerToProximity connect battery.powerOutput to sensors.proximitySensor.powerInput;
			
			connection sensorToNav1 connect sensors.lidar.sensorOutput to navigationController.sensorInput;
			connection sensorToNav2 connect sensors.frontCamera.sensorOutput to navigationController.sensorInput;
			connection sensorToTask1 connect sensors.gripperCamera.sensorOutput to taskController.sensorInput;
			connection sensorToTask2 connect sensors.proximitySensor.sensorOutput to taskController.sensorInput;
			
			connection navToDrive connect navigationController.driveOutput to mobilePlatform.leftDriveMotor.motorControl;
			connection navToSteering connect navigationController.steeringOutput to mobilePlatform.steeringActuator.actuatorControl;
			connection taskToArm connect taskController.armOutput to manipulator.armActuator.armControl;
			connection taskToGripper connect taskController.gripperOutput to manipulator.gripperActuator.gripperControl;
		}
		
		part serviceRobotPhysical : ServiceRobotPhysical {
			attribute redefines robotMass = 85.0 [kg];
			attribute redefines overallDimensions = (0.6, 0.5, 1.2);
			
			perform serviceRobotLogical.performPrimaryTask;
			exhibit serviceRobotLogical.robotBehavior;
		}
		
		item missionCargo : Cargo {
			attribute redefines mass = 12.0 [kg];
			attribute redefines dimensions = (0.3, 0.3, 0.4);
		}
	}
	
	package AllocationModel {
		private import LogicalModel::*;
		private import PhysicalModel::*;
		private import RequirementModel::*;
		
		allocation def LogicalToPhysical {
			end logical : ServiceRobotLogical;
			end physical : ServiceRobotPhysical;
		}
		
		allocation robotAllocation : LogicalToPhysical
			allocate logical ::> serviceRobotLogical to physical ::> serviceRobotPhysical {
			allocate serviceRobotLogical.performPrimaryTask to serviceRobotPhysical.taskController.executeTask;
			allocate serviceRobotLogical.robotBehavior to serviceRobotPhysical.mainController;
		}
		
		satisfy batteryEndurance by serviceRobotLogical;
		satisfy taskCompletionReliability by serviceRobotLogical;
		satisfy navigationAccuracy by serviceRobotLogical;
		satisfy payloadCapacity by missionCargo;
	}
}
