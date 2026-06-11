package HeatPenModel {
  import ScalarValues::*;
  import SI::*;

  item def ElectricalEnergy;
  item def ThermalEnergy;
  item def UserCommand;
  item def SurfaceContact;
  item def InkMark;

  attribute def Temperature :> Real {
    unit = "degC";
  }

  attribute def Power :> Real {
    unit = "W";
  }

  attribute def Voltage :> Real {
    unit = "V";
  }

  attribute def Current :> Real {
    unit = "A";
  }

  attribute def TimeDuration :> Real {
    unit = "s";
  }

  attribute def BatteryCapacity :> Real {
    unit = "mAh";
  }

  port def ElectricalPowerPort {
    in item energyIn: ElectricalEnergy;
    out item energyOut: ElectricalEnergy;
  }

  port def ThermalPort {
    in item heatIn: ThermalEnergy;
    out item heatOut: ThermalEnergy;
  }

  port def CommandPort {
    in item command: UserCommand;
  }

  port def ContactPort {
    in item contact: SurfaceContact;
    out item mark: InkMark;
  }

  part def HeatPen {
    attribute targetTipTemperature: Temperature = 65.0;
    attribute maximumSafeTipTemperature: Temperature = 85.0;
    attribute warmupTimeLimit: TimeDuration = 20.0;
    attribute nominalHeatingPower: Power = 4.5;
    attribute nominalVoltage: Voltage = 3.7;

    port commandIn: CommandPort;
    port writingInterface: ContactPort;

    part battery: RechargeableBattery;
    part controller: TemperatureController;
    part heater: ResistiveHeatingElement;
    part sensor: TipTemperatureSensor;
    part heatedTip: ConductiveWritingTip;
    part grip: InsulatedGrip;
    part indicator: StatusIndicator;
    part safetySwitch: ThermalSafetySwitch;

    connect battery.powerOut to controller.powerIn;
    connect controller.heaterPowerOut to heater.powerIn;
    connect heater.heatOut to heatedTip.heatIn;
    connect heatedTip.sensorInterface to sensor.tipThermalInterface;
    connect sensor.temperatureSignalOut to controller.temperatureSignalIn;
    connect controller.statusOut to indicator.statusIn;
    connect safetySwitch.cutoffCommandOut to controller.safetyCommandIn;
    connect commandIn to controller.userCommandIn;
    connect heatedTip.contactInterface to writingInterface;

    perform action primaryFunction: RegulateAndApplyHeat {
      in targetTemperature = targetTipTemperature;
      in maximumTemperature = maximumSafeTipTemperature;
    }

    exhibit state operatingMode: HeatPenOperatingState;
  }

  part def RechargeableBattery {
    attribute storedCapacity: BatteryCapacity = 750.0;
    attribute outputVoltage: Voltage = 3.7;
    attribute maximumContinuousCurrent: Current = 2.0;

    port powerOut: ElectricalPowerPort;
    port chargePort: ElectricalPowerPort;
  }

  part def TemperatureController {
    attribute controlLoopPeriod: TimeDuration = 0.05;
    attribute standbyTemperature: Temperature = 40.0;
    attribute regulationTolerance: Temperature = 3.0;

    port powerIn: ElectricalPowerPort;
    port heaterPowerOut: ElectricalPowerPort;
    port temperatureSignalIn: ThermalPort;
    port userCommandIn: CommandPort;
    port safetyCommandIn: CommandPort;
    port statusOut: CommandPort;

    perform action regulate: ClosedLoopTemperatureControl;
  }

  part def ResistiveHeatingElement {
    attribute ratedPower: Power = 4.5;
    attribute ratedVoltage: Voltage = 3.7;

    port powerIn: ElectricalPowerPort;
    port heatOut: ThermalPort;
  }

  part def TipTemperatureSensor {
    attribute measurementRangeLow: Temperature = 0.0;
    attribute measurementRangeHigh: Temperature = 120.0;
    attribute measurementAccuracy: Temperature = 1.5;

    port tipThermalInterface: ThermalPort;
    port temperatureSignalOut: ThermalPort;
  }

  part def ConductiveWritingTip {
    attribute operatingTemperature: Temperature;
    attribute maximumContactTemperature: Temperature = 85.0;

    port heatIn: ThermalPort;
    port sensorInterface: ThermalPort;
    port contactInterface: ContactPort;
  }

  part def InsulatedGrip {
    attribute maximumOuterSurfaceTemperature: Temperature = 38.0;
  }

  part def StatusIndicator {
    port statusIn: CommandPort;
  }

  part def ThermalSafetySwitch {
    attribute shutdownTemperature: Temperature = 90.0;
    attribute resetTemperature: Temperature = 55.0;

    port cutoffCommandOut: CommandPort;
  }

  action def RegulateAndApplyHeat {
    in targetTemperature: Temperature;
    in maximumTemperature: Temperature;
    out producedMark: InkMark;

    first start;
    then acceptUserCommand;
    then energizeHeatingElement;
    then monitorTipTemperature;
    then regulatePower;
    then applyControlledHeatToSurface;
    then produceMark;
    then done;

    action acceptUserCommand;
    action energizeHeatingElement;
    action monitorTipTemperature;
    action regulatePower;
    action applyControlledHeatToSurface;
    action produceMark;
  }

  action def ClosedLoopTemperatureControl {
    in sensedTemperature: Temperature;
    in targetTemperature: Temperature;
    out heaterPowerCommand: Power;

    first sampleSensor;
    then compareToTarget;
    then computePowerCommand;
    then limitForSafety;
    then outputPowerCommand;

    action sampleSensor;
    action compareToTarget;
    action computePowerCommand;
    action limitForSafety;
    action outputPowerCommand;
  }

  state def HeatPenOperatingState {
    state Off;
    state Standby;
    state Warming;
    state Ready;
    state Writing;
    state Cooling;
    state Fault;

    transition initial then Off;

    transition powerOn
      first Off
      accept UserCommand
      then Standby;

    transition beginWarmup
      first Standby
      accept UserCommand
      then Warming;

    transition warmupComplete
      first Warming
      if tipTemperature >= targetTipTemperature
      then Ready;

    transition contactDetected
      first Ready
      accept SurfaceContact
      then Writing;

    transition contactReleased
      first Writing
      then Ready;

    transition powerOffFromReady
      first Ready
      accept UserCommand
      then Cooling;

    transition cooled
      first Cooling
      if tipTemperature <= 35.0
      then Off;

    transition overTemperature
      first Warming
      if tipTemperature > maximumSafeTipTemperature
      then Fault;

    transition overTemperatureDuringWriting
      first Writing
      if tipTemperature > maximumSafeTipTemperature
      then Fault;
  }

  requirement def PrimaryFunctionRequirement {
    subject pen: HeatPen;

    require constraint {
      pen shall transform stored electrical energy into regulated thermal energy at the writing tip to create controlled heat-assisted marks on a contacted surface.
    }
  }

  requirement def TemperatureRegulationRequirement {
    subject pen: HeatPen;

    require constraint {
      pen.heatedTip.operatingTemperature >= 62.0 and
      pen.heatedTip.operatingTemperature <= 68.0
    }
  }

  requirement def WarmupRequirement {
    subject pen: HeatPen;

    require constraint {
      pen.warmupTimeLimit <= 20.0
    }
  }

  requirement def SafetyTemperatureRequirement {
    subject pen: HeatPen;

    require constraint {
      pen.heatedTip.operatingTemperature <= pen.maximumSafeTipTemperature
    }
  }

  requirement def GripSafetyRequirement {
    subject pen: HeatPen;

    require constraint {
      pen.grip.maximumOuterSurfaceTemperature <= 38.0
    }
  }

  requirement def PortablePowerRequirement {
    subject pen: HeatPen;

    require constraint {
      pen.battery.outputVoltage == 3.7 and
      pen.battery.storedCapacity >= 500.0
    }
  }

  satisfy PrimaryFunctionRequirement by HeatPen;
  satisfy TemperatureRegulationRequirement by HeatPen;
  satisfy WarmupRequirement by HeatPen;
  satisfy SafetyTemperatureRequirement by HeatPen;
  satisfy GripSafetyRequirement by HeatPen;
  satisfy PortablePowerRequirement by HeatPen;
}