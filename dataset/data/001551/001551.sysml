package 'Robotic System Design' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	package ValueTypes {
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
		
		enum def TaskStatus {
			enum idle;
			enum navigating;
			enum executing;
			enum completed;
			enum failed;
		}
		
		enum def LocomotionMode {
			enum stopped;
			enum moving;
			enum turning;
		}
		
		item def MotionCommand {
			attribute targetPosition : Position;
			attribute targetVelocity : Velocity;
		}
		
		item def SensorData {
			attribute currentPosition : Position;
			attribute obstacleDistance : LengthValue;
		}
	}
	
	package RequirementModel {
		requirement def LocomotionRequirement {
			subject robot : LogicalModel::RobotSystem;
			require constraint {
				robot.locomotionController.speed > 0.0 [m/s]
			}
		}
		
		requirement def TaskCompletionRequirement {
			subject robot : LogicalModel::RobotSystem;
			require constraint {
				robot.taskCompleted == true
			}
		}
		
		requirement def SafetyRequirement {
			subject robot : LogicalModel::RobotSystem;
			require constraint {
				robot.locomotionController.obstacleDistance > 0.5 [m]
			}
		}
		
		requirement primaryTaskRequirement : TaskCompletionRequirement;
		requirement locomotionRequirement : LocomotionRequirement;
		requirement safetyRequirement : SafetyRequirement;
	}
	
	package LogicalModel {
		private import ValueTypes::*;
		
		action def Navigate {
			in targetPos : Position;
			in currentPos : Position;
			out pathValid : Boolean;
			out commandedVelocity : Velocity;
		}
		
		action def Move {
			in velocity : Velocity;
			out distanceTraveled : LengthValue;
		}
		
		action def ExecuteTask {
			in taskParameters : Real[*];
			out taskResult : Boolean;
		}
		
		action def SenseEnvironment {
			out position : Position;
			out obstacleDistance : LengthValue;
		}
		
		action performPrimaryTask {
			in destination : Position;
			out taskCompleted : Boolean;
			
			first start;
			then merge continueOperation;
			then action sense : SenseEnvironment;
			then action navigate : Navigate {
				in targetPos = destination;
				in currentPos = sense.position;
			}
			then decide;
				if navigate.pathValid == true then moveToTarget;
				if navigate.pathValid == false then continueOperation;
			action moveToTarget : Move {
				in velocity = navigate.commandedVelocity;
			}
			then decide;
				if moveToTarget.distanceTraveled >= 0.1 [m] then executeMainTask;
				if moveToTarget.distanceTraveled < 0.1 [m] then continueOperation;
			action executeMainTask : ExecuteTask {
				in taskParameters = (1.0, 2.0, 3.0);
			}
			then assign taskCompleted := executeMainTask.taskResult;
			then done;
		}
		
		part def LocomotionController {
			attribute speed : SpeedValue;
			attribute obstacleDistance : LengthValue;
			attribute mode : LocomotionMode;
			perform action navigateAction : Navigate;
			perform action moveAction : Move;
		}
		
		part def TaskExecutor {
			attribute taskStatus : TaskStatus;
			perform action executeTaskAction : ExecuteTask;
		}
		
		part def SensorSystem {
			perform action senseAction : SenseEnvironment;
		}
		
		part def RobotSystem {
			attribute taskCompleted : Boolean;
			part locomotionController : LocomotionController {
				perform performPrimaryTask.navigate :>> navigateAction;
				perform performPrimaryTask.moveToTarget :>> moveAction;
			}
			part taskExecutor : TaskExecutor {
				perform performPrimaryTask.executeMainTask :>> executeTaskAction;
			}
			part sensors : SensorSystem {
				perform performPrimaryTask.sense :>> senseAction;
			}
			perform performPrimaryTask;
		}
		
		part robotSystem : RobotSystem;
		
		satisfy RequirementModel::primaryTaskRequirement by robotSystem;
		satisfy RequirementModel::locomotionRequirement by robotSystem;
		satisfy RequirementModel::safetyRequirement by robotSystem;
	}
	
	package PhysicalModel {
		private import LogicalModel::*;
		private import ValueTypes::*;
		
		port def PowerPort {
			attribute voltage : ISQ::voltage;
			attribute current : ISQ::electricCurrent;
		}
		
		port def ControlPort {
			flow in commandSignal : MotionCommand;
			flow out feedbackSignal : SensorData;
		}
		
		port def SensorPort {
			flow out sensorData : SensorData;
		}
		
		part def Battery {
			attribute capacity : EnergyValue;
			attribute chargeLevel : Real;
			port powerOut : PowerPort {
				attribute voltage : ISQ::voltage;
				attribute current : ISQ::electricCurrent;
			}
		}
		
		part def Motor {
			attribute torque : TorqueValue;
			attribute rpm : AngularVelocityValue;
			port powerIn : PowerPort {
				attribute voltage : ISQ::voltage;
				attribute current : ISQ::electricCurrent;
			}
			port controlIn : ControlPort;
		}
		
		part def Wheel {
			attribute diameter : LengthValue;
			attribute rotationSpeed : AngularVelocityValue;
		}
		
		part def DriveSystem {
			part leftMotor : Motor {
				attribute :>> torque = 10.0 [N*m];
				attribute :>> rpm = 100.0 [rad/s];
			}
			part rightMotor : Motor {
				attribute :>> torque = 10.0 [N*m];
				attribute :>> rpm = 100.0 [rad/s];
			}
			part leftWheel : Wheel {
				attribute :>> diameter = 0.2 [m];
			}
			part rightWheel : Wheel {
				attribute :>> diameter = 0.2 [m];
			}
			port controlIn : ControlPort;
		}
		
		part def PositionSensor {
			attribute accuracy : LengthValue;
			port sensorOut : SensorPort;
		}
		
		part def ProximitySensor {
			attribute detectionRange : LengthValue;
			attribute obstacleDetected : Boolean;
			port sensorOut : SensorPort;
		}
		
		part def SensorArray {
			part positionSensor : PositionSensor {
				attribute :>> accuracy = 0.01 [m];
			}
			part frontProximity : ProximitySensor {
				attribute :>> detectionRange = 3.0 [m];
			}
			part rearProximity : ProximitySensor {
				attribute :>> detectionRange = 2.0 [m];
			}
			port sensorOut : SensorPort;
		}
		
		part def Manipulator {
			attribute gripperForce : ForceValue;
			attribute reachDistance : LengthValue;
			port controlIn : ControlPort;
			
			perform action grip {
				in force : ForceValue;
				out gripped : Boolean;
			}
			
			perform action release {
				out released : Boolean;
			}
		}
		
		part def ControlComputer {
			attribute processingPower : PowerValue;
			port controlOut : ControlPort[*];
			port sensorIn : SensorPort[*];
			port powerIn : PowerPort;
			
			perform performPrimaryTask;
		}
		
		part def PhysicalRobot {
			attribute totalMass : MassValue;
			
			part powerSupply : Battery {
				attribute :>> capacity = 10000.0 [J];
				attribute :>> chargeLevel = 0.8;
			}
			
			part driveSystem : DriveSystem;
			
			part sensors : SensorArray;
			
			part manipulator : Manipulator {
				attribute :>> gripperForce = 100.0 [N];
				attribute :>> reachDistance = 1.0 [m];
			}
			
			part controller : ControlComputer {
				attribute :>> processingPower = 50.0 [W];
				perform performPrimaryTask;
			}
			
			connect powerSupply.powerOut to driveSystem.leftMotor.powerIn;
			connect powerSupply.powerOut to driveSystem.rightMotor.powerIn;
			connect powerSupply.powerOut to controller.powerIn;
			connect controller.controlOut to driveSystem.controlIn;
			connect controller.controlOut to manipulator.controlIn;
			connect sensors.sensorOut to controller.sensorIn;
		}
		
		part robot : PhysicalRobot {
			attribute :>> totalMass = 30.0 [kg];
		}
	}
	
	package BehaviorModel {
		private import ValueTypes::*;
		
		state def RobotStateMachine {
			entry; then idle;
			
			state idle {
				entry assign currentStatus := TaskStatus::idle;
			}
			accept at startTime
				then navigating;
			
			state navigating {
				entry assign currentStatus := TaskStatus::navigating;
				do action computePath {
					in target : Position;
					out path : Position[*];
				}
			}
			accept when pathComputed
				then moving;
			
			state moving {
				entry assign currentStatus := TaskStatus::executing;
				do action moveAlongPath {
					in path : Position[*];
					out distanceTraveled : LengthValue;
				}
			}
			accept when targetReached
				then executing;
			accept when obstacleDetected
				then navigating;
			
			state executing {
				entry assign currentStatus := TaskStatus::executing;
				do action performManipulation {
					out manipulationComplete : Boolean;
				}
			}
			accept when taskComplete
				then completed;
			accept when taskFailed
				then failed;
			
			state completed {
				entry assign currentStatus := TaskStatus::completed;
			}
			accept done
				then idle;
			
			state failed {
				entry assign currentStatus := TaskStatus::failed;
			}
			accept when resetSignal
				then idle;
			
			attribute currentStatus : TaskStatus;
			attribute startTime : TimeInstantValue;
			attribute pathComputed : Boolean;
			attribute targetReached : Boolean;
			attribute obstacleDetected : Boolean;
			attribute taskComplete : Boolean;
			attribute taskFailed : Boolean;
			attribute resetSignal : Boolean;
		}
		
		part robotWithBehavior : PhysicalModel::PhysicalRobot {
			exhibit state robotState : RobotStateMachine;
		}
	}
	
	allocation def LogicalToPhysicalAllocation {
		end logical : LogicalModel::RobotSystem;
		end physical : PhysicalModel::PhysicalRobot;
	}
	
	allocation systemAllocation : LogicalToPhysicalAllocation
		allocate logical ::> LogicalModel::robotSystem 
		to physical ::> PhysicalModel::robot {
		allocate LogicalModel::robotSystem.locomotionController 
			to PhysicalModel::robot.driveSystem;
		allocate LogicalModel::robotSystem.taskExecutor 
			to PhysicalModel::robot.manipulator;
		allocate LogicalModel::robotSystem.sensors 
			to PhysicalModel::robot.sensors;
		allocate LogicalModel::robotSystem.locomotionController.navigateAction 
			to PhysicalModel::robot.controller.performPrimaryTask;
		allocate LogicalModel::robotSystem.locomotionController.moveAction 
			to PhysicalModel::robot.driveSystem.leftMotor;
		allocate LogicalModel::robotSystem.taskExecutor.executeTaskAction 
			to PhysicalModel::robot.manipulator.grip;
	}
}
