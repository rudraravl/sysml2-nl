package FluidWarmerSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Celsius :> Real;
  attribute def MilliliterPerMinute :> Real;
  attribute def Watt :> Real;
  attribute def Volt :> Real;
  attribute def Ampere :> Real;
  attribute def Pascal :> Real;
  attribute def Joule :> Real;
  attribute def Second :> Real;

  item def Fluid {
    attribute temperature : Celsius;
    attribute flowRate : MilliliterPerMinute;
    attribute pressure : Pascal;
    attribute volume : Real;
  }

  item def ElectricalPower {
    attribute voltage : Volt;
    attribute current : Ampere;
    attribute power : Watt;
  }

  item def ThermalEnergy {
    attribute heatFlow : Watt;
    attribute accumulatedEnergy : Joule;
  }

  item def ControlSignal {
    attribute requestedPower : Watt;
    attribute enableHeating : Boolean;
  }

  item def TemperatureReading {
    attribute measuredTemperature : Celsius;
    attribute valid : Boolean;
  }

  port def FluidInletPort {
    in item incomingFluid : Fluid;
  }

  port def FluidOutletPort {
    out item warmedFluid : Fluid;
  }

  port def PowerInputPort {
    in item suppliedPower : ElectricalPower;
  }

  port def HeatTransferPort {
    out item thermalEnergy : ThermalEnergy;
  }

  port def SensorOutputPort {
    out item reading : TemperatureReading;
  }

  port def ControlPort {
    in item command : ControlSignal;
  }

  part def FluidWarmer {
    attribute targetTemperature : Celsius = 37.0;
    attribute maximumOutletTemperature : Celsius = 42.0;
    attribute minimumOperatingFlow : MilliliterPerMinute = 10.0;
    attribute maximumOperatingFlow : MilliliterPerMinute = 500.0;
    attribute maximumHeaterPower : Watt = 350.0;
    attribute operating : Boolean = false;

    port fluidIn : FluidInletPort;
    port fluidOut : FluidOutletPort;
    port powerIn : PowerInputPort;

    part inletLine : InletFluidPath;
    part heatingChamber : HeatingChamber;
    part outletLine : OutletFluidPath;
    part heater : ResistiveHeater;
    part controller : TemperatureController;
    part inletTemperatureSensor : TemperatureSensor;
    part outletTemperatureSensor : TemperatureSensor;
    part flowSensor : FlowSensor;
    part overTemperatureCutoff : SafetyCutoff;
    part enclosure : InsulatedEnclosure;

    connect fluidIn to inletLine.inlet;
    connect inletLine.outlet to heatingChamber.fluidIn;
    connect heatingChamber.fluidOut to outletLine.inlet;
    connect outletLine.outlet to fluidOut;

    connect powerIn to controller.powerInput;
    connect controller.heaterCommand to heater.controlInput;
    connect heater.heatOutput to heatingChamber.heatInput;

    connect inletTemperatureSensor.sensedFluid to inletLine.measurementPoint;
    connect outletTemperatureSensor.sensedFluid to outletLine.measurementPoint;
    connect flowSensor.sensedFluid to inletLine.measurementPoint;

    connect inletTemperatureSensor.sensorOutput to controller.inletTemperatureInput;
    connect outletTemperatureSensor.sensorOutput to controller.outletTemperatureInput;
    connect flowSensor.flowOutput to controller.flowInput;
    connect controller.safetyCommand to overTemperatureCutoff.controlInput;
    connect overTemperatureCutoff.protectedPower to heater.controlInput;

    perform warmFluid : WarmFluidAction;
    exhibit states : FluidWarmerStateMachine;
  }

  part def InletFluidPath {
    attribute internalVolume : Real = 12.0;
    attribute maximumPressure : Pascal = 300000.0;

    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;
    port measurementPoint : FluidOutletPort;
  }

  part def OutletFluidPath {
    attribute internalVolume : Real = 10.0;
    attribute maximumPressure : Pascal = 300000.0;

    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;
    port measurementPoint : FluidOutletPort;
  }

  part def HeatingChamber {
    attribute chamberVolume : Real = 25.0;
    attribute heatTransferEfficiency : Real = 0.88;
    attribute maximumWallTemperature : Celsius = 55.0;

    port fluidIn : FluidInletPort;
    port fluidOut : FluidOutletPort;
    port heatInput : HeatTransferPort;

    constraint heatBalance {
      in inletTemperature : Celsius;
      in outletTemperature : Celsius;
      in flowRate : MilliliterPerMinute;
      in heaterPower : Watt;
      in efficiency : Real;
      outletTemperature >= inletTemperature;
      heaterPower >= 0.0;
      efficiency <= 1.0;
    }
  }

  part def ResistiveHeater {
    attribute ratedPower : Watt = 350.0;
    attribute resistance : Real = 41.0;
    attribute enabled : Boolean = false;
    attribute commandedPower : Watt = 0.0;

    port controlInput : ControlPort;
    port heatOutput : HeatTransferPort;

    action generateHeat {
      in command : ControlSignal;
      out heat : ThermalEnergy;
      first start;
      then setPower;
      then emitHeat;
      action setPower {
        commandedPower = command.requestedPower;
        enabled = command.enableHeating;
      }
      action emitHeat {
        heat.heatFlow = commandedPower;
      }
    }
  }

  part def TemperatureController {
    attribute proportionalGain : Real = 18.0;
    attribute integralGain : Real = 0.8;
    attribute outletTemperatureSetpoint : Celsius = 37.0;
    attribute heaterPowerLimit : Watt = 350.0;
    attribute computedPower : Watt = 0.0;
    attribute heatingEnabled : Boolean = false;

    port powerInput : PowerInputPort;
    port inletTemperatureInput : SensorOutputPort;
    port outletTemperatureInput : SensorOutputPort;
    port flowInput : SensorOutputPort;
    port heaterCommand : ControlPort;
    port safetyCommand : ControlPort;

    action regulateTemperature {
      in inletReading : TemperatureReading;
      in outletReading : TemperatureReading;
      in flowReading : TemperatureReading;
      out command : ControlSignal;

      first validateInputs;
      then computeThermalDemand;
      then limitCommand;
      then issueCommand;

      action validateInputs {
        heatingEnabled = inletReading.valid and outletReading.valid and flowReading.valid;
      }

      action computeThermalDemand {
        computedPower = proportionalGain * (outletTemperatureSetpoint - outletReading.measuredTemperature);
      }

      action limitCommand {
        if computedPower > heaterPowerLimit then computedPower = heaterPowerLimit;
        if computedPower < 0.0 then computedPower = 0.0;
      }

      action issueCommand {
        command.requestedPower = computedPower;
        command.enableHeating = heatingEnabled;
      }
    }
  }

  part def TemperatureSensor {
    attribute measurementRangeLow : Celsius = 0.0;
    attribute measurementRangeHigh : Celsius = 60.0;
    attribute accuracy : Celsius = 0.3;
    attribute samplePeriod : Second = 0.25;

    port sensedFluid : FluidOutletPort;
    port sensorOutput : SensorOutputPort;

    action measureTemperature {
      in fluid : Fluid;
      out reading : TemperatureReading;
      first sample;
      action sample {
        reading.measuredTemperature = fluid.temperature;
        reading.valid = fluid.temperature >= measurementRangeLow and fluid.temperature <= measurementRangeHigh;
      }
    }
  }

  part def FlowSensor {
    attribute minimumMeasuredFlow : MilliliterPerMinute = 0.0;
    attribute maximumMeasuredFlow : MilliliterPerMinute = 800.0;
    attribute accuracyPercent : Real = 5.0;

    port sensedFluid : FluidOutletPort;
    port flowOutput : SensorOutputPort;

    action measureFlow {
      in fluid : Fluid;
      out reading : TemperatureReading;
      first sampleFlow;
      action sampleFlow {
        reading.measuredTemperature = fluid.flowRate;
        reading.valid = fluid.flowRate >= minimumMeasuredFlow and fluid.flowRate <= maximumMeasuredFlow;
      }
    }
  }

  part def SafetyCutoff {
    attribute tripTemperature : Celsius = 42.0;
    attribute resetTemperature : Celsius = 39.0;
    attribute tripped : Boolean = false;

    port controlInput : ControlPort;
    port protectedPower : ControlPort;

    action protectPatient {
      in outletReading : TemperatureReading;
      in incomingCommand : ControlSignal;
      out protectedCommand : ControlSignal;

      first evaluateTemperature;
      then passOrBlockPower;

      action evaluateTemperature {
        if outletReading.measuredTemperature >= tripTemperature then tripped = true;
        if outletReading.measuredTemperature <= resetTemperature then tripped = false;
      }

      action passOrBlockPower {
        protectedCommand.requestedPower = if tripped then 0.0 else incomingCommand.requestedPower;
        protectedCommand.enableHeating = incomingCommand.enableHeating and not tripped;
      }
    }
  }

  part def InsulatedEnclosure {
    attribute externalSurfaceMaximumTemperature : Celsius = 45.0;
    attribute ingressProtectionRating : String = "IP22";
    attribute thermalLossCoefficient : Real = 0.12;
  }

  action def WarmFluidAction {
    in coldFluid : Fluid;
    in electricalPower : ElectricalPower;
    out warmedFluid : Fluid;

    objective {
      doc /* Raise incoming fluid temperature toward a controlled target before delivery while preserving continuous flow and preventing unsafe outlet temperatures. */
    }

    first acceptFluid;
    then senseInitialConditions;
    then regulateHeaterPower;
    then transferHeatToFluid;
    then verifyOutletTemperature;
    then deliverWarmedFluid;

    action acceptFluid {
      coldFluid.flowRate >= 10.0;
    }

    action senseInitialConditions {
      coldFluid.temperature >= 0.0;
    }

    action regulateHeaterPower {
      electricalPower.power <= 350.0;
    }

    action transferHeatToFluid {
      warmedFluid.temperature >= coldFluid.temperature;
      warmedFluid.flowRate = coldFluid.flowRate;
      warmedFluid.pressure <= coldFluid.pressure;
    }

    action verifyOutletTemperature {
      warmedFluid.temperature <= 42.0;
    }

    action deliverWarmedFluid {
      warmedFluid.temperature >= 35.0 and warmedFluid.temperature <= 42.0;
    }
  }

  state def FluidWarmerStateMachine {
    entry; then Off;

    state Off {
      entry action {
        operating = false;
      }
    }

    transition Off_to_SelfTest
      first Off
      accept PowerApplied
      then SelfTest;

    state SelfTest {
      entry action {
        operating = false;
      }
    }

    transition SelfTest_to_Ready
      first SelfTest
      accept SelfTestPassed
      then Ready;

    transition SelfTest_to_Fault
      first SelfTest
      accept SelfTestFailed
      then Fault;

    state Ready {
      entry action {
        operating = false;
      }
    }

    transition Ready_to_Warming
      first Ready
      accept FlowDetected
      then Warming;

    state Warming {
      entry action {
        operating = true;
      }
    }

    transition Warming_to_Ready
      first Warming
      accept FlowStopped
      then Ready;

    transition Warming_to_OverTemperature
      first Warming
      accept OutletTemperatureHigh
      then OverTemperature;

    state OverTemperature {
      entry action {
        operating = false;
      }
    }

    transition OverTemperature_to_Ready
      first OverTemperature
      accept TemperatureRecovered
      then Ready;

    state Fault {
      entry action {
        operating = false;
      }
    }

    transition Fault_to_Off
      first Fault
      accept PowerRemoved
      then Off;
  }

  requirement def WarmFluidPrimaryFunction {
    subject warmer : FluidWarmer;

    doc /* The fluid warmer shall raise the temperature of incoming fluid to a controlled delivery range near body temperature while maintaining fluid flow from inlet to outlet. */

    require constraint {
      warmer.targetTemperature == 37.0;
      warmer.maximumOutletTemperature <= 42.0;
    }
  }

  requirement def OutletTemperatureSafety {
    subject fluid : Fluid;

    doc /* Delivered fluid shall not exceed the safe maximum outlet temperature. */

    require constraint {
      fluid.temperature <= 42.0;
    }
  }

  requirement def ContinuousFlowCompatibility {
    subject fluid : Fluid;

    doc /* The warmer shall support clinically useful continuous flow within its specified operating range. */

    require constraint {
      fluid.flowRate >= 10.0 and fluid.flowRate <= 500.0;
    }
  }

  requirement def ElectricalPowerLimit {
    subject power : ElectricalPower;

    doc /* The warmer shall limit electrical heating demand to the rated heater capacity. */

    require constraint {
      power.power <= 350.0;
      power.voltage <= 120.0;
      power.current <= 5.0;
    }
  }

  requirement def SensorValidityRequirement {
    subject reading : TemperatureReading;

    doc /* Temperature control shall use valid sensor readings before enabling heater output. */

    require constraint {
      reading.valid == true;
    }
  }

  part fluidWarmerSystem : FluidWarmer {
    attribute targetTemperature = 37.0;
    attribute maximumOutletTemperature = 42.0;
    attribute minimumOperatingFlow = 10.0;
    attribute maximumOperatingFlow = 500.0;
    attribute maximumHeaterPower = 350.0;
  }

  satisfy fluidWarmerSystem by WarmFluidPrimaryFunction;
  satisfy fluidWarmerSystem by OutletTemperatureSafety;
  satisfy fluidWarmerSystem by ContinuousFlowCompatibility;
  satisfy fluidWarmerSystem by ElectricalPowerLimit;
  satisfy fluidWarmerSystem by SensorValidityRequirement;
}