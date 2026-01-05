package AmazonRoboticsWarehouseFulfillmentSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RobotIdentifier;
    attribute def PodIdentifier;
    attribute def StationIdentifier;
    attribute def OrderIdentifier;
    attribute def ItemSKU;
    
    value def GridCoordinate {
        attribute x : LengthValue;
        attribute y : LengthValue;
    }
    
    attribute def BatteryLevel :> Real;
    
    item def InventoryPod {
        attribute podID : PodIdentifier;
        attribute location : GridCoordinate;
        attribute mass : MassValue;
        attribute itemSKUs : ItemSKU[*];
        attribute capacity : Integer;
    }
    
    item def CustomerOrder {
        attribute orderID : OrderIdentifier;
        attribute requestedItems : ItemSKU[*];
        attribute priority : Integer;
        attribute targetStation : StationIdentifier;
    }
    
    item def TaskAssignment {
        attribute assignedRobot : RobotIdentifier;
        attribute targetPod : PodIdentifier;
        attribute pickupLocation : GridCoordinate;
        attribute deliveryLocation : GridCoordinate;
        attribute associatedOrder : OrderIdentifier;
    }
    
    item def RobotTelemetry {
        attribute robotID : RobotIdentifier;
        attribute currentPosition : GridCoordinate;
        attribute batteryStatus : BatteryLevel;
        attribute carryingPod : Boolean;
        attribute currentPodID : PodIdentifier[0..1];
        attribute operationalState : String;
    }
    
    port def CommandPort {
        in item taskCommand : TaskAssignment;
        out item statusReport : RobotTelemetry;
    }
    
    port def PowerPort {
        in attribute chargingPower : PowerValue;
        out attribute batteryVoltage : ElectricPotentialValue;
    }
    
    port def LiftPort {
        in attribute liftCommand : String;
        out attribute liftPosition : LengthValue;
        out attribute loadMass : MassValue;
    }
    
    port def SensorPort {
        out attribute obstacleDetected : Boolean;
        out attribute proximityDistance : LengthValue;
        out attribute qrCodeData : String;
    }
    
    part def DriveSystem {
        attribute maxVelocity : SpeedValue;
        attribute currentVelocity : SpeedValue;
        attribute wheelDiameter : LengthValue;
        
        port motorInterface {
            in attribute velocityCommand : SpeedValue;
            out attribute actualVelocity : SpeedValue;
            out attribute motorCurrent : ElectricCurrentValue;
        }
        
        action def ExecuteMotion {
            in targetVelocity : SpeedValue;
            in duration : TimeValue;
            out distanceTraveled : LengthValue;
        }
    }
    
    part def LiftingMechanism {
        attribute maxHeight : LengthValue;
        attribute maxPayload : MassValue;
        attribute currentHeight : LengthValue;
        attribute liftSpeed : SpeedValue;
        
        port liftInterface : LiftPort;
        
        action def RaisePod {
            in targetHeight : LengthValue;
            in podMass : MassValue;
            out liftSuccessful : Boolean;
        }
        
        action def LowerPod {
            in currentHeight : LengthValue;
            out releaseSuccessful : Boolean;
        }
    }
    
    part def PerceptionSystem {
        port sensors : SensorPort;
        
        part lidarUnit {
            attribute scanRange : LengthValue;
            attribute angularResolution : Real;
            attribute scanFrequency : FrequencyValue;
        }
        
        part visionCamera {
            attribute resolution : Integer[2];
            attribute fieldOfView : Real;
            attribute frameRate : FrequencyValue;
        }
        
        part qrScanner {
            attribute readDistance : LengthValue;
            attribute decodingRate : FrequencyValue;
        }
        
        action def DetectObstacles {
            out obstaclePositions : GridCoordinate[*];
            out clearPath : Boolean;
        }
        
        action def ReadPodIdentifier {
            out podID : PodIdentifier;
            out readSuccess : Boolean;
        }
    }
    
    part def BatteryPack {
        attribute capacity : EnergyValue;
        attribute currentCharge : BatteryLevel;
        attribute voltage : ElectricPotentialValue;
        attribute dischargeCurrent : ElectricCurrentValue;
        
        port powerInterface : PowerPort;
        
        action def MonitorCharge {
            out chargeLevel : BatteryLevel;
            out needsCharging : Boolean;
        }
    }
    
    part def MobileDriveUnit {
        attribute robotID : RobotIdentifier;
        attribute position : GridCoordinate;
        attribute batteryLevel : BatteryLevel;
        attribute maxPayloadCapacity : MassValue;
        attribute isCarryingPod : Boolean;
        
        port commandInterface : CommandPort;
        
        part driveSystem : DriveSystem {
            attribute :>> maxVelocity = 1.5 [m/s];
            attribute :>> wheelDiameter = 0.15 [m];
        }
        
        part liftMechanism : LiftingMechanism {
            attribute :>> maxHeight = 0.3 [m];
            attribute :>> maxPayload = 750.0 [kg];
            attribute :>> liftSpeed = 0.1 [m/s];
        }
        
        part perception : PerceptionSystem;
        
        part battery : BatteryPack {
            attribute :>> capacity = 50000.0 [W*h];
            attribute :>> voltage = 48.0 [V];
        }
        
        perform action executeTask;
        exhibit state robotBehavior : RobotStateMachine;
    }
    
    part def WorkStation {
        attribute stationID : StationIdentifier;
        attribute stationType : String;
        attribute assignedOrders : OrderIdentifier[*];
        
        port stationInterface {
            in item podArrived : PodIdentifier;
            out item pickingComplete : OrderIdentifier;
            out item podReleaseRequest : PodIdentifier;
        }
        
        action def ProcessOrder {
            in order : CustomerOrder;
            in pod : InventoryPod;
            out itemsPicked : ItemSKU[*];
            out orderFulfilled : Boolean;
        }
    }
    
    part def ChargingDock {
        attribute dockID : String;
        attribute chargingPower : PowerValue;
        attribute occupied : Boolean;
        
        port chargingInterface {
            in item robotArrival : RobotIdentifier;
            out attribute powerDelivered : PowerValue;
            out item chargingComplete : RobotIdentifier;
        }
        
        action def ChargeRobot {
            in currentBatteryLevel : BatteryLevel;
            in chargingRate : PowerValue;
            out finalBatteryLevel : BatteryLevel;
            out chargingDuration : TimeValue;
        }
    }
    
    part def WarehouseControlSystem {
        attribute activeOrders : CustomerOrder[*];
        attribute availableRobots : RobotIdentifier[*];
        attribute podInventory : InventoryPod[*];
        attribute taskQueue : TaskAssignment[*];
        
        port systemInterface : CommandPort;
        
        action def ReceiveOrder {
            in newOrder : CustomerOrder;
            out orderAccepted : Boolean;
        }
        
        action def AllocateRobot {
            in order : CustomerOrder;
            out selectedRobot : RobotIdentifier;
            out taskAssignment : TaskAssignment;
        }
        
        action def LocateInventory {
            in requestedSKUs : ItemSKU[*];
            out podLocation : GridCoordinate;
            out podID : PodIdentifier;
        }
        
        action def OptimizePath {
            in startPosition : GridCoordinate;
            in targetPosition : GridCoordinate;
            in obstacleMap : GridCoordinate[*];
            out waypoints : GridCoordinate[*];
            out estimatedTime : TimeValue;
        }
        
        perform action orchestrateFulfillment;
    }
    
    action def NavigateToPosition {
        in startPos : GridCoordinate;
        in targetPos : GridCoordinate;
        in maxSpeed : SpeedValue;
        out finalPos : GridCoordinate;
        out travelTime : TimeValue;
        out pathFollowed : GridCoordinate[*];
    }
    
    action def EngagePod {
        in podID : PodIdentifier;
        in podMass : MassValue;
        in liftHeight : LengthValue;
        out engaged : Boolean;
        out podSecured : Boolean;
    }
    
    action def TransportPodToStation {
        in pod : InventoryPod;
        in destination : GridCoordinate;
        in travelSpeed : SpeedValue;
        out delivered : Boolean;
        out deliveryTime : TimeValue;
    }
    
    action def ReleasePod {
        in currentLiftHeight : LengthValue;
        out released : Boolean;
        out podPlaced : Boolean;
    }
    
    action def ReturnToStandby {
        in currentPos : GridCoordinate;
        in standbyZone : GridCoordinate;
        out arrived : Boolean;
    }
    
    action def FulfillCustomerOrder {
        in order : CustomerOrder;
        out completed : Boolean;
        
        first start;
        then action receiveTask {
            in customerOrder : CustomerOrder = order;
            out robotAssigned : RobotIdentifier;
            out podAssigned : PodIdentifier;
        }
        then action findPod {
            in targetSKUs : ItemSKU[*] = order.requestedItems;
            out podLocation : GridCoordinate;
            out podID : PodIdentifier;
            out podMass : MassValue;
        }
        then action navigateToPod : NavigateToPosition {
            in targetPos = findPod.podLocation;
            in maxSpeed = 1.5 [m/s];
        }
        then action liftPod : EngagePod {
            in podID = findPod.podID;
            in podMass = findPod.podMass;
            in liftHeight = 0.25 [m];
        }
        then action transportToStation : TransportPodToStation {
            in destination;
            in travelSpeed = 1.2 [m/s];
        }
        then action deliverPod : ReleasePod;
        then action waitForPicking {
            out pickingCompleted : Boolean;
            out pickedItems : ItemSKU[*];
        }
        then action reengagePod : EngagePod {
            in podID = findPod.podID;
            in podMass = findPod.podMass;
            in liftHeight = 0.25 [m];
        }
        then action returnPodToStorage : TransportPodToStation {
            in destination = findPod.podLocation;
            in travelSpeed = 1.2 [m/s];
        }
        then action placePod : ReleasePod;
        then action returnToQueue : ReturnToStandby;
        then assign completed := true;
        then done;
    }
    
    state def RobotStateMachine {
        entry; then idle;
        
        state idle;
        
        transition idleToTaskReceived
            first idle
            accept TaskReceived
            then taskReceived;
        
        state taskReceived {
            do action validateTask;
        }
        
        transition taskToNavigating
            first taskReceived
            if batteryLevel > 25.0
            then navigatingToPod;
        
        transition taskToCharging
            first taskReceived
            if batteryLevel <= 25.0
            then charging;
        
        state navigatingToPod {
            do action navigate : NavigateToPosition;
        }
        
        transition navigatingToEngaging
            first navigatingToPod
            accept ArrivedAtPod
            then engagingPod;
        
        state engagingPod {
            do action engage : EngagePod;
        }
        
        transition engagingToTransporting
            first engagingPod
            if engage.engaged
            then transporting;
        
        state transporting {
            do action transport : TransportPodToStation;
        }
        
        transition transportingToDelivering
            first transporting
            accept ArrivedAtStation
            then deliveringPod;
        
        state deliveringPod {
            do action deliver : ReleasePod;
        }
        
        transition deliveringToWaiting
            first deliveringPod
            if deliver.released
            then waitingForPicker;
        
        state waitingForPicker;
        
        transition waitingToRetrieving
            first waitingForPicker
            accept PickingComplete
            then retrievingPod;
        
        state retrievingPod {
            do action retrieve : EngagePod;
        }
        
        transition retrievingToReturning
            first retrievingPod
            if retrieve.engaged
            then returningPod;
        
        state returningPod {
            do action returnPod : TransportPodToStation;
        }
        
        transition returningToPlacing
            first returningPod
            accept ArrivedAtStorage
            then placingPod;
        
        state placingPod {
            do action place : ReleasePod;
        }
        
        transition placingToIdle
            first placingPod
            if place.released
            then idle;
        
        state charging {
            do action charge;
        }
        
        transition chargingToIdle
            first charging
            if batteryLevel >= 95.0
            then idle;
    }
    
    part warehouseFulfillmentSystem {
        part controlSystem : WarehouseControlSystem {
            perform action orchestrateFulfillment {
                first start;
                then merge orderProcessingLoop;
                then action receiveNewOrder : ReceiveOrder {
                    in newOrder;
                    out orderAccepted;
                }
                then action assignRobot : AllocateRobot {
                    in order = receiveNewOrder.newOrder;
                    out selectedRobot;
                    out taskAssignment;
                }
                then action findInventory : LocateInventory {
                    in requestedSKUs = receiveNewOrder.newOrder.requestedItems;
                    out podLocation;
                    out podID;
                }
                then action planPath : OptimizePath {
                    in targetPosition = findInventory.podLocation;
                    out waypoints;
                    out estimatedTime;
                }
                then action dispatchTask {
                    in robotID : RobotIdentifier = assignRobot.selectedRobot;
                    in task : TaskAssignment = assignRobot.taskAssignment;
                }
                then orderProcessingLoop;
            }
        }
        
        part driveUnits : MobileDriveUnit[100] {
            attribute :>> robotID;
            attribute :>> batteryLevel = 100.0;
            attribute :>> maxPayloadCapacity = 750.0 [kg];
            
            perform action executeTask references fulfillmentTask;
            exhibit state :>> robotBehavior;
        }
        
        part workStations : WorkStation[20] {
            attribute :>> stationID;
            attribute :>> stationType = "picking";
        }
        
        part chargingDocks : ChargingDock[15] {
            attribute :>> chargingPower = 3000.0 [W];
            attribute :>> occupied = false;
        }
        
        part inventoryPods : InventoryPod[8000] {
            attribute :>> capacity = 32;
            attribute :>> mass = 150.0 [kg];
        }
        
        action fulfillmentTask : FulfillCustomerOrder[*] ordered;
        
        connect controlSystem.systemInterface to driveUnits.commandInterface;
    }
    
    requirement def OperationalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    
    requirement <'SYS-FUNC-001'> primarySystemFunction {
        doc /* 
            The Amazon Robotics Warehouse Fulfillment System shall autonomously retrieve inventory 
            storage pods from warehouse floor locations, transport them to human-operated picking 
            stations for order fulfillment, and return the pods to storage, thereby enabling efficient, 
            scalable, and high-throughput e-commerce order processing with minimal human walking 
            and search time.
        */
        
        subject warehouseFulfillmentSystem;
        
        require throughputRequirement;
        require robotVelocityRequirement;
        require payloadRequirement;
        require batteryEnduranceRequirement;
        require collisionAvoidanceRequirement;
    }
    
    requirement <'PERF-001'> throughputRequirement : PerformanceRequirement {
        doc /* 
            The warehouse system shall process a minimum of 450 customer orders per hour 
            during peak operational periods.
        */
        
        subject warehouseFulfillmentSystem;
        
        require constraint {
            warehouseFulfillmentSystem.controlSystem.activeOrders->size() >= 450
        }
    }
    
    requirement <'PERF-002'> robotVelocityRequirement : PerformanceRequirement {
        doc /* 
            Each mobile drive unit shall navigate at velocities up to 1.5 m/s while transporting 
            a loaded inventory pod.
        */
        
        subject warehouseFulfillmentSystem.driveUnits;
        
        require constraint {
            warehouseFulfillmentSystem.driveUnits.driveSystem.maxVelocity >= 1.5 [m/s]
        }
    }
    
    requirement <'PERF-003'> payloadRequirement : PerformanceRequirement {
        doc /* 
            Each mobile drive unit lifting mechanism shall support inventory pod loads 
            up to 750 kg without mechanical failure.
        */
        
        subject warehouseFulfillmentSystem.driveUnits.liftMechanism;
        
        require constraint {
            warehouseFulfillmentSystem.driveUnits.liftMechanism.maxPayload >= 750.0 [kg]
        }
    }
    
    requirement <'PERF-004'> batteryEnduranceRequirement : PerformanceRequirement {
        doc /* 
            Each mobile drive unit shall operate continuously for a minimum of 10 hours 
            on a single battery charge under typical warehouse load conditions.
        */
        
        subject warehouseFulfillmentSystem.driveUnits.battery;
        
        assume constraint {
            warehouseFulfillmentSystem.driveUnits.battery.currentCharge == 100.0
        }
        
        require constraint {
            warehouseFulfillmentSystem.driveUnits.battery.capacity >= 50000.0 [W*h]
        }
    }
    
    requirement <'SAFE-001'> collisionAvoidanceRequirement : SafetyRequirement {
        doc /* 
            The control system shall maintain a minimum separation distance of 0.6 meters 
            between all mobile drive units to prevent collisions during simultaneous operation.
        */
        
        subject warehouseFulfillmentSystem.controlSystem;
        
        require constraint minimumSeparation {
            attribute separationDistance : LengthValue = 0.6 [m];
        }
    }
}
