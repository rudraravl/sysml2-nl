package PumpingSubsystem_SinusoidalPump {

  import ScalarValues::*;
  import SI::*;

  attribute def Pressure :> Real {
    unit = "Pa";
  }

  attribute def FlowRate :> Real {
    unit = "m^3/s";
  }

  attribute def Volume :> Real {
    unit = "m^3";
  }

  attribute def Density :> Real {
    unit = "kg/m^3";
  }

  attribute def Frequency :> Real {
    unit = "Hz";
  }

  attribute def AngularFrequency :> Real {
    unit = "rad/s";
  }

  attribute def Time :> Real {
    unit = "s";
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

  attribute def Temperature :> Real {
    unit = "K";
  }

  attribute def Efficiency :> Real {
    unit = "1";
  }

  item def WorkingFluid {
    attribute density : Density;
    attribute temperature : Temperature;
    attribute vaporPressure : Pressure;
    attribute contaminationLevel : Real;
  }

  item def ElectricalEnergy {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute power : Power;
  }

  port def FluidPort {
    inout fluid : WorkingFluid;
    attribute pressure : Pressure;
    attribute flowRate : FlowRate;
  }

  port def ElectricalPowerPort {
    in energy : ElectricalEnergy;
    attribute supplyVoltage : Voltage;
    attribute supplyCurrent : Current;
  }

  port def ControlPort {
    in commandedEnable : Boolean;
    in commandedFrequency : Frequency;
    in commandedMeanFlow : FlowRate;
    in commandedAmplitude : FlowRate;
    out actualFrequency : Frequency;
    out healthOk : Boolean;
  }

  port def SensorSignalPort {
    out pressureSignal : Pressure;
    out flowSignal : FlowRate;
    out temperatureSignal : Temperature;
    out faultSignal : Boolean;
  }

  action def GenerateSinusoidalFlow {
    in meanFlow : FlowRate;
    in amplitude : FlowRate;
    in frequency : Frequency;
    in phase : Real;
    in elapsedTime : Time;
    out instantaneousFlow : FlowRate;

    attribute omega : AngularFrequency;

    assign omega := 6.28318530718 * frequency;
    assign instantaneousFlow := meanFlow + amplitude * sin(omega * elapsedTime + phase);
  }

  action def RegulatePumpCommand {
    in targetMeanFlow : FlowRate;
    in measuredFlow : FlowRate;
    in measuredPressure : Pressure;
    in maxPressure : Pressure;
    out enabled : Boolean;
    out correctedMeanFlow : FlowRate;

    if measuredPressure >= maxPressure {
      assign enabled := false;
      assign correctedMeanFlow := 0.0;
    } else {
      assign enabled := true;
      assign correctedMeanFlow := targetMeanFlow;
    }
  }

  action def DetectFaults {
    in inletPressure : Pressure;
    in outletPressure : Pressure;
    in motorCurrent : Current;
    in fluidTemperature : Temperature;
    in minimumInletPressure : Pressure;
    in maximumOutletPressure : Pressure;
    in maximumMotorCurrent : Current;
    in maximumFluidTemperature : Temperature;
    out faultDetected : Boolean;

    assign faultDetected :=
      inletPressure < minimumInletPressure or
      outletPressure > maximumOutletPressure or
      motorCurrent > maximumMotorCurrent or
      fluidTemperature > maximumFluidTemperature;
  }

  part def Reservoir {
    port outlet : FluidPort;

    attribute storedVolume : Volume = 0.025;
    attribute nominalPressure : Pressure = 101325.0;
    attribute fluidDensity : Density = 997.0;
    attribute fluidTemperature : Temperature = 293.15;
  }

  part def InletFilter {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute particleRatingMicron : Real = 25.0;
    attribute pressureDropAtNominalFlow : Pressure = 3500.0;
    attribute clogged : Boolean = false;
  }

  part def CheckValve {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute crackingPressure : Pressure = 5000.0;
    attribute reverseLeakageFlow : FlowRate = 0.00000002;
    attribute open : Boolean;
  }

  part def SinusoidalPump {
    port inlet : FluidPort;
    port outlet : FluidPort;
    port powerIn : ElectricalPowerPort;
    port control : ControlPort;

    attribute meanFlow : FlowRate = 0.0012;
    attribute amplitude : FlowRate = 0.00045;
    attribute frequency : Frequency = 2.0;
    attribute phase : Real = 0.0;
    attribute elapsedTime : Time;
    attribute instantaneousFlow : FlowRate;
    attribute inletMinimumPressure : Pressure = 80000.0;
    attribute outletMaximumPressure : Pressure = 650000.0;
    attribute hydraulicEfficiency : Efficiency = 0.72;
    attribute electricalEfficiency : Efficiency = 0.88;
    attribute enabled : Boolean = false;
    attribute faultLatched : Boolean = false;

    perform flowGeneration : GenerateSinusoidalFlow {
      in meanFlow = meanFlow;
      in amplitude = amplitude;
      in frequency = frequency;
      in phase = phase;
      in elapsedTime = elapsedTime;
      out instantaneousFlow = instantaneousFlow;
    }

    state machine PumpOperatingState {
      state Off;
      state Priming;
      state Running;
      state Faulted;

      initial then Off;

      transition Off_to_Priming
        first Off
        accept control.commandedEnable
        if control.commandedEnable and not faultLatched
        then Priming;

      transition Priming_to_Running
        first Priming
        if inlet.pressure >= inletMinimumPressure
        then Running;

      transition Running_to_Off
        first Running
        accept control.commandedEnable
        if not control.commandedEnable
        then Off;

      transition Running_to_Faulted
        first Running
        if inlet.pressure < inletMinimumPressure or outlet.pressure > outletMaximumPressure
        then Faulted;

      transition Priming_to_Faulted
        first Priming
        if outlet.pressure > outletMaximumPressure
        then Faulted;

      transition Faulted_to_Off
        first Faulted
        accept control.commandedEnable
        if not control.commandedEnable
        then Off;

      entry action Off {
        assign enabled := false;
        assign instantaneousFlow := 0.0;
      }

      entry action Priming {
        assign enabled := true;
        assign frequency := 0.5;
      }

      entry action Running {
        assign enabled := true;
        assign frequency := control.commandedFrequency;
        assign meanFlow := control.commandedMeanFlow;
        assign amplitude := control.commandedAmplitude;
      }

      entry action Faulted {
        assign enabled := false;
        assign faultLatched := true;
        assign instantaneousFlow := 0.0;
      }
    }
  }

  part def PulsationDampener {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute gasPrechargePressure : Pressure = 250000.0;
    attribute internalVolume : Volume = 0.0015;
    attribute dampingRatio : Real = 0.65;
  }

  part def OutletPressureSensor {
    port sensedFluid : FluidPort;
    port signal : SensorSignalPort;

    attribute rangeMinimum : Pressure = 0.0;
    attribute rangeMaximum : Pressure = 1000000.0;
    attribute accuracyPercentFullScale : Real = 0.5;
  }

  part def FlowSensor {
    port sensedFluid : FluidPort;
    port signal : SensorSignalPort;

    attribute rangeMinimum : FlowRate = 0.0;
    attribute rangeMaximum : FlowRate = 0.003;
    attribute accuracyPercentReading : Real = 1.0;
  }

  part def MotorController {
    port powerInput : ElectricalPowerPort;
    port pumpControl : ControlPort;
    port pressureFeedback : SensorSignalPort;
    port flowFeedback : SensorSignalPort;

    attribute targetMeanFlow : FlowRate = 0.0012;
    attribute targetAmplitude : FlowRate = 0.00045;
    attribute targetFrequency : Frequency = 2.0;
    attribute pressureLimit : Pressure = 650000.0;
    attribute enabledCommand : Boolean;
    attribute healthOk : Boolean;

    perform commandRegulation : RegulatePumpCommand {
      in targetMeanFlow = targetMeanFlow;
      in measuredFlow = flowFeedback.flowSignal;
      in measuredPressure = pressureFeedback.pressureSignal;
      in maxPressure = pressureLimit;
      out enabled = enabledCommand;
      out correctedMeanFlow = pumpControl.commandedMeanFlow;
    }
  }

  part def DischargeLine {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute internalVolume : Volume = 0.0008;
    attribute nominalPressureDrop : Pressure = 12000.0;
    attribute maximumWorkingPressure : Pressure = 750000.0;
  }

  part def PumpingSubsystem {
    port suctionPort : FluidPort;
    port dischargePort : FluidPort;
    port electricalInput : ElectricalPowerPort;
    port commandInput : ControlPort;
    port telemetryOutput : SensorSignalPort;

    part reservoir : Reservoir;
    part inletFilter : InletFilter;
    part inletCheckValve : CheckValve;
    part pump : SinusoidalPump;
    part dampener : PulsationDampener;
    part dischargeCheckValve : CheckValve;
    part pressureSensor : OutletPressureSensor;
    part flowSensor : FlowSensor;
    part controller : MotorController;
    part dischargeLine : DischargeLine;

    connect suctionPort to reservoir.outlet;
    connect reservoir.outlet to inletFilter.inlet;
    connect inletFilter.outlet to inletCheckValve.inlet;
    connect inletCheckValve.outlet to pump.inlet;
    connect pump.outlet to dampener.inlet;
    connect dampener.outlet to dischargeCheckValve.inlet;
    connect dischargeCheckValve.outlet to dischargeLine.inlet;
    connect dischargeLine.outlet to dischargePort;

    connect electricalInput to controller.powerInput;
    connect electricalInput to pump.powerIn;
    connect commandInput to controller.pumpControl;
    connect controller.pumpControl to pump.control;

    connect dischargeLine.inlet to pressureSensor.sensedFluid;
    connect dischargeLine.outlet to flowSensor.sensedFluid;
    connect pressureSensor.signal to controller.pressureFeedback;
    connect flowSensor.signal to controller.flowFeedback;
    connect pressureSensor.signal to telemetryOutput;
    connect flowSensor.signal to telemetryOutput;

    attribute nominalMeanFlow : FlowRate = 0.0012;
    attribute nominalFlowAmplitude : FlowRate = 0.00045;
    attribute nominalFrequency : Frequency = 2.0;
    attribute minimumNetPositiveSuctionPressure : Pressure = 80000.0;
    attribute maximumDischargePressure : Pressure = 650000.0;
    attribute maximumFluidTemperature : Temperature = 333.15;
    attribute supplyVoltage : Voltage = 48.0;
    attribute maximumSupplyCurrent : Current = 18.0;
  }

  requirement def SinusoidalFlowRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.pump.instantaneousFlow ==
      subsystem.pump.meanFlow +
      subsystem.pump.amplitude *
      sin(6.28318530718 * subsystem.pump.frequency * subsystem.pump.elapsedTime + subsystem.pump.phase)
    }
  }

  requirement def PositiveFlowRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.pump.meanFlow > subsystem.pump.amplitude
    }
  }

  requirement def PressureProtectionRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.pump.outlet.pressure <= subsystem.maximumDischargePressure
    }
  }

  requirement def SuctionPressureRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.pump.inlet.pressure >= subsystem.minimumNetPositiveSuctionPressure
    }
  }

  requirement def ElectricalPowerRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.electricalInput.supplyVoltage == subsystem.supplyVoltage and
      subsystem.electricalInput.supplyCurrent <= subsystem.maximumSupplyCurrent
    }
  }

  requirement def TelemetryRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.telemetryOutput.pressureSignal >= 0.0 and
      subsystem.telemetryOutput.flowSignal >= 0.0
    }
  }

  satisfy SinusoidalFlowRequirement by PumpingSubsystem::pump;
  satisfy PositiveFlowRequirement by PumpingSubsystem::pump;
  satisfy PressureProtectionRequirement by PumpingSubsystem::controller;
  satisfy PressureProtectionRequirement by PumpingSubsystem::pump;
  satisfy SuctionPressureRequirement by PumpingSubsystem::inletFilter;
  satisfy ElectricalPowerRequirement by PumpingSubsystem::controller;
  satisfy ElectricalPowerRequirement by PumpingSubsystem::pump;
  satisfy TelemetryRequirement by PumpingSubsystem::pressureSensor;
  satisfy TelemetryRequirement by PumpingSubsystem::flowSensor;
}