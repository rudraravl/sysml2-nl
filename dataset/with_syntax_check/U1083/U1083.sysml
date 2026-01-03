package 'Home Robotic System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BatteryLevel :> Real;
	attribute def DistanceValue :> Real;
	attribute def AreaValue :> Real;
	attribute def EfficiencyRating :> Real;
	
	attribute def Position {
		attribute x : Real;
		attribute y : Real;
		attribute z : Real;
	}
	
	attribute def Velocity {
		attribute vx : Real;
		attribute vy : Real;
	}
	
	enum def OperationalMode {
		enum standby;
		enum active;
		enum maintenance;
		enum error;
	}
	
	enum def TaskType {
		enum cleaning;
		enum delivery;
		enum monitoring;
		enum charging;
	}
	
	enum def NavigationStatus {
		enum idle;
		enum planning;
		enum moving;
		enum arrived;
		enum blocked;
	}
	
	item def TaskCommand {
		attribute taskType : TaskType;
		attribute priority : Integer;
		attribute targetLocation : Position;
	}
	
	item def StatusUpdate {
		attribute mode : OperationalMode;
		attribute batteryLevel : BatteryLevel;
		attribute currentPosition : Position;
		attribute taskProgress : Real;
	}
	
	item def ObstacleAlert {
		attribute obstaclePosition : Position;
		attribute severity : Integer;
	}
	
	item def TaskCompletionReport {
		attribute taskType : TaskType;
		attribute completionTime : Real;
		attribute efficiency : EfficiencyRating;
		attribute success : Boolean;
	}
	
	item def ChargingRequest;
	item def ChargingComplete;
	item def EmergencyStop;
	item def ResumeOperation;
	
	port def CommandPort {
		in item taskCmd : TaskCommand;
		in item emergencyStop : EmergencyStop;
		in item resume : ResumeOperation;
		out item status : StatusUpdate;
	}
	
	port def SensorDataPort {
		out item obstacleAlert : ObstacleAlert;
		out batteryReading : BatteryLevel;
		out positionData : Position;
	}
	
	port def PowerPort {
		in item chargingSignal : ChargingComplete;
		out item chargingRequest : ChargingRequest;
		in powerSupply : PowerValue;
	}
	
	port def TaskReportPort {
		out item completionReport : TaskCompletionReport;
	}
	
	action def MonitorBatteryLevel {
		in currentLevel : BatteryLevel;
		out needsCharging : Boolean;
		out batteryStatus : BatteryLevel;
	}
	
	action def PlanNavigation {
		in startPos : Position;
		in targetPos : Position;
		out pathValid : Boolean;
		out estimatedDistance : DistanceValue;
	}
	
	action def ExecuteMovement {
		in targetPos : Position;
		in currentPos : Position;
		out finalPos : Position;
		out movementSuccess : Boolean;
	}
	
	action def DetectObstacles {
		in currentPos : Position;
		out obstacleDetected : Boolean;
		out obstacleLocation : Position;
	}
	
	action def PerformCleaningTask {
		in targetArea : AreaValue;
		out cleanedArea : AreaValue;
		out cleaningEfficiency : EfficiencyRating;
	}
	
	action def ReturnToChargingStation {
		in currentPos : Position;
		in stationPos : Position;
		out arrived : Boolean;
	}
	
	action def RechargeRobot {
		in currentBattery : BatteryLevel;
		out chargedBattery : BatteryLevel;
	}
	
	part def NavigationSystem {
		attribute currentPosition : Position;
		attribute targetPosition : Position;
		attribute navigationStatus : NavigationStatus;
		
		port sensorInput : SensorDataPort;
		
		perform action planNavigation : PlanNavigation;
		perform action executeMovement : ExecuteMovement;
	}
	
	part def CleaningSystem {
		attribute cleaningPower : PowerValue;
		attribute efficiency : EfficiencyRating;
		attribute operatingArea : AreaValue;
		
		perform action performCleaning : PerformCleaningTask;
	}
	
	part def BatterySystem {
		attribute capacity : Real;
		attribute currentCharge : BatteryLevel;
		attribute chargingRate : Real;
		
		port powerConnection : PowerPort;
		
		perform action monitorBattery : MonitorBatteryLevel;
		perform action recharge : RechargeRobot;
	}
	
	part def SensorArray {
		attribute sensorRange : DistanceValue;
		attribute detectionAccuracy : Real;
		
		port sensorOutput : SensorDataPort;
		
		perform action detectObstacles : DetectObstacles;
	}
	
	part def ControlSystem {
		attribute processingSpeed : Real;
		attribute memoryCapacity : Real;
		
		port commandInterface : CommandPort;
		port reportInterface : TaskReportPort;
	}
	
	part def HomeRobot {
		attribute robotId : String;
		attribute operationalMode : OperationalMode;
		attribute chargingStationLocation : Position;
		attribute taskTargetLocation : Position;
		attribute assignedArea : AreaValue;
		
		part navigation : NavigationSystem {
			attribute :>> currentPosition = Position { :>> x = 0.0; :>> y = 0.0; :>> z = 0.0; };
			attribute :>> navigationStatus = NavigationStatus::idle;
		}
		
		part cleaning : CleaningSystem {
			attribute :>> cleaningPower = 200.0[W];
			attribute :>> efficiency = 0.90;
			attribute :>> operatingArea = 50.0[m^2];
		}
		
		part battery : BatterySystem {
			attribute :>> capacity = 8000.0;
			attribute :>> currentCharge = 100.0;
			attribute :>> chargingRate = 50.0;
		}
		
		part sensors : SensorArray {
			attribute :>> sensorRange = 5.0[m];
			attribute :>> detectionAccuracy = 0.95;
		}
		
		part controller : ControlSystem {
			attribute :>> processingSpeed = 2.4;
			attribute :>> memoryCapacity = 16.0;
		}
		
		connect navigation.sensorInput to sensors.sensorOutput;
		connect controller.commandInterface to robotCommandInterface;
		connect battery.powerConnection to robotPowerInterface;
		
		port robotCommandInterface : CommandPort;
		port robotPowerInterface : PowerPort;
		
		exhibit state behavior : HomeRobotStateMachine;
	}
	
	action def PrimaryTaskExecution {
		in robot : HomeRobot;
		
		first start;
		then merge taskLoop;
		
		then action monitorBattery : MonitorBatteryLevel {
			in currentLevel = robot.battery.currentCharge;
			out needsCharging : Boolean;
			out batteryStatus : BatteryLevel;
		}
		
		then decide;
			if monitorBattery.needsCharging then returnToCharge;
			if not monitorBattery.needsCharging then checkObstacles;
		
		action returnToCharge : ReturnToChargingStation {
			in currentPos = robot.navigation.currentPosition;
			in stationPos = robot.chargingStationLocation;
			out arrived : Boolean;
		}
		
		then action recharge : RechargeRobot {
			in currentBattery = monitorBattery.batteryStatus;
			out chargedBattery : BatteryLevel;
		}
		then taskLoop;
		
		action checkObstacles : DetectObstacles {
			in currentPos = robot.navigation.currentPosition;
			out obstacleDetected : Boolean;
			out obstacleLocation : Position;
		}
		
		then decide;
			if checkObstacles.obstacleDetected then navigate;
			if not checkObstacles.obstacleDetected then executeTask;
		
		action navigate : PlanNavigation {
			in startPos = robot.navigation.currentPosition;
			in targetPos = robot.taskTargetLocation;
			out pathValid : Boolean;
			out estimatedDistance : DistanceValue;
		}
		
		then action move : ExecuteMovement {
			in targetPos = robot.taskTargetLocation;
			in currentPos = robot.navigation.currentPosition;
			out finalPos : Position;
			out movementSuccess : Boolean;
		}
		then taskLoop;
		
		action executeTask : PerformCleaningTask {
			in targetArea = robot.assignedArea;
			out cleanedArea : AreaValue;
			out cleaningEfficiency : EfficiencyRating;
		}
		then taskLoop;
	}
	
	state def HomeRobotStateMachine {
		entry; then standby;
		
		state standby;
		
		transition standby_to_active
			first standby
			accept TaskCommand
			then active;
		
		state active;
		
		transition active_to_navigating
			first active
			accept ObstacleAlert
			then navigating;
		
		transition active_to_charging
			first active
			if battery.currentCharge < 15.0
			then charging;
		
		transition active_to_error
			first active
			accept EmergencyStop
			then error;
		
		state navigating;
		
		transition navigating_to_active
			first navigating
			then active;
		
		transition navigating_to_error
			first navigating
			then error;
		
		state charging;
		
		transition charging_to_standby
			first charging
			accept ChargingComplete
			then standby;
		
		state error;
		
		transition error_to_standby
			first error
			accept ResumeOperation
			then standby;
	}
	
	part def ChargingStation {
		attribute stationId : String;
		attribute location : Position;
		attribute outputPower : PowerValue;
		
		port chargingPort : PowerPort;
	}
	
	part def ControlCenter {
		attribute centerId : String;
		
		port commandOutput : CommandPort;
		port reportInput : TaskReportPort;
	}
	
	requirement def PrimaryTaskRequirement {
		doc /* The robotic system shall perform its primary cleaning task with minimum 85% efficiency. */
		
		subject robot : HomeRobot;
		
		require constraint {
			robot.cleaning.efficiency >= 0.85
		}
	}
	
	requirement def BatteryManagementRequirement {
		doc /* The robot shall automatically return to charging station when battery drops below 15%. */
		
		subject robot : HomeRobot;
		
		require constraint {
			robot.battery.currentCharge < 15.0 implies 
			robot.operationalMode == OperationalMode::maintenance
		}
	}
	
	requirement def NavigationAccuracyRequirement {
		doc /* The robot shall navigate to target positions within 10cm accuracy. */
		
		subject navSys : NavigationSystem;
		
		attribute positionError : Real;
		
		require constraint {
			positionError <= 0.10
		}
	}
	
	requirement def ObstacleAvoidanceRequirement {
		doc /* The robot shall detect and avoid obstacles within its sensor range. */
		
		subject sensors : SensorArray;
		
		require constraint {
			sensors.detectionAccuracy >= 0.90
		}
	}
	
	requirement def OperationalTimeRequirement {
		doc /* The robot shall operate continuously for at least 120 minutes on full charge. */
		
		subject robot : HomeRobot;
		
		attribute operatingTime : Real;
		
		require constraint {
			operatingTime >= 120.0
		}
	}
	
	part def RoboticSystem {
		doc /* A robotic system that performs primary cleaning tasks using a home robot. */
		
		part homeRobot : HomeRobot {
			attribute :>> robotId = "HR-001";
			attribute :>> operationalMode = OperationalMode::standby;
			attribute :>> chargingStationLocation = Position { :>> x = 0.0; :>> y = 0.0; :>> z = 0.0; };
			attribute :>> taskTargetLocation = Position { :>> x = 10.0; :>> y = 10.0; :>> z = 0.0; };
			attribute :>> assignedArea = 50.0[m^2];
		}
		
		part chargingStation : ChargingStation {
			attribute :>> stationId = "CS-001";
			attribute :>> location = Position { :>> x = 0.0; :>> y = 0.0; :>> z = 0.0; };
			attribute :>> outputPower = 250.0[W];
		}
		
		part controlCenter : ControlCenter {
			attribute :>> centerId = "CC-001";
		}
		
		connect homeRobot.robotPowerInterface to chargingStation.chargingPort;
		connect controlCenter.commandOutput to homeRobot.robotCommandInterface;
		connect homeRobot.controller.reportInterface to controlCenter.reportInput;
		
		perform action executePrimaryTask : PrimaryTaskExecution {
			in robot = homeRobot;
		}
		
		satisfy primaryTaskReq : PrimaryTaskRequirement {
			subject robot = homeRobot;
		}
		
		satisfy batteryMgmtReq : BatteryManagementRequirement {
			subject robot = homeRobot;
		}
		
		satisfy navAccuracyReq : NavigationAccuracyRequirement {
			subject navSys = homeRobot.navigation;
		}
		
		satisfy obstacleAvoidReq : ObstacleAvoidanceRequirement {
			subject sensors = homeRobot.sensors;
		}
		
		satisfy opTimeReq : OperationalTimeRequirement {
			subject robot = homeRobot;
		}
	}
	
	part roboticSystemInstance : RoboticSystem {
		part :>> homeRobot {
			attribute :>> robotId = "HR-PROD-001";
			
			part :>> battery {
				attribute :>> currentCharge = 100.0;
			}
			
			part :>> navigation {
				attribute :>> currentPosition = Position {
					:>> x = 0.0;
					:>> y = 0.0;
					:>> z = 0.0;
				}
			}
			
			part :>> cleaning {
				attribute :>> efficiency = 0.92;
			}
			
			part :>> sensors {
				attribute :>> detectionAccuracy = 0.96;
			}
		}
		
		perform :>> executePrimaryTask {
			in :>> robot = homeRobot;
			
			action :>> monitorBattery {
				in :>> currentLevel = 100.0;
				out :>> needsCharging = false;
				out :>> batteryStatus = 100.0;
			}
			
			action :>> checkObstacles {
				in :>> currentPos = Position { :>> x = 0.0; :>> y = 0.0; :>> z = 0.0; };
				out :>> obstacleDetected = false;
			}
			
			action :>> executeTask {
				in :>> targetArea = 50.0[m^2];
				out :>> cleanedArea = 46.0[m^2];
				out :>> cleaningEfficiency = 0.92;
			}
		}
	}
}
