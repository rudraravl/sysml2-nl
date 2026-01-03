package 'Ubiquitous Robotic System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	enum def OperationalMode {
		enum standby;
		enum active;
		enum maintenance;
		enum fault;
	}

	enum def TaskPriority {
		enum low;
		enum medium;
		enum high;
		enum critical;
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

	item def TaskCommand {
		attribute taskID : String;
		attribute priority : TaskPriority;
		attribute targetPosition : Position;
		attribute parameters : String;
	}

	item def TaskResult {
		attribute taskID : String;
		attribute success : Boolean;
		attribute completionTime : Real;
		attribute data : String;
	}

	item def SensorData {
		attribute timestamp : Real;
		attribute position : Position;
		attribute obstacleDetected : Boolean;
		attribute environmentalData : String;
	}

	item def PowerSupply {
		attribute voltage : Real;
		attribute current : Real;
		attribute chargeLevel : Real;
	}

	port def CommandPort {
		in item command : TaskCommand;
		out item result : TaskResult;
	}

	port def SensorPort {
		out item data : SensorData;
	}

	port def PowerPort {
		in item power : PowerSupply;
	}

	port def DataPort {
		in item incomingData : SensorData;
		out item outgoingData : SensorData;
	}

	action def ScanEnvironment {
		in currentPos : Position;
		out sensorData : SensorData;
	}

	action def PlanPath {
		in currentPos : Position;
		in targetPos : Position;
		in obstacles : SensorData;
		out trajectory : String;
	}

	action def Navigate {
		in trajectory : String;
		in currentPos : Position;
		out newPos : Position;
	}

	action def ExecuteOperation {
		in taskCmd : TaskCommand;
		in position : Position;
		out operationResult : String;
	}

	action def ValidateResult {
		in operationResult : String;
		out isValid : Boolean;
	}

	action def ReportCompletion {
		in taskCmd : TaskCommand;
		in operationResult : String;
		in isValid : Boolean;
		out taskResult : TaskResult;
	}

	action def PerformPrimaryTask {
		in taskCommand : TaskCommand;
		out taskResult : TaskResult;
	}

	action performPrimaryTask : PerformPrimaryTask {
		in item taskCommand;
		out item taskResult;

		first start;
		then merge continueTask;
		then action scan : ScanEnvironment {
			in item currentPos;
			out item sensorData;
		}

		flow from scan.sensorData to plan.obstacles;

		then action plan : PlanPath {
			in item currentPos;
			in item targetPos = performPrimaryTask::taskCommand.targetPosition;
			in item obstacles;
			out item trajectory;
		}

		flow from plan.trajectory to navigate.trajectory;

		then action navigate : Navigate {
			in item trajectory;
			in item currentPos;
			out item newPos;
		}

		flow from navigate.newPos to execute.position;

		then action execute : ExecuteOperation {
			in item taskCmd = performPrimaryTask::taskCommand;
			in item position;
			out item operationResult;
		}

		flow from execute.operationResult to validate.operationResult;

		then action validate : ValidateResult {
			in item operationResult;
			out item isValid;
		}

		then decide;
			if validate.isValid == true then report;
			if validate.isValid == false then continueTask;

		action report : ReportCompletion {
			in item taskCmd = performPrimaryTask::taskCommand;
			in item operationResult = execute.operationResult;
			in item isValid = validate.isValid;
			out item taskResult = performPrimaryTask::taskResult;
		}
		then done;
	}

	state def UbiquitousRobotStateMachine {
		entry; then standby;

		state standby {
			entry assign mode = OperationalMode::standby;
		}
		accept at standby
			if taskReceived
			then active;

		state active {
			entry assign mode = OperationalMode::active;
			do action performTask : PerformPrimaryTask;
		}
		accept at active
			if taskCompleted
			then standby;
			if errorOccurred
			then fault;
			if maintenanceRequired
			then maintenance;

		state maintenance {
			entry assign mode = OperationalMode::maintenance;
		}
		accept at maintenance
			if maintenanceComplete
			then standby;

		state fault {
			entry assign mode = OperationalMode::fault;
		}
		accept at fault
			if faultCleared
			then standby;
	}

	part def SensorModule {
		attribute sensorRange : LengthValue;
		attribute updateFrequency : FrequencyValue;
		port sensorPort : SensorPort;

		perform action scan : ScanEnvironment;
	}

	part def NavigationModule {
		attribute maxSpeed : SpeedValue;
		attribute positionAccuracy : LengthValue;

		perform action plan : PlanPath;
		perform action navigate : Navigate;
	}

	part def OperationModule {
		attribute operationCapabilities : String[1..*];
		attribute precision : LengthValue;

		perform action execute : ExecuteOperation;
	}

	part def CommunicationModule {
		attribute communicationRange : LengthValue;
		attribute dataRate : Real;
		port dataPort : DataPort;

		perform action report : ReportCompletion;
	}

	part def PowerModule {
		attribute batteryCapacity : Real;
		attribute currentCharge : Real;
		port powerPort : PowerPort;
	}

	part def UbiquitousRobot {
		attribute robotID : String;
		attribute currentPosition : Position;
		attribute currentOrientation : Orientation;
		attribute operationalMode : OperationalMode;

		port commandInterface : CommandPort;

		part sensors : SensorModule {
			attribute redefines sensorRange = 50.0 [m];
			attribute redefines updateFrequency = 20.0 [Hz];
		}

		part navigation : NavigationModule {
			attribute redefines maxSpeed = 3.0 [m/s];
			attribute redefines positionAccuracy = 0.05 [m];
		}

		part operations : OperationModule {
			attribute redefines operationCapabilities = ("pick", "place", "inspect", "measure");
			attribute redefines precision = 0.01 [m];
		}

		part communications : CommunicationModule {
			attribute redefines communicationRange = 200.0 [m];
			attribute redefines dataRate = 10000.0;
		}

		part power : PowerModule {
			attribute redefines batteryCapacity = 5000.0;
			attribute redefines currentCharge = 5000.0;
		}

		connection sensorToNav connect sensors.sensorPort.data to navigation;
		connection navToOps connect navigation to operations;
		connection opsToComm connect operations to communications.dataPort;
		connection powerToAll connect power.powerPort to sensors;

		perform action primaryTask : PerformPrimaryTask;

		exhibit state behavior : UbiquitousRobotStateMachine;
	}

	part def ControlCenter {
		attribute centerID : String;
		port controlPort : CommandPort;

		action issueTask {
			out command : TaskCommand;
		}

		action processResult {
			in result : TaskResult;
		}
	}

	part def RoboticSystem {
		attribute systemID : String;
		attribute numberOfRobots : Integer;

		part ubiquitousRobot : UbiquitousRobot {
			attribute redefines robotID = "UBOT-001";
			attribute redefines operationalMode = OperationalMode::standby;
			attribute redefines currentPosition = Position {
				attribute x = 0.0 [m];
				attribute y = 0.0 [m];
				attribute z = 0.0 [m];
			}
			attribute redefines currentOrientation = Orientation {
				attribute roll = 0.0;
				attribute pitch = 0.0;
				attribute yaw = 0.0;
			}
		}

		part controlCenter : ControlCenter {
			attribute redefines centerID = "CC-MAIN";
		}

		connection taskLink connect controlCenter.controlPort to ubiquitousRobot.commandInterface;

		perform ubiquitousRobot.primaryTask;
	}

	requirement def SystemRequirement {
		doc /* Base requirement for the robotic system */
		subject system : RoboticSystem;
	}

	requirement def PrimaryTaskRequirement :> SystemRequirement {
		doc /* The robotic system shall perform its primary task using a Ubiquitous robot */
		
		require ubiquitousRobot.primaryTask;
		
		satisfy by ubiquitousRobot;
	}

	requirement def PerformanceRequirement :> SystemRequirement {
		doc /* The Ubiquitous robot shall navigate with accuracy within 0.05 meters */
		
		require constraint {
			ubiquitousRobot.navigation.positionAccuracy <= 0.05 [m]
		}
	}

	requirement def OperationalRequirement :> SystemRequirement {
		doc /* The Ubiquitous robot shall operate autonomously in active mode */
		
		require constraint {
			ubiquitousRobot.behavior.active.performTask == ubiquitousRobot.primaryTask
		}
	}

	requirement def CommunicationRequirement :> SystemRequirement {
		doc /* The Ubiquitous robot shall maintain communication within 200 meter range */
		
		require constraint {
			ubiquitousRobot.communications.communicationRange >= 200.0 [m]
		}
	}

	package LogicalModel {
		action def PerformAutonomousTask;
		part def AutonomousAgent;

		action performAutonomousTask : PerformAutonomousTask {
			action executeTask;
			action reportResults;
		}

		part autonomousAgent : AutonomousAgent {
			perform performAutonomousTask.executeTask;
		}
	}

	package PhysicalModel {
		private import LogicalModel::*;

		part roboticSystem : RoboticSystem {
			part redefines ubiquitousRobot {
				perform performAutonomousTask.executeTask;
			}
		}

		allocate autonomousAgent to roboticSystem.ubiquitousRobot {
			allocate autonomousAgent.executeTask to roboticSystem.ubiquitousRobot.operations.execute;
		}
	}

	part roboticSystemInstance : RoboticSystem {
		attribute redefines systemID = "ROBSYS-001";
		attribute redefines numberOfRobots = 1;
	}

	requirement primaryTaskReq : PrimaryTaskRequirement {
		subject roboticSystemInstance;
	}

	requirement performanceReq : PerformanceRequirement {
		subject roboticSystemInstance;
	}

	requirement operationalReq : OperationalRequirement {
		subject roboticSystemInstance;
	}

	requirement communicationReq : CommunicationRequirement {
		subject roboticSystemInstance;
	}

	satisfy roboticSystemInstance.ubiquitousRobot primaryTaskReq;
	satisfy roboticSystemInstance.ubiquitousRobot.navigation performanceReq;
	satisfy roboticSystemInstance.ubiquitousRobot operationalReq;
	satisfy roboticSystemInstance.ubiquitousRobot.communications communicationReq;
}
