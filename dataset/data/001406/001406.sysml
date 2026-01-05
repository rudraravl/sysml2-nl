package 'Domestic Robotic System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	enum def RobotOperationalMode {
		enum standby;
		enum navigating;
		enum performing;
		enum returning;
		enum charging;
		enum fault;
	}
	
	enum def TaskType {
		enum vacuuming;
		enum mopping;
		enum dusting;
		enum organizing;
	}
	
	enum def SurfaceCategory {
		enum hardFloor;
		enum carpet;
		enum tile;
		enum wood;
	}
	
	attribute def BatteryPercentage :> Real;
	attribute def CleaningCoverage :> AreaValue;
	attribute def PositionCoordinate :> LengthValue;
	
	item def TaskCommand {
		attribute taskType : TaskType;
		attribute targetArea : AreaValue;
		attribute priority : Integer;
	}
	
	item def SensorData {
		attribute positionX : PositionCoordinate;
		attribute positionY : PositionCoordinate;
		attribute positionZ : PositionCoordinate;
		attribute obstaclePresent : Boolean;
		attribute proximityDistance : LengthValue;
		attribute surfaceType : SurfaceCategory;
	}
	
	item def StatusMessage {
		attribute mode : RobotOperationalMode;
		attribute batteryLevel : BatteryPercentage;
		attribute completedArea : CleaningCoverage;
		attribute timestamp : Real;
	}
	
	item def PowerFlow {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
	}
	
	port def TaskInputPort {
		in item taskCmd : TaskCommand;
	}
	
	port def SensorOutputPort {
		out item sensorData : SensorData;
	}
	
	port def StatusOutputPort {
		out item statusMsg : StatusMessage;
	}
	
	port def ChargingPort {
		inout item powerFlow : PowerFlow;
	}
	
	action def NavigateToTarget {
		in targetPosX : PositionCoordinate;
		in targetPosY : PositionCoordinate;
		in targetPosZ : PositionCoordinate;
		in currentPosX : PositionCoordinate;
		in currentPosY : PositionCoordinate;
		in currentPosZ : PositionCoordinate;
		out arrived : Boolean;
		out pathDistance : LengthValue;
	}
	
	action def ScanEnvironment {
		out environmentData : SensorData;
	}
	
	action def ExecuteCleaningTask {
		in taskType : TaskType;
		in surface : SurfaceCategory;
		in targetCoverage : AreaValue;
		out actualCoverage : CleaningCoverage;
		out taskComplete : Boolean;
	}
	
	action def MonitorPowerLevel {
		out batteryStatus : BatteryPercentage;
		out needsCharging : Boolean;
	}
	
	action def PerformCharging {
		in currentLevel : BatteryPercentage;
		out chargingComplete : Boolean;
	}
	
	action def AvoidObstacles {
		in obstacleDistance : LengthValue;
		out alternativePosX : PositionCoordinate;
		out alternativePosY : PositionCoordinate;
		out alternativePosZ : PositionCoordinate;
	}
	
	action def ReturnToBase {
		in basePosX : PositionCoordinate;
		in basePosY : PositionCoordinate;
		in basePosZ : PositionCoordinate;
		in currentPosX : PositionCoordinate;
		in currentPosY : PositionCoordinate;
		in currentPosZ : PositionCoordinate;
		out docked : Boolean;
	}
	
	state def DomesticRobotStates {
		entry; then standbyState;
		
		state standbyState;
		
		transition standby_to_navigating
			first standbyState
			accept TaskCommand
			then navigatingState;
		
		state navigatingState {
			entry action scanEnv : ScanEnvironment;
			do action navigate : NavigateToTarget;
			
			state subNavigation {
				entry; then moving;
				
				state moving;
				
				transition moving_to_avoiding
					first moving
					if scanEnv.environmentData.obstaclePresent
					then avoiding;
				
				state avoiding {
					do action avoid : AvoidObstacles;
				}
				
				transition avoiding_to_moving
					first avoiding
					then moving;
			}
		}
		
		transition navigating_to_performing
			first navigatingState
			if navigatingState.navigate.arrived
			then performingState;
		
		state performingState {
			do action executeTask : ExecuteCleaningTask;
			do action monitorPower : MonitorPowerLevel;
		}
		
		transition performing_to_returning_lowBattery
			first performingState
			if performingState.monitorPower.needsCharging
			then returningState;
		
		transition performing_to_returning_complete
			first performingState
			if performingState.executeTask.taskComplete
			then returningState;
		
		state returningState {
			do action returnHome : ReturnToBase;
		}
		
		transition returning_to_charging
			first returningState
			if returningState.returnHome.docked
			then chargingState;
		
		state chargingState {
			do action charge : PerformCharging;
		}
		
		transition charging_to_standby
			first chargingState
			if chargingState.charge.chargingComplete
			then standbyState;
	}
	
	part def NavigationModule {
		attribute currentLocationX : PositionCoordinate;
		attribute currentLocationY : PositionCoordinate;
		attribute currentLocationZ : PositionCoordinate;
		attribute homeLocationX : PositionCoordinate;
		attribute homeLocationY : PositionCoordinate;
		attribute homeLocationZ : PositionCoordinate;
		port sensorPort : SensorOutputPort;
		
		action pathPlanning : NavigateToTarget;
		action environmentScanning : ScanEnvironment;
		action collisionAvoidance : AvoidObstacles;
		action homing : ReturnToBase;
	}
	
	part def CleaningModule {
		attribute brushMotorPower : PowerValue;
		attribute vacuumSuctionPower : PowerValue;
		attribute mopPressure : PressureValue;
		attribute cleaningWidth : LengthValue;
		
		action taskExecution : ExecuteCleaningTask;
	}
	
	part def PowerModule {
		attribute batteryCapacity : EnergyValue;
		attribute currentChargeLevel : BatteryPercentage;
		attribute chargingRate : PowerValue;
		port chargingPort : ChargingPort;
		
		action powerMonitoring : MonitorPowerLevel;
		action batteryCharging : PerformCharging;
	}
	
	part def ControlModule {
		port taskInput : TaskInputPort;
		port statusOutput : StatusOutputPort;
		attribute currentMode : RobotOperationalMode;
		
		exhibit state operationalStates : DomesticRobotStates;
	}
	
	action def PerformDomesticCleaning;
	
	part def DomesticRobot {
		attribute robotIdentifier : String;
		attribute maximumSpeed : SpeedValue;
		attribute operatingWeight : MassValue;
		attribute dimensionX : LengthValue;
		attribute dimensionY : LengthValue;
		attribute dimensionZ : LengthValue;
		
		part navigation : NavigationModule {
			attribute :>> currentLocationX = 0.0[m];
			attribute :>> currentLocationY = 0.0[m];
			attribute :>> currentLocationZ = 0.0[m];
			attribute :>> homeLocationX = 0.0[m];
			attribute :>> homeLocationY = 0.0[m];
			attribute :>> homeLocationZ = 0.0[m];
		}
		
		part cleaning : CleaningModule {
			attribute :>> brushMotorPower = 80.0[W];
			attribute :>> vacuumSuctionPower = 120.0[W];
			attribute :>> mopPressure = 500.0[Pa];
			attribute :>> cleaningWidth = 0.25[m];
		}
		
		part power : PowerModule {
			attribute :>> batteryCapacity = 3600.0[W*h];
			attribute :>> currentChargeLevel = 100.0;
			attribute :>> chargingRate = 200.0[W];
		}
		
		part control : ControlModule {
			attribute :>> currentMode = RobotOperationalMode::standby;
		}
		
		connect navigation.sensorPort to control;
		connect power.chargingPort to cleaning;
		
		perform action primaryDomesticTask : PerformDomesticCleaning {
			first start;
			then merge operationLoop;
			
			then action receiveTask {
				out taskCmd : TaskCommand;
			}
			
			then action navigateToWorkArea : NavigateToTarget {
				in targetPosX = 5.0[m];
				in targetPosY = 3.0[m];
				in targetPosZ = 0.0[m];
				in currentPosX = navigation.currentLocationX;
				in currentPosY = navigation.currentLocationY;
				in currentPosZ = navigation.currentLocationZ;
			}
			
			then action performCleaning : ExecuteCleaningTask {
				in taskType = receiveTask.taskCmd.taskType;
				in surface = SurfaceCategory::hardFloor;
				in targetCoverage = receiveTask.taskCmd.targetArea;
			}
			
			then action checkPowerStatus : MonitorPowerLevel;
			
			then decide;
				if checkPowerStatus.needsCharging then initiateCharging;
				if performCleaning.taskComplete and not checkPowerStatus.needsCharging then returnToStandby;
				if not performCleaning.taskComplete and not checkPowerStatus.needsCharging then operationLoop;
			
			action initiateCharging {
				first returnToChargingStation;
				then chargeRobot;
				
				action returnToChargingStation : ReturnToBase {
					in basePosX = navigation.homeLocationX;
					in basePosY = navigation.homeLocationY;
					in basePosZ = navigation.homeLocationZ;
					in currentPosX = navigation.currentLocationX;
					in currentPosY = navigation.currentLocationY;
					in currentPosZ = navigation.currentLocationZ;
				}
				
				action chargeRobot : PerformCharging {
					in currentLevel = checkPowerStatus.batteryStatus;
				}
			}
			
			then operationLoop;
			
			action returnToStandby {
				then done;
			}
		}
	}
	
	part def ChargingStation {
		attribute stationLocationX : PositionCoordinate;
		attribute stationLocationY : PositionCoordinate;
		attribute stationLocationZ : PositionCoordinate;
		port powerOutput : ChargingPort;
		attribute outputVoltage : ElectricPotentialValue;
		attribute maxCurrent : ElectricCurrentValue;
		
		action supplyPower {
			out powerSupply : PowerFlow;
		}
	}
	
	part def RoboticSystem {
		part domesticRobot : DomesticRobot;
		part chargingStation : ChargingStation;
		
		connect chargingStation.powerOutput to domesticRobot.power.chargingPort;
		
		perform action systemOperation {
			perform domesticRobot.primaryDomesticTask;
		}
	}
	
	requirement def PrimaryTaskRequirement {
		doc /* The robotic system shall perform its primary domestic cleaning task using the domestic robot with minimum 90% coverage efficiency. */
		
		subject system : RoboticSystem;
		
		require constraint {
			system.domesticRobot.cleaning.taskExecution.actualCoverage >= 
				0.9 * system.domesticRobot.cleaning.taskExecution.targetCoverage
		}
	}
	
	requirement def BatteryEnduranceRequirement {
		doc /* The domestic robot shall operate continuously for at least 90 minutes on a full charge. */
		
		subject robot : DomesticRobot;
		
		require constraint {
			robot.power.batteryCapacity >= 180.0[W*h]
		}
	}
	
	requirement def NavigationAccuracyRequirement {
		doc /* The domestic robot shall navigate to target locations with position accuracy within 0.05 meters. */
		
		subject robot : DomesticRobot;
		
		require constraint {
			robot.navigation.pathPlanning.pathDistance < 0.05[m]
		}
	}
	
	requirement def ObstacleAvoidanceRequirement {
		doc /* The domestic robot shall detect and avoid obstacles at distances greater than 0.2 meters. */
		
		subject robot : DomesticRobot;
		
		require constraint {
			robot.navigation.environmentScanning.environmentData.proximityDistance > 0.2[m]
		}
	}
	
	part roboticCleaningSystem : RoboticSystem {
		part :>> domesticRobot {
			attribute :>> robotIdentifier = "DR-2024-001";
			attribute :>> maximumSpeed = 0.8[m/s];
			attribute :>> operatingWeight = 4.5[kg];
			attribute :>> dimensionX = 0.35[m];
			attribute :>> dimensionY = 0.35[m];
			attribute :>> dimensionZ = 0.10[m];
			
			part :>> navigation {
				perform primaryDomesticTask.navigateToWorkArea;
				perform primaryDomesticTask.receiveTask;
				perform primaryDomesticTask.initiateCharging.returnToChargingStation;
			}
			
			part :>> cleaning {
				perform primaryDomesticTask.performCleaning;
			}
			
			part :>> power {
				perform primaryDomesticTask.checkPowerStatus;
				perform primaryDomesticTask.initiateCharging.chargeRobot;
			}
			
			part :>> control {
				perform primaryDomesticTask;
			}
			
			satisfy primaryReq : PrimaryTaskRequirement {
				subject system = roboticCleaningSystem;
			}
			
			satisfy enduranceReq : BatteryEnduranceRequirement {
				subject robot = roboticCleaningSystem.domesticRobot;
			}
			
			satisfy accuracyReq : NavigationAccuracyRequirement {
				subject robot = roboticCleaningSystem.domesticRobot;
			}
			
			satisfy avoidanceReq : ObstacleAvoidanceRequirement {
				subject robot = roboticCleaningSystem.domesticRobot;
			}
		}
		
		part :>> chargingStation {
			attribute :>> stationLocationX = 0.0[m];
			attribute :>> stationLocationY = 0.0[m];
			attribute :>> stationLocationZ = 0.0[m];
			attribute :>> outputVoltage = 24.0[V];
			attribute :>> maxCurrent = 10.0[A];
		}
	}
	
	verification def VerifyCleaningPerformance {
		subject testRobot : DomesticRobot;
		
		objective verifyTaskCompletion {
			doc /* Verify that the domestic robot completes cleaning tasks with required coverage. */
		}
		
		return verdict : Boolean;
	}
	
	part def TestEnvironment {
		part testFloor {
			attribute floorArea : AreaValue;
			attribute floorType : SurfaceCategory;
		}
		
		part obstacleArray {
			attribute obstacleCount : Integer;
		}
	}
	
	verification cleaningPerformanceTest : VerifyCleaningPerformance {
		subject testRobot :> roboticCleaningSystem.domesticRobot;
	}
	
	part testEnvironment : TestEnvironment {
		perform cleaningPerformanceTest;
		
		part :>> testFloor {
			attribute :>> floorArea = 25.0[m^2];
			attribute :>> floorType = SurfaceCategory::hardFloor;
		}
		
		part :>> obstacleArray {
			attribute :>> obstacleCount = 5;
		}
	}
}
