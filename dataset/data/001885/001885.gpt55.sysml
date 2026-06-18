package VolumetricFlowRateBasedSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  value type Liter specializes Real {
    doc "Unit of volume used for liquid delivery.";
    unit = "L";
  }

  value type Minute specializes Real {
    doc "Unit of time used for operational flow-rate targets.";
    unit = "min";
  }

  value type Second specializes Real {
    doc "Unit of time used for control and response behavior.";
    unit = "s";
  }

  value type Pascal specializes Real {
    doc "Unit of pressure.";
    unit = "Pa";
  }

  value type Watt specializes Real {
    doc "Unit of power.";
    unit = "W";
  }

  value type Volt specializes Real {
    doc "Unit of electrical potential.";
    unit = "V";
  }

  value type Ampere specializes Real {
    doc "Unit of electrical current.";
    unit = "A";
  }

  value type Percent specializes Real {
    doc "Dimensionless percentage value.";
    unit = "%";
  }

  value type RevolutionsPerMinute specializes Real {
    doc "Rotational speed unit for pump motor speed.";
    unit = "rpm";
  }

  value type VolumetricFlowRate specializes Real {
    doc "Volume of fluid passing through a boundary per unit time.";
    unit = "L/min";
    quantityKind = "volumetric flow rate";
  }

  value type Pressure specializes Real {
    unit = "Pa";
    quantityKind = "pressure";
  }

  value type Volume specializes Real {
    unit = "L";
    quantityKind = "volume";
  }

  value type Duration specializes Real {
    unit = "s";
    quantityKind = "time";
  }

  value type Temperature specializes Real {
    unit = "degC";
    quantityKind = "temperature";
  }

  value type ElectricalPower specializes Real {
    unit = "W";
    quantityKind = "power";
  }

  value type ElectricalPotential specializes Real {
    unit = "V";
    quantityKind = "electric potential";
  }

  value type ElectricalCurrent specializes Real {
    unit = "A";
    quantityKind = "electric current";
  }

  value type MotorSpeed specializes Real {
    unit = "rpm";
    quantityKind = "rotational speed";
  }

  value type ControlSignal specializes Real {
    unit = "%";
    quantityKind = "normalized command";
  }

  item def Liquid {
    doc "Working liquid whose volumetric flow rate is regulated by the system.";
    attribute density : Real = 998.0;
    attribute temperature : Temperature;
    attribute contaminationIndex : Real;
  }

  item def ElectricalEnergy {
    doc "Electrical energy supplied to the flow-rate control system.";
    attribute voltage : ElectricalPotential;
    attribute current : ElectricalCurrent;
    attribute power : ElectricalPower;
  }

  item def FlowCommand {
    doc "Operator or supervisory command specifying the desired volumetric flow rate.";
    attribute setPoint : VolumetricFlowRate;
    attribute rampLimit : VolumetricFlowRate;
    attribute enable : Boolean;
  }

  item def FlowMeasurement {
    doc "Measured volumetric flow-rate information.";
    attribute measuredRate : VolumetricFlowRate;
    attribute measurementAge : Duration;
    attribute valid : Boolean;
  }

  item def PressureMeasurement {
    doc "Pressure information at a system boundary or component.";
    attribute measuredPressure : Pressure;
    attribute valid : Boolean;
  }

  item def FaultReport {
    doc "Fault information produced by system diagnostics.";
    attribute faultActive : Boolean;
    attribute faultCode : String;
    attribute severity : Integer;
  }

  item def StatusReport {
    doc "Operational status of the volumetric flow-rate based system.";
    attribute enabled : Boolean;
    attribute deliveredFlowRate : VolumetricFlowRate;
    attribute commandedFlowRate : VolumetricFlowRate;
    attribute inletPressure : Pressure;
    attribute outletPressure : Pressure;
    attribute controllerMode : String;
  }

  port def FluidInletPort {
    doc "Hydraulic interface accepting incoming liquid.";
    in item liquidIn : Liquid;
    out item inletPressure : PressureMeasurement;
    attribute nominalPressure : Pressure;
    attribute maxAllowablePressure : Pressure;
  }

  port def FluidOutletPort {
    doc "Hydraulic interface discharging regulated liquid.";
    out item liquidOut : Liquid;
    out item outletPressure : PressureMeasurement;
    out item outletFlow : FlowMeasurement;
    attribute nominalFlowRate : VolumetricFlowRate;
    attribute maxFlowRate : VolumetricFlowRate;
  }

  port def FluidThroughPort {
    doc "Bidirectional hydraulic component port used internally for liquid transfer.";
    inout item liquid : Liquid;
    inout item flow : FlowMeasurement;
    inout item pressure : PressureMeasurement;
  }

  port def ElectricalPowerPort {
    doc "Electrical power interface.";
    in item supply : ElectricalEnergy;
    attribute nominalVoltage : ElectricalPotential;
    attribute maxCurrent : ElectricalCurrent;
  }

  port def CommandPort {
    doc "Command input interface.";
    in item command : FlowCommand;
  }

  port def MeasurementPort {
    doc "Measurement output interface.";
    out item measurement : FlowMeasurement;
  }

  port def StatusPort {
    doc "Status and fault reporting interface.";
    out item status : StatusReport;
    out item fault : FaultReport;
  }

  port def MotorCommandPort {
    doc "Control interface from controller to pump motor drive.";
    out attribute speedCommand : MotorSpeed;
    out attribute torqueLimitCommand : ControlSignal;
    out attribute enableCommand : Boolean;
  }

  port def ValveCommandPort {
    doc "Control interface from controller to trim valve.";
    out attribute positionCommand : ControlSignal;
    out attribute enableCommand : Boolean;
  }

  part def SupplyReservoir {
    doc "Stores liquid available to the flow-rate based system.";
    attribute usableVolume : Volume = 120.0;
    attribute minimumOperatingVolume : Volume = 5.0;
    attribute reservoirPressure : Pressure = 101325.0;
    attribute liquidTemperature : Temperature = 20.0;

    port outlet : FluidThroughPort {
      attribute pressure::measuredPressure = reservoirPressure;
    }
  }

  part def InletFilter {
    doc "Removes particulate contamination before liquid enters the pump.";
    attribute nominalMicronRating : Real = 50.0;
    attribute cleanPressureDropAtNominalFlow : Pressure = 8000.0;
    attribute cloggedPressureDropLimit : Pressure = 60000.0;
    attribute health : Percent = 100.0;

    port inlet : FluidThroughPort;
    port outlet : FluidThroughPort;

    constraint pressureDropWithinLimit {
      inlet.pressure.measuredPressure - outlet.pressure.measuredPressure <= cloggedPressureDropLimit
    }
  }

  part def VariableSpeedPump {
    doc "Adds hydraulic energy to establish commanded volumetric flow rate.";
    attribute minimumSpeed : MotorSpeed = 300.0;
    attribute maximumSpeed : MotorSpeed = 4800.0;
    attribute nominalSpeed : MotorSpeed = 2400.0;
    attribute displacementPerRevolution : Real = 0.006;
    attribute maximumOutletPressure : Pressure = 700000.0;
    attribute hydraulicEfficiency : Percent = 82.0;
    attribute electricalEfficiency : Percent = 88.0;

    port inlet : FluidThroughPort;
    port outlet : FluidThroughPort;
    port power : ElectricalPowerPort {
      attribute nominalVoltage = 48.0;
      attribute maxCurrent = 35.0;
    }
    port driveCommand : MotorCommandPort;

    attribute actualSpeed : MotorSpeed;
    attribute estimatedFlowRate : VolumetricFlowRate;

    constraint speedWithinLimits {
      actualSpeed >= minimumSpeed and actualSpeed <= maximumSpeed
    }

    constraint outletPressureWithinLimit {
      outlet.pressure.measuredPressure <= maximumOutletPressure
    }
  }

  part def FlowMeter {
    doc "Measures volumetric flow rate downstream of the pump.";
    attribute measurementRangeMinimum : VolumetricFlowRate = 0.0;
    attribute measurementRangeMaximum : VolumetricFlowRate = 80.0;
    attribute accuracyPercentOfReading : Percent = 1.0;
    attribute samplePeriod : Duration = 0.05;
    attribute lastMeasuredFlowRate : VolumetricFlowRate;

    port inlet : FluidThroughPort;
    port outlet : FluidThroughPort;
    port measuredFlow : MeasurementPort;

    constraint measurementRange {
      lastMeasuredFlowRate >= measurementRangeMinimum and lastMeasuredFlowRate <= measurementRangeMaximum
    }
  }

  part def ProportionalControlValve {
    doc "Fine-trims delivered volumetric flow rate by varying hydraulic restriction.";
    attribute minimumOpenPosition : ControlSignal = 0.0;
    attribute maximumOpenPosition : ControlSignal = 100.0;
    attribute failSafePosition : ControlSignal = 0.0;
    attribute currentOpenPosition : ControlSignal;
    attribute maximumPressureDrop : Pressure = 250000.0;

    port inlet : FluidThroughPort;
    port outlet : FluidThroughPort;
    port valveCommand : ValveCommandPort;

    constraint valvePositionWithinLimits {
      currentOpenPosition >= minimumOpenPosition and currentOpenPosition <= maximumOpenPosition
    }

    constraint valvePressureDropWithinLimit {
      inlet.pressure.measuredPressure - outlet.pressure.measuredPressure <= maximumPressureDrop
    }
  }

  part def DischargeInterface {
    doc "External delivery interface for regulated liquid flow.";
    attribute minimumBackPressure : Pressure = 101325.0;
    attribute maximumBackPressure : Pressure = 500000.0;
    attribute deliveredFlowRate : VolumetricFlowRate;

    port inlet : FluidThroughPort;
    port outlet : FluidOutletPort {
      attribute nominalFlowRate = 40.0;
      attribute maxFlowRate = 80.0;
    }

    constraint backPressureRange {
      outlet.outletPressure.measuredPressure >= minimumBackPressure and
      outlet.outletPressure.measuredPressure <= maximumBackPressure
    }
  }

  part def FlowRateController {
    doc "Closed-loop controller that compares commanded and measured volumetric flow rate and commands pump speed and valve position.";
    attribute minimumCommandedFlowRate : VolumetricFlowRate = 2.0;
    attribute maximumCommandedFlowRate : VolumetricFlowRate = 75.0;
    attribute commandedFlowRate : VolumetricFlowRate;
    attribute measuredFlowRate : VolumetricFlowRate;
    attribute flowError : VolumetricFlowRate;
    attribute steadyStateTolerance : VolumetricFlowRate = 0.8;
    attribute responseTimeLimit : Duration = 3.0;
    attribute pumpSpeedCommand : MotorSpeed;
    attribute valvePositionCommand : ControlSignal;
    attribute enabled : Boolean;
    attribute faulted : Boolean;

    port commandIn : CommandPort;
    port measurementIn : MeasurementPort;
    port pumpCommandOut : MotorCommandPort;
    port valveCommandOut : ValveCommandPort;
    port statusOut : StatusPort;

    constraint commandRange {
      commandedFlowRate >= minimumCommandedFlowRate and commandedFlowRate <= maximumCommandedFlowRate
    }

    constraint errorCalculation {
      flowError == commandedFlowRate - measuredFlowRate
    }
  }

  action def AcceptFlowCommand {
    in item operatorCommand : FlowCommand;
    out attribute acceptedSetPoint : VolumetricFlowRate;
    out attribute acceptedEnable : Boolean;

    constraint acceptedSetPointWithinRange {
      acceptedSetPoint >= 2.0 and acceptedSetPoint <= 75.0
    }
  }

  action def MeasureVolumetricFlowRate {
    in item liquid : Liquid;
    out item measurement : FlowMeasurement;

    attribute samplePeriod : Duration = 0.05;

    constraint measurementIsCurrent {
      measurement.measurementAge <= samplePeriod
    }
  }

  action def ComputeFlowControl {
    in attribute setPoint : VolumetricFlowRate;
    in attribute actualFlow : VolumetricFlowRate;
    out attribute pumpSpeed : MotorSpeed;
    out attribute valvePosition : ControlSignal;

    attribute proportionalGainPump : Real = 38.0;
    attribute proportionalGainValve : Real = 1.5;
    attribute error : VolumetricFlowRate;

    constraint computeError {
      error == setPoint - actualFlow
    }

    constraint pumpCommandRange {
      pumpSpeed >= 300.0 and pumpSpeed <= 4800.0
    }

    constraint valveCommandRange {
      valvePosition >= 0.0 and valvePosition <= 100.0
    }
  }

  action def DeliverRegulatedLiquid {
    doc "Primary system function: deliver liquid at a commanded volumetric flow rate.";
    in item supplyLiquid : Liquid;
    in item command : FlowCommand;
    out item deliveredLiquid : Liquid;
    out item status : StatusReport;

    attribute targetFlowRate : VolumetricFlowRate;
    attribute actualFlowRate : VolumetricFlowRate;
    attribute allowedError : VolumetricFlowRate = 0.8;

    first start;
    then acceptCommand : AcceptFlowCommand {
      in operatorCommand = command;
      out acceptedSetPoint = targetFlowRate;
    }
    then measureFlow : MeasureVolumetricFlowRate {
      in liquid = supplyLiquid;
    }
    then computeControl : ComputeFlowControl {
      in setPoint = targetFlowRate;
      in actualFlow = actualFlowRate;
    }
    then discharge;

    constraint primaryFunctionAccuracy {
      actualFlowRate >= targetFlowRate - allowedError and
      actualFlowRate <= targetFlowRate + allowedError
    }
  }

  state def FlowControlOperatingModes {
    doc "Operational states for the flow-rate based system controller.";

    attribute commandedFlowRate : VolumetricFlowRate;
    attribute measuredFlowRate : VolumetricFlowRate;
    attribute inletPressure : Pressure;
    attribute outletPressure : Pressure;
    attribute faultActive : Boolean;

    state Off {
      entry action {
        faultActive = false;
      }
    }

    state Standby {
      entry action {
        commandedFlowRate = 0.0;
      }
    }

    state Priming {
      entry action {
        commandedFlowRate = 5.0;
      }
    }

    state Regulating {
      do action regulate : ComputeFlowControl {
        in setPoint = commandedFlowRate;
        in actualFlow = measuredFlowRate;
      }
    }

    state Faulted {
      entry action {
        faultActive = true;
        commandedFlowRate = 0.0;
      }
    }

    transition initialToOff first start then Off;

    transition offToStandby
      first Off
      accept FlowCommand
      if command.enable == true
      then Standby;

    transition standbyToPriming
      first Standby
      if commandedFlowRate > 0.0
      then Priming;

    transition primingToRegulating
      first Priming
      if measuredFlowRate > 1.0
      then Regulating;

    transition regulatingToStandby
      first Regulating
      accept FlowCommand
      if command.enable == false
      then Standby;

    transition anyToFaultedLowInletPressure
      first Standby, Priming, Regulating
      if inletPressure < 50000.0
      then Faulted;

    transition anyToFaultedHighOutletPressure
      first Standby, Priming, Regulating
      if outletPressure > 700000.0
      then Faulted;

    transition faultedToStandby
      first Faulted
      accept FlowCommand
      if command.enable == true and faultActive == false
      then Standby;
  }

  part def FlowRateControlledDeliverySystem {
    doc "A system specified around volumetric flow rate. Its primary high-level function is to accept a commanded volumetric flow-rate set point and deliver liquid to an outlet while regulating measured flow to the set point.";

    attribute commandedVolumetricFlowRate : VolumetricFlowRate;
    attribute measuredVolumetricFlowRate : VolumetricFlowRate;
    attribute deliveredVolumetricFlowRate : VolumetricFlowRate;
    attribute minimumDeliverableFlowRate : VolumetricFlowRate = 2.0;
    attribute nominalDeliverableFlowRate : VolumetricFlowRate = 40.0;
    attribute maximumDeliverableFlowRate : VolumetricFlowRate = 75.0;
    attribute steadyStateFlowTolerance : VolumetricFlowRate = 0.8;
    attribute maximumResponseTime : Duration = 3.0;
    attribute maximumOutletPressure : Pressure = 700000.0;
    attribute minimumInletPressure : Pressure = 50000.0;
    attribute nominalSupplyVoltage : ElectricalPotential = 48.0;

    port liquidInlet : FluidInletPort {
      attribute nominalPressure = 101325.0;
      attribute maxAllowablePressure = 400000.0;
    }

    port regulatedLiquidOutlet : FluidOutletPort {
      attribute nominalFlowRate = 40.0;
      attribute maxFlowRate = 75.0;
    }

    port electricalInput : ElectricalPowerPort {
      attribute nominalVoltage = 48.0;
      attribute maxCurrent = 35.0;
    }

    port flowCommandInput : CommandPort;
    port systemStatusOutput : StatusPort;

    part reservoir : SupplyReservoir;
    part inletFilter : InletFilter;
    part pump : VariableSpeedPump;
    part flowMeter : FlowMeter;
    part trimValve : ProportionalControlValve;
    part discharge : DischargeInterface;
    part controller : FlowRateController;

    connection reservoirToFilter connect reservoir.outlet to inletFilter.inlet;
    connection filterToPump connect inletFilter.outlet to pump.inlet;
    connection pumpToMeter connect pump.outlet to flowMeter.inlet;
    connection meterToValve connect flowMeter.outlet to trimValve.inlet;
    connection valveToDischarge connect trimValve.outlet to discharge.inlet;
    connection dischargeToSystemOutlet connect discharge.outlet to regulatedLiquidOutlet;

    connection externalInletToReservoir connect liquidInlet to reservoir.outlet;
    connection powerToPump connect electricalInput to pump.power;
    connection commandToController connect flowCommandInput to controller.commandIn;
    connection meterToController connect flowMeter.measuredFlow to controller.measurementIn;
    connection controllerToPump connect controller.pumpCommandOut to pump.driveCommand;
    connection controllerToValve connect controller.valveCommandOut to trimValve.valveCommand;
    connection controllerStatusToSystemStatus connect controller.statusOut to systemStatusOutput;

    perform primaryFunction : DeliverRegulatedLiquid {
      in supplyLiquid = liquidInlet.liquidIn;
      in command = flowCommandInput.command;
      out deliveredLiquid = regulatedLiquidOutlet.liquidOut;
      out status = systemStatusOutput.status;
    }

    state operatingModes : FlowControlOperatingModes {
      attribute commandedFlowRate = commandedVolumetricFlowRate;
      attribute measuredFlowRate = measuredVolumetricFlowRate;
      attribute inletPressure = liquidInlet.inletPressure.measuredPressure;
      attribute outletPressure = regulatedLiquidOutlet.outletPressure.measuredPressure;
    }

    constraint flowRangeCapability {
      commandedVolumetricFlowRate >= minimumDeliverableFlowRate and
      commandedVolumetricFlowRate <= maximumDeliverableFlowRate
    }

    constraint steadyStateFlowAccuracy {
      deliveredVolumetricFlowRate >= commandedVolumetricFlowRate - steadyStateFlowTolerance and
      deliveredVolumetricFlowRate <= commandedVolumetricFlowRate + steadyStateFlowTolerance
    }

    constraint pressureSafetyEnvelope {
      liquidInlet.inletPressure.measuredPressure >= minimumInletPressure and
      regulatedLiquidOutlet.outletPressure.measuredPressure <= maximumOutletPressure
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc "The system shall deliver liquid at a commanded volumetric flow rate as its primary high-level function.";
    subject system : FlowRateControlledDeliverySystem;

    require constraint {
      system.deliveredVolumetricFlowRate >= system.commandedVolumetricFlowRate - system.steadyStateFlowTolerance and
      system.deliveredVolumetricFlowRate <= system.commandedVolumetricFlowRate + system.steadyStateFlowTolerance
    }
  }

  requirement def FlowRateRangeRequirement {
    doc "The system shall accept and regulate commanded volumetric flow-rate set points from 2 L/min to 75 L/min.";
    subject system : FlowRateControlledDeliverySystem;

    require constraint {
      system.commandedVolumetricFlowRate >= 2.0 and
      system.commandedVolumetricFlowRate <= 75.0
    }
  }

  requirement def NominalFlowRequirement {
    doc "The system shall support a nominal volumetric flow rate of 40 L/min during continuous operation.";
    subject system : FlowRateControlledDeliverySystem;

    require constraint {
      system.nominalDeliverableFlowRate == 40.0
    }
  }

  requirement def FlowAccuracyRequirement {
    doc "At steady state, delivered volumetric flow rate shall remain within plus or minus 0.8 L/min of the commanded set point.";
    subject system : FlowRateControlledDeliverySystem;

    require constraint {
      system.deliveredVolumetricFlowRate >= system.commandedVolumetricFlowRate - 0.8 and
      system.deliveredVolumetricFlowRate <= system.commandedVolumetricFlowRate + 0.8
    }
  }

  requirement def FlowResponseRequirement {
    doc "Following a valid set-point change, the system shall settle to the new volumetric flow-rate target within 3 seconds.";
    subject system : FlowRateControlledDeliverySystem;

    require constraint {
      system.maximumResponseTime <= 3.0
    }
  }

  requirement def PressureProtectionRequirement {
    doc "The system shall enter a faulted safe state if outlet pressure exceeds 700000 Pa or inlet pressure falls below 50000 Pa.";
    subject system : FlowRateControlledDeliverySystem;

    require constraint {
      system.maximumOutletPressure <= 700000.0 and
      system.minimumInletPressure >= 50000.0
    }
  }

  requirement def MeasurementRequirement {
    doc "The flow meter shall measure volumetric flow rate over the full commanded range with at least 1 percent reading accuracy.";
    subject meter : FlowMeter;

    require constraint {
      meter.measurementRangeMinimum <= 2.0 and
      meter.measurementRangeMaximum >= 75.0 and
      meter.accuracyPercentOfReading <= 1.0
    }
  }

  requirement def ElectricalSupplyRequirement {
    doc "The system shall operate from a nominal 48 V electrical input and limit pump supply current to 35 A.";
    subject system : FlowRateControlledDeliverySystem;

    require constraint {
      system.nominalSupplyVoltage == 48.0 and
      system.pump.power.maxCurrent <= 35.0
    }
  }

  part flowRateBasedSystem : FlowRateControlledDeliverySystem {
    attribute commandedVolumetricFlowRate = 40.0;
    attribute measuredVolumetricFlowRate = 40.0;
    attribute deliveredVolumetricFlowRate = 40.0;
  }

  requirement primaryFunction : PrimaryFunctionRequirement {
    subject system = flowRateBasedSystem;
  }

  requirement range : FlowRateRangeRequirement {
    subject system = flowRateBasedSystem;
  }

  requirement nominal : NominalFlowRequirement {
    subject system = flowRateBasedSystem;
  }

  requirement accuracy : FlowAccuracyRequirement {
    subject system = flowRateBasedSystem;
  }

  requirement response : FlowResponseRequirement {
    subject system = flowRateBasedSystem;
  }

  requirement protection : PressureProtectionRequirement {
    subject system = flowRateBasedSystem;
  }

  requirement measurement : MeasurementRequirement {
    subject meter = flowRateBasedSystem.flowMeter;
  }

  requirement electrical : ElectricalSupplyRequirement {
    subject system = flowRateBasedSystem;
  }

  satisfy primaryFunction by flowRateBasedSystem.primaryFunction;
  satisfy range by flowRateBasedSystem;
  satisfy nominal by flowRateBasedSystem;
  satisfy accuracy by flowRateBasedSystem.controller;
  satisfy response by flowRateBasedSystem.controller;
  satisfy protection by flowRateBasedSystem.operatingModes;
  satisfy measurement by flowRateBasedSystem.flowMeter;
  satisfy electrical by flowRateBasedSystem.pump;
}
