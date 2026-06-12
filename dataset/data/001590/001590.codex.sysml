package SymboticWarehouseAutomationModel {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Percent :> Real;
    attribute def ThroughputRate {
        value rate : Real;
        value unit : String = "cases/hour";
    }

    attribute def EnergyRate {
        value rate : Real;
        value unit : String = "kW";
    }

    attribute def MassFlowRate {
        value rate : Real;
        value unit : String = "kg/hour";
    }

    attribute def Location3D {
        value x : Real;
        value y : Real;
        value z : Real;
        value unit : String = "m";
    }

    attribute def BatteryState {
        value stateOfCharge : Percent;
        value voltage : Real;
        value temperature : Real;
    }

    item def Case {
        attribute caseId : String;
        attribute sku : String;
        attribute length : Real;
        attribute width : Real;
        attribute height : Real;
        attribute mass : Real;
        attribute fragile : Boolean;
        attribute temperatureZone : String;
    }

    item def Tote {
        attribute toteId : String;
        attribute maxPayloadMass : Real = 35.0;
        attribute occupied : Boolean;
    }

    item def Pallet {
        attribute palletId : String;
        attribute inboundLane : String;
        attribute estimatedCaseCount : Integer;
    }

    item def Order {
        attribute orderId : String;
        attribute destinationDoor : String;
        attribute priority : Integer;
        attribute requiredShipTime : String;
    }

    item def Mission {
        attribute missionId : String;
        attribute missionType : String;
        attribute sourceLocation : Location3D;
        attribute targetLocation : Location3D;
        attribute priority : Integer;
    }

    port def CaseInputPort {
        in item receivedCase : Case;
    }

    port def CaseOutputPort {
        out item releasedCase : Case;
    }

    port def TotePort {
        inout item tote : Tote;
    }

    port def MissionPort {
        in item assignedMission : Mission;
        out item missionStatus : String;
    }

    port def TelemetryPort {
        out attribute position : Location3D;
        out attribute healthState : String;
        out attribute utilization : Percent;
    }

    port def ControlPort {
        in attribute command : String;
        out attribute response : String;
    }

    part def SymboticWarehouseSystem {
        doc /* 
         * High-level primary function:
         * Receive mixed-SKU inbound inventory, break it down into individual cases,
         * store cases in a dense automated structure, retrieve and sequence cases
         * according to outbound orders, and deliver them to shipping doors with high
         * throughput, traceability, and minimal manual handling.
         */

        attribute nominalThroughput : ThroughputRate;
        attribute storageCapacityCases : Integer;
        attribute systemAvailabilityTarget : Percent = 99.0;
        attribute maxConcurrentOrders : Integer;

        port inboundPallets : CaseInputPort;
        port outboundCases : CaseOutputPort;
        port operatorControl : ControlPort;
        port systemTelemetry : TelemetryPort;

        part inboundReceiving : InboundReceivingSubsystem;
        part depalletizer : RoboticDepalletizer;
        part induction : CaseInductionSubsystem;
        part storageGrid : DenseStorageStructure;
        part robotFleet : AutonomousRobotFleet;
        part orderSequencer : OrderSequencingSubsystem;
        part outboundBuffer : OutboundBufferSubsystem;
        part warehouseExecutionSystem : WarehouseExecutionSystem;
        part safetySystem : SafetySupervisionSystem;
        part chargingSystem : ChargingSubsystem;

        connect inboundReceiving.caseOut to depalletizer.caseIn;
        connect depalletizer.caseOut to induction.caseIn;
        connect induction.caseOut to storageGrid.caseIn;
        connect warehouseExecutionSystem.robotMissionPort to robotFleet.fleetMissionPort;
        connect robotFleet.gridInterface to storageGrid.robotInterface;
        connect storageGrid.caseOut to orderSequencer.caseIn;
        connect orderSequencer.caseOut to outboundBuffer.caseIn;
        connect outboundBuffer.caseOut to outboundCases;
        connect safetySystem.controlInterlock to robotFleet.safetyControl;
        connect chargingSystem.chargeControl to robotFleet.chargeInterface;

        perform action receiveStoreRetrieveSequence;
    }

    part def InboundReceivingSubsystem {
        attribute dockDoorCount : Integer;
        attribute inboundThroughput : ThroughputRate;

        port palletInput : CaseInputPort;
        port caseOut : CaseOutputPort;
        port control : ControlPort;

        part scanTunnel : IdentificationScanner;
        part palletConveyor : ConveyorSegment;

        action receiveInboundPallet {
            in item pallet : Pallet;
            out item registeredCases : Case;
            first start;
            then scanPallet;
            then registerInventory;
            then releaseToDepalletizer;
            then done;

            action scanPallet;
            action registerInventory;
            action releaseToDepalletizer;
        }
    }

    part def RoboticDepalletizer {
        attribute maxLiftMass : Real = 30.0;
        attribute cycleRate : ThroughputRate;
        attribute visionConfidenceThreshold : Percent = 97.5;

        port caseIn : CaseInputPort;
        port caseOut : CaseOutputPort;
        port control : ControlPort;
        port telemetry : TelemetryPort;

        part robotArm : SixAxisManipulator;
        part endEffector : VacuumGripper;
        part visionSystem : MachineVisionSystem;
        part rejectLane : ConveyorSegment;

        action depalletizeCases {
            in item sourcePallet : Pallet;
            out item separatedCase : Case;
            first localizeTopCase;
            then planPick;
            then gripCase;
            then verifyGrip;
            then placeOnInduction;
            then updateInventory;

            action localizeTopCase;
            action planPick;
            action gripCase;
            action verifyGrip;
            action placeOnInduction;
            action updateInventory;
        }

        state machine depalletizerOperatingState {
            state idle;
            state scanning;
            state picking;
            state placing;
            state exceptionHandling;
            state stopped;

            initial then idle;
            transition idle_to_scanning first idle then scanning accept command == "start";
            transition scanning_to_picking first scanning then picking accept visionSystem.targetDetected == true;
            transition picking_to_placing first picking then placing accept endEffector.gripVerified == true;
            transition placing_to_scanning first placing then scanning;
            transition any_to_exception first scanning then exceptionHandling accept visionSystem.confidence < visionConfidenceThreshold;
            transition exception_to_idle first exceptionHandling then idle accept command == "clear";
            transition stop_from_idle first idle then stopped accept command == "stop";
        }
    }

    part def CaseInductionSubsystem {
        attribute inductionRate : ThroughputRate;
        attribute dimensionTolerance : Real = 0.005;

        port caseIn : CaseInputPort;
        port caseOut : CaseOutputPort;
        port control : ControlPort;

        part scanner : IdentificationScanner;
        part dimensioner : CaseDimensioner;
        part scale : WeighScale;
        part conveyor : ConveyorSegment;

        action validateAndInductCase {
            in item incomingCase : Case;
            out item inductedCase : Case;
            first identifyCase;
            then measureDimensions;
            then weighCase;
            then verifyStorageEligibility;
            then assignStorageMission;

            action identifyCase;
            action measureDimensions;
            action weighCase;
            action verifyStorageEligibility;
            action assignStorageMission;
        }
    }

    part def DenseStorageStructure {
        attribute aisleCount : Integer;
        attribute levelCount : Integer;
        attribute cellCount : Integer;
        attribute occupiedCellCount : Integer;
        attribute structuralLoadLimit : Real;

        port caseIn : CaseInputPort;
        port caseOut : CaseOutputPort;
        port robotInterface : TotePort;
        port telemetry : TelemetryPort;

        part storageCells : StorageCell[1..*];
        part accessRails : RailSegment[1..*];
        part liftStations : VerticalLift[1..*];

        action storeCase {
            in item c : Case;
            in attribute targetCell : Location3D;
            first reserveCell;
            then transportToCell;
            then depositCase;
            then confirmInventoryLocation;

            action reserveCell;
            action transportToCell;
            action depositCase;
            action confirmInventoryLocation;
        }

        action retrieveCase {
            in attribute sourceCell : Location3D;
            out item c : Case;
            first lockCell;
            then dispatchRobot;
            then extractCase;
            then deliverToSequencer;
            then releaseCell;

            action lockCell;
            action dispatchRobot;
            action extractCase;
            action deliverToSequencer;
            action releaseCell;
        }
    }

    part def StorageCell {
        attribute cellId : String;
        attribute location : Location3D;
        attribute maxMass : Real = 40.0;
        attribute occupied : Boolean;
        item storedCase : Case[0..1];
    }

    part def AutonomousRobotFleet {
        attribute robotCount : Integer;
        attribute activeRobotCount : Integer;
        attribute fleetUtilization : Percent;
        attribute averageMissionLatency : Real;

        port fleetMissionPort : MissionPort;
        port gridInterface : TotePort;
        port safetyControl : ControlPort;
        port chargeInterface : ControlPort;
        port telemetry : TelemetryPort;

        part robots : MobileStorageRobot[1..*];
        part trafficManager : FleetTrafficManager;

        action executeFleetMissions {
            in item missionQueue : Mission;
            first prioritizeMissions;
            then allocateRobot;
            then reservePath;
            then executeMotion;
            then confirmCompletion;

            action prioritizeMissions;
            action allocateRobot;
            action reservePath;
            action executeMotion;
            action confirmCompletion;
        }
    }

    part def MobileStorageRobot {
        attribute robotId : String;
        attribute maxSpeed : Real = 4.0;
        attribute maxPayloadMass : Real = 45.0;
        attribute position : Location3D;
        attribute battery : BatteryState;
        attribute healthState : String;

        port missionPort : MissionPort;
        port toteInterface : TotePort;
        port control : ControlPort;
        port telemetry : TelemetryPort;

        part driveBase : OmnidirectionalDrive;
        part liftMechanism : CaseLiftMechanism;
        part obstacleSensor : SafetyScanner;
        part localController : RobotController;

        state machine robotMissionState {
            state available;
            state assigned;
            state navigatingToSource;
            state loading;
            state navigatingToDestination;
            state unloading;
            state charging;
            state faulted;

            initial then available;
            transition assignMission first available then assigned accept assignedMission.missionId != "";
            transition beginMoveSource first assigned then navigatingToSource;
            transition arriveSource first navigatingToSource then loading accept position == assignedMission.sourceLocation;
            transition loadComplete first loading then navigatingToDestination;
            transition arriveDestination first navigatingToDestination then unloading accept position == assignedMission.targetLocation;
            transition unloadComplete first unloading then available;
            transition lowBattery first available then charging accept battery.stateOfCharge < 20.0;
            transition charged first charging then available accept battery.stateOfCharge > 85.0;
            transition faultDetected first navigatingToSource then faulted accept healthState == "fault";
            transition faultCleared first faulted then available accept command == "reset";
        }
    }

    part def OrderSequencingSubsystem {
        attribute sequencingAccuracyTarget : Percent = 99.8;
        attribute outboundThroughput : ThroughputRate;
        attribute activeOrderCount : Integer;

        port caseIn : CaseInputPort;
        port caseOut : CaseOutputPort;
        port orderInput : ControlPort;
        port telemetry : TelemetryPort;

        part sortationConveyors : ConveyorSegment[1..*];
        part mergeController : MergeController;
        part bufferLanes : SequencingLane[1..*];

        action sequenceOrder {
            in item order : Order;
            out item sequencedCase : Case;
            first analyzeOrderLines;
            then requestRetrievalMissions;
            then bufferCasesByStop;
            then releaseCasesInDoorSequence;

            action analyzeOrderLines;
            action requestRetrievalMissions;
            action bufferCasesByStop;
            action releaseCasesInDoorSequence;
        }
    }

    part def OutboundBufferSubsystem {
        attribute laneCount : Integer;
        attribute stagingCapacityCases : Integer;
        attribute shipDoorCount : Integer;

        port caseIn : CaseInputPort;
        port caseOut : CaseOutputPort;
        port control : ControlPort;

        part doorLanes : SequencingLane[1..*];
        part labelVerifier : IdentificationScanner;
        part takeawayConveyor : ConveyorSegment;

        action stageOutboundCases {
            in item sequencedCase : Case;
            in item assignedOrder : Order;
            first verifyLabel;
            then assignDoorLane;
            then stageByDepartureTime;
            then releaseToShipping;

            action verifyLabel;
            action assignDoorLane;
            action stageByDepartureTime;
            action releaseToShipping;
        }
    }

    part def WarehouseExecutionSystem {
        attribute orderPlanningHorizonMinutes : Integer;
        attribute inventoryAccuracyTarget : Percent = 99.9;
        attribute missionReplanIntervalSeconds : Real = 2.0;

        port robotMissionPort : MissionPort;
        port hostInterface : ControlPort;
        port systemTelemetry : TelemetryPort;

        part inventoryService : InventoryControlService;
        part orderPlanner : OrderPlanningService;
        part missionScheduler : MissionSchedulingService;
        part exceptionManager : ExceptionManagementService;

        action planWarehouseFlow {
            in item orders : Order;
            first receiveOrders;
            then computeCaseDemand;
            then allocateInventory;
            then generateRobotMissions;
            then monitorExecution;

            action receiveOrders;
            action computeCaseDemand;
            action allocateInventory;
            action generateRobotMissions;
            action monitorExecution;
        }
    }

    part def SafetySupervisionSystem {
        attribute emergencyStopActive : Boolean;
        attribute guardedZoneClear : Boolean;
        attribute safetyIntegrityLevel : String = "SIL2";

        port controlInterlock : ControlPort;
        port telemetry : TelemetryPort;

        part emergencyStops : EmergencyStopDevice[1..*];
        part lightCurtains : PresenceSensor[1..*];
        part safetyPLC : SafetyController;

        action superviseSafety {
            first monitorZones;
            then evaluateInterlocks;
            then permitOrStopMotion;

            action monitorZones;
            action evaluateInterlocks;
            action permitOrStopMotion;
        }
    }

    part def ChargingSubsystem {
        attribute chargerCount : Integer;
        attribute maxChargePower : EnergyRate;
        attribute chargingQueueLength : Integer;

        port chargeControl : ControlPort;
        port telemetry : TelemetryPort;

        part chargers : RobotCharger[1..*];

        action manageCharging {
            first identifyLowBatteryRobots;
            then reserveCharger;
            then routeRobotToCharger;
            then chargeUntilReady;
            then releaseRobot;

            action identifyLowBatteryRobots;
            action reserveCharger;
            action routeRobotToCharger;
            action chargeUntilReady;
            action releaseRobot;
        }
    }

    part def ConveyorSegment {
        attribute segmentId : String;
        attribute length : Real;
        attribute speed : Real;
        attribute running : Boolean;
        port caseIn : CaseInputPort;
        port caseOut : CaseOutputPort;
    }

    part def IdentificationScanner {
        attribute scanRate : ThroughputRate;
        attribute readAccuracy : Percent;
        attribute lastReadId : String;
    }

    part def CaseDimensioner {
        attribute measurementAccuracy : Real;
    }

    part def WeighScale {
        attribute maxMass : Real;
        attribute accuracy : Real;
    }

    part def SixAxisManipulator {
        attribute reach : Real;
        attribute payload : Real;
        attribute repeatability : Real;
    }

    part def VacuumGripper {
        attribute vacuumLevel : Real;
        attribute gripVerified : Boolean;
    }

    part def MachineVisionSystem {
        attribute confidence : Percent;
        attribute targetDetected : Boolean;
    }

    part def RailSegment {
        attribute railId : String;
        attribute length : Real;
        attribute maxRobotSpeed : Real;
    }

    part def VerticalLift {
        attribute liftId : String;
        attribute maxPayloadMass : Real;
        attribute liftSpeed : Real;
    }

    part def OmnidirectionalDrive {
        attribute wheelCount : Integer = 4;
        attribute maxAcceleration : Real;
    }

    part def CaseLiftMechanism {
        attribute liftHeight : Real;
        attribute liftCapacity : Real;
    }

    part def SafetyScanner {
        attribute detectionRange : Real;
        attribute protectiveFieldActive : Boolean;
    }

    part def RobotController {
        attribute firmwareVersion : String;
        attribute controlLoopFrequency : Real;
    }

    part def FleetTrafficManager {
        attribute reservedPathCount : Integer;
        attribute deadlockDetected : Boolean;

        action resolveTraffic {
            first detectConflicts;
            then assignRightOfWay;
            then replanBlockedRobots;

            action detectConflicts;
            action assignRightOfWay;
            action replanBlockedRobots;
        }
    }

    part def SequencingLane {
        attribute laneId : String;
        attribute capacityCases : Integer;
        attribute assignedDoor : String;
        attribute currentFillLevel : Integer;
    }

    part def MergeController {
        attribute mergeRate : ThroughputRate;
        attribute jamDetected : Boolean;
    }

    part def InventoryControlService {
        attribute trackedCaseCount : Integer;
        attribute inventoryAccuracy : Percent;
    }

    part def OrderPlanningService {
        attribute plannedOrderCount : Integer;
        attribute lateOrderRiskCount : Integer;
    }

    part def MissionSchedulingService {
        attribute queuedMissionCount : Integer;
        attribute completedMissionCount : Integer;
    }

    part def ExceptionManagementService {
        attribute openExceptionCount : Integer;
        attribute meanTimeToRecoverMinutes : Real;
    }

    part def EmergencyStopDevice {
        attribute deviceId : String;
        attribute activated : Boolean;
    }

    part def PresenceSensor {
        attribute sensorId : String;
        attribute zoneClear : Boolean;
    }

    part def SafetyController {
        attribute safetyState : String;
        attribute motionPermit : Boolean;
    }

    part def RobotCharger {
        attribute chargerId : String;
        attribute available : Boolean;
        attribute chargePower : EnergyRate;
    }

    action def receiveStoreRetrieveSequence {
        in item inboundCase : Case;
        in item outboundOrder : Order;
        out item shippedCase : Case;

        first receiveInboundInventory;
        then depalletizeMixedPallets;
        then identifyAndInductCases;
        then storeCasesInDenseGrid;
        then planOutboundRetrieval;
        then retrieveCasesByOrder;
        then sequenceCasesToDoor;
        then releaseCasesForShipment;

        action receiveInboundInventory;
        action depalletizeMixedPallets;
        action identifyAndInductCases;
        action storeCasesInDenseGrid;
        action planOutboundRetrieval;
        action retrieveCasesByOrder;
        action sequenceCasesToDoor;
        action releaseCasesForShipment;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall automate case-level warehouse fulfillment by receiving inbound inventory, storing cases in a dense automated structure, retrieving required cases, sequencing them by outbound order, and delivering them to shipping doors. */
    }

    requirement def ThroughputRequirement {
        doc /* The system shall sustain at least 12000 cases per hour across induction, storage retrieval, sequencing, and outbound release under nominal operating conditions. */
        attribute requiredThroughput : ThroughputRate;
    }

    requirement def InventoryTraceabilityRequirement {
        doc /* The system shall maintain a recorded identity and storage location for every inducted case from receipt through outbound release. */
        attribute minimumAccuracy : Percent = 99.9;
    }

    requirement def SafetyRequirement {
        doc /* The system shall stop hazardous motion when an emergency stop is activated or a guarded human-access zone is occupied. */
        attribute maximumStopTimeSeconds : Real = 1.0;
    }

    requirement def RobotEnergyRequirement {
        doc /* The robot fleet shall automatically route robots to charging before state of charge falls below the minimum operating threshold. */
        attribute minimumOperatingStateOfCharge : Percent = 20.0;
    }

    requirement def SequencingRequirement {
        doc /* The order sequencing subsystem shall release cases to outbound doors in the planned loading sequence for each order. */
        attribute sequencingAccuracy : Percent = 99.8;
    }

    requirement def AvailabilityRequirement {
        doc /* The warehouse automation system shall provide high operational availability through fault detection, mission replanning, and redundant robot capacity. */
        attribute targetAvailability : Percent = 99.0;
    }

    satisfy PrimaryFunctionRequirement by SymboticWarehouseSystem;
    satisfy ThroughputRequirement by SymboticWarehouseSystem;
    satisfy InventoryTraceabilityRequirement by WarehouseExecutionSystem;
    satisfy SafetyRequirement by SafetySupervisionSystem;
    satisfy RobotEnergyRequirement by ChargingSubsystem;
    satisfy SequencingRequirement by OrderSequencingSubsystem;
    satisfy AvailabilityRequirement by AutonomousRobotFleet;

    constraint def ThroughputCapacityConstraint {
        in inductionRate : Real;
        in retrievalRate : Real;
        in sequencingRate : Real;
        in requiredRate : Real;
        constraint min(inductionRate, retrievalRate, sequencingRate) >= requiredRate;
    }

    constraint def StorageUtilizationConstraint {
        in occupiedCells : Integer;
        in totalCells : Integer;
        in maximumUtilization : Real;
        constraint occupiedCells / totalCells <= maximumUtilization;
    }

    constraint def RobotPayloadConstraint {
        in caseMass : Real;
        in robotPayloadLimit : Real;
        constraint caseMass <= robotPayloadLimit;
    }

    constraint def BatteryDispatchConstraint {
        in stateOfCharge : Real;
        in minimumDispatchCharge : Real;
        constraint stateOfCharge >= minimumDispatchCharge;
    }

    analysis def NominalSystemSizing {
        subject system : SymboticWarehouseSystem;

        objective maximizeThroughput {
            doc /* Balance induction capacity, robot retrieval capacity, sequencing capacity, and outbound staging capacity. */
        }

        constraint throughputCapacity : ThroughputCapacityConstraint {
            inductionRate = system.induction.inductionRate.rate;
            retrievalRate = system.robotFleet.activeRobotCount * 45.0;
            sequencingRate = system.orderSequencer.outboundThroughput.rate;
            requiredRate = 12000.0;
        }

        constraint storageUtilization : StorageUtilizationConstraint {
            occupiedCells = system.storageGrid.occupiedCellCount;
            totalCells = system.storageGrid.cellCount;
            maximumUtilization = 0.92;
        }
    }

    verification case VerifyPrimaryFulfillmentFlow {
        subject system : SymboticWarehouseSystem;
        objective verify system satisfies PrimaryFunctionRequirement;

        action runNominalFulfillmentScenario {
            first injectInboundCases;
            then createOutboundOrders;
            then executeStorageAndRetrieval;
            then confirmSequencedDoorRelease;

            action injectInboundCases;
            action createOutboundOrders;
            action executeStorageAndRetrieval;
            action confirmSequencedDoorRelease;
        }
    }

    verification case VerifyEmergencyStop {
        subject safety : SafetySupervisionSystem;
        objective verify safety satisfies SafetyRequirement;

        action runEmergencyStopScenario {
            first commandRobotMotion;
            then activateEmergencyStop;
            then measureMotionStopTime;
            then confirmMotionPermitFalse;

            action commandRobotMotion;
            action activateEmergencyStop;
            action measureMotionStopTime;
            action confirmMotionPermitFalse;
        }
    }

    verification case VerifyRobotChargingBehavior {
        subject fleet : AutonomousRobotFleet;
        objective verify ChargingSubsystem satisfies RobotEnergyRequirement;

        action runLowBatteryScenario {
            first setRobotBatteryBelowThreshold;
            then requestMissionAssignment;
            then confirmChargingMissionIssued;
            then confirmRobotUnavailableForStorageMission;

            action setRobotBatteryBelowThreshold;
            action requestMissionAssignment;
            action confirmChargingMissionIssued;
            action confirmRobotUnavailableForStorageMission;
        }
    }
}