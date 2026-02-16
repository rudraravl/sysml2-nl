package 'Robotic System Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	enum def RobotState {
		enum idle;
		enum sensing;
		enum planning;
		enum executing;
		enum gripping;
		enum releasing;
		enum error;
	}

	enum def TaskStatus {
		enum pending;
		enum active;
		enum completed;
		enum failed;
	}

	attribute def Position {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}

	attribute def Orientation {
		attribute roll : Real;
		attribute pitch : Real;
		attribute yaw : Real;
	}

	attribute def Pose {
		attribute position : Position;
		attribute orientation : Orientation;
	}

	attribute def JointAngles {
		attribute joint1 : Real;
		attribute joint2 : Real;
		attribute joint3 : Real;
		attribute joint4 : Real;
		attribute joint5 : Real;
		attribute joint6 : Real;
	}

	item def WorkPiece {
		attribute weight : MassValue;
		attribute dimensions : Position;
		attribute currentPose : Pose;
	}

	item def TaskCommand {
		attribute targetPose : Pose;
		attribute gripForce : ForceValue;
		attribute priority : Integer;
	}

	item def SensorData {
		attribute measuredPose : Pose;
		attribute obstacleDetected : Boolean;
		attribute forceReading : ForceValue;
	}

	port def ControlPort {
		in attribute command : TaskCommand;
		out attribute status : TaskStatus;
	}

	port def PowerPort {
		in attribute voltage : Real;
		in attribute current : Real;
	}

	port def SensorPort {
		out attribute data : SensorData;
	}

	port def DataPort {
		in attribute sensorInput : SensorData;
		out attribute controlOutput : TaskCommand;
	}

	connection def ControlConnection {
		end source : ControlPort;
		end target : ControlPort;
	}

	connection def PowerConnection {
		end supply : PowerPort;
		end load : PowerPort;
	}

	connection def DataConnection {
		end sensorOut : SensorPort;
		end controllerIn : DataPort;
	}

	action def InitializeRobot {
		out systemReady : Boolean;
	}

	action def SenseEnvironment {
		out environmentData : SensorData;
	}

	action def PlanMotion {
		in currentPose : Pose;
		in targetPose : Pose;
		in obstacles : Boolean;
		out trajectory : JointAngles[0..*];
		out pathValid : Boolean;
	}

	action def ExecuteMotion {
		in trajectory : JointAngles[0..*];
		out finalPose : Pose;
		out success : Boolean;
	}

	action def GripWorkPiece {
		in workpiece : WorkPiece;
		in gripForce : ForceValue;
		out gripped : Boolean;
	}

	action def ReleaseWorkPiece {
		in workpiece : WorkPiece;
		out released : Boolean;
	}

	action def PerformPrimaryTask {
		in workpiece : WorkPiece;
		in targetLocation : Pose;
		out taskStatus : TaskStatus;
	}

	part def VisionSensor {
		attribute sensorType : String = "3D Vision";
		attribute resolution : Integer;
		port output : SensorPort;

		action sense : SenseEnvironment {
			out item environmentData;
		}
	}

	part def ForceSensor {
		attribute sensorType : String = "Force/Torque";
		attribute maxForce : ForceValue;
		port output : SensorPort;

		action measure {
			out forceData : ForceValue;
		}
	}

	part def Gripper {
		attribute maxGripForce : ForceValue;
		attribute currentForce : ForceValue;
		attribute fingerCount : Integer = 2;

		part forceSensor : ForceSensor;

		action grip : GripWorkPiece {
			in item workpiece;
			in item gripForce;
			out item gripped;
		}

		action release : ReleaseWorkPiece {
			in item workpiece;
			out item released;
		}
	}

	part def Joint {
		attribute jointId : Integer;
		attribute currentAngle : Real;
		attribute minAngle : Real;
		attribute maxAngle : Real;
		attribute maxSpeed : Real;

		action rotate {
			in targetAngle : Real;
			out reached : Boolean;
		}
	}

	part def RoboticArm {
		attribute reachRadius : LengthValue;
		attribute currentPose : Pose;
		attribute jointConfiguration : JointAngles;

		part joints[6] : Joint;
		part endEffector : Gripper;

		action moveToTarget : ExecuteMotion {
			in item trajectory;
			out item finalPose;
			out item success;
		}
	}

	part def MotionController {
		attribute controlFrequency : Real;
		port controlInterface : ControlPort;
		port dataInterface : DataPort;

		action planPath : PlanMotion {
			in item currentPose;
			in item targetPose;
			in item obstacles;
			out item trajectory;
			out item pathValid;
		}

		action executeControl {
			in command : TaskCommand;
			out controlSignal : JointAngles;
		}
	}

	part def Robot {
		attribute robotId : String;
		attribute currentState : RobotState;
		attribute isOperational : Boolean;

		port controlPort : ControlPort;
		port powerPort : PowerPort;

		part controller : MotionController;
		part arm : RoboticArm;
		part visionSensor : VisionSensor;

		connection sensorToController : DataConnection 
			connect visionSensor.output to controller.dataInterface;

		state robotStateMachine {
			entry; 
			then idleState;

			state idleState;
			then sensingState;

			state sensingState {
				do action senseAction : SenseEnvironment;
			}
			then planningState;

			state planningState {
				do action planAction : PlanMotion;
			}
			accept when planAction.pathValid
				then executingState;
			accept when !planAction.pathValid
				then errorState;

			state executingState {
				do action executeAction : ExecuteMotion;
			}
			accept when executeAction.success
				then grippingState;
			accept when !executeAction.success
				then errorState;

			state grippingState {
				do action gripAction : GripWorkPiece;
			}
			accept when gripAction.gripped
				then releasingState;
			accept when !gripAction.gripped
				then errorState;

			state releasingState {
				do action releaseAction : ReleaseWorkPiece;
			}
			accept when releaseAction.released
				then idleState;
			accept when !releaseAction.released
				then errorState;

			state errorState;
			then idleState;
		}

		action executePrimaryTask : PerformPrimaryTask {
			in item workpiece;
			in item targetLocation;
			out item taskStatus;

			first start;
			then action initialize : InitializeRobot {
				out item systemReady;
			}
			then action sense : SenseEnvironment {
				out item environmentData;
			}
			then action plan : PlanMotion {
				in item currentPose = arm.currentPose;
				in item targetPose = executePrimaryTask::targetLocation;
				in item obstacles = sense.environmentData.obstacleDetected;
				out item trajectory;
				out item pathValid;
			}
			then decide;
				if plan.pathValid then executeMove;
				if !plan.pathValid then handleError;

			action executeMove : ExecuteMotion {
				in item trajectory = plan.trajectory;
				out item finalPose;
				out item success;
			}
			then gripObject;

			action handleError {
				assign executePrimaryTask::taskStatus = TaskStatus::failed;
			}
			then done;

			action gripObject : GripWorkPiece {
				in item workpiece = executePrimaryTask::workpiece;
				in item gripForce;
				out item gripped;
			}
			then moveToTarget;

			action moveToTarget : ExecuteMotion {
				in item trajectory;
				out item finalPose;
				out item success;
			}
			then releaseObject;

			action releaseObject : ReleaseWorkPiece {
				in item workpiece = executePrimaryTask::workpiece;
				out item released;
			}
			then complete;

			action complete {
				assign executePrimaryTask::taskStatus = TaskStatus::completed;
			}
			then done;
		}
	}

	part def WorkCell {
		attribute cellId : String;
		attribute workArea : Position;

		part inputConveyor {
			attribute speed : Real;
			port outputPort;
		}

		part outputConveyor {
			attribute speed : Real;
			port inputPort;
		}

		part workpieces[0..*] : WorkPiece;
	}

	part def PowerSupply {
		attribute outputVoltage : Real = 48.0;
		attribute maxCurrent : Real = 100.0;
		port powerOutput : PowerPort;
	}

	requirement def SystemRequirement {
		doc /* Base requirement for robotic system */
		subject system : RoboticSystem;
	}

	requirement primaryTaskRequirement : SystemRequirement {
		doc /* The robotic system shall perform its primary task using a Robot */

		subject roboticSystem : RoboticSystem;

		require constraint {
			roboticSystem.robot.isOperational == true
		}

		require constraint {
			roboticSystem.robot.executePrimaryTask.taskStatus == TaskStatus::completed
		}
	}

	requirement safetyRequirement : SystemRequirement {
		doc /* Robot shall detect obstacles before executing motion */

		subject robot : Robot;

		require constraint {
			robot.visionSensor.sense.environmentData.obstacleDetected implies 
				!robot.controller.planPath.pathValid
		}
	}

	requirement performanceRequirement : SystemRequirement {
		doc /* Robot shall operate within force limits */

		subject robot : Robot;

		require constraint {
			robot.arm.endEffector.currentForce <= robot.arm.endEffector.maxGripForce
		}
	}

	package LogicalModel {
		action def PerformTask;
		part def TaskExecutor;

		action performTask : PerformTask {
			action executeWorkflow;
		}

		part taskExecutor : TaskExecutor {
			perform performTask.executeWorkflow;
		}
	}

	package PhysicalModel {
		private import LogicalModel::*;

		part def RoboticSystem {
			attribute systemId : String;
			attribute operationalMode : String;

			part robot : Robot;
			part workCell : WorkCell;
			part powerSupply : PowerSupply;

			connection powerLink : PowerConnection 
				connect powerSupply.powerOutput to robot.powerPort;

			perform action systemOperation : PerformPrimaryTask {
				in item workpiece;
				in item targetLocation;
				out item taskStatus;
			}
		}

		part roboticSystem : RoboticSystem {
			attribute redefines systemId = "ROBOSYS-001";
			attribute redefines operationalMode = "Automatic";

			part redefines robot {
				attribute redefines robotId = "ROBOT-001";
				attribute redefines isOperational = true;
				attribute redefines currentState = RobotState::idle;

				perform performTask.executeWorkflow;
			}

			part redefines workCell {
				attribute redefines cellId = "CELL-001";
			}
		}

		allocate taskExecutor to roboticSystem {
			allocate taskExecutor.executeWorkflow to roboticSystem.robot.executePrimaryTask;
		}

		satisfy primaryTaskRequirement by roboticSystem;
		satisfy safetyRequirement by roboticSystem.robot;
		satisfy performanceRequirement by roboticSystem.robot;
	}

	part roboticSystemInstance : PhysicalModel::RoboticSystem {
		part redefines workCell {
			part redefines workpieces[5] : WorkPiece;
		}
	}
}
