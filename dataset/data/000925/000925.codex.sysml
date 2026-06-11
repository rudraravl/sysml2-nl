package PumpingSubsystemModel {

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

  attribute def Temperature :> Real {
    unit = "K";
  }

  attribute def RotationalSpeed :> Real {
    unit = "rpm";
  }

  attribute def ElectricVoltage :> Real {
    unit = "V";
  }

  attribute def ElectricCurrent :> Real {
    unit = "A";
  }

  attribute def Power :> Real {
    unit = "W";
  }

  attribute def TimeDuration :> Real {
    unit = "s";
  }

  attribute def Percent :> Real {
    unit = "%";
  }

  item def Fluid {
    attribute density : Real = 998.0;
    attribute dynamicViscosity : Real = 0.001;
    attribute temperature : Temperature;
    attribute contaminationLevel : Percent;
  }

  item def FluidCommand {
    attribute requestedFlowRate : FlowRate;
    attribute requestedVolume : Volume;
    attribute maxDispenseTime : TimeDuration;
  }

  item def PumpStatus {
    attribute actualFlowRate : FlowRate;
    attribute inletPressure : Pressure;
    attribute outletPressure : Pressure;
    attribute motorSpeed : RotationalSpeed;
    attribute dispensedVolume : Volume;
    attribute faultActive : Boolean;
    attribute ready : Boolean;
  }

  item def ElectricalPower {
    attribute voltage : ElectricVoltage;
    attribute current : ElectricCurrent;
    attribute availablePower : Power;
  }

  item def ControlSignal {
    attribute enabled : Boolean;
    attribute speedCommand : RotationalSpeed;
    attribute valveOpenCommand : Boolean;
  }

  item def SensorSignal {
    attribute measuredValue : Real;
    attribute valid : Boolean;
    attribute timestamp : TimeDuration;
  }

  port def FluidInletPort {
    in item fluidIn : Fluid;
  }

  port def FluidOutletPort {
    out item fluidOut : Fluid;
  }

  port def CommandPort {
    in item commandIn : FluidCommand;
  }

  port def StatusPort {
    out item statusOut : PumpStatus;
  }

  port def PowerPort {
    in item powerIn : ElectricalPower;
  }

  port def ControlPort {
    in item controlIn : ControlSignal;
    out item sensorOut : SensorSignal;
  }

  part def Reservoir {
    attribute capacity : Volume = 0.020;
    attribute currentVolume : Volume;
    attribute fluidTemperature : Temperature;
    attribute lowLevelThreshold : Volume = 0.002;

    port outlet : FluidOutletPort;

    state def ReservoirState {
      state normal;
      state lowLevel;
      state empty;

      entry;
      then normal;

      transition normal_to_low
        first normal
        accept when currentVolume <= lowLevelThreshold
        then lowLevel;

      transition low_to_empty
        first lowLevel
        accept when currentVolume <= 0.0
        then empty;

      transition refill_to_normal
        first lowLevel
        accept when currentVolume > lowLevelThreshold
        then normal;
    }

    exhibit stateMachine : ReservoirState;
  }

  part def Filter {
    attribute pressureDrop : Pressure;
    attribute cloggingPercent : Percent;
    attribute maxAllowedClogging : Percent = 80.0;

    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;

    action def FilterFluid {
      in item unfilteredFluid : Fluid;
      out item filteredFluid : Fluid;
      out attribute resultingPressureDrop : Pressure;

      assign filteredFluid = unfilteredFluid;
      assign filteredFluid.contaminationLevel = unfilteredFluid.contaminationLevel * 0.05;
      assign resultingPressureDrop = pressureDrop;
    }
  }

  part def PumpDispenser {
    attribute displacementPerRevolution : Volume = 0.00000025;
    attribute commandedSpeed : RotationalSpeed;
    attribute actualSpeed : RotationalSpeed;
    attribute volumetricEfficiency : Percent = 92.0;
    attribute minimumFlowRate : FlowRate = 0.000001;
    attribute maximumFlowRate : FlowRate = 0.000080;
    attribute maximumOutletPressure : Pressure = 600000.0;
    attribute dryRunDetected : Boolean;
    attribute internalLeakageRate : FlowRate;
    attribute accumulatedDispensedVolume : Volume;

    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;
    port control : ControlPort;

    action def PrimePump {
      in item incomingFluid : Fluid;
      out attribute primed : Boolean;

      assign primed = incomingFluid.density > 0.0;
      assign dryRunDetected = not primed;
    }

    action def PumpFluid {
      in item incomingFluid : Fluid;
      in attribute speedSetpoint : RotationalSpeed;
      out item pressurizedFluid : Fluid;
      out attribute producedFlowRate : FlowRate;

      assign actualSpeed = speedSetpoint;
      assign producedFlowRate =
        displacementPerRevolution * actualSpeed * volumetricEfficiency / 100.0 / 60.0
        - internalLeakageRate;
      assign pressurizedFluid = incomingFluid;
    }

    action def StopPump {
      assign commandedSpeed = 0.0;
      assign actualSpeed = 0.0;
    }

    state def PumpOperatingState {
      state off;
      state priming;
      state dispensing;
      state stopping;
      state fault;

      entry;
      then off;

      transition start_prime
        first off
        accept control.controlIn.enabled
        then priming;

      transition prime_complete
        first priming
        accept when not dryRunDetected
        then dispensing;

      transition dry_run_fault
        first priming
        accept when dryRunDetected
        then fault;

      transition overpressure_fault
        first dispensing
        accept when control.sensorOut.measuredValue > maximumOutletPressure
        then fault;

      transition commanded_stop
        first dispensing
        accept when not control.controlIn.enabled
        then stopping;

      transition stopped
        first stopping
        do StopPump
        then off;
    }

    exhibit stateMachine : PumpOperatingState;
  }

  part def CheckValve {
    attribute crackingPressure : Pressure = 5000.0;
    attribute reverseLeakageRate : FlowRate = 0.0;
    attribute open : Boolean;

    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;

    action def PreventBackflow {
      in item upstreamFluid : Fluid;
      out item downstreamFluid : Fluid;

      assign downstreamFluid = upstreamFluid;
      assign open = true;
    }
  }

  part def DispenseValve {
    attribute open : Boolean;
    attribute responseTime : TimeDuration = 0.050;
    attribute nominalOrificeArea : Real = 0.000015;

    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;
    port control : ControlPort;

    action def OpenValve {
      assign open = true;
    }

    action def CloseValve {
      assign open = false;
    }

    state def ValveState {
      state closed;
      state opening;
      state openState;
      state closing;

      entry;
      then closed;

      transition command_open
        first closed
        accept control.controlIn.valveOpenCommand
        then opening;

      transition opened
        first opening
        do OpenValve
        then openState;

      transition command_close
        first openState
        accept when not control.controlIn.valveOpenCommand
        then closing;

      transition closed_done
        first closing
        do CloseValve
        then closed;
    }

    exhibit stateMachine : ValveState;
  }

  part def FlowMeter {
    attribute measuredFlowRate : FlowRate;
    attribute measurementAccuracy : Percent = 1.5;
    attribute minimumDetectableFlow : FlowRate = 0.0000005;

    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;
    port signal : ControlPort;

    action def MeasureFlow {
      in item passingFluid : Fluid;
      out item unchangedFluid : Fluid;
      out item flowSignal : SensorSignal;

      assign unchangedFluid = passingFluid;
      assign flowSignal.measuredValue = measuredFlowRate;
      assign flowSignal.valid = measuredFlowRate >= minimumDetectableFlow;
    }
  }

  part def PressureSensor {
    attribute measuredPressure : Pressure;
    attribute accuracy : Percent = 1.0;
    attribute upperRangeLimit : Pressure = 700000.0;

    port wettedPort : FluidInletPort;
    port signal : ControlPort;

    action def MeasurePressure {
      out item pressureSignal : SensorSignal;

      assign pressureSignal.measuredValue = measuredPressure;
      assign pressureSignal.valid = measuredPressure <= upperRangeLimit;
    }
  }

  part def MotorController {
    attribute supplyVoltage : ElectricVoltage = 24.0;
    attribute maximumCurrent : ElectricCurrent = 8.0;
    attribute enabled : Boolean;
    attribute requestedSpeed : RotationalSpeed;
    attribute commandedSpeed : RotationalSpeed;

    port power : PowerPort;
    port command : CommandPort;
    port pumpControl : ControlPort;
    port valveControl : ControlPort;
    port statusInput : ControlPort;

    action def ComputeSpeedCommand {
      in item dispenseCommand : FluidCommand;
      out item pumpControlSignal : ControlSignal;
      out item valveControlSignal : ControlSignal;

      assign enabled = dispenseCommand.requestedVolume > 0.0
        and dispenseCommand.requestedFlowRate > 0.0;
      assign requestedSpeed = dispenseCommand.requestedFlowRate * 60.0 / 0.00000025;
      assign commandedSpeed = requestedSpeed;
      assign pumpControlSignal.enabled = enabled;
      assign pumpControlSignal.speedCommand = commandedSpeed;
      assign pumpControlSignal.valveOpenCommand = enabled;
      assign valveControlSignal.enabled = enabled;
      assign valveControlSignal.speedCommand = 0.0;
      assign valveControlSignal.valveOpenCommand = enabled;
    }

    state def ControllerState {
      state unpowered;
      state standby;
      state dispensing;
      state completed;
      state fault;

      entry;
      then unpowered;

      transition power_available
        first unpowered
        accept when power.powerIn.voltage >= 18.0
        then standby;

      transition begin_dispense
        first standby
        accept command.commandIn
        then dispensing;

      transition target_volume_reached
        first dispensing
        accept when statusInput.sensorOut.measuredValue >= command.commandIn.requestedVolume
        then completed;

      transition timeout_fault
        first dispensing
        accept after command.commandIn.maxDispenseTime
        then fault;

      transition reset_to_standby
        first completed
        accept when not pumpControl.controlIn.enabled
        then standby;
    }

    exhibit stateMachine : ControllerState;
  }

  part def OutletNozzle {
    attribute nominalDiameter : Real = 0.006;
    attribute sprayIncludedAngle : Real = 15.0;
    attribute dripRetentionVolume : Volume = 0.000002;

    port inlet : FluidInletPort;
    port dispenseOutlet : FluidOutletPort;

    action def DispenseToProcess {
      in item pressurizedFluid : Fluid;
      out item deliveredFluid : Fluid;

      assign deliveredFluid = pressurizedFluid;
    }
  }

  part def PumpingSubsystem {
    attribute requestedFlowRate : FlowRate;
    attribute requestedVolume : Volume;
    attribute actualFlowRate : FlowRate;
    attribute dispensedVolume : Volume;
    attribute inletPressure : Pressure;
    attribute outletPressure : Pressure;
    attribute ready : Boolean;
    attribute faultActive : Boolean;

    port fluidSupply : FluidInletPort;
    port fluidDelivery : FluidOutletPort;
    port command : CommandPort;
    port status : StatusPort;
    port electricalPower : PowerPort;

    part reservoir : Reservoir {
      attribute capacity = 0.020;
    }

    part inletFilter : Filter {
      attribute pressureDrop = 2500.0;
    }

    part pumpDispenser : PumpDispenser {
      attribute maximumFlowRate = 0.000080;
      attribute maximumOutletPressure = 600000.0;
    }

    part outletCheckValve : CheckValve;
    part dispenseValve : DispenseValve;
    part flowMeter : FlowMeter;
    part outletPressureSensor : PressureSensor;
    part controller : MotorController;
    part nozzle : OutletNozzle;

    connect fluidSupply to reservoir.outlet;
    connect reservoir.outlet to inletFilter.inlet;
    connect inletFilter.outlet to pumpDispenser.inlet;
    connect pumpDispenser.outlet to outletCheckValve.inlet;
    connect outletCheckValve.outlet to dispenseValve.inlet;
    connect dispenseValve.outlet to flowMeter.inlet;
    connect flowMeter.outlet to nozzle.inlet;
    connect nozzle.dispenseOutlet to fluidDelivery;

    connect electricalPower to controller.power;
    connect command to controller.command;
    connect controller.pumpControl to pumpDispenser.control;
    connect controller.valveControl to dispenseValve.control;
    connect flowMeter.signal to controller.statusInput;
    connect outletPressureSensor.signal to pumpDispenser.control;
    connect status to controller.statusInput;

    action def ExecuteDispenseCycle {
      in item dispenseRequest : FluidCommand;
      out item deliveredFluid : Fluid;
      out item finalStatus : PumpStatus;

      first start;
      then validateRequest;
      then prime;
      then dispense;
      then stop;
      then report;

      action start {
        assign requestedFlowRate = dispenseRequest.requestedFlowRate;
        assign requestedVolume = dispenseRequest.requestedVolume;
      }

      action validateRequest {
        assign ready =
          requestedFlowRate >= pumpDispenser.minimumFlowRate and
          requestedFlowRate <= pumpDispenser.maximumFlowRate and
          requestedVolume <= reservoir.currentVolume and
          not faultActive;
      }

      action prime {
        perform pumpDispenser.PrimePump;
      }

      action dispense {
        perform controller.ComputeSpeedCommand;
        perform pumpDispenser.PumpFluid;
        perform outletCheckValve.PreventBackflow;
        perform dispenseValve.OpenValve;
        perform flowMeter.MeasureFlow;
        perform nozzle.DispenseToProcess;
      }

      action stop {
        perform dispenseValve.CloseValve;
        perform pumpDispenser.StopPump;
      }

      action report {
        assign finalStatus.actualFlowRate = actualFlowRate;
        assign finalStatus.inletPressure = inletPressure;
        assign finalStatus.outletPressure = outletPressure;
        assign finalStatus.motorSpeed = pumpDispenser.actualSpeed;
        assign finalStatus.dispensedVolume = dispensedVolume;
        assign finalStatus.faultActive = faultActive;
        assign finalStatus.ready = ready;
      }
    }

    state def SubsystemState {
      state off;
      state idle;
      state armed;
      state priming;
      state dispensing;
      state complete;
      state fault;

      entry;
      then off;

      transition powered
        first off
        accept when electricalPower.powerIn.voltage >= 18.0
        then idle;

      transition valid_command
        first idle
        accept command.commandIn
        then armed;

      transition begin_prime
        first armed
        accept when reservoir.currentVolume >= command.commandIn.requestedVolume
        then priming;

      transition insufficient_fluid_fault
        first armed
        accept when reservoir.currentVolume < command.commandIn.requestedVolume
        then fault;

      transition prime_success
        first priming
        accept when not pumpDispenser.dryRunDetected
        then dispensing;

      transition reached_target
        first dispensing
        accept when dispensedVolume >= command.commandIn.requestedVolume
        then complete;

      transition pressure_fault
        first dispensing
        accept when outletPressure > pumpDispenser.maximumOutletPressure
        then fault;

      transition flow_fault
        first dispensing
        accept when actualFlowRate < pumpDispenser.minimumFlowRate
        then fault;

      transition reset_complete
        first complete
        accept when not command.commandIn.requestedVolume > 0.0
        then idle;
    }

    exhibit stateMachine : SubsystemState;
  }

  requirement def MoveFluidRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.fluidDelivery.fluidOut.density > 0.0
    }

    doc /* The pumping subsystem shall move fluid from the supply interface to the delivery interface using the Pump dispenser. */
  }

  requirement def FlowControlRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.actualFlowRate >= subsystem.pumpDispenser.minimumFlowRate and
      subsystem.actualFlowRate <= subsystem.pumpDispenser.maximumFlowRate
    }

    doc /* The subsystem shall regulate delivered flow within the qualified flow range of the Pump dispenser during dispensing. */
  }

  requirement def DispensedVolumeRequirement {
    subject subsystem : PumpingSubsystem;

    attribute volumeTolerance : Percent = 2.0;

    require constraint {
      subsystem.dispensedVolume >= subsystem.requestedVolume * (1.0 - volumeTolerance / 100.0) and
      subsystem.dispensedVolume <= subsystem.requestedVolume * (1.0 + volumeTolerance / 100.0)
    }

    doc /* The subsystem shall deliver the requested fluid volume within the specified tolerance. */
  }

  requirement def OverPressureProtectionRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.outletPressure <= subsystem.pumpDispenser.maximumOutletPressure
    }

    doc /* The subsystem shall prevent operation above the maximum outlet pressure of the Pump dispenser. */
  }

  requirement def DryRunProtectionRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      not subsystem.pumpDispenser.dryRunDetected
    }

    doc /* The subsystem shall detect lack of inlet fluid during priming and shall inhibit dispensing to prevent dry running. */
  }

  requirement def BackflowPreventionRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.outletCheckValve.reverseLeakageRate <= 0.0000001
    }

    doc /* The subsystem shall limit reverse flow from the delivery side toward the Pump dispenser. */
  }

  requirement def ElectricalPowerRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.electricalPower.powerIn.voltage >= 18.0 and
      subsystem.electricalPower.powerIn.voltage <= 30.0
    }

    doc /* The subsystem shall operate from a nominal 24 VDC supply over the specified voltage range. */
  }

  requirement def StatusReportingRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.status.statusOut.ready == subsystem.ready and
      subsystem.status.statusOut.faultActive == subsystem.faultActive
    }

    doc /* The subsystem shall report readiness, active faults, flow, pressure, speed, and dispensed volume to the external controller. */
  }

  part pumpingSubsystem : PumpingSubsystem;

  satisfy MoveFluidRequirement by pumpingSubsystem;
  satisfy FlowControlRequirement by pumpingSubsystem;
  satisfy DispensedVolumeRequirement by pumpingSubsystem;
  satisfy OverPressureProtectionRequirement by pumpingSubsystem;
  satisfy DryRunProtectionRequirement by pumpingSubsystem;
  satisfy BackflowPreventionRequirement by pumpingSubsystem;
  satisfy ElectricalPowerRequirement by pumpingSubsystem;
  satisfy StatusReportingRequirement by pumpingSubsystem;
}