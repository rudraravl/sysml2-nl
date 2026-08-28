package 'Symbotic Automated Warehouse System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    package 'Types and Items' {
        item def ProductCase {
            attribute caseId : String;
            attribute weight : MassValue;
            attribute length : LengthValue;
            attribute width : LengthValue;
            attribute height : LengthValue;
        }

        attribute def GridCoordinate {
            attribute x : Integer;
            attribute y : Integer;
            attribute z : Integer;
        }

        attribute def RobotTask {
            attribute taskId : String;
            attribute taskType : String;
            attribute pickupLocation : GridCoordinate;
            attribute dropoffLocation : GridCoordinate;
            attribute caseId : String;
            attribute assignedRobotId : String;
        }

        attribute def RobotStatus {
            attribute robotId : String;
            attribute currentState : String;
            attribute batteryLevel : Real;
            attribute currentLocation : GridCoordinate;
        }

        attribute def InventoryUpdate {
            attribute location : GridCoordinate;
            attribute occupied : Boolean;
            attribute caseId : String;
        }

        attribute def RetrievalRequest {
            attribute caseId : String;
            attribute destination : GridCoordinate;
        }

        attribute def TaskAssigned;
        attribute def ArrivedAtPickup;
        attribute def CasePicked;
        attribute def ArrivedAtStorage;
        attribute def CaseDropped;
        attribute def TaskComplete;
        attribute def LowBattery;
        attribute def ArrivedAtCharger;
        attribute def ChargeComplete;
    }

    package 'Component Definitions' {
        private import 'Types and Items'::*;

        part def HighDensityStorageStructure {
            attribute gridWidth : Integer;
            attribute gridDepth : Integer;
            attribute gridHeight : Integer;
            attribute maxCapacity : Integer;
            attribute currentOccupancy : Integer;
            port storageAccessPort {
                in caseToStore : ProductCase;
                out caseRetrieved : ProductCase;
            }
            port inventoryPort {
                out update : InventoryUpdate;
            }
            part storageGrid {
                attribute totalLocations : Integer;
            }
        }

        part def PowerSystem {
            attribute batteryCapacity : EnergyValue;
            attribute currentCharge : EnergyValue;
            attribute chargeRate : PowerValue;
            port chargingPort {
                in charge : ElectricChargeValue;
            }
            port statusPort {
                out batteryLevel : Real;
            }
            perform action monitorCharge {
                out level : Real;
                first start;
                then action readCharge;
                then action computePercentage;
                then done;
            }
        }

        part def NavigationModule {
            attribute currentPosition : GridCoordinate;
            attribute targetPosition : GridCoordinate;
            attribute maxSpeed : SpeedValue;
            port locationPort {
                out position : GridCoordinate;
            }
            perform action navigate {
                in target : GridCoordinate;
                out position : GridCoordinate;
                first start;
                then action planRoute;
                then action executeMovement;
                then done;
            }
        }

        part def LiftingMechanism {
            attribute payloadCapacity : MassValue;
            attribute hasCase : Boolean = false;
            port liftPort {
                in caseToLift : ProductCase;
                out caseLifted : ProductCase;
            }
            perform action lift {
                in c : ProductCase;
                first start;
                then action engageGripper;
                then action raisePlatform;
                then done;
            }
            perform action drop {
                out c : ProductCase;
                first start;
                then action lowerPlatform;
                then action releaseGripper;
                then done;
            }
        }

        part def AutonomousMobileRobot {
            attribute robotId : String;
            attribute maxPayload : MassValue;
            part powerSystem : PowerSystem;
            part navigationModule : NavigationModule;
            part liftingMechanism : LiftingMechanism;

            port taskAssignmentPort {
                in task : RobotTask;
            }
            port statusReportPort {
                out status : RobotStatus;
            }
            port caseInteractionPort {
                in caseIn : ProductCase;
                out caseOut : ProductCase;
            }
            port chargingPort {
                in charge : ElectricChargeValue;
            }

            state robotStates {
                entry; then idle;
                state idle;
                accept TaskAssigned via taskAssignmentPort then travelingToPickup;
                state travelingToPickup;
                accept ArrivedAtPickup then picking;
                state picking;
                accept CasePicked then travelingToStorage;
                state travelingToStorage;
                accept ArrivedAtStorage then dropping;
                state dropping;
                accept CaseDropped then idle;
                transition idle_lowBattery
                    first idle
                    accept LowBattery
                    then travelingToCharger;
                state travelingToCharger;
                accept ArrivedAtCharger then charging;
                state charging;
                accept ChargeComplete then idle;
            }

            perform action executeTask {
                in assignedTask : RobotTask;
                first start;
                then action navigateToPickup;
                then action pickupCase;
                then action navigateToStorage;
                then action dropoffCase;
                then action reportComplete;
                then done;
            }
        }

        part def TaskOrchestrator {
            port taskOutputPort {
                out task : RobotTask;
            }
            port statusInputPort {
                in status : RobotStatus;
            }
            port inventoryInputPort {
                in update : InventoryUpdate;
            }
            perform action assignTask {
                in caseId : String;
                in targetLocation : GridCoordinate;
                in availableRobotId : String;
                out task : RobotTask;
                first start;
                then action createTask;
                then action selectRobot;
                then action dispatchTask;
                then done;
            }
        }

        part def PathOptimizationEngine {
            port pathRequestPort {
                in startLocation : GridCoordinate;
                in endLocation : GridCoordinate;
            }
            port pathOutputPort {
                out path : GridCoordinate[*];
            }
            perform action computeOptimalPath {
                in start : GridCoordinate;
                in destination : GridCoordinate;
                in occupiedLocations : GridCoordinate[*];
                out path : GridCoordinate[*];
                first start;
                then action buildGraph;
                then action searchPath;
                then action validatePath;
                then done;
            }
        }

        part def IntelligentControlSystem {
            part taskOrchestrator : TaskOrchestrator;
            part pathOptimizationEngine : PathOptimizationEngine;
            port wmsInterfacePort {
                in inventoryUpdate : InventoryUpdate;
                out retrievalRequest : RetrievalRequest;
            }
            port conveyorInterfacePort {
                in caseArrival : ProductCase;
                out caseRetrieval : ProductCase;
            }
            port robotControlPort {
                out task : RobotTask;
                in status : RobotStatus;
            }
            perform action processIncomingCase {
                in case : ProductCase;
                first start;
                then action identifyCase;
                then action determineStorageLocation;
                then action selectAvailableRobot;
                then action generateTask;
                then done;
            }
            perform action processRetrievalRequest {
                in request : RetrievalRequest;
                first start;
                then action locateCase;
                then action selectRobot;
                then action generateRetrievalTask;
                then done;
            }
        }

        part def ConveyorNetwork {
            part inductionConveyor {
                port inductionPort {
                    out newCase : ProductCase;
                }
                perform action transportToInduction {
                    out c : ProductCase;
                    first start;
                    then action receiveCase;
                    then action moveCase;
                    then done;
                }
            }
            part outboundConveyor {
                port outboundPort {
                    in retrievedCase : ProductCase;
                }
                perform action transportToOutbound {
                    in c : ProductCase;
                    first start;
                    then action receiveCase;
                    then action moveCase;
                    then done;
                }
            }
            port systemPort {
                out incomingCase : ProductCase;
                in outgoingCase : ProductCase;
            }
        }

        part def WarehouseManagementSystem {
            port wmsPort {
                out inventoryUpdate : InventoryUpdate;
                in retrievalRequest : RetrievalRequest;
            }
        }
    }

    package 'System Assembly' {
        private import 'Component Definitions'::*;
        private import 'Types and Items'::*;

        part warehouseSystem {
            part storageStructure : HighDensityStorageStructure {
                :>> gridWidth = 100;
                :>> gridDepth = 100;
                :>> gridHeight = 12;
                :>> maxCapacity = 120000;
                :>> currentOccupancy = 0;
            }
            part robots : AutonomousMobileRobot[50];
            part controlSystem : IntelligentControlSystem;
            part conveyorNetwork : ConveyorNetwork;
            part wms : WarehouseManagementSystem;

            interface ControlToRobotInterface connect controlSystem.robotControlPort to robots.taskAssignmentPort {
                flow taskFlow of RobotTask from controlSystem.robotControlPort.task to robots.taskAssignmentPort.task;
            }
            interface RobotToControlInterface connect robots.statusReportPort to controlSystem.robotControlPort {
                flow statusFlow of RobotStatus from robots.statusReportPort.status to controlSystem.robotControlPort.status;
            }
            interface WmsToControlInterface connect wms.wmsPort to controlSystem.wmsInterfacePort {
                flow inventoryFlow of InventoryUpdate from wms.wmsPort.inventoryUpdate to controlSystem.wmsInterfacePort.inventoryUpdate;
                flow retrievalFlow of RetrievalRequest from controlSystem.wmsInterfacePort.retrievalRequest to wms.wmsPort.retrievalRequest;
            }
            interface ConveyorToControlInterface connect conveyorNetwork.systemPort to controlSystem.conveyorInterfacePort {
                flow caseArrivalFlow of ProductCase from conveyorNetwork.systemPort.incomingCase to controlSystem.conveyorInterfacePort.caseArrival;
            }
            interface ControlToConveyorInterface connect controlSystem.conveyorInterfacePort to conveyorNetwork.systemPort {
                flow caseRetrievalFlow of ProductCase from controlSystem.conveyorInterfacePort.caseRetrieval to conveyorNetwork.systemPort.outgoingCase;
            }
            interface StorageInventoryInterface connect storageStructure.inventoryPort to controlSystem.taskOrchestrator.inventoryInputPort {
                flow inventoryUpdateFlow of InventoryUpdate from storageStructure.inventoryPort.update to controlSystem.taskOrchestrator.inventoryInputPort.update;
            }

            perform action operateWarehouse {
                first start;
                then action receiveIncomingCase;
                then action processCase;
                then action assignRobotTask;
                then action robotExecute;
                then action updateInventory;
                then done;
            }
        }
    }

    package 'Requirements' {
        private import 'System Assembly'::*;

        requirement def HighThroughputRequirement {
            doc /* The system shall process at least 500 product cases per hour during peak operation. */
            attribute targetThroughput : Real = 500.0;
        }

        requirement def StorageDensityRequirement {
            doc /* The storage structure shall achieve at least 80 percent volumetric utilization of the available footprint. */
            attribute targetDensity : Real = 80.0;
        }

        requirement def PickingAccuracyRequirement {
            doc /* The system shall achieve a picking accuracy of at least 99.9 percent. */
            attribute targetAccuracy : Real = 99.9;
        }

        requirement def AutonomousOperationRequirement {
            doc /* Robots shall operate without human intervention except for scheduled maintenance. */
        }

        requirement def BatteryManagementRequirement {
            doc /* Robots shall automatically navigate to charging stations when battery levels fall below 20 percent capacity. */
            attribute threshold : Real = 20.0;
        }

        requirement def CollisionFreeNavigationRequirement {
            doc /* The path optimization engine shall compute collision-free routes for all robots operating simultaneously. */
        }

        requirement 'SystemHighThroughput' : HighThroughputRequirement {
            subject w : warehouseSystem;
        }
        requirement 'SystemStorageDensity' : StorageDensityRequirement {
            subject s : warehouseSystem.storageStructure;
        }
        requirement 'SystemPickingAccuracy' : PickingAccuracyRequirement {
            subject c : warehouseSystem.controlSystem;
        }
        requirement 'SystemAutonomousOperation' : AutonomousOperationRequirement {
            subject r : warehouseSystem.robots;
        }
        requirement 'SystemBatteryManagement' : BatteryManagementRequirement {
            subject p : warehouseSystem.robots.powerSystem;
        }
        requirement 'SystemCollisionFree' : CollisionFreeNavigationRequirement {
            subject e : warehouseSystem.controlSystem.pathOptimizationEngine;
        }

        satisfy 'SystemHighThroughput' by warehouseSystem;
        satisfy 'SystemStorageDensity' by warehouseSystem.storageStructure;
        satisfy 'SystemPickingAccuracy' by warehouseSystem.controlSystem;
        satisfy 'SystemAutonomousOperation' by warehouseSystem.robots;
        satisfy 'SystemBatteryManagement' by warehouseSystem.robots.powerSystem;
        satisfy 'SystemCollisionFree' by warehouseSystem.controlSystem.pathOptimizationEngine;
    }
}
