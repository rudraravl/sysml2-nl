package SymboticAutomatedWarehouseSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def CaseID :> String;
	attribute def GridCoordinate :> Integer;
	attribute def TaskPriority :> Integer;
	
	item def ProductCase {
		attribute caseID : CaseID;
		attribute mass : MassValue;
		attribute sku : String;
		attribute dimensions : LengthValue[3];
	}
	
	item def StorageTask {
		attribute taskID : String;
		attribute priority : TaskPriority;
		attribute targetCase : CaseID;
		attribute sourceLocation : GridCoordinate[3];
		attribute destinationLocation : GridCoordinate[3];
		attribute taskType : String;
	}
	
	item def RobotStatus {
		attribute robotID : String;
		attribute position : GridCoordinate[3];
		attribute batteryLevel : Real;
		attribute loadStatus : Boolean;
		attribute currentTask : String;
	}
	
	item def InventoryRecord {
		attribute caseID : CaseID;
		attribute storageLocation : GridCoordinate[3];
		attribute timestamp : Real;
	}
	
	attribute def ThroughputRate :> Real;
	
	attribute def GridDimension {
		attribute rows : GridCoordinate;
		attribute columns : GridCoordinate;
		attribute levels : GridCoordinate;
	}
	
	port def RobotCommandPort {
		out item taskOut : StorageTask;
		in item statusIn : RobotStatus;
	}
	
	port def ConveyorPort {
		in item caseIn : ProductCase;
		out item caseOut : ProductCase;
	}
	
	port def StorageInterfacePort {
		in item storageRequest : StorageTask;
		out item inventoryUpdate : InventoryRecord;
	}
	
	part def AutonomousMobileRobot {
		attribute robotID : String;
		attribute maxVelocity : SpeedValue;
		attribute maxLoad : MassValue;
		attribute batteryCapacity : Real;
		attribute currentBattery : Real;
		attribute currentVelocity : SpeedValue;
		attribute loadStatus : Boolean;
		attribute taskValid : Boolean;
		attribute arrivedAtSource : Boolean;
		attribute caseSecured : Boolean;
		attribute arrivedAtDestination : Boolean;
		attribute caseStored : Boolean;
		attribute maintenanceComplete : Boolean;
		
		port commandInterface : RobotCommandPort;
		
		part navigationModule {
			attribute currentX : GridCoordinate;
			attribute currentY : GridCoordinate;
			attribute currentZ : GridCoordinate;
		}
		
		part liftingMechanism {
			attribute maxHeight : LengthValue;
			attribute liftSpeed : SpeedValue;
		}
		
		part powerSystem {
			attribute voltage : Real;
			attribute remainingCharge : Real;
		}
		
		perform action executeStorageTask;
	}
	
	part def HighDensityStorageStructure {
		attribute gridDimensions : GridDimension;
		attribute totalSlots : Integer;
		attribute occupiedSlots : Integer;
		attribute utilizationRate : Real;
		
		port storageAccess : StorageInterfacePort;
		
		part storageGrid[*] {
			attribute slotID : GridCoordinate[3];
			attribute occupied : Boolean;
			attribute storedCase : CaseID;
		}
		
		part structuralFramework {
			attribute height : LengthValue;
			attribute loadCapacity : MassValue;
		}
	}
	
	part def IntelligentControlSystem {
		attribute activeTaskCount : Integer;
		attribute completedTaskCount : Integer;
		
		port robotControl : RobotCommandPort[*];
		
		part taskOrchestrator {
			attribute queuedTasks : Integer;
			attribute taskThroughput : ThroughputRate;
		}
		
		part inventoryManagementSystem {
			attribute totalInventory : Integer;
			attribute inventoryAccuracy : Real;
		}
		
		part pathOptimizationEngine {
			attribute activeRoutes : Integer;
			attribute optimizationAlgorithm : String;
		}
		
		part warehouseManagementInterface {
			attribute connectedSystems : Integer;
		}
		
		perform action orchestrateWarehouseOperations;
	}
	
	part def ConveyorNetwork {
		attribute totalLength : LengthValue;
		attribute operatingSpeed : SpeedValue;
		attribute throughputCapacity : Integer;
		
		port inductionPort : ConveyorPort;
		port dispatchPort : ConveyorPort;
		
		part inductionConveyor {
			attribute position : LengthValue;
			attribute sensorCount : Integer;
		}
		
		part distributionConveyor {
			attribute position : LengthValue;
			attribute sortingCapability : Boolean;
		}
		
		part transferConveyor {
			attribute segments : Integer;
		}
	}
	
	action def NavigateToGridLocation {
		in startX : GridCoordinate;
		in startY : GridCoordinate;
		in startZ : GridCoordinate;
		in targetX : GridCoordinate;
		in targetY : GridCoordinate;
		in targetZ : GridCoordinate;
		in velocity : SpeedValue;
		out finalX : GridCoordinate;
		out finalY : GridCoordinate;
		out finalZ : GridCoordinate;
		out travelDuration : TimeValue;
	}
	
	action def RetrieveCase {
		in caseLocation : GridCoordinate[3];
		in caseWeight : MassValue;
		out retrievedCase : CaseID;
		out operationSuccess : Boolean;
	}
	
	action def StoreCase {
		in productCase : CaseID;
		in storageLocation : GridCoordinate[3];
		out operationSuccess : Boolean;
		out storageTime : TimeValue;
	}
	
	action def UpdateInventory {
		in caseID : CaseID;
		in location : GridCoordinate[3];
		in operation : String;
		out inventoryRecord : InventoryRecord;
	}
	
	action def OptimizeTaskSequence {
		in pendingTasks : StorageTask[*];
		in robotAvailability : RobotStatus[*];
		out optimizedSequence : StorageTask[*];
		out assignedRobots : String[*];
	}
	
	action def RobotStorageOperation {
		in batteryCapacity : Real;
		in currentBattery : Real;
		
		first start;
		then action receiveTask {
			out assignedTask : StorageTask;
		}
		then action navigateToSource : NavigateToGridLocation {
			in startX;
			in startY;
			in startZ;
			in targetX = receiveTask.assignedTask.sourceLocation[0];
			in targetY = receiveTask.assignedTask.sourceLocation[1];
			in targetZ = receiveTask.assignedTask.sourceLocation[2];
			in velocity;
			out finalX;
			out finalY;
			out finalZ;
		}
		then action retrieveProduct : RetrieveCase {
			in caseLocation = receiveTask.assignedTask.sourceLocation;
			in caseWeight;
			out retrievedCase;
			out operationSuccess;
		}
		then decide;
			if retrieveProduct.operationSuccess then navigateToDestination;
			if not retrieveProduct.operationSuccess then reportError;
		action navigateToDestination : NavigateToGridLocation {
			in startX = navigateToSource.finalX;
			in startY = navigateToSource.finalY;
			in startZ = navigateToSource.finalZ;
			in targetX = receiveTask.assignedTask.destinationLocation[0];
			in targetY = receiveTask.assignedTask.destinationLocation[1];
			in targetZ = receiveTask.assignedTask.destinationLocation[2];
			in velocity;
			out finalX;
			out finalY;
			out finalZ;
		}
		then action storeProduct : StoreCase {
			in productCase = retrieveProduct.retrievedCase;
			in storageLocation = receiveTask.assignedTask.destinationLocation;
			out operationSuccess;
		}
		then action updateRecord : UpdateInventory {
			in caseID = retrieveProduct.retrievedCase;
			in location = receiveTask.assignedTask.destinationLocation;
			in operation = "STORE";
			out inventoryRecord;
		}
		then action reportCompletion {
			in status : RobotStatus;
		}
		then evaluateBattery;
		action reportError {
			in errorStatus : RobotStatus;
		}
		then evaluateBattery;
		merge evaluateBattery;
		then decide;
			if currentBattery < 20.0 then recharge;
			if currentBattery >= 20.0 then done;
		action recharge {
			in currentLevel : Real;
			out finalLevel : Real;
		}
		then done;
	}
	
	action def WarehouseOperationCycle {
		first start;
		then merge operationLoop;
		then action receiveCaseInduction {
			out incomingCase : ProductCase;
		}
		then action determineStorageLocation {
			in productCase : ProductCase = receiveCaseInduction.incomingCase;
			out optimalLocation : GridCoordinate[3];
			out storageUtilization : Real;
		}
		then action optimizeTasks : OptimizeTaskSequence {
			in pendingTasks;
			in robotAvailability;
			out optimizedSequence;
			out assignedRobots;
		}
		then action dispatchRobots {
			in robotIDs : String[*] = optimizeTasks.assignedRobots;
			in tasks : StorageTask[*] = optimizeTasks.optimizedSequence;
		}
		then action monitorProgress {
			in robotStatuses : RobotStatus[*];
			out allTasksComplete : Boolean;
			out systemThroughput : ThroughputRate;
		}
		then decide;
			if monitorProgress.allTasksComplete then updateSystemMetrics;
			if not monitorProgress.allTasksComplete then operationLoop;
		action updateSystemMetrics {
			in throughput : ThroughputRate;
			in utilization : Real;
		}
		then operationLoop;
	}
	
	state def RobotOperationalState {
		in batteryCapacity : Real;
		in maxVelocity : SpeedValue;
		in currentBattery : Real;
		in currentVelocity : SpeedValue;
		in loadStatus : Boolean;
		in taskValid : Boolean;
		in arrivedAtSource : Boolean;
		in caseSecured : Boolean;
		in arrivedAtDestination : Boolean;
		in caseStored : Boolean;
		in maintenanceComplete : Boolean;
		
		entry; then idle;
		
		state idle;
		
		transition idle_to_tasked
			first idle
			accept task : StorageTask
			then tasked;
		
		state tasked;
		
		transition tasked_to_traveling
			first tasked
			if taskValid
			then traveling;
		
		state traveling;
		
		transition traveling_to_retrieving
			first traveling
			if arrivedAtSource
			then retrieving;
		
		state retrieving;
		
		transition retrieving_to_loaded
			first retrieving
			if caseSecured
			then loaded;
		
		state loaded;
		
		transition loaded_to_transporting
			first loaded
			then transporting;
		
		state transporting;
		
		transition transporting_to_storing
			first transporting
			if arrivedAtDestination
			then storing;
		
		state storing;
		
		transition storing_to_idle
			first storing
			if caseStored
			then idle;
		
		state charging;
		
		transition low_battery_to_charging
			first idle
			if currentBattery < 15.0
			then charging;
		
		transition charging_to_idle
			first charging
			if currentBattery >= 95.0
			then idle;
		
		state maintenance;
		
		transition any_to_maintenance
			first idle
			accept maintenanceRequest
			then maintenance;
		
		transition maintenance_to_idle
			first maintenance
			if maintenanceComplete
			then idle;
	}
	
	requirement def SystemRequirements {
		doc /* The Symbotic automated warehouse system shall provide high-throughput, 
		       high-density storage and retrieval of product cases using autonomous 
		       mobile robots operating within a structured storage grid. */
		
		requirement <'SYS-001'> primaryFunction {
			doc /* The system shall autonomously store and retrieve product cases 
			       from a high-density storage structure using coordinated mobile robots, 
			       conveyor systems, and intelligent control software. */
			subject system : SymboticWarehouse;
		}
		
		requirement <'SYS-002'> throughputCapacity {
			doc /* The system shall achieve a minimum throughput of 400 cases per hour 
			       during normal operations. */
			subject system : SymboticWarehouse;
			require constraint {
				system.operationalThroughput >= 400.0
			}
		}
		
		requirement <'SYS-003'> storageUtilization {
			doc /* The storage structure shall maintain at least 90% space utilization 
			       under steady-state conditions. */
			subject storage : HighDensityStorageStructure;
			require constraint {
				storage.utilizationRate >= 0.90
			}
		}
		
		requirement <'SYS-004'> robotFleetAvailability {
			doc /* The robot fleet shall maintain 98% operational availability during 
			       scheduled operating hours. */
			subject robots : AutonomousMobileRobot[*];
			require constraint {
				robots.fleetAvailability >= 0.98
			}
		}
		
		requirement <'SYS-005'> inventoryAccuracy {
			doc /* The system shall maintain 99.9% inventory location accuracy. */
			subject controller : IntelligentControlSystem;
			require constraint {
				controller.inventoryManagementSystem.inventoryAccuracy >= 0.999
			}
		}
		
		requirement <'SYS-006'> retrievalLatency {
			doc /* The system shall retrieve requested cases within 3 minutes of 
			       order receipt under normal load conditions. */
			subject system : SymboticWarehouse;
			require constraint {
				system.averageRetrievalTime <= 180.0
			}
		}
	}
	
	part def SymboticWarehouse {
		attribute operationalThroughput : Real;
		attribute averageRetrievalTime : Real;
		attribute systemUptime : Real;
		
		part centralController : IntelligentControlSystem {
			:>> activeTaskCount = 0;
			:>> completedTaskCount = 0;
			
			perform action warehouseControl : WarehouseOperationCycle;
		}
		
		part storageStructure : HighDensityStorageStructure {
			:>> totalSlots = 125000;
			:>> occupiedSlots = 112500;
			:>> utilizationRate = 0.90;
		}
		
		part robotFleet : AutonomousMobileRobot[30] {
			:>> maxVelocity = 3.0 [m/s];
			:>> maxLoad = 50.0 [kg];
			:>> batteryCapacity = 100.0;
			:>> currentBattery = 85.0;
			
			attribute fleetAvailability : Real;
			
			perform action robotOperation : RobotStorageOperation {
				in batteryCapacity = robotFleet.batteryCapacity;
				in currentBattery = robotFleet.currentBattery;
			}
			
			exhibit state robotState : RobotOperationalState {
				in batteryCapacity = robotFleet.batteryCapacity;
				in maxVelocity = robotFleet.maxVelocity;
				in currentBattery = robotFleet.currentBattery;
				in currentVelocity = robotFleet.currentVelocity;
				in loadStatus = robotFleet.loadStatus;
				in taskValid = robotFleet.taskValid;
				in arrivedAtSource = robotFleet.arrivedAtSource;
				in caseSecured = robotFleet.caseSecured;
				in arrivedAtDestination = robotFleet.arrivedAtDestination;
				in caseStored = robotFleet.caseStored;
				in maintenanceComplete = robotFleet.maintenanceComplete;
			}
		}
		
		part conveyorSystem : ConveyorNetwork {
			:>> totalLength = 200.0 [m];
			:>> operatingSpeed = 1.0 [m/s];
			:>> throughputCapacity = 500;
		}
		
		connection robotCommands [30] connect 
			robotFleet.commandInterface to centralController.robotControl;
		
		satisfy systemRequirements : SystemRequirements;
	}
	
	part symboticWarehouse : SymboticWarehouse {
		:>> operationalThroughput = 450.0;
		:>> averageRetrievalTime = 150.0;
		:>> systemUptime = 0.99;
	}
}
