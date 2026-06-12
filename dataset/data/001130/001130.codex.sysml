package MOSFETBasedSwitchingSystem {

  attribute def Voltage {
    attribute value : Real;
    attribute unit : String = "V";
  }

  attribute def Current {
    attribute value : Real;
    attribute unit : String = "A";
  }

  attribute def Resistance {
    attribute value : Real;
    attribute unit : String = "ohm";
  }

  attribute def Power {
    attribute value : Real;
    attribute unit : String = "W";
  }

  attribute def Temperature {
    attribute value : Real;
    attribute unit : String = "degC";
  }

  attribute def Time {
    attribute value : Real;
    attribute unit : String = "s";
  }

  item def ElectricPowerFlow {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute power : Power;
  }

  port def ElectricalTerminal {
    inout item flow : ElectricPowerFlow;
    attribute potential : Voltage;
    attribute terminalCurrent : Current;
  }

  port def ControlInput {
    in item gateCommand : Voltage;
  }

  port def ThermalPort {
    out item dissipatedHeat : Power;
    attribute junctionTemperature : Temperature;
  }

  part def DCSource {
    attribute nominalVoltage : Voltage;
    attribute maximumCurrent : Current;

    port positive : ElectricalTerminal;
    port negative : ElectricalTerminal;
  }

  part def ResistiveLoad {
    attribute loadResistance : Resistance;
    attribute ratedPower : Power;

    port highSide : ElectricalTerminal;
    port lowSide : ElectricalTerminal;
  }

  part def GateController {
    attribute lowCommandVoltage : Voltage;
    attribute highCommandVoltage : Voltage;
    attribute switchingPeriod : Time;

    port commandInput : ControlInput;
    port gateOutput : ElectricalTerminal;

    action def GenerateGateDrive {
      in desiredOnState : Boolean;
      out commandedGateVoltage : Voltage;
    }
  }

  part def NChannelMOSFET {
    attribute thresholdVoltage : Voltage;
    attribute maximumDrainSourceVoltage : Voltage;
    attribute maximumContinuousDrainCurrent : Current;
    attribute onResistance : Resistance;
    attribute offLeakageCurrent : Current;
    attribute gateInputResistance : Resistance;
    attribute junctionTemperatureLimit : Temperature;

    port gate : ElectricalTerminal;
    port drain : ElectricalTerminal;
    port source : ElectricalTerminal;
    port body : ElectricalTerminal;
    port thermal : ThermalPort;

    action def ControlDrainCurrent {
      in gateSourceVoltage : Voltage;
      in drainSourceVoltage : Voltage;
      out drainCurrent : Current;
      out conductionPowerLoss : Power;
    }

    state def OperatingMode {
      state Off;
      state TurningOn;
      state On;
      state TurningOff;
      state Fault;

      transition initial then Off;

      transition Off_To_TurningOn
        first Off
        then TurningOn
        if gate.potential.value - source.potential.value >= thresholdVoltage.value;

      transition TurningOn_To_On
        first TurningOn
        then On
        if drain.terminalCurrent.value > offLeakageCurrent.value;

      transition On_To_TurningOff
        first On
        then TurningOff
        if gate.potential.value - source.potential.value < thresholdVoltage.value;

      transition TurningOff_To_Off
        first TurningOff
        then Off
        if drain.terminalCurrent.value <= offLeakageCurrent.value;

      transition Any_To_Fault
        first Off
        then Fault
        if thermal.junctionTemperature.value >= junctionTemperatureLimit.value;
    }
  }

  part def HeatSink {
    attribute thermalDissipationCapacity : Power;
    attribute ambientTemperature : Temperature;

    port heatInput : ThermalPort;
  }

  part def MOSFETSwitchSubsystem {
    attribute commandedOn : Boolean;
    attribute switchingVoltage : Voltage;
    attribute loadCurrent : Current;
    attribute dissipatedPower : Power;

    part supply : DCSource {
      :>> nominalVoltage.value = 24.0;
      :>> maximumCurrent.value = 10.0;
    }

    part load : ResistiveLoad {
      :>> loadResistance.value = 12.0;
      :>> ratedPower.value = 50.0;
    }

    part controller : GateController {
      :>> lowCommandVoltage.value = 0.0;
      :>> highCommandVoltage.value = 10.0;
      :>> switchingPeriod.value = 0.001;
    }

    part switch : NChannelMOSFET {
      :>> thresholdVoltage.value = 3.0;
      :>> maximumDrainSourceVoltage.value = 60.0;
      :>> maximumContinuousDrainCurrent.value = 20.0;
      :>> onResistance.value = 0.025;
      :>> offLeakageCurrent.value = 0.000001;
      :>> gateInputResistance.value = 1000000.0;
      :>> junctionTemperatureLimit.value = 150.0;
    }

    part heatSink : HeatSink {
      :>> thermalDissipationCapacity.value = 5.0;
      :>> ambientTemperature.value = 25.0;
    }

    connect supply.positive to load.highSide;
    connect load.lowSide to switch.drain;
    connect switch.source to supply.negative;
    connect switch.body to switch.source;
    connect controller.gateOutput to switch.gate;
    connect switch.thermal to heatSink.heatInput;

    action def SwitchLoadCurrent {
      in requestedOn : Boolean;
      out deliveredLoadCurrent : Current;

      first controller.GenerateGateDrive;
      then switch.ControlDrainCurrent;
    }

    state def SystemOperatingState {
      state Disabled;
      state EnabledOff;
      state EnabledOn;
      state OverTemperatureShutdown;

      transition initial then Disabled;

      transition Disabled_To_EnabledOff
        first Disabled
        then EnabledOff
        if commandedOn == false;

      transition EnabledOff_To_EnabledOn
        first EnabledOff
        then EnabledOn
        if commandedOn == true;

      transition EnabledOn_To_EnabledOff
        first EnabledOn
        then EnabledOff
        if commandedOn == false;

      transition EnabledOn_To_OverTemperatureShutdown
        first EnabledOn
        then OverTemperatureShutdown
        if switch.thermal.junctionTemperature.value >= switch.junctionTemperatureLimit.value;

      transition OverTemperatureShutdown_To_EnabledOff
        first OverTemperatureShutdown
        then EnabledOff
        if switch.thermal.junctionTemperature.value < 120.0;
    }
  }

  requirement def PrimaryFunction {
    subject subsystem : MOSFETSwitchSubsystem;

    doc /* The MOSFET-based system shall use the gate voltage of an N-channel MOSFET to control current through a load, providing high-level electronic switching between an energized load state and a de-energized load state. */

    require constraint {
      subsystem.commandedOn == true implies
      subsystem.loadCurrent.value > 0.0
    }

    require constraint {
      subsystem.commandedOn == false implies
      subsystem.loadCurrent.value <= subsystem.switch.offLeakageCurrent.value
    }
  }

  requirement def VoltageControl {
    subject switch : NChannelMOSFET;

    require constraint {
      switch.gate.potential.value - switch.source.potential.value >= switch.thresholdVoltage.value implies
      switch.drain.terminalCurrent.value > switch.offLeakageCurrent.value
    }
  }

  requirement def SafeOperatingLimits {
    subject switch : NChannelMOSFET;

    require constraint {
      switch.drain.potential.value - switch.source.potential.value <= switch.maximumDrainSourceVoltage.value
    }

    require constraint {
      switch.drain.terminalCurrent.value <= switch.maximumContinuousDrainCurrent.value
    }

    require constraint {
      switch.thermal.junctionTemperature.value < switch.junctionTemperatureLimit.value
    }
  }

  requirement def LowLossOnState {
    subject switch : NChannelMOSFET;

    require constraint {
      switch.drain.terminalCurrent.value * switch.drain.terminalCurrent.value * switch.onResistance.value <= 5.0
    }
  }

  part mosfetControlledLoadSystem : MOSFETSwitchSubsystem;

  satisfy PrimaryFunction by mosfetControlledLoadSystem;
  satisfy VoltageControl by mosfetControlledLoadSystem.switch;
  satisfy SafeOperatingLimits by mosfetControlledLoadSystem.switch;
  satisfy LowLossOnState by mosfetControlledLoadSystem.switch;
}