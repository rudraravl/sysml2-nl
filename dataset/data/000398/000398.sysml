package 'Robotic System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	enum def RobotOperationalMode {
		enum standby;
		enum active;
		enum charging;
		enum maintenance;
		enum fault;
	}
	
	enum def TaskType {
		enum delivery;
		enum cleaning;
		enum surveillance;
		enum assistance;
	}
	
	enum def TaskOutcome {
		enum success;
		enum failure;
		enum partial;
		enum aborted;
	}
	
	attribute def BatteryCapacity :> Real;
	
	attribute def Position3D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}
	
	attribute def Velocity3D {
		attribute vx : SpeedValue;
		attribute vy : SpeedValue;
		attribute vz : SpeedValue;
	}
	
	item def TaskCommand {
		attribute taskId : String;
		attribute taskType : TaskType;
		attribute priority : Integer;
		attribute targetLocation : Position3D;
		attribute deadline : TimeValue;
	}
	
	item def TaskReport {
		attribute taskId : String;
		attribute outcome : TaskOutcome;
		attribute completionTime : TimeValue;
		attribute energyConsumed : EnergyValue;
	}
	
	item def SensorReading {
		attribute timestamp : TimeValue;
		attribute position : Position3D;
		attribute obstacleDistance : LengthValue;
		attribute temperature : TemperatureValue;
	}
	
	item def PowerSignal {
		attribute voltage : Real;
		attribute current : Real;
		attribute powerLevel : Real;
	}
	
	item def NavigationData {
		attribute currentPosition : Position3D;
		attribute currentVelocity : Velocity3D;
		attribute heading : Real;
	}
	
	item def LowBatteryAlert;
	item def TaskCompleteSignal;
	item def ChargingCompleteSignal;
	item def FaultDetectedSignal;
	item def ResetSignal;
	
	port def TaskCommandPort {
		in item command : TaskCommand;
	}
	
	port def TaskReportPort {
		out item report : TaskReport;
	}
	
	port def SensorPort {
		out item reading : SensorReading;
	}
	
	port def PowerInputPort {
		in item power : PowerSignal;
	}
	
	port def PowerOutputPort {
		out item power : PowerSignal;
	}
	
	port def NavigationPort {
		out item navData : NavigationData;
	}
	
	action def MonitorBatteryLevel {
		in currentCharge : BatteryCapacity;
		in threshold : Real;
		out needsCharging : Boolean;
	}
	
	action def PlanPath {
		in startPosition : Position3D;
		in targetPosition : Position3D;
		in sensorData : SensorReading;
		out waypoints : Position3D[1..*];
	}
	
	action def NavigateToLocation {
		in targetPosition : Position3D;
		in currentPosition : Position3D;
		out arrived : Boolean;
		out navigationData : NavigationData;
	}
	
	action def ExecuteTaskAction {
		in taskCommand : TaskCommand;
		in sensorData : SensorReading;
		out taskResult : TaskOutcome;
	}
	
	action def PerformCharging {
		in currentCharge : BatteryCapacity;
		in maxCapacity : BatteryCapacity;
		out chargeComplete : Boolean;
	}
	
	action def ScanEnvironment {
		out sensorReading : SensorReading;
	}
	
	action def DiagnoseFault {
		in faultSignal : FaultDetectedSignal;
		out faultCode : String;
		out recoverable : Boolean;
	}
	
	state def PersonalRobotStateMachine {
		entry; then standbyState;
		
		state standbyState;
		
		transition standbyToActive
			first standbyState
			accept TaskCommand
			if batteryLevel > 20.0
			then activeState;
		
		transition standbyToCharging
			first standbyState
			accept LowBatteryAlert
			then chargingState;
		
		state activeState {
			entry; then planning;
			
			state planning;
			
			transition planToNavigating
				first planning
				if pathPlanned
				then navigating;
			
			state navigating;
			
			transition navigatingToExecuting
				first navigating
				if arrivedAtTarget
				then executing;
			
			state executing;
			
			transition executingToReporting
				first executing
				if taskCompleted
				then reporting;
			
			state reporting;
			
			transition reportingToDone
				first reporting
				then done;
		}
		
		transition activeToStandby
			first activeState
			accept TaskCompleteSignal
			then standbyState;
		
		transition activeToCharging
			first activeState
			accept LowBatteryAlert
			then chargingState;
		
		state chargingState;
		
		transition chargingToStandby
			first chargingState
			accept ChargingCompleteSignal
			then standbyState;
		
		transition anyToFault
			first standbyState, activeState, chargingState
			accept FaultDetectedSignal
			then faultState;
		
		state faultState {
			entry; then diagnosing;
			
			state diagnosing;
			
			transition diagnosingToRecovering
				first diagnosing
				if faultRecoverable
				then recovering;
			
			state recovering;
			
			transition recoveringToDone
				first recovering
				then done;
		}
		
		transition faultToStandby
			first faultState
			accept ResetSignal
			then standbyState;
	}
	
	part def PerceptionSystem {
		attribute sensorCount : Integer;
		attribute detectionRange : LengthValue;
		
		port sensorOutput : SensorPort;
		
		action scan : ScanEnvironment {
			out reading : SensorReading;
		}
		
		perform scan;
	}
	
	part def NavigationSystem {
		attribute currentPosition : Position3D;
		attribute currentVelocity : Velocity3D;
		
		port navOutput : NavigationPort;
		
		action planRoute : PlanPath {
			in start : Position3D;
			in target : Position3D;
			in sensors : SensorReading;
			out path : Position3D[1..*];
		}
		
		action navigate : NavigateToLocation {
			in target : Position3D;
			in current : Position3D;
			out reached : Boolean;
			out navData : NavigationData;
		}
		
		perform planRoute;
		perform navigate;
	}
	
	part def TaskExecutionSystem {
		attribute activeTaskId : String;
		attribute taskHistory : Integer;
		
		action executeTask : ExecuteTaskAction {
			in task : TaskCommand;
			in sensors : SensorReading;
			out result : TaskOutcome;
		}
		
		perform executeTask;
	}
	
	part def PowerManagementSystem {
		attribute batteryCapacity : BatteryCapacity;
		attribute currentCharge : BatteryCapacity;
		attribute chargingRate : Real;
		
		port powerIn : PowerInputPort;
		
		action monitorPower : MonitorBatteryLevel {
			in charge : BatteryCapacity;
			in limit : Real;
			out lowBattery : Boolean;
		}
		
		action charge : PerformCharging {
			in current : BatteryCapacity;
			in max : BatteryCapacity;
			out complete : Boolean;
		}
		
		perform monitorPower;
		perform charge;
	}
	
	part def ControlSystem {
		attribute systemMode : RobotOperationalMode;
		attribute taskQueue : Integer;
		
		perform robotControl : PersonalRobotStateMachine;
		
		action processCommand {
			in cmd : TaskCommand;
			out accepted : Boolean;
		}
		
		action coordinateSubsystems {
			in sensorInput : SensorReading;
			in navInput : NavigationData;
			in powerStatus : BatteryCapacity;
			out controlSignals : String;
		}
		
		action generateReport {
			in taskId : String;
			in outcome : TaskOutcome;
			out report : TaskReport;
		}
		
		perform processCommand;
		perform coordinateSubsystems;
		perform generateReport;
	}
	
	part def PersonalRobot {
		attribute robotId : String;
		attribute operationalMode : RobotOperationalMode;
		attribute batteryLevel : BatteryCapacity;
		attribute pathPlanned : Boolean;
		attribute arrivedAtTarget : Boolean;
		attribute taskCompleted : Boolean;
		attribute faultRecoverable : Boolean;
		
		port taskInput : TaskCommandPort;
		port taskOutput : TaskReportPort;
		port powerInput : PowerInputPort;
		
		part perception : PerceptionSystem {
			attribute redefines sensorCount = 6;
			attribute redefines detectionRange = 10.0 [m];
		}
		
		part navigation : NavigationSystem {
			attribute redefines currentPosition = Position3D {
				attribute redefines x = 0.0 [m];
				attribute redefines y = 0.0 [m];
				attribute redefines z = 0.0 [m];
			}
			attribute redefines currentVelocity = Velocity3D {
				attribute redefines vx = 0.0 [m/s];
				attribute redefines vy = 0.0 [m/s];
				attribute redefines vz = 0.0 [m/s];
			}
		}
		
		part taskExecutor : TaskExecutionSystem {
			attribute redefines taskHistory = 0;
		}
		
		part powerManagement : PowerManagementSystem {
			attribute redefines batteryCapacity = 100.0;
			attribute redefines currentCharge = 100.0;
			attribute redefines chargingRate = 5.0;
		}
		
		part controller : ControlSystem {
			attribute redefines systemMode = RobotOperationalMode::standby;
			attribute redefines taskQueue = 0;
		}
		
		connect powerManagement.powerIn to powerInput;
		
		perform controller.robotControl;
	}
	
	action def RoboticSystemPrimaryTask {
		first start;
		
		then action initializeSystem {
			out robot : PersonalRobot;
		}
		
		then merge operationalLoop;
		
		then action monitorSystemStatus {
			in robot : PersonalRobot;
			out batteryOk : Boolean;
			out systemHealthy : Boolean;
		}
		
		then decide;
			if monitorSystemStatus.batteryOk and monitorSystemStatus.systemHealthy then awaitTask;
			if not monitorSystemStatus.batteryOk then initiateCharging;
			if not monitorSystemStatus.systemHealthy then handleFault;
		
		action awaitTask {
			out receivedCommand : TaskCommand;
		}
		then performPrimaryTask;
		
		action performPrimaryTask {
			in taskCmd : TaskCommand = awaitTask.receivedCommand;
			
			first start;
			
			then action scanSurroundings {
				out environmentData : SensorReading;
			}
			
			then action planTaskExecution {
				in task : TaskCommand = taskCmd;
				in sensorData : SensorReading = scanSurroundings.environmentData;
				out executionPlan : Position3D[1..*];
			}
			
			then action navigateToTaskLocation {
				in targetPos : Position3D = taskCmd.targetLocation;
				out navigationComplete : Boolean;
			}
			
			then decide;
				if navigateToTaskLocation.navigationComplete then executeTaskAtLocation;
				if not navigateToTaskLocation.navigationComplete then abortTask;
			
			action executeTaskAtLocation {
				in task : TaskCommand = taskCmd;
				in sensors : SensorReading = scanSurroundings.environmentData;
				out executionResult : TaskOutcome;
			}
			then reportTaskCompletion;
			
			action abortTask {
				out abortReason : String;
			}
			then reportTaskCompletion;
			
			action reportTaskCompletion {
				in taskId : String = taskCmd.taskId;
				out report : TaskReport;
			}
			then done;
		}
		
		then action sendTaskReport {
			in report : TaskReport = performPrimaryTask.reportTaskCompletion.report;
		}
		then operationalLoop;
		
		action initiateCharging {
			first start;
			
			then action navigateToChargingStation {
				out arrived : Boolean;
			}
			
			then action connectToPower;
			
			then merge chargingCycle;
			
			then action checkChargeLevel {
				out fullyCharged : Boolean;
			}
			
			then decide;
				if checkChargeLevel.fullyCharged then disconnectFromPower;
				if not checkChargeLevel.fullyCharged then chargingCycle;
			
			action disconnectFromPower;
			then done;
		}
		then operationalLoop;
		
		action handleFault {
			first start;
			
			then action diagnoseProblem : DiagnoseFault {
				out errorCode : String;
				out canRecover : Boolean;
			}
			
			then decide;
				if diagnoseProblem.canRecover then attemptRecovery;
				if not diagnoseProblem.canRecover then requestMaintenance;
			
			action attemptRecovery {
				in errorCode : String = diagnoseProblem.errorCode;
				out recovered : Boolean;
			}
			then done;
			
			action requestMaintenance {
				out maintenanceRequest : String;
			}
			then done;
		}
		then operationalLoop;
		
		then done;
	}
	
	part def ChargingStation {
		attribute stationId : String;
		attribute maxPowerOutput : Real;
		
		port powerOutput : PowerOutputPort;
		
		action supplyPower {
			out power : PowerSignal;
		}
	}
	
	part def TaskDispatcher {
		attribute dispatcherId : String;
		
		port commandOutput : TaskCommandPort;
		port reportInput : TaskReportPort;
		
		action dispatchTask {
			in taskType : TaskType;
			in priority : Integer;
			out command : TaskCommand;
		}
		
		action receiveReport {
			in report : TaskReport;
		}
	}
	
	part def OperatingEnvironment {
		attribute environmentType : String;
		attribute areaSize : LengthValue;
	}
	
	part def RoboticSystem {
		part personalRobot : PersonalRobot {
			attribute redefines robotId = "PR-001";
			attribute redefines operationalMode = RobotOperationalMode::standby;
			attribute redefines batteryLevel = 100.0;
		}
		
		part chargingStation : ChargingStation {
			attribute redefines stationId = "CS-001";
			attribute redefines maxPowerOutput = 500.0;
		}
		
		part taskDispatcher : TaskDispatcher {
			attribute redefines dispatcherId = "TD-001";
		}
		
		part environment : OperatingEnvironment {
			attribute redefines environmentType = "Indoor";
			attribute redefines areaSize = 100.0 [m];
		}
		
		connect chargingStation.powerOutput to personalRobot.powerInput;
		
		perform systemOperation : RoboticSystemPrimaryTask;
	}
	
	requirement def SafetyRequirements {
		doc /* The robotic system shall operate safely in human-occupied environments */
		
		require obstacleDetection {
			doc /* The personal robot shall detect obstacles within 2 meters with 99% accuracy */
		}
		
		require collisionAvoidance {
			doc /* The personal robot shall avoid collisions by maintaining minimum 0.5 meter clearance */
		}
		
		require emergencyStop {
			doc /* The personal robot shall execute emergency stop within 0.3 seconds of fault detection */
		}
	}
	
	requirement def PerformanceRequirements {
		doc /* The robotic system shall meet specified performance criteria */
		
		require taskCompletionRate {
			doc /* The personal robot shall complete assigned tasks with 95% success rate */
		}
		
		require batteryEndurance {
			doc /* The personal robot shall operate continuously for minimum 6 hours on full charge */
		}
		
		require responseTime {
			doc /* The personal robot shall respond to task commands within 1 second */
		}
		
		require navigationAccuracy {
			doc /* The personal robot shall navigate to target locations within 0.1 meter accuracy */
		}
	}
	
	requirement def FunctionalRequirements {
		doc /* The robotic system shall provide required functional capabilities */
		
		require primaryTaskExecution {
			doc /* The personal robot shall autonomously execute its primary task from command to completion */
		}
		
		require autonomousNavigation {
			doc /* The personal robot shall navigate autonomously using onboard sensors */
		}
		
		require autonomousCharging {
			doc /* The personal robot shall autonomously return to charging station when battery is low */
		}
		
		require faultRecovery {
			doc /* The personal robot shall attempt automatic recovery from recoverable faults */
		}
	}
	
	requirement def SystemRequirements {
		doc /* Overall requirements for the robotic system */
		
		subject roboticSystem : RoboticSystem;
		
		require safety : SafetyRequirements;
		require performance : PerformanceRequirements;
		require functional : FunctionalRequirements;
		
		assume operatingConditions {
			doc /* System operates in controlled indoor environment with flat surfaces and adequate lighting */
		}
		
		require primaryTaskCapability {
			doc /* The robotic system shall perform its primary task using a personal robot with full autonomy */
		}
	}
	
	part roboticSystemInstance : RoboticSystem;
	
	satisfy systemRequirementsSatisfaction {
		subject roboticSystemInstance;
		requirement SystemRequirements;
	}
}
