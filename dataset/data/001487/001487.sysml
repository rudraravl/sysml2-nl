package 'Legged Robotic System' {
	private import ScalarValues::*;

	// Value types with units
	attribute def Velocity :> Real {
		attribute value : Real;
		attribute unit : String = "m/s";
	}

	attribute def Distance :> Real {
		attribute value : Real;
		attribute unit : String = "m";
	}

	attribute def Force :> Real {
		attribute value : Real;
		attribute unit : String = "N";
	}

	attribute def Torque :> Real {
		attribute value : Real;
		attribute unit : String = "Nm";
	}

	attribute def Angle :> Real {
		attribute value : Real;
		attribute unit : String = "deg";
	}

	attribute def Power :> Real {
		attribute value : Real;
		attribute unit : String = "W";
	}

	// Enumerations
	enum def GaitType {
		enum walk;
		enum trot;
		enum gallop;
		enum crawl;
	}

	enum def TerrainCondition {
		enum flat;
		enum rough;
		enum inclined;
		enum stairs;
	}

	enum def LegPhaseState {
		enum stance;
		enum swing;
		enum liftOff;
		enum touchdown;
	}

	enum def RobotMode {
		enum idle;
		enum navigating;
		enum executing;
		enum recovering;
	}

	// Item definitions
	item def NavigationCommand {
		attribute targetX : Distance;
		attribute targetY : Distance;
		attribute targetZ : Distance;
		attribute desiredSpeed : Velocity;
	}

	item def TaskCommand {
		attribute taskId : Integer;
		attribute taskType : String;
		attribute priority : Integer;
	}

	item def SensorReading {
		attribute positionX : Distance;
		attribute positionY : Distance;
		attribute positionZ : Distance;
		attribute orientationRoll : Angle;
		attribute orientationPitch : Angle;
		attribute orientationYaw : Angle;
		attribute terrainType : TerrainCondition;
	}

	item def LegControlSignal {
		attribute legIndex : Integer;
		attribute hipAngle : Angle;
		attribute kneeAngle : Angle;
		attribute ankleAngle : Angle;
		attribute targetForce : Force;
	}

	item def StatusReport {
		attribute currentMode : RobotMode;
		attribute batteryLevel : Real;
		attribute taskProgress : Real;
		attribute isStable : Boolean;
	}

	// Port definitions
	port def CommandPort {
		in navCmd : NavigationCommand;
		in taskCmd : TaskCommand;
	}

	port def SensorPort {
		out sensorData : SensorReading;
	}

	port def ControlPort {
		out legControl : LegControlSignal;
	}

	port def StatusPort {
		out status : StatusReport;
	}

	port def PowerPort {
		in powerSupply : Power;
	}

	// Action definitions
	action def SenseEnvironment {
		in terrain : TerrainCondition;
		out reading : SensorReading;
	}

	action def PlanMotion {
		in currentReading : SensorReading;
		in navCommand : NavigationCommand;
		out selectedGait : GaitType;
		out legSignals : LegControlSignal[4];
	}

	action def ExecuteLegMotion {
		in controlSignal : LegControlSignal;
		in currentPhase : LegPhaseState;
		out jointAngles : Angle[3];
		out appliedForce : Force;
	}

	action def MonitorBalance {
		in sensorReading : SensorReading;
		in legPhases : LegPhaseState[4];
		out stable : Boolean;
		out correctionNeeded : Boolean;
	}

	action def PerformTask {
		in taskCmd : TaskCommand;
		in position : SensorReading;
		out taskComplete : Boolean;
		out result : String;
	}

	action def ManagePower {
		in powerDemand : Power;
		out powerAvailable : Power;
		out batteryLevel : Real;
	}

	// Part definitions
	part def ForceSensor {
		attribute maxForce : Force;
		attribute groundForce : Force;
		attribute contactDetected : Boolean;

		port sensorOut : SensorPort;
	}

	part def Joint {
		attribute jointId : Integer;
		attribute currentAngle : Angle;
		attribute maxTorque : Torque;
		attribute minAngle : Angle;
		attribute maxAngle : Angle;

		port angleControl : ControlPort;
	}

	part def Leg {
		attribute legId : Integer;
		attribute legLength : Distance;
		attribute currentPhase : LegPhaseState;

		port controlInput : ControlPort;
		port phaseOutput : StatusPort;

		part hipJoint : Joint {
			attribute :>> jointId = 1;
		}

		part kneeJoint : Joint {
			attribute :>> jointId = 2;
		}

		part ankleJoint : Joint {
			attribute :>> jointId = 3;
		}

		part footSensor : ForceSensor;

		perform action executeLegMotion : ExecuteLegMotion;

		state legStateMachine {
			entry; then idle;

			state idle;
			transition idle_to_liftoff
				first idle
				accept at controlInput
				then liftOff;

			state liftOff;
			transition liftoff_to_swing
				first liftOff
				then swing;

			state swing;
			transition swing_to_touchdown
				first swing
				then touchdown;

			state touchdown;
			transition touchdown_to_stance
				first touchdown
				then stance;

			state stance;
			transition stance_to_idle
				first stance
				then idle;
		}
	}

	part def IMU {
		attribute sampleRate : Real;
		attribute accelerationRange : Real;
		attribute gyroRange : Real;

		port sensorOut : SensorPort;

		perform action senseEnvironment : SenseEnvironment;
	}

	part def LidarSensor {
		attribute range : Distance;
		attribute resolution : Angle;
		attribute scanRate : Real;

		port sensorOut : SensorPort;
	}

	part def Battery {
		attribute capacity : Power;
		attribute currentCharge : Real;
		attribute voltage : Real;

		port powerOut : PowerPort;

		perform action managePower : ManagePower;
	}

	part def MotionPlanner {
		attribute currentGait : GaitType;

		port sensorIn : SensorPort;
		port commandIn : CommandPort;
		port controlOut : ControlPort;

		perform action planMotion : PlanMotion;
	}

	part def BalanceController {
		attribute stabilityThreshold : Real;

		port sensorIn : SensorPort;
		port statusOut : StatusPort;

		perform action monitorBalance : MonitorBalance;
	}

	part def TaskExecutor {
		attribute currentTaskId : Integer;

		port commandIn : CommandPort;
		port sensorIn : SensorPort;
		port statusOut : StatusPort;

		perform action performTask : PerformTask;
	}

	part def LeggedRobot {
		attribute robotMass : Real;
		attribute robotHeight : Distance;
		attribute operationalMode : RobotMode;

		port commandPort : CommandPort;
		port statusPort : StatusPort;
		port powerPort : PowerPort;

		part imu : IMU {
			attribute :>> sampleRate = 100.0;
		}

		part lidar : LidarSensor;

		part battery : Battery {
			attribute :>> currentCharge = 100.0;
		}

		part frontLeftLeg : Leg {
			attribute :>> legId = 1;
		}

		part frontRightLeg : Leg {
			attribute :>> legId = 2;
		}

		part rearLeftLeg : Leg {
			attribute :>> legId = 3;
		}

		part rearRightLeg : Leg {
			attribute :>> legId = 4;
		}

		part motionPlanner : MotionPlanner;
		part balanceController : BalanceController;
		part taskExecutor : TaskExecutor;

		connect imu.sensorOut to motionPlanner.sensorIn;
		connect imu.sensorOut to balanceController.sensorIn;
		connect imu.sensorOut to taskExecutor.sensorIn;

		connect commandPort to motionPlanner.commandIn;
		connect commandPort to taskExecutor.commandIn;

		connect motionPlanner.controlOut to frontLeftLeg.controlInput;
		connect motionPlanner.controlOut to frontRightLeg.controlInput;
		connect motionPlanner.controlOut to rearLeftLeg.controlInput;
		connect motionPlanner.controlOut to rearRightLeg.controlInput;

		connect balanceController.statusOut to statusPort;
		connect taskExecutor.statusOut to statusPort;

		connect battery.powerOut to powerPort;

		state robotStateMachine {
			entry; then idle;

			state idle;
			transition idle_to_navigating
				first idle
				accept NavigationCommand at commandPort
				then navigating;

			state navigating;
			transition navigating_to_executing
				first navigating
				accept TaskCommand at commandPort
				then executing;

			state executing;
			transition executing_to_recovering
				first executing
				then recovering;
			transition executing_to_idle
				first executing
				then idle;

			state recovering;
			transition recovering_to_navigating
				first recovering
				then navigating;
		}
	}

	part def ControlStation {
		port commandOut : CommandPort;
		port statusIn : StatusPort;

		action def IssueNavigationCommand {
			out navCmd : NavigationCommand;
		}

		action def IssueTaskCommand {
			out taskCmd : TaskCommand;
		}

		perform action issueNavigationCommand : IssueNavigationCommand;
		perform action issueTaskCommand : IssueTaskCommand;
	}

	// Logical model
	package LogicalModel {
		action def ExecutePrimaryTask;
		action def NavigateToLocation;
		action def PerformMission;

		part def PrimaryTaskExecutor;

		action executePrimaryTask : ExecutePrimaryTask {
			first start;
			then action navigate : NavigateToLocation;
			then action performMission : PerformMission;
			then done;
		}

		part primaryTaskExecutor : PrimaryTaskExecutor {
			perform executePrimaryTask;
		}
	}

	// Physical model with allocation
	package PhysicalModel {
		private import LogicalModel::*;

		part roboticSystem {
			in item missionCommand : TaskCommand;
			in item navigationTarget : NavigationCommand;

			part controlStation : ControlStation;

			part leggedRobot : LeggedRobot {
				attribute :>> robotMass = 85.0;
				perform executePrimaryTask.navigate;
				perform executePrimaryTask.performMission;
			}

			connect controlStation.commandOut to leggedRobot.commandPort;
			connect leggedRobot.statusPort to controlStation.statusIn;
		}

		allocate primaryTaskExecutor to roboticSystem.leggedRobot {
			allocate primaryTaskExecutor.executePrimaryTask.navigate
				to roboticSystem.leggedRobot.navigate;
			allocate primaryTaskExecutor.executePrimaryTask.performMission
				to roboticSystem.leggedRobot.performMission;
		}
	}

	// Main system action
	action roboticSystemOperation {
		in item navCommand : NavigationCommand;
		in item taskCommand : TaskCommand;
		out item missionComplete : Boolean;

		first start;
		then merge operationLoop;

		then action sense : SenseEnvironment {
			in item terrain = TerrainCondition::flat;
			out item reading;
		}

		then action plan : PlanMotion {
			in item currentReading = sense.reading;
			in item navCommand = roboticSystemOperation::navCommand;
			out item selectedGait;
			out item legSignals;
		}

		then action executeLegMotions : ExecuteLegMotion[4] {
			in item controlSignal = plan.legSignals;
			in item currentPhase = LegPhaseState::stance;
			out item jointAngles;
			out item appliedForce;
		}

		then action checkBalance : MonitorBalance {
			in item sensorReading = sense.reading;
			in item legPhases[4];
			out item stable;
			out item correctionNeeded;
		}

		then decide;
			if checkBalance.stable then performTaskAction;
			if not checkBalance.stable then operationLoop;

		action performTaskAction : PerformTask {
			in item taskCmd = roboticSystemOperation::taskCommand;
			in item position = sense.reading;
			out item taskComplete;
			out item result;
		}

		then decide;
			if performTaskAction.taskComplete then complete;
			if not performTaskAction.taskComplete then operationLoop;

		action complete {
			assign missionComplete = true;
		}
		then done;
	}

	// Requirements
	requirement def PrimaryTaskRequirement {
		doc /* The robotic system shall perform its primary task using a legged robot. */
		subject robot : LeggedRobot;
		require constraint {
			robot.operationalMode in RobotMode
		}
	}

	requirement def MobilityRequirement {
		doc /* The legged robot shall traverse multiple terrain types using adaptive gait patterns. */
		subject robot : LeggedRobot;
		require constraint {
			robot.motionPlanner.currentGait in GaitType
		}
	}

	requirement def StabilityRequirement {
		doc /* The legged robot shall maintain dynamic stability during all operations. */
		subject controller : BalanceController;
		require constraint {
			controller.monitorBalance.stable == true
		}
	}

	requirement def PowerRequirement {
		doc /* The legged robot shall operate for minimum duration on battery power. */
		subject battery : Battery;
		attribute minOperatingTime : Real = 120.0;
		require constraint {
			battery.currentCharge > 20.0
		}
	}

	requirement def TaskExecutionRequirement {
		doc /* The legged robot shall execute commanded tasks upon reaching target location. */
		subject executor : TaskExecutor;
		require constraint {
			executor.performTask.taskComplete == true
		}
	}

	requirement systemRequirements {
		requirement primaryTaskReq : PrimaryTaskRequirement;
		requirement mobilityReq : MobilityRequirement;
		requirement stabilityReq : StabilityRequirement;
		requirement powerReq : PowerRequirement;
		requirement taskExecReq : TaskExecutionRequirement;
	}
}
