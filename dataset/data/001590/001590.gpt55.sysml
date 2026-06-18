package SymboticBasedWarehouseAutomationModel {

  import ScalarValues::*;
  import ISQ::*;

  attribute def CaseRate :> Real {
    attribute unitSymbol : String = "case/h";
  }

  attribute def OrderRate :> Real {
    attribute unitSymbol : String = "orders/h";
  }

  attribute def AvailabilityRatio :> Real {
    attribute unitSymbol : String = "1";
  }

  attribute def PercentValue :> Real {
    attribute unitSymbol : String = "%";
  }

  attribute def TimeSeconds :> Real {
    attribute unitSymbol : String = "s";
  }

  attribute def TimeMinutes :> Real {
    attribute unitSymbol : String = "min";
  }

  attribute def ElectricPower_kW :> Real {
    attribute unitSymbol : String = "kW";
  }

  attribute def ElectricEnergy_kWh :> Real {
    attribute unitSymbol : String = "kWh";
  }

  attribute def Speed_mps :> Real {
    attribute unitSymbol : String = "m/s";
  }

  attribute def Length_m :> Real {
    attribute unitSymbol : String = "m";
  }

  attribute def Mass_kg :> Real {
    attribute unitSymbol : String = "kg";
  }

  attribute def Count :> Integer {
    attribute unitSymbol : String = "count";
  }

  enum def InventoryDisposition {
    enum store;
    enum crossDock;
    enum reject;
    enum quarantine;
    enum ship;
  }

  enum def RobotHealth {
    enum nominal;
    enum degraded;
    enum charging;
    enum blocked;
    enum faulted;
    enum emergencyStopped;
  }

  enum def OrderPriority {
    enum routine;
    enum expedited;
    enum waveCritical;
    enum recovery;
  }

  item def SKU {
    attribute skuId : String;
    attribute description : String;
    attribute family : String;
    attribute eachMass : Mass_kg;
    attribute caseLength : Length_m;
    attribute caseWidth : Length_m;
    attribute caseHeight : Length_m;
    attribute temperatureClass : String;
    attribute hazardous : Boolean;
  }

  item def InventoryCase {
    attribute caseId : String;
    attribute sku : SKU;
    attribute mass : Mass_kg;
    attribute length : Length_m;
    attribute width : Length_m;
    attribute height : Length_m;
    attribute barcode : String;
    attribute lotCode : String;
    attribute expirationDate : String;
    attribute disposition : InventoryDisposition;
  }

  item def CaseBatch {
    item cases : InventoryCase[*];
    attribute batchId : String;
    attribute caseCount : Count;
    attribute receivedTime : String;
  }

  item def StorageLocation {
    attribute aisle : Integer;
    attribute level : Integer;
    attribute lane : Integer;
    attribute slot : Integer;
    attribute xCoordinate : Length_m;
    attribute yCoordinate : Length_m;
    attribute zCoordinate : Length_m;
  }

  item def StoredCaseRecord {
    item storedCase : InventoryCase;
    item location : StorageLocation;
    attribute storedTime : String;
    attribute availableForAllocation : Boolean;
  }

  item def StoreOrderLine {
    attribute lineId : String;
    attribute skuId : String;
    attribute requiredCases : Count;
    attribute sequenceNumber : Integer;
  }

  item def StoreOrder {
    attribute orderId : String;
    attribute destinationStoreId : String;
    attribute shipWindowStart : String;
    attribute shipWindowEnd : String;
    attribute priority : OrderPriority;
    item lines : StoreOrderLine[*];
  }

  item def PalletPattern {
    attribute patternId : String;
    attribute maxLayers : Count;
    attribute maxCaseOverhang : Length_m;
    attribute targetHeight : Length_m;
    attribute heavyCaseBottomRule : Boolean;
    attribute storeAisleSequenceRule : Boolean;
  }

  item def StoreReadyPallet {
    attribute palletId : String;
    attribute destinationStoreId : String;
    attribute totalCases : Count;
    attribute grossMass : Mass_kg;
    attribute height : Length_m;
    attribute wrapped : Boolean;
    item pattern : PalletPattern;
    item cases : InventoryCase[*];
  }

  item def RobotMission {
    attribute missionId : String;
    attribute assignedRobotId : String;
    item sourceLocation : StorageLocation;
    item destinationLocation : StorageLocation;
    attribute targetCaseId : String;
    attribute priority : OrderPriority;
    attribute plannedTravelDistance : Length_m;
    attribute deadline : String;
  }

  item def RobotStatus {
    attribute robotId : String;
    attribute health : RobotHealth;
    attribute batteryStateOfCharge : PercentValue;
    attribute currentSpeed : Speed_mps;
    item currentLocation : StorageLocation;
    attribute carryingCaseId : String;
    attribute currentMissionId : String;
  }

  item def InventorySnapshot {
    attribute snapshotId : String;
    attribute recordCount : Count;
    item records : StoredCaseRecord[*];
  }

  item def DiagnosticEvent {
    attribute eventId : String;
    attribute sourceAssetId : String;
    attribute severity : String;
    attribute message : String;
    attribute timestamp : String;
  }

  item def HumanCommand {
    attribute commandId : String;
    attribute operatorId : String;
    attribute commandName : String;
    attribute reason : String;
  }

  item def ElectricPower {
    attribute voltage : Real;
    attribute current : Real;
    attribute power : ElectricPower_kW;
  }

  port def CaseReceivePort {
    in item receivedCase : InventoryCase;
  }

  port def CaseDispatchPort {
    out item dispatchedCase : InventoryCase;
  }

  port def CaseTransferInPort {
    in item transferredCase : InventoryCase;
  }

  port def CaseTransferOutPort {
    out item transferredCase : InventoryCase;
  }

  port def OrderInputPort {
    in item order : StoreOrder;
  }

  port def PalletOutputPort {
    out item pallet : StoreReadyPallet;
  }

  port def InventoryDataPort {
    in item inventorySnapshot : InventorySnapshot;
    out item allocationUpdate : StoredCaseRecord;
  }

  port def RobotControlPort {
    out item mission : RobotMission;
    in item status : RobotStatus;
  }

  port def RobotAccessPort {
    in item robotStatus : RobotStatus;
    out item accessibleCase : InventoryCase;
  }

  port def DiagnosticPort {
    out item event : DiagnosticEvent;
  }

  port def OperatorPort {
    in item command : HumanCommand;
    out item event : DiagnosticEvent;
  }

  port def ElectricPowerInputPort {
    in item power : ElectricPower;
  }

  port def ElectricPowerOutputPort {
    out item power : ElectricPower;
  }

  port def SafetyInterlockPort {
    in item stopCommand : HumanCommand;
    out item safetyEvent : DiagnosticEvent;
  }

  action def ReceiveAndIdentifyCases {
    in item rawInboundCase : InventoryCase;
    out item identifiedCase : InventoryCase;
    out item rejectedCase : InventoryCase;

    attribute scanTime : TimeSeconds = 0.8;
    attribute minimumBarcodeReadConfidence : PercentValue = 99.5;
    attribute maximumAcceptedMass : Mass_kg = 32.0;
  }

  action def DecideInventoryDisposition {
    in item identifiedCase : InventoryCase;
    in item activeOrders : StoreOrder[*];
    out item caseForStorage : InventoryCase;
    out item caseForCrossDock : InventoryCase;
    out item caseForQuarantine : InventoryCase;

    attribute decisionLatency : TimeSeconds = 0.3;
  }

  action def StoreCasesInDenseGrid {
    in item caseForStorage : InventoryCase;
    in item availableLocation : StorageLocation;
    out item storedRecord : StoredCaseRecord;

    attribute placementAccuracy : Length_m = 0.01;
    attribute targetStorageLatency : TimeSeconds = 45.0;
  }

  action def AllocateCasesToOrder {
    in item order : StoreOrder;
    in item inventory : InventorySnapshot;
    out item retrievalMission : RobotMission[*];

    attribute allocationLatency : TimeSeconds = 2.0;
    attribute fifoLotRotationEnabled : Boolean = true;
    attribute expirationDateRotationEnabled : Boolean = true;
  }

  action def RetrieveCasesFromGrid {
    in item retrievalMission : RobotMission;
    out item retrievedCase : InventoryCase;
    out item robotStatus : RobotStatus;

    attribute nominalTravelSpeed : Speed_mps = 3.5;
    attribute maximumLiftHeight : Length_m = 12.0;
  }

  action def SequenceCasesForPalletizing {
    in item retrievedCase : InventoryCase[*];
    in item order : StoreOrder;
    out item sequencedCase : InventoryCase[*];

    attribute sequenceAccuracy : PercentValue = 99.95;
  }

  action def BuildStoreReadyPallet {
    in item sequencedCase : InventoryCase[*];
    in item order : StoreOrder;
    out item pallet : StoreReadyPallet;

    attribute maximumPalletMass : Mass_kg = 1200.0;
    attribute maximumPalletHeight : Length_m = 2.3;
    attribute palletBuildAccuracy : PercentValue = 99.9;
  }

  action def WrapLabelAndReleasePallet {
    in item pallet : StoreReadyPallet;
    out item releasedPallet : StoreReadyPallet;

    attribute wrapCycleTime : TimeSeconds = 25.0;
    attribute labelVerificationRequired : Boolean = true;
  }

  action def FulfillStoreOrder {
    in item inboundCase : InventoryCase[*];
    in item storeOrder : StoreOrder;
    in item currentInventory : InventorySnapshot;
    out item completedPallet : StoreReadyPallet;

    action receive : ReceiveAndIdentifyCases;
    action decide : DecideInventoryDisposition;
    action store : StoreCasesInDenseGrid;
    action allocate : AllocateCasesToOrder;
    action retrieve : RetrieveCasesFromGrid;
    action sequence : SequenceCasesForPalletizing;
    action palletize : BuildStoreReadyPallet;
    action release : WrapLabelAndReleasePallet;

    flow receive.identifiedCase to decide.identifiedCase;
    flow decide.caseForStorage to store.caseForStorage;
    flow store.storedRecord to currentInventory.records;
    flow storeOrder to allocate.order;
    flow currentInventory to allocate.inventory;
    flow allocate.retrievalMission to retrieve.retrievalMission;
    flow retrieve.retrievedCase to sequence.retrievedCase;
    flow storeOrder to sequence.order;
    flow sequence.sequencedCase to palletize.sequencedCase;
    flow storeOrder to palletize.order;
    flow palletize.pallet to release.pallet;
    flow release.releasedPallet to completedPallet;
  }

  state def FulfillmentSystemOperatingStates {
    entry;

    state PoweredOff;
    state Starting;
    state Ready;
    state ReceivingInventory;
    state StoringInventory;
    state FulfillingOrders;
    state ReplenishingRobotEnergy;
    state DegradedOperation;
    state EmergencyStopped;
    state Maintenance;

    transition entry then PoweredOff;

    transition PoweredOff then Starting accept HumanCommand
      if command.commandName == "PowerOn";

    transition Starting then Ready
      if startupComplete == true;

    transition Ready then ReceivingInventory
      if inboundCasesAvailable == true;

    transition ReceivingInventory then StoringInventory
      if identifiedCasesQueued == true;

    transition StoringInventory then Ready
      if storageQueueEmpty == true;

    transition Ready then FulfillingOrders
      if openOrdersAvailable == true;

    transition FulfillingOrders then Ready
      if activeOrderWaveComplete == true;

    transition Ready then ReplenishingRobotEnergy
      if fleetAverageBatteryStateOfCharge < 35.0;

    transition ReplenishingRobotEnergy then Ready
      if fleetAverageBatteryStateOfCharge > 80.0;

    transition Ready then DegradedOperation
      if nonCriticalFaultPresent == true;

    transition ReceivingInventory then DegradedOperation
      if nonCriticalFaultPresent == true;

    transition StoringInventory then DegradedOperation
      if nonCriticalFaultPresent == true;

    transition FulfillingOrders then DegradedOperation
      if nonCriticalFaultPresent == true;

    transition DegradedOperation then Ready
      if nonCriticalFaultCleared == true;

    transition PoweredOff then Maintenance accept HumanCommand
      if command.commandName == "EnterMaintenance";

    transition Ready then Maintenance accept HumanCommand
      if command.commandName == "EnterMaintenance";

    transition Maintenance then Starting accept HumanCommand
      if command.commandName == "ExitMaintenance";

    transition Starting then EmergencyStopped
      if emergencyStopActive == true;

    transition Ready then EmergencyStopped
      if emergencyStopActive == true;

    transition ReceivingInventory then EmergencyStopped
      if emergencyStopActive == true;

    transition StoringInventory then EmergencyStopped
      if emergencyStopActive == true;

    transition FulfillingOrders then EmergencyStopped
      if emergencyStopActive == true;

    transition DegradedOperation then EmergencyStopped
      if emergencyStopActive == true;

    transition EmergencyStopped then Starting accept HumanCommand
      if command.commandName == "ResetEmergencyStop";
  }

  state def MobileRobotStates {
    entry;

    state Idle;
    state AssignedMission;
    state NavigatingToSource;
    state AcquiringCase;
    state CarryingCase;
    state ReleasingCase;
    state Charging;
    state Blocked;
    state Faulted;

    transition entry then Idle;

    transition Idle then AssignedMission
      if missionAssigned == true;

    transition AssignedMission then NavigatingToSource
      if pathReserved == true;

    transition NavigatingToSource then AcquiringCase
      if sourceReached == true;

    transition AcquiringCase then CarryingCase
      if caseSecured == true;

    transition CarryingCase then ReleasingCase
      if destinationReached == true;

    transition ReleasingCase then Idle
      if caseReleased == true;

    transition Idle then Charging
      if batteryStateOfCharge < 20.0;

    transition Charging then Idle
      if batteryStateOfCharge > 90.0;

    transition NavigatingToSource then Blocked
      if pathObstructed == true;

    transition CarryingCase then Blocked
      if pathObstructed == true;

    transition Blocked then NavigatingToSource
      if rerouteComplete == true and carryingCase == false;

    transition Blocked then CarryingCase
      if rerouteComplete == true and carryingCase == true;

    transition Idle then Faulted
      if robotFaultDetected == true;

    transition AssignedMission then Faulted
      if robotFaultDetected == true;

    transition NavigatingToSource then Faulted
      if robotFaultDetected == true;

    transition CarryingCase then Faulted
      if robotFaultDetected == true;

    transition Faulted then Idle
      if faultCleared == true;
  }

  part def BarcodeScanner {
    attribute readRate : CaseRate = 4500.0;
    attribute readAccuracy : PercentValue = 99.97;
    attribute scanEnvelopeHeight : Length_m = 0.8;
    port caseIn : CaseReceivePort;
    port caseOut : CaseTransferOutPort;
    port diagnostics : DiagnosticPort;
  }

  part def DimensioningAndWeighingStation {
    attribute dimensionalAccuracy : Length_m = 0.005;
    attribute massAccuracy : Mass_kg = 0.05;
    attribute maximumCaseMass : Mass_kg = 32.0;
    port caseIn : CaseTransferInPort;
    port caseOut : CaseTransferOutPort;
    port diagnostics : DiagnosticPort;
  }

  part def InboundInductionSubsystem {
    attribute nominalInductionRate : CaseRate = 1800.0;
    attribute rejectRateLimit : PercentValue = 1.0;
    attribute inductionLaneCount : Count = 12;

    part scanner : BarcodeScanner[12];
    part dimensioner : DimensioningAndWeighingStation[12];

    port receiving : CaseReceivePort;
    port caseOut : CaseTransferOutPort;
    port rejectedCaseOut : CaseTransferOutPort;
    port diagnostics : DiagnosticPort;
    port powerIn : ElectricPowerInputPort;

    perform action identifyInboundCase : ReceiveAndIdentifyCases;
  }

  part def DenseStorageGrid {
    attribute gridLength : Length_m = 140.0;
    attribute gridWidth : Length_m = 90.0;
    attribute gridHeight : Length_m = 14.0;
    attribute storageCapacity : Count = 420000;
    attribute locationAccuracy : Length_m = 0.01;
    attribute nominalCaseDwellTime : TimeMinutes = 720.0;

    item storageRecords : StoredCaseRecord[*];

    port caseIn : CaseTransferInPort;
    port caseOut : CaseTransferOutPort;
    port robotAccess : RobotAccessPort;
    port inventoryData : InventoryDataPort;
    port diagnostics : DiagnosticPort;
    port powerIn : ElectricPowerInputPort;

    perform action storeCase : StoreCasesInDenseGrid;
    perform action retrieveCase : RetrieveCasesFromGrid;
  }

  part def AutonomousMobileRobot {
    attribute robotId : String;
    attribute maximumPayload : Mass_kg = 32.0;
    attribute maximumSpeed : Speed_mps = 4.0;
    attribute positioningTolerance : Length_m = 0.015;
    attribute batteryCapacity : ElectricEnergy_kWh = 2.4;
    attribute nominalOperatingTime : TimeMinutes = 240.0;
    attribute batteryStateOfCharge : PercentValue = 85.0;

    port command : RobotControlPort;
    port gridAccess : RobotAccessPort;
    port powerIn : ElectricPowerInputPort;
    port diagnostics : DiagnosticPort;

    exhibit state robotState : MobileRobotStates;
  }

  part def RobotCharger {
    attribute chargerPower : ElectricPower_kW = 3.0;
    attribute chargeTimeFrom20To90 : TimeMinutes = 38.0;
    attribute connectorAlignmentTolerance : Length_m = 0.02;

    port powerIn : ElectricPowerInputPort;
    port powerOut : ElectricPowerOutputPort;
    port diagnostics : DiagnosticPort;
  }

  part def AutonomousRobotFleet {
    attribute fleetSize : Count = 240;
    attribute minimumAvailableRobots : Count = 200;
    attribute averageBatteryStateOfCharge : PercentValue = 78.0;
    attribute fleetMissionCompletionRate : CaseRate = 1500.0;

    part robots : AutonomousMobileRobot[240];
    part chargers : RobotCharger[24];

    port command : RobotControlPort;
    port gridAccess : RobotAccessPort;
    port diagnostics : DiagnosticPort;
    port powerIn : ElectricPowerInputPort;
  }

  part def VerticalLift {
    attribute liftId : String;
    attribute ratedPayload : Mass_kg = 50.0;
    attribute liftSpeed : Speed_mps = 2.2;
    attribute maximumLiftHeight : Length_m = 14.0;
    attribute transferCycleTime : TimeSeconds = 8.0;

    port caseIn : CaseTransferInPort;
    port caseOut : CaseTransferOutPort;
    port robotAccess : RobotAccessPort;
    port diagnostics : DiagnosticPort;
    port powerIn : ElectricPowerInputPort;
  }

  part def LiftBank {
    attribute liftCount : Count = 32;
    attribute nominalLiftThroughput : CaseRate = 2200.0;

    part lifts : VerticalLift[32];

    port caseIn : CaseTransferInPort;
    port caseOut : CaseTransferOutPort;
    port robotAccess : RobotAccessPort;
    port diagnostics : DiagnosticPort;
    port powerIn : ElectricPowerInputPort;
  }

  part def SequencingBuffer {
    attribute bufferCapacity : Count = 2000;
    attribute releaseAccuracy : PercentValue = 99.95;
    attribute maximumBufferDwellTime : TimeMinutes = 30.0;

    port caseIn : CaseTransferInPort;
    port caseOut : CaseTransferOutPort;
    port diagnostics : DiagnosticPort;
  }

  part def RoboticPalletizer {
    attribute palletizerId : String;
    attribute picksPerHour : CaseRate = 650.0;
    attribute maximumCaseMass : Mass_kg = 32.0;
    attribute placementTolerance : Length_m = 0.012;
    attribute maximumPalletHeight : Length_m = 2.3;

    port caseIn : CaseTransferInPort;
    port palletOut : PalletOutputPort;
    port diagnostics : DiagnosticPort;
    port powerIn : ElectricPowerInputPort;

    perform action buildPallet : BuildStoreReadyPallet;
  }

  part def WrapperAndLabeler {
    attribute wrapRate : OrderRate = 120.0;
    attribute labelVerificationAccuracy : PercentValue = 99.99;
    attribute filmConsumptionPerPallet : Length_m = 35.0;

    port palletIn : PalletOutputPort;
    port palletOut : PalletOutputPort;
    port diagnostics : DiagnosticPort;
    port powerIn : ElectricPowerInputPort;

    perform action releasePallet : WrapLabelAndReleasePallet;
  }

  part def RoboticPalletizingSubsystem {
    attribute palletizingCellCount : Count = 8;
    attribute nominalPalletThroughput : OrderRate = 480.0;
    attribute casePlacementAccuracy : PercentValue = 99.9;

    part buffer : SequencingBuffer;
    part palletizers : RoboticPalletizer[8];
    part wrapperLabeler : WrapperAndLabeler[8];

    port caseIn : CaseTransferInPort;
    port palletOut : PalletOutputPort;
    port diagnostics : DiagnosticPort;
    port powerIn : ElectricPowerInputPort;

    perform action sequenceCases : SequenceCasesForPalletizing;
    perform action buildPallets : BuildStoreReadyPallet;
  }

  part def WarehouseOrchestrationController {
    attribute controllerName : String = "Symbotic-Based Warehouse Orchestration Controller";
    attribute orderPlanningLatency : TimeSeconds = 2.0;
    attribute robotDispatchLatency : TimeSeconds = 0.5;
    attribute inventoryAccuracy : PercentValue = 99.98;
    attribute nominalOrdersManaged : OrderRate = 600.0;

    port orderIn : OrderInputPort;
    port robotControl : RobotControlPort;
    port inventoryData : InventoryDataPort;
    port diagnostics : DiagnosticPort;
    port operatorInterface : OperatorPort;
    port powerIn : ElectricPowerInputPort;

    perform action allocateCases : AllocateCasesToOrder;
  }

  part def SafetySubsystem {
    attribute safetyIntegrityLevel : String = "SIL 3 equivalent";
    attribute emergencyStopReactionTime : TimeSeconds = 0.2;
    attribute guardedZoneCount : Count = 48;
    attribute lightCurtainResolution : Length_m = 0.03;

    port operatorInterface : OperatorPort;
    port interlock : SafetyInterlockPort;
    port diagnostics : DiagnosticPort;
    port powerIn : ElectricPowerInputPort;
  }

  part def PowerDistributionSubsystem {
    attribute utilityVoltage : Real = 480.0;
    attribute nominalConnectedLoad : ElectricPower_kW = 1800.0;
    attribute peakDemandLimit : ElectricPower_kW = 1450.0;
    attribute backupRideThroughTime : TimeMinutes = 15.0;
    attribute energyMeteringAccuracy : PercentValue = 1.0;

    port utilityPowerIn : ElectricPowerInputPort;
    port automationPowerOut : ElectricPowerOutputPort;
    port diagnostics : DiagnosticPort;
  }

  part def OperationsAnalyticsSubsystem {
    attribute dataRetentionDays : Count = 730;
    attribute eventProcessingLatency : TimeSeconds = 1.0;
    attribute throughputForecastHorizon : TimeMinutes = 120.0;

    port inventoryData : InventoryDataPort;
    port diagnosticsIn : DiagnosticPort;
    port operatorInterface : OperatorPort;
    port powerIn : ElectricPowerInputPort;
  }

  part def SymboticBasedFulfillmentSystem {
    attribute systemName : String = "Symbotic-Based Automated Case Fulfillment System";
    attribute primaryFunction : String = "Autonomously transform inbound mixed-SKU cases into sequenced, store-ready outbound pallets by identifying, storing, retrieving, buffering, palletizing, and releasing inventory with coordinated mobile robots and warehouse orchestration software.";
    attribute nominalInboundThroughput : CaseRate = 1800.0;
    attribute nominalOutboundThroughput : CaseRate = 1500.0;
    attribute nominalPalletThroughput : OrderRate = 480.0;
    attribute storageCapacity : Count = 420000;
    attribute targetInventoryAccuracy : PercentValue = 99.98;
    attribute targetOrderAccuracy : PercentValue = 99.95;
    attribute targetSystemAvailability : AvailabilityRatio = 0.995;
    attribute maximumCaseMass : Mass_kg = 32.0;
    attribute facilityFootprintLength : Length_m = 165.0;
    attribute facilityFootprintWidth : Length_m = 115.0;
    attribute connectedElectricalLoad : ElectricPower_kW = 1800.0;

    part inboundInduction : InboundInductionSubsystem;
    part storageGrid : DenseStorageGrid;
    part robotFleet : AutonomousRobotFleet;
    part liftBank : LiftBank;
    part palletizing : RoboticPalletizingSubsystem;
    part orchestrationController : WarehouseOrchestrationController;
    part safety : SafetySubsystem;
    part powerDistribution : PowerDistributionSubsystem;
    part analytics : OperationsAnalyticsSubsystem;

    port inboundCases : CaseReceivePort;
    port storeOrders : OrderInputPort;
    port releasedPallets : PalletOutputPort;
    port operatorInterface : OperatorPort;
    port utilityPower : ElectricPowerInputPort;
    port diagnostics : DiagnosticPort;

    connection inboundPhysicalFlow connect inboundCases to inboundInduction.receiving;
    connection inductionToStorage connect inboundInduction.caseOut to storageGrid.caseIn;
    connection gridRobotAccess connect robotFleet.gridAccess to storageGrid.robotAccess;
    connection gridToLift connect storageGrid.caseOut to liftBank.caseIn;
    connection liftRobotAccess connect robotFleet.gridAccess to liftBank.robotAccess;
    connection liftToPalletizing connect liftBank.caseOut to palletizing.caseIn;
    connection palletRelease connect palletizing.palletOut to releasedPallets;

    connection orderFlow connect storeOrders to orchestrationController.orderIn;
    connection robotCommandFlow connect orchestrationController.robotControl to robotFleet.command;
    connection inventoryDataFlow connect storageGrid.inventoryData to orchestrationController.inventoryData;
    connection analyticsInventoryFlow connect storageGrid.inventoryData to analytics.inventoryData;

    connection operatorToController connect operatorInterface to orchestrationController.operatorInterface;
    connection operatorToSafety connect operatorInterface to safety.operatorInterface;
    connection safetyInterlock connect safety.interlock to robotFleet.command;

    connection utilityToPowerDistribution connect utilityPower to powerDistribution.utilityPowerIn;
    connection powerToInduction connect powerDistribution.automationPowerOut to inboundInduction.powerIn;
    connection powerToGrid connect powerDistribution.automationPowerOut to storageGrid.powerIn;
    connection powerToFleet connect powerDistribution.automationPowerOut to robotFleet.powerIn;
    connection powerToLiftBank connect powerDistribution.automationPowerOut to liftBank.powerIn;
    connection powerToPalletizing connect powerDistribution.automationPowerOut to palletizing.powerIn;
    connection powerToController connect powerDistribution.automationPowerOut to orchestrationController.powerIn;
    connection powerToSafety connect powerDistribution.automationPowerOut to safety.powerIn;
    connection powerToAnalytics connect powerDistribution.automationPowerOut to analytics.powerIn;

    connection controllerDiagnostics connect orchestrationController.diagnostics to diagnostics;
    connection inductionDiagnostics connect inboundInduction.diagnostics to diagnostics;
    connection gridDiagnostics connect storageGrid.diagnostics to diagnostics;
    connection robotDiagnostics connect robotFleet.diagnostics to diagnostics;
    connection liftDiagnostics connect liftBank.diagnostics to diagnostics;
    connection palletizingDiagnostics connect palletizing.diagnostics to diagnostics;
    connection safetyDiagnostics connect safety.diagnostics to diagnostics;
    connection powerDiagnostics connect powerDistribution.diagnostics to diagnostics;
    connection analyticsDiagnostics connect analytics.diagnosticsIn to diagnostics;

    exhibit state operatingState : FulfillmentSystemOperatingStates;
    perform action primaryFulfillmentFunction : FulfillStoreOrder;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : SymboticBasedFulfillmentSystem;

    doc /* The system shall provide the high-level primary function of converting inbound mixed-SKU inventory cases into store-ready outbound pallets using autonomous storage, retrieval, sequencing, and palletizing. */

    require constraint {
      system.primaryFunction == "Autonomously transform inbound mixed-SKU cases into sequenced, store-ready outbound pallets by identifying, storing, retrieving, buffering, palletizing, and releasing inventory with coordinated mobile robots and warehouse orchestration software."
    }
  }

  requirement def ThroughputRequirement {
    subject system : SymboticBasedFulfillmentSystem;

    doc /* The system shall sustain non-trivial automated warehouse throughput for inbound and outbound case handling. */

    require constraint {
      system.nominalInboundThroughput >= 1800.0 and
      system.nominalOutboundThroughput >= 1500.0 and
      system.nominalPalletThroughput >= 480.0
    }
  }

  requirement def InventoryAccuracyRequirement {
    subject system : SymboticBasedFulfillmentSystem;

    doc /* The system shall maintain accurate inventory records suitable for automated allocation and retrieval. */

    require constraint {
      system.targetInventoryAccuracy >= 99.98
    }
  }

  requirement def OrderAccuracyRequirement {
    subject system : SymboticBasedFulfillmentSystem;

    doc /* The system shall build store-ready pallets with high case selection and sequence accuracy. */

    require constraint {
      system.targetOrderAccuracy >= 99.95
    }
  }

  requirement def AvailabilityRequirement {
    subject system : SymboticBasedFulfillmentSystem;

    doc /* The system shall remain operationally available for continuous distribution-center operations. */

    require constraint {
      system.targetSystemAvailability >= 0.995
    }
  }

  requirement def CaseHandlingEnvelopeRequirement {
    subject system : SymboticBasedFulfillmentSystem;

    doc /* The system shall handle distribution cases up to the declared maximum mass while respecting the mechanical payload limits of robots, lifts, and palletizers. */

    require constraint {
      system.maximumCaseMass <= system.robotFleet.robots.maximumPayload and
      system.maximumCaseMass <= system.liftBank.lifts.ratedPayload and
      system.maximumCaseMass <= system.palletizing.palletizers.maximumCaseMass
    }
  }

  requirement def SafeStopRequirement {
    subject system : SymboticBasedFulfillmentSystem;

    doc /* The system shall transition to an emergency-stopped safe state when an emergency stop or guarded-zone violation occurs. */

    require constraint {
      system.safety.emergencyStopReactionTime <= 0.2
    }
  }

  requirement def EnergyDemandRequirement {
    subject system : SymboticBasedFulfillmentSystem;

    doc /* The system shall distribute electrical power within the configured facility peak demand limit. */

    require constraint {
      system.powerDistribution.peakDemandLimit <= system.powerDistribution.nominalConnectedLoad
    }
  }

  part symboticBasedWarehouseSystem : SymboticBasedFulfillmentSystem {
    attribute systemName = "High-Level Symbotic-Based Automated Warehouse";
    attribute primaryFunction = "Autonomously transform inbound mixed-SKU cases into sequenced, store-ready outbound pallets by identifying, storing, retrieving, buffering, palletizing, and releasing inventory with coordinated mobile robots and warehouse orchestration software.";
    attribute nominalInboundThroughput = 1800.0;
    attribute nominalOutboundThroughput = 1500.0;
    attribute nominalPalletThroughput = 480.0;
    attribute storageCapacity = 420000;
    attribute targetInventoryAccuracy = 99.98;
    attribute targetOrderAccuracy = 99.95;
    attribute targetSystemAvailability = 0.995;
    attribute maximumCaseMass = 32.0;
  }

  requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
    subject system = symboticBasedWarehouseSystem;
  }

  requirement throughputRequirement : ThroughputRequirement {
    subject system = symboticBasedWarehouseSystem;
  }

  requirement inventoryAccuracyRequirement : InventoryAccuracyRequirement {
    subject system = symboticBasedWarehouseSystem;
  }

  requirement orderAccuracyRequirement : OrderAccuracyRequirement {
    subject system = symboticBasedWarehouseSystem;
  }

  requirement availabilityRequirement : AvailabilityRequirement {
    subject system = symboticBasedWarehouseSystem;
  }

  requirement caseHandlingEnvelopeRequirement : CaseHandlingEnvelopeRequirement {
    subject system = symboticBasedWarehouseSystem;
  }

  requirement safeStopRequirement : SafeStopRequirement {
    subject system = symboticBasedWarehouseSystem;
  }

  requirement energyDemandRequirement : EnergyDemandRequirement {
    subject system = symboticBasedWarehouseSystem;
  }

}
