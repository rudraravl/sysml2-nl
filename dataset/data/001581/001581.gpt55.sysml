package SmartManufacturingSystemModel {

  import ScalarValues::*;

  attribute def Identifier :> String;
  attribute def Quantity :> Integer {
    doc /* Unit: count of discrete manufactured items. */
  }
  attribute def Temperature_degC :> Real {
    doc /* Unit: degree Celsius. */
  }
  attribute def Pressure_kPa :> Real {
    doc /* Unit: kilopascal. */
  }
  attribute def Power_kW :> Real {
    doc /* Unit: kilowatt. */
  }
  attribute def Energy_kWh :> Real {
    doc /* Unit: kilowatt-hour. */
  }
  attribute def Speed_mm_per_s :> Real {
    doc /* Unit: millimeter per second. */
  }
  attribute def Position_mm :> Real {
    doc /* Unit: millimeter. */
  }
  attribute def Time_s :> Real {
    doc /* Unit: second. */
  }
  attribute def ProductionRate_parts_per_h :> Real {
    doc /* Unit: finished parts per hour. */
  }
  attribute def Ratio_percent :> Real {
    doc /* Unit: percent. */
  }
  attribute def Mass_kg :> Real {
    doc /* Unit: kilogram. */
  }
  attribute def Vibration_mm_per_s :> Real {
    doc /* Unit: millimeter per second RMS. */
  }

  enum def OrderPriority {
    enum low;
    enum normal;
    enum high;
    enum expedite;
  }

  enum def ProductDisposition {
    enum accepted;
    enum reworkRequired;
    enum rejected;
    enum quarantined;
  }

  enum def EquipmentMode {
    enum off;
    enum automatic;
    enum manual;
    enum maintenance;
    enum faulted;
  }

  enum def WorkCenterCapability {
    enum cncMachining;
    enum roboticAssembly;
    enum additiveManufacturing;
    enum inspection;
    enum packaging;
    enum materialHandling;
  }

  enum def AlarmSeverity {
    enum information;
    enum warning;
    enum critical;
    enum emergencyStop;
  }

  item def ManufacturingOrder {
    attribute orderId : Identifier;
    attribute productCode : Identifier;
    attribute requiredQuantity : Quantity;
    attribute dueTime_s : Time_s;
    attribute priority : OrderPriority;
    attribute revision : Identifier;
  }

  item def ProductionPlan {
    attribute planId : Identifier;
    attribute orderId : Identifier;
    attribute plannedQuantity : Quantity;
    attribute targetRate_parts_per_h : ProductionRate_parts_per_h;
    attribute plannedStart_s : Time_s;
    attribute plannedFinish_s : Time_s;
  }

  item def WorkInstruction {
    attribute instructionId : Identifier;
    attribute productCode : Identifier;
    attribute operationNumber : Integer;
    attribute requiredCapability : WorkCenterCapability;
    attribute nominalCycleTime_s : Time_s;
    attribute targetTemperature_degC : Temperature_degC;
    attribute targetPressure_kPa : Pressure_kPa;
    attribute targetSpeed_mm_per_s : Speed_mm_per_s;
  }

  item def RawMaterialLot {
    attribute lotId : Identifier;
    attribute materialCode : Identifier;
    attribute mass_kg : Mass_kg;
    attribute supplierId : Identifier;
    attribute certificateId : Identifier;
  }

  item def InProcessUnit {
    attribute serialNumber : Identifier;
    attribute productCode : Identifier;
    attribute currentOperation : Integer;
    attribute accumulatedProcessTime_s : Time_s;
  }

  item def FinishedProductLot {
    attribute lotId : Identifier;
    attribute productCode : Identifier;
    attribute quantity : Quantity;
    attribute disposition : ProductDisposition;
    attribute traceabilityRecordId : Identifier;
  }

  item def QualityMeasurement {
    attribute serialNumber : Identifier;
    attribute featureId : Identifier;
    attribute measuredValue_mm : Position_mm;
    attribute lowerTolerance_mm : Position_mm;
    attribute upperTolerance_mm : Position_mm;
    attribute pass : Boolean;
  }

  item def TraceabilityRecord {
    attribute recordId : Identifier;
    attribute orderId : Identifier;
    attribute materialLotId : Identifier;
    attribute equipmentId : Identifier;
    attribute operatorId : Identifier;
    attribute startTime_s : Time_s;
    attribute finishTime_s : Time_s;
    attribute energyUsed_kWh : Energy_kWh;
  }

  item def EquipmentStatus {
    attribute equipmentId : Identifier;
    attribute mode : EquipmentMode;
    attribute availability_percent : Ratio_percent;
    attribute temperature_degC : Temperature_degC;
    attribute vibration_mm_per_s : Vibration_mm_per_s;
    attribute activeAlarmCount : Integer;
  }

  item def ControlCommand {
    attribute commandId : Identifier;
    attribute targetEquipmentId : Identifier;
    attribute requestedMode : EquipmentMode;
    attribute recipeId : Identifier;
    attribute speedOverride_percent : Ratio_percent;
  }

  item def TelemetryFrame {
    attribute sourceId : Identifier;
    attribute timestamp_s : Time_s;
    attribute temperature_degC : Temperature_degC;
    attribute power_kW : Power_kW;
    attribute vibration_mm_per_s : Vibration_mm_per_s;
    attribute producedCount : Quantity;
  }

  item def AlarmEvent {
    attribute alarmId : Identifier;
    attribute sourceId : Identifier;
    attribute severity : AlarmSeverity;
    attribute timestamp_s : Time_s;
    attribute message : String;
  }

  item def EnergyAllocation {
    attribute allocationId : Identifier;
    attribute maximumPower_kW : Power_kW;
    attribute expectedEnergy_kWh : Energy_kWh;
    attribute validUntil_s : Time_s;
  }

  item def MaintenanceWorkOrder {
    attribute workOrderId : Identifier;
    attribute equipmentId : Identifier;
    attribute reason : String;
    attribute requestedCompletion_s : Time_s;
  }

  item def PowerOnSignal;
  item def ShutdownSignal;
  item def StartProductionSignal;
  item def StopProductionSignal;
  item def FaultDetectedSignal;
  item def FaultClearedSignal;
  item def MaintenanceRequestedSignal;

  port def OrderIntakePort {
    in item order : ManufacturingOrder;
  }

  port def PlanPort {
    in item planIn : ProductionPlan;
    out item planOut : ProductionPlan;
  }

  port def WorkInstructionPort {
    in item instructionIn : WorkInstruction;
    out item instructionOut : WorkInstruction;
  }

  port def MaterialInputPort {
    in item rawMaterial : RawMaterialLot;
  }

  port def MaterialTransferPort {
    in item unitIn : InProcessUnit;
    out item unitOut : InProcessUnit;
    in item materialIn : RawMaterialLot;
    out item materialOut : RawMaterialLot;
  }

  port def ProductOutputPort {
    out item productLot : FinishedProductLot;
  }

  port def QualityDataPort {
    in item measurementIn : QualityMeasurement;
    out item measurementOut : QualityMeasurement;
  }

  port def TraceabilityPort {
    in item recordIn : TraceabilityRecord;
    out item recordOut : TraceabilityRecord;
  }

  port def CommandStatusPort {
    in item command : ControlCommand;
    out item status : EquipmentStatus;
    out item alarm : AlarmEvent;
  }

  port def TelemetryPort {
    out item telemetry : TelemetryFrame;
  }

  port def EnergyPort {
    in item allocation : EnergyAllocation;
    out item telemetry : TelemetryFrame;
  }

  port def MaintenancePort {
    out item maintenanceRequest : MaintenanceWorkOrder;
    in item maintenanceRelease : ControlCommand;
  }

  part def EnterprisePlanningSystem {
    port orders : OrderIntakePort;
    port productionPlans : PlanPort;
  }

  part def ManufacturingExecutionSystem {
    attribute currentOee_percent : Ratio_percent = 0.0;
    attribute activeOrderCount : Integer = 0;
    port orderIntake : OrderIntakePort;
    port planExchange : PlanPort;
    port instructionDispatch : WorkInstructionPort;
    port traceabilityExchange : TraceabilityPort;
    port qualityExchange : QualityDataPort;
    port equipmentSupervision : CommandStatusPort;
  }

  part def AdvancedScheduler {
    attribute scheduleHorizon_s : Time_s = 86400.0;
    attribute targetUtilization_percent : Ratio_percent = 82.0;
    port planInput : PlanPort;
    port instructionOutput : WorkInstructionPort;
    port statusInput : CommandStatusPort;
  }

  part def DigitalTwin {
    attribute modelVersion : Identifier = "DT-FACTORY-4.2";
    attribute predictionHorizon_s : Time_s = 7200.0;
    attribute predictedThroughput_parts_per_h : ProductionRate_parts_per_h = 150.0;
    port liveTelemetry : TelemetryPort;
    port planInput : PlanPort;
    port optimizedInstructions : WorkInstructionPort;
    port maintenanceOutput : MaintenancePort;
  }

  part def EdgeController {
    attribute controllerId : Identifier;
    attribute controlCycleTime_s : Time_s = 0.010;
    port commandStatus : CommandStatusPort;
    port instructions : WorkInstructionPort;
    port telemetry : TelemetryPort;
    port materialFlow : MaterialTransferPort;
  }

  part def AutonomousWarehouse {
    attribute storedMaterialLots : Integer = 0;
    attribute maximumStorageMass_kg : Mass_kg = 25000.0;
    port materialReceiving : MaterialInputPort;
    port materialDispatch : MaterialTransferPort;
    port commandStatus : CommandStatusPort;
    port telemetry : TelemetryPort;
  }

  part def AutomatedGuidedVehicleFleet {
    attribute vehicleCount : Integer = 8;
    attribute payloadCapacity_kg : Mass_kg = 500.0;
    attribute averageSpeed_mm_per_s : Speed_mm_per_s = 1200.0;
    port materialTransfer : MaterialTransferPort;
    port commandStatus : CommandStatusPort;
    port telemetry : TelemetryPort;
  }

  part def RobotArm {
    attribute equipmentId : Identifier;
    attribute axes : Integer = 6;
    attribute maximumPayload_kg : Mass_kg = 25.0;
    attribute repeatability_mm : Position_mm = 0.05;
    attribute mode : EquipmentMode = EquipmentMode::off;
    port commandStatus : CommandStatusPort;
    port materialTransfer : MaterialTransferPort;
    port telemetry : TelemetryPort;
  }

  part def CncMachine {
    attribute equipmentId : Identifier;
    attribute spindlePower_kW : Power_kW = 18.0;
    attribute maximumFeed_mm_per_s : Speed_mm_per_s = 250.0;
    attribute coolantTemperature_degC : Temperature_degC = 21.0;
    attribute mode : EquipmentMode = EquipmentMode::off;
    port commandStatus : CommandStatusPort;
    port materialTransfer : MaterialTransferPort;
    port telemetry : TelemetryPort;
  }

  part def AdditiveManufacturingMachine {
    attribute equipmentId : Identifier;
    attribute buildVolumeX_mm : Position_mm = 400.0;
    attribute buildVolumeY_mm : Position_mm = 400.0;
    attribute buildVolumeZ_mm : Position_mm = 450.0;
    attribute chamberTemperature_degC : Temperature_degC = 80.0;
    attribute laserPower_kW : Power_kW = 1.0;
    attribute mode : EquipmentMode = EquipmentMode::off;
    port commandStatus : CommandStatusPort;
    port materialTransfer : MaterialTransferPort;
    port telemetry : TelemetryPort;
  }

  part def ConveyorSegment {
    attribute segmentId : Identifier;
    attribute length_mm : Position_mm = 6000.0;
    attribute beltSpeed_mm_per_s : Speed_mm_per_s = 500.0;
    port upstream : MaterialTransferPort;
    port downstream : MaterialTransferPort;
    port commandStatus : CommandStatusPort;
    port telemetry : TelemetryPort;
  }

  part def VisionInspectionStation {
    attribute equipmentId : Identifier;
    attribute measurementResolution_mm : Position_mm = 0.005;
    attribute inspectionCycleTime_s : Time_s = 12.0;
    port materialTransfer : MaterialTransferPort;
    port qualityData : QualityDataPort;
    port commandStatus : CommandStatusPort;
    port telemetry : TelemetryPort;
  }

  part def PackagingStation {
    attribute equipmentId : Identifier;
    attribute nominalRate_parts_per_h : ProductionRate_parts_per_h = 180.0;
    port materialTransfer : MaterialTransferPort;
    port productOutput : ProductOutputPort;
    port commandStatus : CommandStatusPort;
    port telemetry : TelemetryPort;
  }

  part def EnergyManagementSystem {
    attribute facilityPowerLimit_kW : Power_kW = 850.0;
    attribute currentDemand_kW : Power_kW = 0.0;
    attribute dailyEnergyBudget_kWh : Energy_kWh = 6500.0;
    port energyToCells : EnergyPort;
    port telemetryInput : TelemetryPort;
  }

  part def PredictiveMaintenanceSystem {
    attribute warningVibrationThreshold_mm_per_s : Vibration_mm_per_s = 4.5;
    attribute criticalVibrationThreshold_mm_per_s : Vibration_mm_per_s = 7.1;
    port telemetryInput : TelemetryPort;
    port maintenanceExchange : MaintenancePort;
    port equipmentStatus : CommandStatusPort;
  }

  part def HumanMachineInterface {
    attribute activeOperatorId : Identifier = "none";
    port orderView : OrderIntakePort;
    port statusView : CommandStatusPort;
    port maintenanceView : MaintenancePort;
    port traceabilityView : TraceabilityPort;
  }

  part def FlexibleProductionCell {
    attribute cellId : Identifier;
    attribute nominalThroughput_parts_per_h : ProductionRate_parts_per_h = 75.0;
    attribute cellAvailability_percent : Ratio_percent = 95.0;

    port cellInstructions : WorkInstructionPort;
    port cellMaterialIn : MaterialTransferPort;
    port cellMaterialOut : MaterialTransferPort;
    port cellCommandStatus : CommandStatusPort;
    port cellTelemetry : TelemetryPort;
    port cellEnergy : EnergyPort;

    part controller : EdgeController {
      :>> controllerId = "CELL-CONTROLLER";
    }

    part loadingRobot : RobotArm {
      :>> equipmentId = "ROBOT-LOAD";
    }

    part machineTool : CncMachine {
      :>> equipmentId = "CNC-PRIMARY";
    }

    part assemblyRobot : RobotArm {
      :>> equipmentId = "ROBOT-ASSEMBLY";
    }

    part additiveMachine : AdditiveManufacturingMachine {
      :>> equipmentId = "AM-AUXILIARY";
    }

    part inboundConveyor : ConveyorSegment {
      :>> segmentId = "CONV-IN";
    }

    part outboundConveyor : ConveyorSegment {
      :>> segmentId = "CONV-OUT";
    }

    connect cellInstructions to controller.instructions;
    connect controller.commandStatus to loadingRobot.commandStatus;
    connect controller.commandStatus to machineTool.commandStatus;
    connect controller.commandStatus to assemblyRobot.commandStatus;
    connect controller.commandStatus to additiveMachine.commandStatus;
    connect cellMaterialIn to inboundConveyor.upstream;
    connect inboundConveyor.downstream to loadingRobot.materialTransfer;
    connect loadingRobot.materialTransfer to machineTool.materialTransfer;
    connect machineTool.materialTransfer to assemblyRobot.materialTransfer;
    connect assemblyRobot.materialTransfer to additiveMachine.materialTransfer;
    connect additiveMachine.materialTransfer to outboundConveyor.upstream;
    connect outboundConveyor.downstream to cellMaterialOut;
    connect loadingRobot.telemetry to cellTelemetry;
    connect machineTool.telemetry to cellTelemetry;
    connect assemblyRobot.telemetry to cellTelemetry;
    connect additiveMachine.telemetry to cellTelemetry;
    connect controller.telemetry to cellTelemetry;
    connect cellCommandStatus to controller.commandStatus;
    connect cellEnergy to controller.telemetry;
  }

  state def SmartFactoryOperatingState {
    state offline;
    state starting;
    state idle;
    state producing;
    state paused;
    state maintenance;
    state faulted;
    state shuttingDown;

    transition initialToOffline first offline;
    transition powerOn first offline accept PowerOnSignal then starting;
    transition startupComplete first starting then idle;
    transition beginProduction first idle accept StartProductionSignal then producing;
    transition pauseProduction first producing accept StopProductionSignal then paused;
    transition resumeProduction first paused accept StartProductionSignal then producing;
    transition requestMaintenanceFromIdle first idle accept MaintenanceRequestedSignal then maintenance;
    transition requestMaintenanceFromProducing first producing accept MaintenanceRequestedSignal then maintenance;
    transition maintenanceComplete first maintenance accept FaultClearedSignal then idle;
    transition detectFaultFromStarting first starting accept FaultDetectedSignal then faulted;
    transition detectFaultFromIdle first idle accept FaultDetectedSignal then faulted;
    transition detectFaultFromProducing first producing accept FaultDetectedSignal then faulted;
    transition clearFault first faulted accept FaultClearedSignal then idle;
    transition shutdownFromIdle first idle accept ShutdownSignal then shuttingDown;
    transition shutdownFromPaused first paused accept ShutdownSignal then shuttingDown;
    transition shutdownComplete first shuttingDown then offline;
  }

  action def ValidateManufacturingOrder {
    in item order : ManufacturingOrder;
    out item validatedOrder : ManufacturingOrder;
  }

  action def GenerateOptimizedProductionPlan {
    in item order : ManufacturingOrder;
    in item status : EquipmentStatus;
    out item plan : ProductionPlan;
    out item instruction : WorkInstruction;
  }

  action def AllocateCertifiedMaterial {
    in item plan : ProductionPlan;
    in item materialLot : RawMaterialLot;
    out item allocatedMaterial : RawMaterialLot;
  }

  action def ConfigureProductionCell {
    in item instruction : WorkInstruction;
    out item command : ControlCommand;
  }

  action def FabricateInProcessUnit {
    in item materialLot : RawMaterialLot;
    in item instruction : WorkInstruction;
    out item unit : InProcessUnit;
    out item telemetry : TelemetryFrame;
  }

  action def InspectInProcessUnit {
    in item unit : InProcessUnit;
    out item measurement : QualityMeasurement;
    out item disposition : ProductDisposition;
  }

  action def PackageAcceptedProduct {
    in item unit : InProcessUnit;
    in item measurement : QualityMeasurement;
    out item productLot : FinishedProductLot;
  }

  action def RecordEndToEndTraceability {
    in item order : ManufacturingOrder;
    in item materialLot : RawMaterialLot;
    in item productLot : FinishedProductLot;
    in item telemetry : TelemetryFrame;
    out item record : TraceabilityRecord;
  }

  action def AnalyzeEquipmentHealth {
    in item telemetry : TelemetryFrame;
    in item status : EquipmentStatus;
    out item maintenanceRequest : MaintenanceWorkOrder;
  }

  action def ManufactureTraceableProducts {
    doc /* Primary high-level function: transform approved manufacturing orders and certified raw material lots into finished, quality-verified, traceable product lots by dynamically planning, controlling, monitoring, inspecting, and optimizing cyber-physical production resources. */

    in item order : ManufacturingOrder;
    in item materialLot : RawMaterialLot;
    out item finishedLot : FinishedProductLot;
    out item traceabilityRecord : TraceabilityRecord;

    action validateOrder : ValidateManufacturingOrder;
    action planProduction : GenerateOptimizedProductionPlan;
    action allocateMaterial : AllocateCertifiedMaterial;
    action configureCell : ConfigureProductionCell;
    action fabricate : FabricateInProcessUnit;
    action inspect : InspectInProcessUnit;
    action packageProduct : PackageAcceptedProduct;
    action recordTraceability : RecordEndToEndTraceability;
    action analyzeHealth : AnalyzeEquipmentHealth;

    first validateOrder;
    then planProduction;
    then allocateMaterial;
    then configureCell;
    then fabricate;
    then inspect;
    then packageProduct;
    then recordTraceability;
    then analyzeHealth;
  }

  part def SmartManufacturingSystem {
    doc /* Smart manufacturing system that integrates enterprise planning, manufacturing execution, autonomous material handling, flexible production cells, digital twin optimization, quality inspection, predictive maintenance, and energy management to fulfill product orders with high traceability and adaptive control. */

    attribute systemId : Identifier = "SMART-FACTORY-01";
    attribute requiredThroughput_parts_per_h : ProductionRate_parts_per_h = 120.0;
    attribute measuredThroughput_parts_per_h : ProductionRate_parts_per_h = 0.0;
    attribute targetOee_percent : Ratio_percent = 85.0;
    attribute measuredOee_percent : Ratio_percent = 0.0;
    attribute maximumPowerDemand_kW : Power_kW = 850.0;
    attribute averageEnergyPerPart_kWh : Energy_kWh = 1.8;
    attribute qualityYield_percent : Ratio_percent = 0.0;

    port enterpriseOrders : OrderIntakePort;
    port inboundMaterials : MaterialInputPort;
    port finishedGoods : ProductOutputPort;
    port operatorInterface : CommandStatusPort;
    port enterprisePlans : PlanPort;
    port traceabilityRecords : TraceabilityPort;
    port maintenanceInterface : MaintenancePort;

    part enterprisePlanning : EnterprisePlanningSystem;
    part manufacturingExecution : ManufacturingExecutionSystem;
    part scheduler : AdvancedScheduler;
    part digitalTwin : DigitalTwin;
    part warehouse : AutonomousWarehouse;
    part vehicleFleet : AutomatedGuidedVehicleFleet;
    part cellA : FlexibleProductionCell {
      :>> cellId = "CELL-A";
      :>> nominalThroughput_parts_per_h = 75.0;
    }
    part cellB : FlexibleProductionCell {
      :>> cellId = "CELL-B";
      :>> nominalThroughput_parts_per_h = 75.0;
    }
    part inspectionStation : VisionInspectionStation {
      :>> equipmentId = "VISION-FINAL";
    }
    part packagingStation : PackagingStation {
      :>> equipmentId = "PACK-01";
    }
    part energyManager : EnergyManagementSystem;
    part maintenanceSystem : PredictiveMaintenanceSystem;
    part hmi : HumanMachineInterface;

    connect enterpriseOrders to enterprisePlanning.orders;
    connect enterprisePlanning.productionPlans to manufacturingExecution.planExchange;
    connect manufacturingExecution.orderIntake to enterprisePlanning.orders;
    connect manufacturingExecution.planExchange to scheduler.planInput;
    connect scheduler.instructionOutput to manufacturingExecution.instructionDispatch;
    connect scheduler.instructionOutput to digitalTwin.optimizedInstructions;
    connect digitalTwin.planInput to manufacturingExecution.planExchange;
    connect inboundMaterials to warehouse.materialReceiving;
    connect warehouse.materialDispatch to vehicleFleet.materialTransfer;
    connect vehicleFleet.materialTransfer to cellA.cellMaterialIn;
    connect vehicleFleet.materialTransfer to cellB.cellMaterialIn;
    connect manufacturingExecution.instructionDispatch to cellA.cellInstructions;
    connect manufacturingExecution.instructionDispatch to cellB.cellInstructions;
    connect cellA.cellMaterialOut to inspectionStation.materialTransfer;
    connect cellB.cellMaterialOut to inspectionStation.materialTransfer;
    connect inspectionStation.materialTransfer to packagingStation.materialTransfer;
    connect packagingStation.productOutput to finishedGoods;
    connect inspectionStation.qualityData to manufacturingExecution.qualityExchange;
    connect manufacturingExecution.traceabilityExchange to traceabilityRecords;
    connect cellA.cellTelemetry to digitalTwin.liveTelemetry;
    connect cellB.cellTelemetry to digitalTwin.liveTelemetry;
    connect packagingStation.telemetry to digitalTwin.liveTelemetry;
    connect inspectionStation.telemetry to digitalTwin.liveTelemetry;
    connect cellA.cellTelemetry to maintenanceSystem.telemetryInput;
    connect cellB.cellTelemetry to maintenanceSystem.telemetryInput;
    connect maintenanceSystem.maintenanceExchange to maintenanceInterface;
    connect maintenanceSystem.maintenanceExchange to digitalTwin.maintenanceOutput;
    connect energyManager.energyToCells to cellA.cellEnergy;
    connect energyManager.energyToCells to cellB.cellEnergy;
    connect cellA.cellTelemetry to energyManager.telemetryInput;
    connect cellB.cellTelemetry to energyManager.telemetryInput;
    connect hmi.statusView to operatorInterface;
    connect hmi.maintenanceView to maintenanceInterface;
    connect hmi.traceabilityView to traceabilityRecords;

    perform action primaryFunction : ManufactureTraceableProducts;
    exhibit state operatingState : SmartFactoryOperatingState;
  }

  constraint def ThroughputAtLeastRequired {
    in measured : ProductionRate_parts_per_h;
    in required : ProductionRate_parts_per_h;
    constraint throughputSatisfied { measured >= required }
  }

  constraint def OeeAtLeastTarget {
    in measured : Ratio_percent;
    in target : Ratio_percent;
    constraint oeeSatisfied { measured >= target }
  }

  constraint def PowerWithinFacilityLimit {
    in demand : Power_kW;
    in limit : Power_kW;
    constraint powerSatisfied { demand <= limit }
  }

  constraint def YieldAtLeastMinimum {
    in yield : Ratio_percent;
    in minimumYield : Ratio_percent;
    constraint yieldSatisfied { yield >= minimumYield }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The smart manufacturing system shall, at a high level, convert approved manufacturing orders and certified raw materials into finished product lots by coordinating planning, material handling, production execution, quality verification, traceability recording, predictive maintenance, and energy-aware optimization. */
    subject system : SmartManufacturingSystem;
  }

  requirement def ThroughputRequirement {
    doc /* The system shall sustain the required finished-product throughput during automatic production. */
    subject system : SmartManufacturingSystem;
    require constraint throughput : ThroughputAtLeastRequired {
      in measured = system.measuredThroughput_parts_per_h;
      in required = system.requiredThroughput_parts_per_h;
    }
  }

  requirement def OverallEquipmentEffectivenessRequirement {
    doc /* The system shall maintain overall equipment effectiveness at or above the target value. */
    subject system : SmartManufacturingSystem;
    require constraint oee : OeeAtLeastTarget {
      in measured = system.measuredOee_percent;
      in target = system.targetOee_percent;
    }
  }

  requirement def EnergyRequirement {
    doc /* The system shall coordinate production resources so that facility power demand does not exceed the configured maximum. */
    subject system : SmartManufacturingSystem;
    require constraint powerLimit : PowerWithinFacilityLimit {
      in demand = system.energyManager.currentDemand_kW;
      in limit = system.maximumPowerDemand_kW;
    }
  }

  requirement def QualityRequirement {
    doc /* The system shall achieve a first-pass quality yield of at least 98 percent for accepted finished product lots. */
    subject system : SmartManufacturingSystem;
    attribute minimumYield_percent : Ratio_percent = 98.0;
    require constraint yieldLimit : YieldAtLeastMinimum {
      in yield = system.qualityYield_percent;
      in minimumYield = minimumYield_percent;
    }
  }

  requirement def TraceabilityRequirement {
    doc /* The system shall record order, material lot, equipment, operator, timing, quality, and energy data for each finished product lot. */
    subject system : SmartManufacturingSystem;
  }

  part smartFactory : SmartManufacturingSystem;

  requirement reqPrimaryFunction : PrimaryFunctionRequirement {
    subject system = smartFactory;
  }

  requirement reqThroughput : ThroughputRequirement {
    subject system = smartFactory;
  }

  requirement reqOee : OverallEquipmentEffectivenessRequirement {
    subject system = smartFactory;
  }

  requirement reqEnergy : EnergyRequirement {
    subject system = smartFactory;
  }

  requirement reqQuality : QualityRequirement {
    subject system = smartFactory;
  }

  requirement reqTraceability : TraceabilityRequirement {
    subject system = smartFactory;
  }

  satisfy reqPrimaryFunction by smartFactory.primaryFunction;
  satisfy reqThroughput by smartFactory;
  satisfy reqOee by smartFactory.manufacturingExecution;
  satisfy reqEnergy by smartFactory.energyManager;
  satisfy reqQuality by smartFactory.inspectionStation;
  satisfy reqTraceability by smartFactory.traceabilityRecords;
}
