package HeatPenSystem {

  import ScalarValues::*;
  import SI::*;

  attribute def CelsiusTemperature :> Real {
    doc "Temperature value expressed in degrees Celsius.";
  }

  attribute def WattPower :> Real {
    doc "Thermal or electrical power value expressed in watts.";
  }

  attribute def VoltElectricPotential :> Real {
    doc "Electric potential value expressed in volts.";
  }

  attribute def AmpereCurrent :> Real {
    doc "Electric current value expressed in amperes.";
  }

  attribute def JouleEnergy :> Real {
    doc "Energy value expressed in joules.";
  }

  attribute def SecondTime :> Real {
    doc "Time value expressed in seconds.";
  }

  attribute def PercentRatio :> Real {
    doc "Percentage value from 0 to 100.";
  }

  attribute def NewtonForce :> Real {
    doc "Force value expressed in newtons.";
  }

  item def ElectricalEnergy {
    attribute voltage : VoltElectricPotential;
    attribute current : AmpereCurrent;
    attribute availableEnergy : JouleEnergy;
  }

  item def ThermalEnergy {
    attribute temperature : CelsiusTemperature;
    attribute power : WattPower;
  }

  item def UserCommand {
    attribute requestedOn : Boolean;
    attribute targetTemperature : CelsiusTemperature;
  }

  item def StatusIndication {
    attribute isOn : Boolean;
    attribute isAtTemperature : Boolean;
    attribute measuredTipTemperature : CelsiusTemperature;
    attribute batteryCharge : PercentRatio;
  }

  item def HeatTransferContact {
    attribute contactForce : NewtonForce;
    attribute contactDuration : SecondTime;
    attribute deliveredHeat : JouleEnergy;
  }

  port def ElectricalPowerPort {
    in item energyIn : ElectricalEnergy;
  }

  port def ThermalOutputPort {
    out item heatOut : ThermalEnergy;
  }

  port def UserInputPort {
    in item commandIn : UserCommand;
  }

  port def StatusOutputPort {
    out item statusOut : StatusIndication;
  }

  port def TemperatureSensePort {
    out item sensedHeat : ThermalEnergy;
  }

  port def HeatContactPort {
    out item contactHeat : HeatTransferContact;
  }

  part def RechargeableBattery {
    attribute nominalVoltage : VoltElectricPotential = 3.7;
    attribute maximumEnergy : JouleEnergy = 21600.0;
    attribute remainingEnergy : JouleEnergy;
    attribute stateOfCharge : PercentRatio;
    attribute maximumDischargePower : WattPower = 30.0;

    port powerOut : ElectricalPowerPort;
  }

  part def PowerController {
    attribute enabled : Boolean;
    attribute requestedPower : WattPower;
    attribute outputPower : WattPower;
    attribute overCurrentLimit : AmpereCurrent = 8.0;
    attribute undervoltageCutoff : VoltElectricPotential = 3.2;

    port powerIn : ElectricalPowerPort;
    port heaterPowerOut : ElectricalPowerPort;
    port controlIn : UserInputPort;
    port statusOut : StatusOutputPort;
  }

  part def HeatingElement {
    attribute electricalResistance : Real = 1.8;
    attribute maximumElectricalPower : WattPower = 25.0;
    attribute thermalEfficiency : PercentRatio = 82.0;
    attribute generatedThermalPower : WattPower;

    port electricalIn : ElectricalPowerPort;
    port thermalOut : ThermalOutputPort;
  }

  part def HeatedTip {
    attribute targetTemperature : CelsiusTemperature = 180.0;
    attribute measuredTemperature : CelsiusTemperature;
    attribute ambientTemperature : CelsiusTemperature = 22.0;
    attribute maximumSafeTemperature : CelsiusTemperature = 240.0;
    attribute usableTemperatureTolerance : CelsiusTemperature = 5.0;
    attribute tipThermalCapacity : Real = 18.0;

    port heatIn : ThermalOutputPort;
    port workContact : HeatContactPort;
    port sensorTap : TemperatureSensePort;
  }

  part def TemperatureSensor {
    attribute measuredTemperature : CelsiusTemperature;
    attribute measurementError : CelsiusTemperature = 2.0;
    attribute samplePeriod : SecondTime = 0.1;

    port thermalSenseIn : TemperatureSensePort;
    port statusOut : StatusOutputPort;
  }

  part def UserInterface {
    attribute powerButtonPressed : Boolean;
    attribute selectedTemperature : CelsiusTemperature = 180.0;
    attribute readyIndicatorOn : Boolean;
    attribute faultIndicatorOn : Boolean;

    port userCommandOut : UserInputPort;
    port statusIn : StatusOutputPort;
  }

  part def InsulatedBody {
    attribute surfaceTemperature : CelsiusTemperature;
    attribute maximumComfortableSurfaceTemperature : CelsiusTemperature = 45.0;
    attribute gripLength : Real = 95.0;
    attribute outerDiameter : Real = 14.0;
  }

  part def WorkSurface {
    attribute localTemperature : CelsiusTemperature;
    attribute heatAbsorptionCapacity : JouleEnergy;
    attribute allowableSurfaceTemperature : CelsiusTemperature;

    port heatContactIn : HeatContactPort;
  }

  action def AcceptUserTemperatureCommand {
    in command : UserCommand;
    out enabled : Boolean;
    out setPoint : CelsiusTemperature;
  }

  action def ConvertElectricalEnergyToHeat {
    in electricalEnergy : ElectricalEnergy;
    in requestedPower : WattPower;
    out thermalEnergy : ThermalEnergy;
  }

  action def SenseTipTemperature {
    in thermalEnergyAtTip : ThermalEnergy;
    out measuredTemperature : CelsiusTemperature;
  }

  action def RegulateTipTemperature {
    in setPoint : CelsiusTemperature;
    in measuredTemperature : CelsiusTemperature;
    in maximumSafeTemperature : CelsiusTemperature;
    out requestedHeaterPower : WattPower;
    out atTemperature : Boolean;
    out overTemperatureFault : Boolean;
  }

  action def TransferHeatToWorkSurface {
    in tipTemperature : CelsiusTemperature;
    in contactForce : NewtonForce;
    in contactDuration : SecondTime;
    out deliveredHeat : JouleEnergy;
  }

  action def ProvideHeatPenPrimaryFunction {
    doc "Primary high-level function: receive a user temperature command, heat the pen tip, regulate the tip temperature, and transfer controlled heat through the tip to a contacted work surface.";

    in command : UserCommand;
    in availableEnergy : ElectricalEnergy;
    in contactForce : NewtonForce;
    in contactDuration : SecondTime;

    out status : StatusIndication;
    out deliveredContact : HeatTransferContact;

    action acceptCommand : AcceptUserTemperatureCommand {
      in command = ProvideHeatPenPrimaryFunction::command;
    }

    action regulateTemperature : RegulateTipTemperature {
      in setPoint = acceptCommand::setPoint;
      in maximumSafeTemperature = 240.0;
    }

    action convertEnergy : ConvertElectricalEnergyToHeat {
      in electricalEnergy = ProvideHeatPenPrimaryFunction::availableEnergy;
      in requestedPower = regulateTemperature::requestedHeaterPower;
    }

    action senseTemperature : SenseTipTemperature {
      in thermalEnergyAtTip = convertEnergy::thermalEnergy;
    }

    action transferHeat : TransferHeatToWorkSurface {
      in tipTemperature = senseTemperature::measuredTemperature;
      in contactForce = ProvideHeatPenPrimaryFunction::contactForce;
      in contactDuration = ProvideHeatPenPrimaryFunction::contactDuration;
    }

    bind regulateTemperature::measuredTemperature = senseTemperature::measuredTemperature;
    bind deliveredContact::contactForce = ProvideHeatPenPrimaryFunction::contactForce;
    bind deliveredContact::contactDuration = ProvideHeatPenPrimaryFunction::contactDuration;
    bind deliveredContact::deliveredHeat = transferHeat::deliveredHeat;
    bind status::isOn = acceptCommand::enabled;
    bind status::isAtTemperature = regulateTemperature::atTemperature;
    bind status::measuredTipTemperature = senseTemperature::measuredTemperature;
  }

  state def HeatPenOperatingState {
    doc "Discrete operating states of the heat pen.";

    state Off;
    state Standby;
    state Heating;
    state Ready;
    state ApplyingHeat;
    state Cooling;
    state Fault;

    transition powerOn
      first Off
      then Standby
      accept UserCommand
      if commandIn.requestedOn == true;

    transition beginHeating
      first Standby
      then Heating
      if commandIn.targetTemperature > 0.0;

    transition reachSetPoint
      first Heating
      then Ready
      if statusOut.measuredTipTemperature >= commandIn.targetTemperature - 5.0;

    transition contactWork
      first Ready
      then ApplyingHeat
      if statusOut.isAtTemperature == true;

    transition liftFromWork
      first ApplyingHeat
      then Ready;

    transition powerOffFromStandby
      first Standby
      then Cooling
      accept UserCommand
      if commandIn.requestedOn == false;

    transition powerOffFromReady
      first Ready
      then Cooling
      accept UserCommand
      if commandIn.requestedOn == false;

    transition cooled
      first Cooling
      then Off
      if statusOut.measuredTipTemperature <= 45.0;

    transition overTemperature
      first Heating
      then Fault
      if statusOut.measuredTipTemperature > 240.0;

    transition faultPowerOff
      first Fault
      then Cooling
      accept UserCommand
      if commandIn.requestedOn == false;
  }

  part def HeatPen {
    doc "Portable pen-shaped heating device that uses stored electrical energy to maintain a controlled heated tip for localized thermal application.";

    attribute mass : Real = 0.085;
    attribute length : Real = 165.0;
    attribute maximumTipTemperature : CelsiusTemperature = 240.0;
    attribute nominalOperatingTemperature : CelsiusTemperature = 180.0;
    attribute warmUpTimeLimit : SecondTime = 20.0;
    attribute minimumOperatingStateOfCharge : PercentRatio = 10.0;
    attribute primaryFunctionDescription : String = "Provide controlled localized heat at a pen tip to a contacted work surface.";

    port userInput : UserInputPort;
    port userStatus : StatusOutputPort;
    port heatOutput : HeatContactPort;

    part battery : RechargeableBattery {
      attribute remainingEnergy = 18000.0;
      attribute stateOfCharge = 83.0;
    }

    part controller : PowerController {
      attribute enabled = false;
      attribute requestedPower = 0.0;
      attribute outputPower = 0.0;
    }

    part heater : HeatingElement;
    part tip : HeatedTip {
      attribute measuredTemperature = 22.0;
    }

    part sensor : TemperatureSensor {
      attribute measuredTemperature = 22.0;
    }

    part interface : UserInterface;
    part body : InsulatedBody {
      attribute surfaceTemperature = 25.0;
    }

    perform action primaryFunction : ProvideHeatPenPrimaryFunction;
    exhibit state operatingState : HeatPenOperatingState;

    connect battery.powerOut to controller.powerIn;
    connect controller.heaterPowerOut to heater.electricalIn;
    connect heater.thermalOut to tip.heatIn;
    connect tip.sensorTap to sensor.thermalSenseIn;
    connect interface.userCommandOut to controller.controlIn;
    connect controller.statusOut to interface.statusIn;
    connect userInput to interface.userCommandOut;
    connect interface.statusIn to userStatus;
    connect tip.workContact to heatOutput;
  }

  part def HeatPenUseContext {
    doc "Operational context in which a user applies the heat pen to a work surface.";

    part heatPen : HeatPen;
    part targetSurface : WorkSurface {
      attribute localTemperature = 22.0;
      attribute heatAbsorptionCapacity = 5000.0;
      attribute allowableSurfaceTemperature = 210.0;
    }

    connect heatPen.heatOutput to targetSurface.heatContactIn;
  }

  requirement def PrimaryFunctionRequirement {
    doc "The heat pen shall provide controlled localized heat through a pen tip to a contacted work surface when commanded by the user.";

    subject pen : HeatPen;

    require constraint {
      pen.primaryFunctionDescription == "Provide controlled localized heat at a pen tip to a contacted work surface."
    }
  }

  requirement def WarmUpRequirement {
    doc "The heat pen shall reach the selected operating tip temperature within the warm-up time limit under nominal battery charge.";

    subject pen : HeatPen;

    require constraint {
      pen.warmUpTimeLimit <= 20.0
    }
  }

  requirement def TemperatureControlRequirement {
    doc "The heat pen shall regulate the heated tip within the usable tolerance of the selected target temperature during normal operation.";

    subject pen : HeatPen;

    require constraint {
      pen.tip.measuredTemperature <= pen.tip.targetTemperature + pen.tip.usableTemperatureTolerance
    }
  }

  requirement def OverTemperatureProtectionRequirement {
    doc "The heat pen shall enter a fault or stop heating before the heated tip exceeds the maximum safe temperature.";

    subject pen : HeatPen;

    require constraint {
      pen.tip.measuredTemperature <= pen.maximumTipTemperature
    }
  }

  requirement def UserSafetySurfaceRequirement {
    doc "The insulated body shall remain below the maximum comfortable surface temperature during normal operation.";

    subject pen : HeatPen;

    require constraint {
      pen.body.surfaceTemperature <= pen.body.maximumComfortableSurfaceTemperature
    }
  }

  requirement def BatteryOperationRequirement {
    doc "The heat pen shall inhibit heating when battery state of charge is below the minimum operating value.";

    subject pen : HeatPen;

    require constraint {
      pen.battery.stateOfCharge >= pen.minimumOperatingStateOfCharge
    }
  }

  part heatPenSystem : HeatPenUseContext {
    satisfy PrimaryFunctionRequirement by heatPen;
    satisfy WarmUpRequirement by heatPen;
    satisfy TemperatureControlRequirement by heatPen;
    satisfy OverTemperatureProtectionRequirement by heatPen;
    satisfy UserSafetySurfaceRequirement by heatPen;
    satisfy BatteryOperationRequirement by heatPen;
  }

}
