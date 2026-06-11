package ElectroosmoticPumpingSubsystemModel {

  import ScalarValues::*;
  import SI::*;

  item def WorkingFluid {
    attribute dynamicViscosity : Viscosity;
    attribute density : Density;
    attribute electricalConductivity : Conductivity;
    attribute relativePermittivity : Real;
    attribute pH : Real;
    attribute temperature : Temperature;
  }

  item def ElectricalEnergy {
    attribute voltage : Voltage;
    attribute current : ElectricCurrent;
    attribute power : Power;
  }

  item def Heat {
    attribute heatFlowRate : Power;
    attribute temperature : Temperature;
  }

  attribute def FlowRate :> Real {
    unit = "uL/min";
  }

  attribute def Pressure :> Real {
    unit = "kPa";
  }

  attribute def Voltage :> Real {
    unit = "V";
  }

  attribute def ElectricCurrent :> Real {
    unit = "mA";
  }

  attribute def Power :> Real {
    unit = "W";
  }

  attribute def Temperature :> Real {
    unit = "degC";
  }

  attribute def Density :> Real {
    unit = "kg/m^3";
  }

  attribute def Viscosity :> Real {
    unit = "mPa*s";
  }

  attribute def Conductivity :> Real {
    unit = "mS/cm";
  }

  attribute def Volume :> Real {
    unit = "mL";
  }

  attribute def Resistance :> Real {
    unit = "MOhm";
  }

  attribute def Time :> Real {
    unit = "s";
  }

  enum def PumpMode {
    enum idle;
    enum priming;
    enum pumping;
    enum flushing;
    enum faulted;
    enum shutdown;
  }

  enum def FaultCode {
    enum noFault;
    enum dryInlet;
    enum blockedOutlet;
    enum overCurrent;
    enum overTemperature;
    enum leakageDetected;
    enum conductivityOutOfRange;
    enum voltageSupplyFault;
  }

  port def FluidPort {
    inout item fluid : WorkingFluid;
    attribute pressure : Pressure;
    attribute flowRate : FlowRate;
  }

  port def ElectricalPowerPort {
    in item energy : ElectricalEnergy;
    attribute supplyVoltage : Voltage;
    attribute supplyCurrent : ElectricCurrent;
  }

  port def ThermalPort {
    out item heat : Heat;
    attribute caseTemperature : Temperature;
  }

  port def SignalPort {
    inout attribute value : Real;
  }

  part def FluidReservoir {
    attribute capacity : Volume = 25.0;
    attribute currentVolume : Volume;
    port outlet : FluidPort;
  }

  part def OutletLoad {
    attribute requiredDeliveryPressure : Pressure;
    attribute receivedVolume : Volume;
    port inlet : FluidPort;
  }

  part def HighVoltageDriver {
    attribute commandVoltage : Voltage;
    attribute measuredVoltage : Voltage;
    attribute measuredCurrent : ElectricCurrent;
    attribute maximumVoltage : Voltage = 1500.0;
    attribute maximumCurrent : ElectricCurrent = 2.0;
    port dcInput : ElectricalPowerPort;
    port hvOutput : ElectricalPowerPort;
    port voltageCommand : SignalPort;
    port currentFeedback : SignalPort;

    action def RegulateVoltage {
      in attribute targetVoltage : Voltage;
      out attribute deliveredVoltage : Voltage;
      out attribute deliveredCurrent : ElectricCurrent;
    }
  }

  part def ElectroosmoticPumpCore {
    attribute zetaPotential : Voltage = -0.075;
    attribute porousMediaHydraulicResistance : Resistance = 18.0;
    attribute electrodeSpacing : Real = 0.012;
    attribute channelCrossSectionArea : Real = 2.5e-6;
    attribute nominalFlowRate : FlowRate = 80.0;
    attribute maximumPressureRise : Pressure = 250.0;
    attribute minimumFluidConductivity : Conductivity = 0.05;
    attribute maximumFluidConductivity : Conductivity = 5.0;

    port inlet : FluidPort;
    port outlet : FluidPort;
    port electricalInput : ElectricalPowerPort;
    port thermalOutput : ThermalPort;

    flow of WorkingFluid from inlet to outlet;
    flow of ElectricalEnergy from electricalInput to thermalOutput;

    action def GenerateElectroosmoticFlow {
      in item incomingFluid : WorkingFluid;
      in attribute appliedVoltage : Voltage;
      out item deliveredFluid : WorkingFluid;
      out attribute generatedFlowRate : FlowRate;
      out attribute pressureRise : Pressure;
    }
  }

  part def FlowSensor {
    attribute measuredFlowRate : FlowRate;
    attribute accuracy : Real = 0.03;
    port inlet : FluidPort;
    port outlet : FluidPort;
    port flowSignal : SignalPort;

    flow of WorkingFluid from inlet to outlet;
  }

  part def PressureSensor {
    attribute measuredPressure : Pressure;
    attribute maximumPressure : Pressure = 300.0;
    port pressureTap : FluidPort;
    port pressureSignal : SignalPort;
  }

  part def TemperatureSensor {
    attribute measuredTemperature : Temperature;
    attribute maximumRatedTemperature : Temperature = 60.0;
    port thermalTap : ThermalPort;
    port temperatureSignal : SignalPort;
  }

  part def LeakDetector {
    attribute leakageDetected : Boolean = false;
    port leakSignal : SignalPort;
  }

  part def CheckValve {
    attribute crackingPressure : Pressure = 2.0;
    attribute reverseLeakageRate : FlowRate = 0.1;
    port inlet : FluidPort;
    port outlet : FluidPort;

    flow of WorkingFluid from inlet to outlet;
  }

  part def Controller {
    attribute requestedFlowRate : FlowRate = 80.0;
    attribute commandedVoltage : Voltage;
    attribute mode : PumpMode = PumpMode::idle;
    attribute activeFault : FaultCode = FaultCode::noFault;
    attribute startupPrimeTime : Time = 5.0;
    attribute maximumTemperature : Temperature = 55.0;
    attribute maximumOutletPressure : Pressure = 230.0;

    port flowFeedback : SignalPort;
    port pressureFeedback : SignalPort;
    port temperatureFeedback : SignalPort;
    port leakFeedback : SignalPort;
    port voltageCommand : SignalPort;

    action def ComputeVoltageCommand {
      in attribute desiredFlow : FlowRate;
      in attribute measuredFlow : FlowRate;
      in attribute measuredPressure : Pressure;
      in attribute measuredTemperature : Temperature;
      out attribute voltageCommand : Voltage;
    }

    action def DetectFaults {
      in attribute measuredFlow : FlowRate;
      in attribute measuredPressure : Pressure;
      in attribute measuredTemperature : Temperature;
      in attribute leakageFlag : Boolean;
      out attribute fault : FaultCode;
    }

    state def PumpControlStateMachine {
      state idle;
      state priming;
      state pumping;
      state flushing;
      state faulted;
      state shutdown;

      transition idle_to_priming
        first idle
        then priming
        accept StartCommand;

      transition priming_to_pumping
        first priming
        then pumping
        accept PrimeComplete;

      transition pumping_to_flushing
        first pumping
        then flushing
        accept FlushCommand;

      transition pumping_to_faulted
        first pumping
        then faulted
        accept FaultDetected;

      transition priming_to_faulted
        first priming
        then faulted
        accept FaultDetected;

      transition flushing_to_idle
        first flushing
        then idle
        accept FlushComplete;

      transition faulted_to_shutdown
        first faulted
        then shutdown
        accept ShutdownCommand;

      transition shutdown_to_idle
        first shutdown
        then idle
        accept ResetCommand;
    }

    exhibit state controlState : PumpControlStateMachine;
  }

  part def ElectroosmoticPumpingSubsystem {
    attribute targetFlowRate : FlowRate = 80.0;
    attribute deliveredFlowRate : FlowRate;
    attribute inletPressure : Pressure;
    attribute outletPressure : Pressure;
    attribute appliedVoltage : Voltage;
    attribute operatingTemperature : Temperature;
    attribute totalDeliveredVolume : Volume;
    attribute subsystemMode : PumpMode;
    attribute subsystemFault : FaultCode;

    port fluidInlet : FluidPort;
    port fluidOutlet : FluidPort;
    port electricalSupply : ElectricalPowerPort;
    port wasteHeat : ThermalPort;
    port flowCommand : SignalPort;
    port statusOutput : SignalPort;

    part inletReservoir : FluidReservoir {
      attribute capacity = 25.0;
    }

    part inletCheckValve : CheckValve {
      attribute crackingPressure = 1.5;
    }

    part eopCore : ElectroosmoticPumpCore {
      attribute nominalFlowRate = 80.0;
      attribute maximumPressureRise = 250.0;
    }

    part outletCheckValve : CheckValve {
      attribute crackingPressure = 2.0;
    }

    part flowMeter : FlowSensor;
    part outletPressureSensor : PressureSensor;
    part caseTemperatureSensor : TemperatureSensor;
    part leakDetector : LeakDetector;
    part hvDriver : HighVoltageDriver;
    part controller : Controller;
    part load : OutletLoad;

    connect fluidInlet to inletReservoir.outlet;
    connect inletReservoir.outlet to inletCheckValve.inlet;
    connect inletCheckValve.outlet to eopCore.inlet;
    connect eopCore.outlet to outletCheckValve.inlet;
    connect outletCheckValve.outlet to flowMeter.inlet;
    connect flowMeter.outlet to fluidOutlet;
    connect fluidOutlet to load.inlet;

    connect electricalSupply to hvDriver.dcInput;
    connect hvDriver.hvOutput to eopCore.electricalInput;
    connect eopCore.thermalOutput to wasteHeat;
    connect eopCore.thermalOutput to caseTemperatureSensor.thermalTap;

    connect flowMeter.flowSignal to controller.flowFeedback;
    connect outletPressureSensor.pressureSignal to controller.pressureFeedback;
    connect caseTemperatureSensor.temperatureSignal to controller.temperatureFeedback;
    connect leakDetector.leakSignal to controller.leakFeedback;
    connect controller.voltageCommand to hvDriver.voltageCommand;

    flow of WorkingFluid from fluidInlet to fluidOutlet;
    flow of ElectricalEnergy from electricalSupply to eopCore.electricalInput;
    flow of Heat from eopCore.thermalOutput to wasteHeat;

    action def PrimeSubsystem {
      out attribute primed : Boolean;
    }

    action def PumpAtCommandedFlow {
      in attribute commandedFlow : FlowRate;
      out attribute actualFlow : FlowRate;
      out attribute deliveredVolume : Volume;
    }

    action def FlushSubsystem {
      in attribute flushDuration : Time;
      out attribute flushedVolume : Volume;
    }

    action def StopSubsystem {
      out attribute voltageRemoved : Boolean;
    }
  }

  requirement def FlowDeliveryRequirement {
    subject subsystem : ElectroosmoticPumpingSubsystem;

    require constraint {
      subsystem.deliveredFlowRate >= 70.0 and
      subsystem.deliveredFlowRate <= 90.0
    }
  }

  requirement def PressureCapabilityRequirement {
    subject subsystem : ElectroosmoticPumpingSubsystem;

    require constraint {
      subsystem.outletPressure - subsystem.inletPressure >= 200.0
    }
  }

  requirement def VoltageLimitRequirement {
    subject subsystem : ElectroosmoticPumpingSubsystem;

    require constraint {
      subsystem.appliedVoltage <= 1500.0
    }
  }

  requirement def TemperatureLimitRequirement {
    subject subsystem : ElectroosmoticPumpingSubsystem;

    require constraint {
      subsystem.operatingTemperature <= 55.0
    }
  }

  requirement def LeakageRequirement {
    subject subsystem : ElectroosmoticPumpingSubsystem;

    require constraint {
      subsystem.subsystemFault != FaultCode::leakageDetected
    }
  }

  requirement def FaultResponseRequirement {
    subject subsystem : ElectroosmoticPumpingSubsystem;

    require constraint {
      subsystem.subsystemFault == FaultCode::noFault or
      subsystem.subsystemMode == PumpMode::faulted or
      subsystem.subsystemMode == PumpMode::shutdown
    }
  }

  requirement def ConductivityCompatibilityRequirement {
    subject pump : ElectroosmoticPumpCore;

    require constraint {
      pump.minimumFluidConductivity <= pump.inlet.fluid.electricalConductivity and
      pump.inlet.fluid.electricalConductivity <= pump.maximumFluidConductivity
    }
  }

  part electroosmoticPumpingSubsystem : ElectroosmoticPumpingSubsystem;

  satisfy FlowDeliveryRequirement by electroosmoticPumpingSubsystem;
  satisfy PressureCapabilityRequirement by electroosmoticPumpingSubsystem;
  satisfy VoltageLimitRequirement by electroosmoticPumpingSubsystem;
  satisfy TemperatureLimitRequirement by electroosmoticPumpingSubsystem;
  satisfy LeakageRequirement by electroosmoticPumpingSubsystem;
  satisfy FaultResponseRequirement by electroosmoticPumpingSubsystem;
  satisfy ConductivityCompatibilityRequirement by electroosmoticPumpingSubsystem.eopCore;
}