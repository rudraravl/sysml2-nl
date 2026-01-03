package 'Continuum Robotic System' {
	private import ScalarValues::*;
	private import SI::*;
	private import ISQ::*;

	package ValueTypes {
		attribute def Pose {
			attribute x : LengthValue;
			attribute y : LengthValue;
			attribute z : LengthValue;
			attribute roll : ISQ::planeAngle;
			attribute pitch : ISQ::planeAngle;
			attribute yaw : ISQ::planeAngle;
		}

		attribute def Curvature :> Real;

		enum def OperationalMode {
			enum idle;
			enum calibrating;
			enum ready;
			enum executing;
			enum completed;
			enum fault;
		}

		enum def TaskType {
			enum manipulation;
			enum inspection;
			enum navigation;
		}
	}

	package ItemModel {
		private import ValueTypes::*;

		item def ControlCommand {
			attribute targetPose : Pose;
			attribute targetCurvature : Curvature;
		}

		item def SensorFeedback {
			attribute currentPose : Pose;
			attribute appliedForce : ForceValue;
			attribute temperature : ThermodynamicTemperatureValue;
		}

		item def TaskPayload {
			attribute mass : MassValue;
			attribute dimensions : LengthValue[3];
		}
	}

	package InterfaceDefinitions {
		private import ItemModel::*;

		port def ControlPort {
			in item command : ControlCommand;
		}

		port def FeedbackPort {
			out item feedback : SensorFeedback;
		}

		port def PowerPort {
			in power : PowerValue;
		}

		port def PayloadPort {
			in item payload : TaskPayload;
		}
	}

	package LogicalModel {
		private import ValueTypes::*;
		private import ItemModel::*;

		action def SenseEnvironment {
			out feedback : SensorFeedback;
		}

		action def PlanTrajectory {
			in currentPose : Pose;
			in targetPose : Pose;
			out trajectory : Pose[1..*];
		}

		action def ExecuteMotion {
			in trajectory : Pose[1..*];
			out commands : ControlCommand[1..*];
		}

		action def ManipulatePayload {
			in payload : TaskPayload;
			in graspForce : ForceValue;
			out success : Boolean;
		}

		action def PerformPrimaryTask {
			in taskType : TaskType;
			out taskSuccess : Boolean;

			first start;
			then merge continueTask;
			then action sense : SenseEnvironment;
			then action plan : PlanTrajectory {
				in currentPose;
				in targetPose;
			}
			then action execute : ExecuteMotion {
				in trajectory = plan.trajectory;
			}
			then decide;
				if taskType == TaskType::manipulation then manipulate;
				else complete;
			action manipulate : ManipulatePayload;
			then complete;
			action complete {
				out result : Boolean = true;
			}
			then done;
		}

		part def LogicalElement;

		part def TaskExecutionUnit :> LogicalElement {
			attribute operationalState : OperationalMode;
			perform action executeTask : PerformPrimaryTask;
		}

		part taskExecutor : TaskExecutionUnit {
			attribute redefines operationalState = OperationalMode::ready;
		}
	}

	package PhysicalModel {
		private import ValueTypes::*;
		private import ItemModel::*;
		private import InterfaceDefinitions::*;

		part def PhysicalElement;

		part def ContinuumSegment :> PhysicalElement {
			attribute segmentLength : LengthValue;
			attribute segmentDiameter : LengthValue;
			attribute maxCurvature : Curvature;
			attribute stiffness : PressureValue;

			port actuatorControl : ControlPort;
			port sensorFeedback : FeedbackPort;
		}

		part def PneumaticActuator :> PhysicalElement {
			attribute maxPressure : PressureValue;
			attribute responseTime : TimeValue;
			attribute chambers : Integer;

			port controlInput : ControlPort;
		}

		part def ForceSensor :> PhysicalElement {
			attribute maxForce : ForceValue;
			attribute resolution : ForceValue;
			attribute sampleRate : FrequencyValue;

			port dataOutput : FeedbackPort;
		}

		part def ShapeSensor :> PhysicalElement {
			attribute fiberCount : Integer;
			attribute accuracy : LengthValue;

			port dataOutput : FeedbackPort;
		}

		part def EndEffector :> PhysicalElement {
			attribute graspForce : ForceValue;
			attribute graspRange : LengthValue;
			attribute fingerCount : Integer;

			port actuatorInput : ControlPort;
			port forceOutput : FeedbackPort;

			part gripperSensor : ForceSensor {
				attribute redefines maxForce = 50.0 [SI::N];
				attribute redefines resolution = 0.1 [SI::N];
				attribute redefines sampleRate = 100.0 [SI::Hz];
			}
		}

		part def ContinuumRobot :> PhysicalElement {
			attribute totalLength : LengthValue;
			attribute workspaceRadius : LengthValue;
			attribute positionAccuracy : LengthValue;
			attribute maxPayload : MassValue;

			part segments : ContinuumSegment[3] {
				attribute redefines segmentLength = 200.0 [SI::mm];
				attribute redefines segmentDiameter = 25.0 [SI::mm];
				attribute redefines maxCurvature = 0.05;
				attribute redefines stiffness = 100.0 [SI::Pa];
			}

			part actuators : PneumaticActuator[9] {
				attribute redefines maxPressure = 600.0 [SI::Pa];
				attribute redefines responseTime = 0.1 [SI::s];
				attribute redefines chambers = 3;
			}

			part shapeSensors : ShapeSensor[3] {
				attribute redefines fiberCount = 4;
				attribute redefines accuracy = 1.0 [SI::mm];
			}

			part endEffector : EndEffector {
				attribute redefines graspForce = 30.0 [SI::N];
				attribute redefines graspRange = 80.0 [SI::mm];
				attribute redefines fingerCount = 2;
			}

			port controlInterface : ControlPort;
			port feedbackInterface : FeedbackPort;

			perform action executeMotion : LogicalModel::ExecuteMotion;
		}

		part def ControlComputer :> PhysicalElement {
			attribute processorSpeed : FrequencyValue;
			attribute memoryCapacity : Real;
			attribute controlFrequency : FrequencyValue;

			port commandOutput : ~ControlPort;
			port feedbackInput : ~FeedbackPort;
			port powerInput : ~PowerPort;

			perform action planTrajectory : LogicalModel::PlanTrajectory;

			action def ControlLoop {
				first start;
				then merge continueControl;
				then action readSensors;
				then action computeControl;
				then action sendCommands;
				then continueControl;
			}

			perform action controlLoop : ControlLoop;
		}

		part def PowerSupply :> PhysicalElement {
			attribute outputVoltage : ElectricPotentialValue;
			attribute maxCurrent : ElectricCurrentValue;
			attribute capacity : Real;

			port powerOutput : PowerPort;
		}

		part def RoboticSystem :> PhysicalElement {
			attribute systemReliability : Real;
			attribute taskSuccessRate : Real;

			part continuumRobot : ContinuumRobot {
				attribute redefines totalLength = 600.0 [SI::mm];
				attribute redefines workspaceRadius = 500.0 [SI::mm];
				attribute redefines positionAccuracy = 2.0 [SI::mm];
				attribute redefines maxPayload = 2.0 [SI::kg];
			}

			part controller : ControlComputer {
				attribute redefines processorSpeed = 2.4e9 [SI::Hz];
				attribute redefines memoryCapacity = 8.0;
				attribute redefines controlFrequency = 500.0 [SI::Hz];
			}

			part powerSupply : PowerSupply {
				attribute redefines outputVoltage = 48.0 [SI::V];
				attribute redefines maxCurrent = 20.0 [SI::A];
				attribute redefines capacity = 5000.0;
			}

			port payloadInterface : PayloadPort;

			connection controlLink connect controller.commandOutput to continuumRobot.controlInterface;
			connection feedbackLink connect continuumRobot.feedbackInterface to controller.feedbackInput;
			connection powerLink connect powerSupply.powerOutput to controller.powerInput;

			perform action performTask : LogicalModel::PerformPrimaryTask;
		}

		part roboticSystem : RoboticSystem {
			attribute redefines systemReliability = 0.95;
			attribute redefines taskSuccessRate = 0.92;
		}
	}

	package BehaviorModel {
		private import ValueTypes::*;

		state def RobotStateMachine {
			entry; then idle;

			state idle;
			accept InitCommand;
			then calibrating;

			state calibrating;
			if testActuators.success then ready;
			if not testActuators.success then fault;

			state ready;
			accept TaskCommand;
			then executing;

			state executing;
			if performTask.taskSuccess then completed;
			if not performTask.taskSuccess then fault;

			state completed;
			then ready;

			state fault;
			accept ResetCommand;
			then idle;
		}

		state robotOperation : RobotStateMachine;
	}

	package RequirementModel {
		private import PhysicalModel::*;

		requirement performanceRequirement {
			subject robot : ContinuumRobot;
			doc /* The continuum robot shall achieve specified accuracy and payload capacity */
			require constraint {
				robot.positionAccuracy <= 3.0 [SI::mm] and
				robot.maxPayload >= 1.5 [SI::kg] and
				robot.workspaceRadius >= 400.0 [SI::mm]
			}
		}

		requirement safetyRequirement {
			subject effector : EndEffector;
			doc /* The end effector shall limit grasp force to prevent damage */
			require constraint {
				effector.graspForce <= 50.0 [SI::N]
			}
		}

		requirement taskExecutionRequirement {
			subject system : RoboticSystem;
			doc /* The robotic system shall successfully execute primary tasks */
			require constraint {
				system.taskSuccessRate >= 0.90
			}
		}

		requirement reliabilityRequirement {
			subject system : RoboticSystem;
			doc /* The system shall maintain high operational reliability */
			require constraint {
				system.systemReliability >= 0.93
			}
		}
	}

	package AllocationModel {
		private import LogicalModel::*;
		private import PhysicalModel::*;
		private import RequirementModel::*;

		allocation def LogicalToPhysical {
			end logical : LogicalElement;
			end physical : PhysicalElement;
		}

		allocation taskExecutorAllocation : LogicalToPhysical
			allocate logical ::> taskExecutor to physical ::> roboticSystem {
			allocate taskExecutor.executeTask to roboticSystem.performTask;
			allocate taskExecutor.executeTask.execute to roboticSystem.continuumRobot.executeMotion;
			allocate taskExecutor.executeTask.plan to roboticSystem.controller.planTrajectory;
		}

		satisfy performanceRequirement by roboticSystem.continuumRobot;
		satisfy safetyRequirement by roboticSystem.continuumRobot.endEffector;
		satisfy taskExecutionRequirement by roboticSystem;
		satisfy reliabilityRequirement by roboticSystem;
	}
}
