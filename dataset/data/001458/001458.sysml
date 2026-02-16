package 'Collaborative Robotic Assembly System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import NumericalFunctions::*;

	package DataModel {
		enum def TaskState {
			enum pending;
			enum inProgress;
			enum awaitingApproval;
			enum completed;
			enum rejected;
		}

		enum def CommandType {
			enum start;
			enum pause;
			enum resume;
			enum approve;
			enum reject;
			enum emergency_stop;
		}

		enum def FeedbackLevel {
			enum info;
			enum warning;
			enum error;
			enum critical;
		}

		item def HumanCommand {
			attribute commandType : CommandType;
			attribute timestamp : Real;
			attribute operatorId : String;
		}

		item def RobotStatus {
			attribute currentTask : TaskState;
			attribute position : PositionVector;
			attribute safetyZoneClear : Boolean;
			attribute timestamp : Real;
		}

		item def VisualFeedback {
			attribute feedbackMessage : String;
			attribute level : FeedbackLevel;
			attribute displayDuration : Real;
		}

		item def AudioFeedback {
			attribute feedbackMessage : String;
			attribute urgency : FeedbackLevel;
		}

		item def AssemblyPart {
			attribute partId : String;
			attribute mass : MassValue;
			attribute dimensions : DimensionVector;
			attribute position : PositionVector;
		}

		item def WorkInstruction {
			attribute instructionId : String;
			attribute description : String;
			attribute requiredParts : String[1..*];
			attribute estimatedDuration : Real;
		}

		attribute def PositionVector {
			attribute x : LengthValue;
			attribute y : LengthValue;
			attribute z : LengthValue;
		}

		attribute def DimensionVector {
			attribute length : LengthValue;
			attribute width : LengthValue;
			attribute height : LengthValue;
		}

		attribute def VelocityVector {
			attribute vx : Real;
			attribute vy : Real;
			attribute vz : Real;
		}
	}

	package InterfaceModel {
		private import DataModel::*;

		port def HumanCommandPort {
			in item command : HumanCommand;
		}

		port def RobotStatusPort {
			out item status : RobotStatus;
		}

		port def FeedbackPort {
			out item visual : VisualFeedback;
			out item audio : AudioFeedback;
		}

		port def ManipulatorControlPort {
			out attribute targetPosition : PositionVector;
			out attribute targetVelocity : VelocityVector;
			in attribute currentPosition : PositionVector;
			in attribute gripperState : Boolean;
		}

		port def SafetySensorPort {
			out attribute proximityDistance : LengthValue;
			out attribute humanDetected : Boolean;
			out attribute emergencyStopActive : Boolean;
		}

		port def VisionSystemPort {
			out item detectedParts : AssemblyPart[0..*];
			out attribute calibrationValid : Boolean;
		}

		port def WorkstationPort {
			in item instruction : WorkInstruction;
			out item completedAssembly : AssemblyPart;
		}
	}

	package BehaviorModel {
		private import DataModel::*;
		private import InterfaceModel::*;

		action def ProcessHumanCommand {
			in command : HumanCommand;
			out commandValid : Boolean;
			out interpretedAction : String;
		}

		action def PlanAssemblyTask {
			in instruction : WorkInstruction;
			in availableParts : AssemblyPart[0..*];
			out taskPlan : String;
			out estimatedTime : Real;
		}

		action def ExecuteAssemblyStep {
			in taskPlan : String;
			in targetPart : AssemblyPart;
			out stepComplete : Boolean;
			out assemblyPosition : PositionVector;
		}

		action def RequestHumanApproval {
			in assemblyResult : AssemblyPart;
			out approvalRequest : VisualFeedback;
		}

		action def MonitorSafety {
			in proximityData : LengthValue;
			in humanPresent : Boolean;
			out safeToOperate : Boolean;
			out emergencyStop : Boolean;
		}

		action def GenerateFeedback {
			in taskStatus : TaskState;
			in safetyStatus : Boolean;
			out visual : VisualFeedback;
			out audio : AudioFeedback;
		}

		action def CollaborativeAssemblyProcess {
			first start;
			then merge awaitCommand;

			action receiveCommand : ProcessHumanCommand {
				in command : HumanCommand;
				out commandValid : Boolean;
				out interpretedAction : String;
			}

			then decide;
				if receiveCommand.commandValid && receiveCommand.command.commandType == CommandType::start
					then checkSafety;
				if receiveCommand.commandValid && receiveCommand.command.commandType == CommandType::emergency_stop
					then handleEmergency;
				if !receiveCommand.commandValid
					then provideFeedback;

			action checkSafety : MonitorSafety {
				in proximityData : LengthValue;
				in humanPresent : Boolean;
				out safeToOperate : Boolean;
				out emergencyStop : Boolean;
			}

			then decide;
				if checkSafety.safeToOperate && !checkSafety.emergencyStop
					then planTask;
				if !checkSafety.safeToOperate || checkSafety.emergencyStop
					then handleEmergency;

			action planTask : PlanAssemblyTask {
				in instruction : WorkInstruction;
				in availableParts : AssemblyPart[0..*];
				out taskPlan : String;
				out estimatedTime : Real;
			}

			then executeStep;

			action executeStep : ExecuteAssemblyStep {
				in taskPlan = planTask.taskPlan;
				in targetPart : AssemblyPart;
				out stepComplete : Boolean;
				out assemblyPosition : PositionVector;
			}

			then requestApproval;

			action requestApproval : RequestHumanApproval {
				in assemblyResult : AssemblyPart;
				out approvalRequest : VisualFeedback;
			}

			then merge awaitApproval;

			action awaitApprovalCommand : ProcessHumanCommand {
				in command : HumanCommand;
				out commandValid : Boolean;
				out interpretedAction : String;
			}

			then decide;
				if awaitApprovalCommand.command.commandType == CommandType::approve
					then completeTask;
				if awaitApprovalCommand.command.commandType == CommandType::reject
					then executeStep;

			action completeTask {
				then provideFeedback;
			}

			action provideFeedback : GenerateFeedback {
				in taskStatus : TaskState;
				in safetyStatus : Boolean;
				out visual : VisualFeedback;
				out audio : AudioFeedback;
			}

			then awaitCommand;

			action handleEmergency {
				then provideFeedback;
				then awaitCommand;
			}

			then done;
		}

		state def RobotOperationalStates {
			entry; then idle;

			state idle {
				entry assign isWaitingForCommand = true;
				entry assign currentTaskState = TaskState::pending;
			}

			transition idle_to_receiving
				first idle
				accept cmd : HumanCommand
				if cmd.commandType == CommandType::start
				then receiving;

			state receiving {
				entry assign isProcessingCommand = true;
				do action processCmd : ProcessHumanCommand;
			}

			transition receiving_to_planning
				first receiving
				if processCmd.commandValid
				then planning;

			transition receiving_to_idle
				first receiving
				if !processCmd.commandValid
				then idle;

			state planning {
				entry assign currentTaskState = TaskState::inProgress;
				do action planningAction : PlanAssemblyTask;
			}

			transition planning_to_safetyCheck
				first planning
				then safetyCheck;

			state safetyCheck {
				do action safetyMonitor : MonitorSafety;
			}

			transition safetyCheck_to_executing
				first safetyCheck
				if safetyMonitor.safeToOperate
				then executing;

			transition safetyCheck_to_emergency
				first safetyCheck
				if safetyMonitor.emergencyStop
				then emergency;

			state executing {
				entry assign isExecutingTask = true;
				do action executeAction : ExecuteAssemblyStep;
			}

			transition executing_to_awaitingApproval
				first executing
				if executeAction.stepComplete
				then awaitingApproval;

			state awaitingApproval {
				entry assign currentTaskState = TaskState::awaitingApproval;
				entry assign humanApprovalReceived = false;
			}

			transition approval_to_completed
				first awaitingApproval
				accept approvalCmd : HumanCommand
				if approvalCmd.commandType == CommandType::approve
				then completed;

			transition approval_to_executing
				first awaitingApproval
				accept rejectCmd : HumanCommand
				if rejectCmd.commandType == CommandType::reject
				then executing;

			state completed {
				entry assign currentTaskState = TaskState::completed;
				entry assign humanApprovalReceived = true;
			}

			transition completed_to_idle
				first completed
				then idle;

			state emergency {
				entry assign emergencyActive = true;
				entry assign currentTaskState = TaskState::rejected;
			}

			transition emergency_to_idle
				first emergency
				accept resetCmd : HumanCommand
				then idle;
		}
	}

	package LogicalModel {
		private import DataModel::*;
		private import InterfaceModel::*;
		private import BehaviorModel::*;

		part def HumanOperatorInterface {
			attribute operatorPresent : Boolean;
			port commandPort : HumanCommandPort;
			port feedbackPort : FeedbackPort;

			perform action issueCommand : ProcessHumanCommand;
			perform action receiveFeedback : GenerateFeedback;
		}

		part def SafetySystem {
			attribute currentProximity : LengthValue;
			attribute emergencyStopEngaged : Boolean;
			port sensorPort : SafetySensorPort;

			perform action monitorSafety : MonitorSafety;
		}

		part def TaskController {
			attribute currentState : TaskState;
			attribute humanApprovalReceived : Boolean;
			attribute requiresHumanApproval : Boolean;

			perform action manageTask : CollaborativeAssemblyProcess;
			exhibit state operationalStates : RobotOperationalStates;
		}

		part def CommandProcessor {
			attribute responseTime : Real;

			perform action processCommand : ProcessHumanCommand;
		}

		part def VisionSystem {
			attribute detectionAccuracy : Real;
			port visionPort : VisionSystemPort;

			perform action detectParts;
		}

		part def ManipulatorController {
			attribute currentPosition : PositionVector;
			attribute targetPosition : PositionVector;
			port controlPort : ManipulatorControlPort;

			perform action executeMotion : ExecuteAssemblyStep;
		}
	}

	package PhysicalModel {
		private import LogicalModel::*;
		private import InterfaceModel::*;
		private import DataModel::*;

		part def LaserScanner {
			attribute scanRange : LengthValue;
			attribute scanFrequency : FrequencyValue;
			attribute accuracy : LengthValue;
			port output : SafetySensorPort;
		}

		part def ProximitySensor {
			attribute detectionRange : LengthValue;
			attribute responseTime : Real;
			port output : SafetySensorPort;
		}

		part def RGBDCamera {
			attribute resolution : Integer;
			attribute frameRate : FrequencyValue;
			attribute depthRange : LengthValue;
			port output : VisionSystemPort;
		}

		part def TouchScreen {
			attribute screenSize : LengthValue;
			attribute brightness : Real;
		}

		part def AudioSystem {
			attribute maxVolume : Real;
			attribute speakerCount : Integer;
		}

		part def LEDIndicator {
			attribute colorChannels : Integer;
			attribute brightness : Real;
		}

		part def RoboticArm {
			attribute reachRadius : LengthValue;
			attribute maxPayload : MassValue;
			attribute degreesOfFreedom : Integer;
			attribute repeatability : LengthValue;
			port controlPort : ManipulatorControlPort;

			part endEffector {
				attribute gripForce : ForceValue;
				attribute openingWidth : LengthValue;
			}
		}

		part def ControlUnit {
			attribute processorSpeed : FrequencyValue;
			attribute memoryCapacity : Real;
			attribute operatingSystem : String;
		}

		part def PowerSupply {
			attribute voltage : Real;
			attribute current : Real;
			attribute efficiency : Real;
		}

		part def CollaborativeRobot {
			attribute requiresHumanApproval : Boolean;

			part operatorInterface : HumanOperatorInterface {
				attribute :>> operatorPresent = true;
				port :>> commandPort : HumanCommandPort;
				port :>> feedbackPort : FeedbackPort;

				perform :>> issueCommand : ProcessHumanCommand;
				perform :>> receiveFeedback : GenerateFeedback;
			}

			part safetySystem : SafetySystem {
				attribute :>> currentProximity : LengthValue = 0.5 [m];
				attribute :>> emergencyStopEngaged = false;
				port :>> sensorPort : SafetySensorPort;

				perform :>> monitorSafety : MonitorSafety;
			}

			part taskController : TaskController {
				attribute :>> currentState = TaskState::pending;
				attribute :>> humanApprovalReceived = false;
				attribute :>> requiresHumanApproval = true;

				perform :>> manageTask : CollaborativeAssemblyProcess;
				exhibit :>> operationalStates : RobotOperationalStates;
			}

			part commandProcessor : CommandProcessor {
				attribute :>> responseTime = 0.8;

				perform :>> processCommand : ProcessHumanCommand;
			}

			part visionSystem : VisionSystem {
				attribute :>> detectionAccuracy = 0.98;
				port :>> visionPort : VisionSystemPort;

				perform :>> detectParts;
			}

			part manipulatorController : ManipulatorController {
				port :>> controlPort : ManipulatorControlPort;

				perform :>> executeMotion : ExecuteAssemblyStep;
			}

			part laserScanner : LaserScanner {
				attribute :>> scanRange : LengthValue = 5.0 [m];
				attribute :>> scanFrequency : FrequencyValue = 25.0 [Hz];
				attribute :>> accuracy : LengthValue = 0.01 [m];
				port :>> output : SafetySensorPort;
			}

			part proximitySensor : ProximitySensor {
				attribute :>> detectionRange : LengthValue = 1.5 [m];
				attribute :>> responseTime = 0.05;
				port :>> output : SafetySensorPort;
			}

			part camera : RGBDCamera {
				attribute :>> resolution = 1920;
				attribute :>> frameRate : FrequencyValue = 30.0 [Hz];
				attribute :>> depthRange : LengthValue = 3.0 [m];
				port :>> output : VisionSystemPort;
			}

			part touchScreen : TouchScreen {
				attribute :>> screenSize : LengthValue = 0.3 [m];
				attribute :>> brightness = 500.0;
			}

			part audioSystem : AudioSystem {
				attribute :>> maxVolume = 85.0;
				attribute :>> speakerCount = 2;
			}

			part ledIndicator : LEDIndicator {
				attribute :>> colorChannels = 3;
				attribute :>> brightness = 1000.0;
			}

			part roboticArm : RoboticArm {
				attribute :>> reachRadius : LengthValue = 0.9 [m];
				attribute :>> maxPayload : MassValue = 10.0 [kg];
				attribute :>> degreesOfFreedom = 6;
				attribute :>> repeatability : LengthValue = 0.0001 [m];
				port :>> controlPort : ManipulatorControlPort;
			}

			part controlUnit : ControlUnit {
				attribute :>> processorSpeed : FrequencyValue = 3.5e9 [Hz];
				attribute :>> memoryCapacity = 32.0;
				attribute :>> operatingSystem = "ROS2";
			}

			part powerSupply : PowerSupply {
				attribute :>> voltage = 48.0;
				attribute :>> current = 20.0;
				attribute :>> efficiency = 0.92;
			}

			connection safetyConnection1 connect laserScanner.output to safetySystem.sensorPort;
			connection safetyConnection2 connect proximitySensor.output to safetySystem.sensorPort;
			connection visionConnection connect camera.output to visionSystem.visionPort;
			connection manipulatorConnection connect manipulatorController.controlPort to roboticArm.controlPort;
		}

		part def Workstation {
			attribute workstationId : String;
			port workPort : WorkstationPort;

			part assemblyFixture {
				attribute fixtureType : String;
			}

			part partStorage {
				attribute capacity : Integer;
			}
		}

		part def HumanOperator {
			attribute operatorId : String;
			attribute certificationLevel : String;
			port commandInterface : HumanCommandPort;
		}

		part def CollaborativeAssemblySystem {
			part robot : CollaborativeRobot {
				attribute :>> requiresHumanApproval = true;
			}

			part workstation : Workstation {
				attribute :>> workstationId = "WS-001";
			}

			part operator : HumanOperator {
				attribute :>> operatorId = "OP-123";
				attribute :>> certificationLevel = "Advanced";
			}

			connection operatorToRobot connect operator.commandInterface to robot.operatorInterface.commandPort;
			binding workstationBinding bind workstation.workPort to robot.taskController;
		}
	}

	package RequirementModel {
		private import PhysicalModel::*;

		requirement def HumanRobotInteractionRequirement {
			doc /* The robotic system shall require human interaction to initiate and complete assembly tasks. */
			subject robot : CollaborativeRobot;
			require constraint {
				robot.requiresHumanApproval == true
			}
		}

		requirement def SafetyRequirement {
			doc /* The robot shall maintain a minimum safe distance from humans during operation. */
			subject robot : CollaborativeRobot;
			attribute minSafeDistance : LengthValue;
			require constraint {
				robot.safetySystem.currentProximity >= minSafeDistance
			}
		}

		requirement def TaskCompletionRequirement {
			doc /* Assembly tasks shall only be marked complete after human verification. */
			subject robot : CollaborativeRobot;
			require constraint {
				robot.taskController.currentState == TaskState::completed implies
				robot.taskController.humanApprovalReceived == true
			}
		}

		requirement def ResponseTimeRequirement {
			doc /* The robot shall respond to human commands within specified time limit. */
			subject robot : CollaborativeRobot;
			attribute maxResponseTime : Real;
			require constraint {
				robot.commandProcessor.responseTime <= maxResponseTime
			}
		}

		requirement collaborativeAssemblySpec {
			doc /* Overall collaborative assembly system requirements */
			subject system : CollaborativeAssemblySystem;

			require hriReq : HumanRobotInteractionRequirement {
				subject robot = system.robot;
			}

			require safetyReq : SafetyRequirement {
				subject robot = system.robot;
				attribute :>> minSafeDistance = 0.3 [m];
			}

			require taskReq : TaskCompletionRequirement {
				subject robot = system.robot;
			}

			require responseReq : ResponseTimeRequirement {
				subject robot = system.robot;
				attribute :>> maxResponseTime = 1.5;
			}
		}
	}

	package AllocationModel {
		private import LogicalModel::*;
		private import PhysicalModel::*;

		allocation def LogicalToPhysicalAllocation {
			end logical : TaskController;
			end physical : CollaborativeRobot;
		}

		allocation taskAllocation : LogicalToPhysicalAllocation
			allocate logical ::> taskController to physical ::> robot {
			allocate taskController.manageTask to robot.taskController.manageTask;
			allocate taskController.operationalStates to robot.taskController.operationalStates;
		}

		allocation safetyAllocation
			allocate safetySystem to robot.safetySystem {
			allocate safetySystem.monitorSafety to robot.taskController.manageTask.checkSafety;
		}

		allocation visionAllocation
			allocate visionSystem to robot.visionSystem {
			allocate visionSystem.detectParts to robot.taskController.manageTask.planTask;
		}

		allocation manipulatorAllocation
			allocate manipulatorController to robot.manipulatorController {
			allocate manipulatorController.executeMotion to robot.taskController.manageTask.executeStep;
		}
	}

	package VerificationModel {
		private import RequirementModel::*;
		private import PhysicalModel::*;

		part systemInstance : CollaborativeAssemblySystem;

		satisfy collaborativeAssemblySpec by systemInstance;
		satisfy hriReq by systemInstance.robot;
		satisfy safetyReq by systemInstance.robot.safetySystem;
		satisfy taskReq by systemInstance.robot.taskController;
		satisfy responseReq by systemInstance.robot.commandProcessor;
	}

	constraint def HumanApprovalConstraint {
		in taskState : TaskState;
		in approvalReceived : Boolean;
		(taskState == TaskState::completed) implies approvalReceived
	}

	constraint def SafetyDistanceConstraint {
		in currentDistance : LengthValue;
		in minimumDistance : LengthValue;
		currentDistance >= minimumDistance
	}

	part systemContext : PhysicalModel::CollaborativeAssemblySystem {
		assert constraint approvalCheck : HumanApprovalConstraint {
			in taskState = robot.taskController.currentState;
			in approvalReceived = robot.taskController.humanApprovalReceived;
		}

		assert constraint safetyCheck : SafetyDistanceConstraint {
			in currentDistance = robot.safetySystem.currentProximity;
			in minimumDistance = 0.3 [m];
		}
	}
}
