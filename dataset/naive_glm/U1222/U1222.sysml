package AutomatedWarehouse {

    public import ScalarValues::*;
    public import ISQ::*;

    value type Mass :> Real { unit "kg"; }
    value type Length :> Real { unit "m"; }
    value type Velocity :> Real { unit "m/s"; }
    value type Power :> Real { unit "W"; }
    value type Energy :> Real { unit "J"; }
    value type BatteryLevel :> Real { unit "%"; }
    value type Duration :> Real { unit "s"; }
    value type Throughput :> Real { unit "cases/h"; }

    enum def TaskType { store; retrieve; charge; }
    enum def TaskState { assigned; inProgress; completed; failed; }

    attribute def GridCoordinate {
        attribute x : Integer;
        attribute y : Integer;
        attribute z : Integer;
    }

    item def ProductCase {
        attribute caseId : String;
        attribute sku : String;
        attribute weight : Mass;
        attribute length : Length;
        attribute width : Length;
        attribute height : Length;
    }

    item def Task {
        attribute id : String;
        attribute type : TaskType;
        attribute source : GridCoordinate;
        attribute destination : GridCoordinate;
        ref case : ProductCase;
    }

    item def TaskStatus {
        attribute taskId : String;
        attribute state : TaskState;
        attribute robotId : String;
    }

    item def InventoryRecord {
        attribute caseId : String;
        attribute location : GridCoordinate;
        attribute timestamp : Duration;
    }

    item def RetrievalOrder {
        attribute orderId : String;
        attribute sku : String;
        attribute quantity : Integer;
    }

    port def RobotControlPort {
        in item task : Task;
        out item status : TaskStatus;
        out attribute position : GridCoordinate;
        out attribute battery : BatteryLevel;
    }

    port def ConveyorPort {
        out item inboundCase : ProductCase;
        in item outboundCase : ProductCase;
    }

    port def WmsPort {
        out item inboundCase : ProductCase;
        in item retrievalOrder : RetrievalOrder;
        in item inventoryUpdate : InventoryRecord;
    }

    port def StorageCoordPort {
        in attribute coordinate : GridCoordinate;
        out attribute allocated : Boolean;
    }

    part def StorageCell {
        attribute coordinate : GridCoordinate;
        attribute occupied : Boolean = false;
        ref storedCase : ProductCase;
    }

    part def HighDensityStorageStructure {
        attribute levels : Integer;
        attribute gridWidth : Integer;
        attribute gridDepth : Integer;
        attribute totalCapacity : Integer = levels * gridWidth * gridDepth;
        port inductionPort : ConveyorPort;
        port outboundPort : ConveyorPort;
        port coordPort : StorageCoordPort;
        part cells : StorageCell[levels * gridWidth * gridDepth];

        action def AllocateLocation(in case : ProductCase) :> GridCoordinate {
            // Find first unoccupied cell matching case dimensions
        }

        action def DeallocateLocation(in coord : GridCoordinate) {
            // Mark cell as unoccupied and clear storedCase
        }

        action def RetrieveCase(in coord : GridCoordinate) :> ProductCase {
            // Return the case stored at coord and deallocate
        }
    }

    part def NavigationModule {
        attribute currentPosition : GridCoordinate;
        attribute targetPosition : GridCoordinate;
        attribute path : GridCoordinate[0..*];

        action def NavigateTo(in target : GridCoordinate) {
            // Set target and follow path
        }

        action def UpdatePosition(in newPos : GridCoordinate);
    }

    part def PowerSystem {
        attribute batteryLevel : BatteryLevel = 100;
        attribute maxCapacity : Energy;
        attribute chargingRate : Power;
        attribute lowThreshold : BatteryLevel = 20;

        action def Charge {
            // Increase batteryLevel at chargingRate
        }

        action def Consume(in amount : Energy) {
            // Decrease batteryLevel by amount
        }

        action def IsLow() :> Boolean {
            return batteryLevel < lowThreshold;
        }
    }

    part def LiftingMechanism {
        attribute payloadCapacity : Mass;
        attribute currentLoad : Mass = 0;
        ref carriedCase : ProductCase;

        action def PickUp(in case : ProductCase) {
            // Engage lift and secure case
        }

        action def DropOff {
            // Release case at destination
        }
    }

    part def AutonomousMobileRobot {
        attribute robotId : String;
        attribute maxSpeed : Velocity;
        attribute chargeStationCoord : GridCoordinate;
        port controlPort : RobotControlPort;
        part navigation : NavigationModule;
        part power : PowerSystem;
        part lifter : LiftingMechanism;

        action def ExecuteTask(in task : Task) {
            // Travel to source, pick up, travel to destination, drop off
        }

        action def ReportStatus(out status : TaskStatus) {
            // Send task completion status via controlPort
        }

        exhibit state def RobotBehavior {
            entry;
            state Idle;
            state TravelingToPickup;
            state PickingUp;
            state TravelingToStorage;
            state Depositing;
            state TravelingToCharge;
            state Charging;

            transition Idle to TravelingToPickup
                when controlPort.task.type == TaskType::store
                and not power.IsLow();

            transition Idle to TravelingToCharge
                when power.IsLow();

            transition TravelingToPickup to PickingUp
                when navigation.currentPosition == controlPort.task.source;

            transition PickingUp to TravelingToStorage
                when lifter.currentLoad > 0;

            transition TravelingToStorage to Depositing
                when navigation.currentPosition == controlPort.task.destination;

            transition Depositing to Idle
                when lifter.currentLoad == 0;

            transition TravelingToCharge to Charging
                when navigation.currentPosition == chargeStationCoord;

            transition Charging to Idle
                when power.batteryLevel >= 100;
        }
    }

    part def TaskOrchestrator {
        attribute pendingTasks : Task[0..*];
        attribute activeTasks : Task[0..*];
        port robotPorts : RobotControlPort[0..*];

        action def CreateTask(in case : ProductCase, in dest : GridCoordinate, out task : Task) {
            // Construct a store task with unique id
        }

        action def AssignTask(in robot : AutonomousMobileRobot, out task : Task) {
            // Select a pending task and assign to robot
        }

        action def ReceiveStatus(in status : TaskStatus) {
            // Update activeTasks based on status
        }

        action def SelectAvailableRobot(out robot : AutonomousMobileRobot) {
            // Find an idle robot
        }
    }

    part def PathOptimizationEngine {
        action def PlanPath(in start : GridCoordinate, in end : GridCoordinate, out path : GridCoordinate[0..*]) {
            // Compute collision-free shortest path through grid
        }

        action def AvoidCollisions(in robots : AutonomousMobileRobot[0..*]) {
            // Adjust paths to prevent robot-to-robot collisions
        }

        action def ReserveCell(in coord : GridCoordinate, in robotId : String) :> Boolean {
            // Temporarily reserve a grid cell for a robot
        }
    }

    part def WmsInterface {
        port wmsPort : WmsPort;
        attribute inventory : InventoryRecord[0..*];

        action def ReceiveInbound(out case : ProductCase) {
            // Receive case from WMS
        }

        action def SendInventoryUpdate(in record : InventoryRecord) {
            // Push inventory record to WMS
        }

        action def ProcessRetrievalOrder(in order : RetrievalOrder, out task : Task) {
            // Convert order to retrieval task
        }
    }

    part def IntelligentControlSystem {
        part orchestrator : TaskOrchestrator;
        part pathEngine : PathOptimizationEngine;
        part wmsInterface : WmsInterface;
        port robotPorts : RobotControlPort[0..*];
        port storageCoordPort : StorageCoordPort;

        action def ProcessInboundCase(in case : ProductCase) {
            // Identify case, allocate location, create and assign task
        }

        action def HandleRetrieval(in order : RetrievalOrder) {
            // Locate case, create retrieval task, assign robot
        }

        action def UpdateInventory(in record : InventoryRecord) {
            // Forward to WMS interface
        }

        exhibit state def ControlBehavior {
            entry;
            state Monitoring;
            state Dispatching;
            state Updating;

            transition Monitoring to Dispatching
                when wmsInterface.wmsPort.inboundCase != null;

            transition Dispatching to Updating
                when orchestrator.activeTasks.size > 0;

            transition Updating to Monitoring;
        }
    }

    part def ConveyorSegment {
        attribute segmentId : String;
        attribute speed : Velocity;
        attribute length : Length;
        attribute direction : String;
        flow of ProductCase;
    }

    part def InductionPoint {
        attribute coordinate : GridCoordinate;
        port inductionPort : ConveyorPort;
        ref pendingCase : ProductCase;

        action def HoldCaseForPickup(in case : ProductCase) {
            // Stage case at induction coordinate
        }
    }

    part def OutboundPoint {
        attribute coordinate : GridCoordinate;
        port outboundPort : ConveyorPort;

        action def ReleaseCase(in case : ProductCase) {
            // Send case onto outbound conveyor
        }
    }

    part def ConveyorNetwork {
        part segments : ConveyorSegment[0..*];
        part inductionPoints : InductionPoint[0..*];
        part outboundPoints : OutboundPoint[0..*];

        action def TransportInbound(in case : ProductCase) {
            // Move case along segments to an induction point
        }

        action def TransportOutbound(in case : ProductCase) {
            // Move case from outbound point to shipping
        }
    }

    part def WarehouseSystem {
        attribute systemId : String;
        attribute targetThroughput : Throughput = 1000;
        part storage : HighDensityStorageStructure;
        part robots : AutonomousMobileRobot[0..*];
        part control : IntelligentControlSystem;
        part conveyor : ConveyorNetwork;

        connection def ControlToRobot {
            end controlPort : RobotControlPort;
            end robotPort : RobotControlPort;
        }

        connection control.robotPorts to robots.controlPort;
        connection conveyor.inductionPoints.inductionPort to storage.inductionPort;
        connection conveyor.outboundPoints.outboundPort to storage.outboundPort;
        connection control.storageCoordPort to storage.coordPort;

        action def Operate {
            // Continuous loop: receive cases, dispatch robots, update inventory
        }
    }

    requirement def HighThroughputRequirement {
        attribute minThroughput : Throughput = 1000;
        subject system : WarehouseSystem;
        require system.targetThroughput >= minThroughput;
    }

    requirement def HighDensityStorageRequirement {
        attribute minLevels : Integer = 12;
        attribute minGridWidth : Integer = 20;
        attribute minGridDepth : Integer = 20;
        subject storage : HighDensityStorageStructure;
        require storage.levels >= minLevels
            and storage.gridWidth >= minGridWidth
            and storage.gridDepth >= minGridDepth;
    }

    requirement def AutonomousOperationRequirement {
        subject system : WarehouseSystem;
        require system.robots.size > 0
            and system.control.orchestrator.pendingTasks.size >= 0;
    }

    requirement def BatteryManagementRequirement {
        attribute minBatteryThreshold : BatteryLevel = 20;
        subject robot : AutonomousMobileRobot;
        require robot.power.lowThreshold == minBatteryThreshold;
    }

    requirement def CollisionAvoidanceRequirement {
        subject engine : PathOptimizationEngine;
        require engine.AvoidCollisions().isInvoked;
    }

    requirement def LiftingCapacityRequirement {
        attribute minPayload : Mass = 30;
        subject lifter : LiftingMechanism;
        require lifter.payloadCapacity >= minPayload;
    }

    requirement def ConveyorInterfaceRequirement {
        subject system : WarehouseSystem;
        require system.conveyor.inductionPoints.size > 0
            and system.conveyor.outboundPoints.size > 0;
    }

    requirement def InventoryTrackingRequirement {
        subject control : IntelligentControlSystem;
        require control.wmsInterface.inventory.size >= 0;
    }

    part def WarehouseSystemVerification {
        subject system : WarehouseSystem;
        satisfy HighThroughputRequirement by system;
        satisfy HighDensityStorageRequirement by system.storage;
        satisfy AutonomousOperationRequirement by system;
        satisfy BatteryManagementRequirement by system.robots;
        satisfy CollisionAvoidanceRequirement by system.control.pathEngine;
        satisfy LiftingCapacityRequirement by system.robots.lifter;
        satisfy ConveyorInterfaceRequirement by system;
        satisfy InventoryTrackingRequirement by system.control;
    }

}
