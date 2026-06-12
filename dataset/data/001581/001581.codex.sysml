package SmartManufacturingSystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Percent :> Real;
  attribute def PartsPerHour :> Real;
  attribute def Millisecond :> Real;
  attribute def KilowattHour :> Real;
  attribute def Celsius :> Real;
  attribute def NewtonMeter :> Real;

  enum def MachineMode {
    enum idle;
    enum setup;
    enum automatic;
    enum manual;
    enum maintenance;
    enum fault;
  }

  enum def QualityDisposition {
    enum accepted;
    enum rework;
    enum rejected;
  }

  item def ProductionOrder {
    attribute orderId : String;
    attribute productCode : String;
    attribute quantity : Integer;
    attribute priority : Integer;
    attribute dueTime : Time;
  }

  item def Workpiece {
    attribute serialNumber : String;
    attribute productCode : String;
    attribute processStep : String;
    attribute temperature : Celsius;
  }

  item def FinishedPart :> Workpiece {
    attribute disposition : QualityDisposition;
    attribute measuredTolerance : LengthValue;
  }

  item def ProcessPlan {
    attribute planId : String;
    attribute taktTime : Millisecond;
    attribute targetThroughput : PartsPerHour;
  }

  item def ToolCommand {
    attribute commandId : String;
    attribute targetTorque : NewtonMeter;
    attribute feedRate : Real;
    attribute spindleSpeedRpm : Real;
  }

  item def RobotCommand {
    attribute commandId : String;
    attribute targetStation : String;
    attribute speedPercent : Percent;
  }

  item def SensorReading {
    attribute sensorId : String;
    attribute value : Real;
    attribute unitSymbol : String;
    attribute timestamp : Time;
  }

  item def QualityMeasurement {
    attribute partSerialNumber : String;
    attribute dimensionError : LengthValue;
    attribute surfaceScore : Percent;
    attribute timestamp : Time;
  }

  item def MaintenanceAlert {
    attribute assetId : String;
    attribute severity : Integer;
    attribute predictedFailureTime : Time;
    attribute description : String;
  }

  item def EnergySample {
    attribute assetId : String;
    attribute consumedEnergy : KilowattHour;
    attribute timestamp : Time;
  }

  port def OrderPort {
    in item order : ProductionOrder;
  }

  port def PlanPort {
    in item planIn : ProcessPlan;
    out item planOut : ProcessPlan;
  }

  port def MaterialInputPort {
    in item workpieceIn : Workpiece;
  }

  port def MaterialOutputPort {
    out item workpieceOut : Workpiece;
  }

  port def FinishedGoodsPort {
    out item finishedPart : FinishedPart;
  }

  port def ToolControlPort {
    in item command : ToolCommand;
    out item reading : SensorReading;
  }

  port def RobotControlPort {
    in item command : RobotCommand;
    out item reading : SensorReading;
  }

  port def SensorTelemetryPort {
    out item reading : SensorReading;
  }

  port def QualityPort {
    in item partIn : Workpiece;
    out item measurement : QualityMeasurement;
    out item inspectedPart : FinishedPart;
  }

  port def MaintenancePort {
    out item alert : MaintenanceAlert;
  }

  port def EnergyPort {
    out item sample : EnergySample;
  }

  part def SmartManufacturingLine {
    attribute nominalThroughput : PartsPerHour = 150;
    attribute maximumAllowedScrapRate : Percent = 2.5;
    attribute targetOee : Percent = 85.0;
    attribute maximumCellLatency : Millisecond = 100;
    attribute maximumEnergyPerPart : KilowattHour = 0.42;

    port orders : OrderPort;
    port materialInput : MaterialInputPort;
    port finishedGoods : FinishedGoodsPort;
    port maintenanceNotifications : MaintenancePort;
    port energyTelemetry : EnergyPort;

    part manufacturingExecutionSystem : ManufacturingExecutionSystem;
    part digitalTwin : DigitalTwin;
    part edgeController : EdgeController;
    part robotCell : RobotCell;
    part machiningCenter : MachiningCenter;
    part additivePrinter : AdditivePrinter;
    part inspectionStation : InspectionStation;
    part conveyor : SmartConveyor;
    part sensorNetwork : SensorNetwork;
    part predictiveMaintenanceService : PredictiveMaintenanceService;
    part energyManager : EnergyManager;
    part humanMachineInterface : HumanMachineInterface;

    connection orderFeed connect orders to manufacturingExecutionSystem.orderIntake;
    connection planToTwin connect manufacturingExecutionSystem.planDispatch to digitalTwin.planPort;
    connection validatedPlanToController connect digitalTwin.validatedPlan to edgeController.planPort;

    connection controllerToRobot connect edgeController.robotControl to robotCell.control;
    connection controllerToMachining connect edgeController.toolControl to machiningCenter.control;
    connection controllerToPrinter connect edgeController.printerControl to additivePrinter.control;

    connection rawMaterialToConveyor connect materialInput to conveyor.input;
    connection conveyorToRobot connect conveyor.output to robotCell.materialInput;
    connection robotToMachining connect robotCell.materialOutput to machiningCenter.materialInput;
    connection machiningToPrinter connect machiningCenter.materialOutput to additivePrinter.materialInput;
    connection printerToInspection connect additivePrinter.materialOutput to inspectionStation.qualityInput;
    connection acceptedPartsOut connect inspectionStation.finishedOutput to finishedGoods;

    connection robotTelemetry connect robotCell.telemetry to sensorNetwork.sensorInput;
    connection machiningTelemetry connect machiningCenter.telemetry to sensorNetwork.sensorInput;
    connection printerTelemetry connect additivePrinter.telemetry to sensorNetwork.sensorInput;
    connection inspectionTelemetry connect inspectionStation.measurementOutput to digitalTwin.qualityInput;
    connection sensorToController connect sensorNetwork.telemetryOutput to edgeController.sensorInput;
    connection sensorToMaintenance connect sensorNetwork.telemetryOutput to predictiveMaintenanceService.sensorInput;
    connection maintenanceAlerts connect predictiveMaintenanceService.alertOutput to maintenanceNotifications;

    connection energyRobot connect robotCell.energyOutput to energyManager.energyInput;
    connection energyMachining connect machiningCenter.energyOutput to energyManager.energyInput;
    connection energyPrinter connect additivePrinter.energyOutput to energyManager.energyInput;
    connection energyLineOut connect energyManager.energySummary to energyTelemetry;

    connection hmiToMes connect humanMachineInterface.operatorOrders to manufacturingExecutionSystem.orderIntake;
    connection controllerStatusToHmi connect edgeController.statusOutput to humanMachineInterface.statusInput;

    perform action produceConfiguredLot : ProduceConfiguredLot;
    exhibit state lifecycle : SmartLineLifecycle;
  }

  part def ManufacturingExecutionSystem {
    port orderIntake : OrderPort;
    port planDispatch : PlanPort;

    attribute scheduledOrders : Integer;
    attribute planningHorizonHours : Real = 8.0;

    perform action createPlan : GenerateAdaptiveProcessPlan;
  }

  part def DigitalTwin {
    port planPort : PlanPort;
    port validatedPlan : PlanPort;
    port qualityInput : QualityPort;

    attribute simulationUpdatePeriod : Millisecond = 50;
    attribute predictedThroughput : PartsPerHour;
    attribute predictedScrapRate : Percent;

    perform action validatePlan : SimulateAndOptimizePlan;
  }

  part def EdgeController {
    port planPort : PlanPort;
    port sensorInput : SensorTelemetryPort;
    port robotControl : RobotControlPort;
    port toolControl : ToolControlPort;
    port printerControl : ToolControlPort;
    port statusOutput : SensorTelemetryPort;

    attribute controlCycleTime : Millisecond = 20;
    attribute commandLatency : Millisecond;

    perform action coordinateAssets : CoordinateProductionAssets;
  }

  part def RobotCell {
    port control : RobotControlPort;
    port materialInput : MaterialInputPort;
    port materialOutput : MaterialOutputPort;
    port telemetry : SensorTelemetryPort;
    port energyOutput : EnergyPort;

    attribute payloadCapacityKg : Real = 12.0;
    attribute repeatability : LengthValue = 0.05 [mm];
    attribute mode : MachineMode;

    exhibit state robotState : AssetLifecycle;
  }

  part def MachiningCenter {
    port control : ToolControlPort;
    port materialInput : MaterialInputPort;
    port materialOutput : MaterialOutputPort;
    port telemetry : SensorTelemetryPort;
    port energyOutput : EnergyPort;

    attribute spindlePowerKw : Real = 18.0;
    attribute maximumSpindleSpeedRpm : Real = 18000;
    attribute toolWearPercent : Percent;
    attribute mode : MachineMode;

    exhibit state machineState : AssetLifecycle;
  }

  part def AdditivePrinter {
    port control : ToolControlPort;
    port materialInput : MaterialInputPort;
    port materialOutput : MaterialOutputPort;
    port telemetry : SensorTelemetryPort;
    port energyOutput : EnergyPort;

    attribute buildChamberTemperature : Celsius;
    attribute layerHeight : LengthValue = 0.08 [mm];
    attribute mode : MachineMode;

    exhibit state printerState : AssetLifecycle;
  }

  part def InspectionStation {
    port qualityInput : QualityPort;
    port measurementOutput : QualityPort;
    port finishedOutput : FinishedGoodsPort;
    port telemetry : SensorTelemetryPort;

    attribute inspectionCycleTime : Millisecond = 450;
    attribute measurementResolution : LengthValue = 0.002 [mm];

    perform action inspectPart : InspectAndClassifyPart;
  }

  part def SmartConveyor {
    port input : MaterialInputPort;
    port output : MaterialOutputPort;
    port telemetry : SensorTelemetryPort;

    attribute nominalSpeedMetersPerSecond : Real = 0.8;
    attribute bufferCapacity : Integer = 24;
    attribute bufferedParts : Integer;
  }

  part def SensorNetwork {
    port sensorInput : SensorTelemetryPort;
    port telemetryOutput : SensorTelemetryPort;

    attribute samplingPeriod : Millisecond = 10;
    attribute networkAvailability : Percent = 99.9;
  }

  part def PredictiveMaintenanceService {
    port sensorInput : SensorTelemetryPort;
    port alertOutput : MaintenancePort;

    attribute predictionConfidence : Percent;
    attribute minimumUsefulLifeHours : Real = 24.0;

    perform action detectDegradation : PredictAssetFailure;
  }

  part def EnergyManager {
    port energyInput : EnergyPort;
    port energySummary : EnergyPort;

    attribute rollingEnergyPerPart : KilowattHour;
    attribute peakDemandKw : Real;

    perform action optimizeEnergy : OptimizeEnergyUse;
  }

  part def HumanMachineInterface {
    port operatorOrders : OrderPort;
    port statusInput : SensorTelemetryPort;

    attribute activeOperators : Integer;
    attribute alarmCount : Integer;
  }

  action def ProduceConfiguredLot {
    in item order : ProductionOrder;
    out item finishedPart : FinishedPart;

    action plan : GenerateAdaptiveProcessPlan;
    action simulate : SimulateAndOptimizePlan;
    action coordinate : CoordinateProductionAssets;
    action inspect : InspectAndClassifyPart;
    action maintain : PredictAssetFailure;
    action optimizeEnergy : OptimizeEnergyUse;

    flow order to plan.order;
    flow plan.processPlan to simulate.plan;
    flow simulate.optimizedPlan to coordinate.plan;
    flow coordinate.completedWorkpiece to inspect.part;
    flow inspect.finishedPart to finishedPart;
  }

  action def GenerateAdaptiveProcessPlan {
    in item order : ProductionOrder;
    out item processPlan : ProcessPlan;

    attribute maximumPlanningTime : Millisecond = 250;
  }

  action def SimulateAndOptimizePlan {
    in item plan : ProcessPlan;
    out item optimizedPlan : ProcessPlan;

    attribute simulationConfidence : Percent;
    attribute expectedThroughput : PartsPerHour;
    attribute expectedEnergyPerPart : KilowattHour;
  }

  action def CoordinateProductionAssets {
    in item plan : ProcessPlan;
    in item sensorFeedback : SensorReading;
    out item robotCommand : RobotCommand;
    out item toolCommand : ToolCommand;
    out item completedWorkpiece : Workpiece;

    attribute maximumCommandLatency : Millisecond = 100;
  }

  action def InspectAndClassifyPart {
    in item part : Workpiece;
    out item measurement : QualityMeasurement;
    out item finishedPart : FinishedPart;

    attribute acceptanceTolerance : LengthValue = 0.03 [mm];
  }

  action def PredictAssetFailure {
    in item telemetry : SensorReading;
    out item alert : MaintenanceAlert;

    attribute warningHorizonHours : Real = 24.0;
    attribute minimumConfidence : Percent = 80.0;
  }

  action def OptimizeEnergyUse {
    in item sample : EnergySample;
    out item adjustedPlan : ProcessPlan;

    attribute energyLimitPerPart : KilowattHour = 0.42;
  }

  state def SmartLineLifecycle {
    entry action initializeLine;

    state poweredOff;
    state starting;
    state idle;
    state producing;
    state qualityHold;
    state adaptiveReschedule;
    state maintenanceRequired;
    state faulted;
    state shuttingDown;

    transition initial then poweredOff;
    transition startLine first poweredOff then starting;
    transition ready first starting then idle;
    transition orderReleased first idle then producing;
    transition nonconformanceDetected first producing then qualityHold;
    transition qualityCleared first qualityHold then producing;
    transition planDeviationDetected first producing then adaptiveReschedule;
    transition planUpdated first adaptiveReschedule then producing;
    transition maintenanceAlertRaised first producing then maintenanceRequired;
    transition maintenanceCompleted first maintenanceRequired then idle;
    transition unrecoverableFault first producing then faulted;
    transition resetFault first faulted then idle;
    transition stopRequested first idle then shuttingDown;
    transition shutdownComplete first shuttingDown then poweredOff;
  }

  state def AssetLifecycle {
    state unavailable;
    state standby;
    state setup;
    state automaticRun;
    state manualRun;
    state degraded;
    state maintenance;
    state assetFault;

    transition initial then unavailable;
    transition enable first unavailable then standby;
    transition configure first standby then setup;
    transition startAutomatic first setup then automaticRun;
    transition manualOverride first standby then manualRun;
    transition degradationDetected first automaticRun then degraded;
    transition continueWithLimits first degraded then automaticRun;
    transition serviceRequested first degraded then maintenance;
    transition serviceComplete first maintenance then standby;
    transition faultDetected first automaticRun then assetFault;
    transition recover first assetFault then standby;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : SmartManufacturingLine;

    doc /* The smart manufacturing system shall transform production orders and raw workpieces into inspected finished parts by coordinating connected machines, robots, sensors, digital-twin optimization, quality inspection, predictive maintenance, and energy management. */
  }

  requirement def ThroughputRequirement {
    subject system : SmartManufacturingLine;

    require constraint {
      system.nominalThroughput >= 120
    }
  }

  requirement def QualityRequirement {
    subject system : SmartManufacturingLine;

    require constraint {
      system.maximumAllowedScrapRate <= 2.5
    }
  }

  requirement def OverallEquipmentEffectivenessRequirement {
    subject system : SmartManufacturingLine;

    require constraint {
      system.targetOee >= 85.0
    }
  }

  requirement def ControlLatencyRequirement {
    subject system : SmartManufacturingLine;

    require constraint {
      system.maximumCellLatency <= 100
    }
  }

  requirement def EnergyEfficiencyRequirement {
    subject system : SmartManufacturingLine;

    require constraint {
      system.maximumEnergyPerPart <= 0.42
    }
  }

  requirement def PredictiveMaintenanceRequirement {
    subject service : PredictiveMaintenanceService;

    require constraint {
      service.minimumUsefulLifeHours >= 24.0
    }
  }

  requirement def InspectionResolutionRequirement {
    subject station : InspectionStation;

    require constraint {
      station.measurementResolution <= 0.005 [mm]
    }
  }

  requirement def DigitalTwinUpdateRequirement {
    subject twin : DigitalTwin;

    require constraint {
      twin.simulationUpdatePeriod <= 100
    }
  }

  satisfy PrimaryFunctionRequirement by SmartManufacturingLine;
  satisfy ThroughputRequirement by SmartManufacturingLine;
  satisfy QualityRequirement by SmartManufacturingLine;
  satisfy OverallEquipmentEffectivenessRequirement by SmartManufacturingLine;
  satisfy ControlLatencyRequirement by EdgeController;
  satisfy EnergyEfficiencyRequirement by EnergyManager;
  satisfy PredictiveMaintenanceRequirement by PredictiveMaintenanceService;
  satisfy InspectionResolutionRequirement by InspectionStation;
  satisfy DigitalTwinUpdateRequirement by DigitalTwin;
}