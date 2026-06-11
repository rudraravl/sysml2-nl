package PumpingSubsystemModel {

  import ScalarValues::*;
  import SI::*;

  item def Fuel {
    attribute density : Real;
    attribute temperature : Real;
    attribute vaporPressure : Real;
    attribute contaminationLevel : Real;
  }

  item def ElectricalPower {
    attribute voltage : Real;
    attribute current : Real;
    attribute frequency : Real;
  }

  item def PumpCommand {
    attribute enable : Boolean;
    attribute requestedFlowRate : Real;
    attribute requestedPressureRise : Real;
  }

  item def PumpStatus {
    attribute running : Boolean;
    attribute faulted : Boolean;
    attribute deliveredFlowRate : Real;
    attribute outletPressure : Real;
    attribute motorSpeed : Real;
    attribute faultCode : String;
  }

  item def Heat {
    attribute heatFlowRate : Real;
  }

  port def FuelInletPort {
    in item fuelIn : Fuel;
  }

  port def FuelOutletPort {
    out item fuelOut : Fuel;
  }

  port def ElectricalPowerPort {
    in item powerIn : ElectricalPower;
  }

  port def CommandPort {
    in item commandIn : PumpCommand;
  }

  port def StatusPort {
    out item statusOut : PumpStatus;
  }

  port def ThermalPort {
    out item rejectedHeat : Heat;
  }

  part def FuelPump {
    port inlet : FuelInletPort;
    port outlet : FuelOutletPort;
    port electricalInput : ElectricalPowerPort;
    port commandInput : CommandPort;
    port statusOutput : StatusPort;
    port thermalOutput : ThermalPort;

    attribute ratedVoltage : Real = 28.0;
    attribute minimumVoltage : Real = 18.0;
    attribute maximumVoltage : Real = 32.0;
    attribute maximumFlowRate : Real = 0.85;
    attribute minimumFlowRate : Real = 0.05;
    attribute nominalPressureRise : Real = 350000.0;
    attribute maximumPressureRise : Real = 600000.0;
    attribute maximumMotorSpeed : Real = 9000.0;
    attribute hydraulicEfficiency : Real = 0.62;
    attribute motorEfficiency : Real = 0.84;
    attribute maximumFuelTemperature : Real = 358.15;
    attribute minimumFuelTemperature : Real = 233.15;

    attribute actualFlowRate : Real;
    attribute actualPressureRise : Real;
    attribute motorSpeed : Real;
    attribute windingTemperature : Real;
    attribute bearingWearFraction : Real;
    attribute faultActive : Boolean;
    attribute cavitationDetected : Boolean;

    state def PumpOperatingState {
      state off;
      state priming;
      state running;
      state regulating;
      state degraded;
      state faulted;
      state shutdown;

      transition initial then off;

      transition off_to_priming
        first off
        accept PumpCommand
        if commandIn.enable
        then priming;

      transition priming_to_running
        first priming
        if inlet.fuelIn.density > 650.0 and electricalInput.powerIn.voltage >= minimumVoltage
        then running;

      transition running_to_regulating
        first running
        if commandInput.commandIn.requestedFlowRate > minimumFlowRate
        then regulating;

      transition regulating_to_degraded
        first regulating
        if cavitationDetected or windingTemperature > 393.15
        then degraded;

      transition degraded_to_regulating
        first degraded
        if not cavitationDetected and windingTemperature <= 383.15
        then regulating;

      transition any_to_faulted
        first off, priming, running, regulating, degraded
        if faultActive or electricalInput.powerIn.voltage > maximumVoltage
        then faulted;

      transition commanded_shutdown
        first priming, running, regulating, degraded
        accept PumpCommand
        if not commandIn.enable
        then shutdown;

      transition shutdown_to_off
        first shutdown
        then off;
    }

    action def PrimePump {
      in item fuelSupply : Fuel;
      out item primedFuel : Fuel;
      attribute primeDuration : Real = 2.5;
      attribute purgeVolume : Real = 0.12;
    }

    action def PressurizeFuel {
      in item inletFuel : Fuel;
      in item electricalPower : ElectricalPower;
      in item command : PumpCommand;
      out item outletFuel : Fuel;
      out item status : PumpStatus;

      attribute commandedFlowRate : Real;
      attribute commandedPressureRise : Real;
      attribute hydraulicPower : Real;
      attribute electricalPowerConsumed : Real;
      attribute heatRejected : Real;
    }

    action def DetectFaults {
      in item measuredStatus : PumpStatus;
      out item faultStatus : PumpStatus;

      attribute dryRunDetected : Boolean;
      attribute overVoltageDetected : Boolean;
      attribute underVoltageDetected : Boolean;
      attribute overTemperatureDetected : Boolean;
      attribute blockedOutletDetected : Boolean;
    }

    perform PumpOperatingState;
  }

  part def InletFilter {
    port upstreamInlet : FuelInletPort;
    port downstreamOutlet : FuelOutletPort;

    attribute nominalMicronRating : Real = 40.0;
    attribute cleanPressureDrop : Real = 8000.0;
    attribute cloggedPressureDrop : Real = 60000.0;
    attribute bypassCrackingPressure : Real = 75000.0;
    attribute contaminationCapacity : Real = 0.015;
    attribute capturedContaminationMass : Real;
    attribute bypassOpen : Boolean;
  }

  part def CheckValve {
    port inlet : FuelInletPort;
    port outlet : FuelOutletPort;

    attribute crackingPressure : Real = 12000.0;
    attribute reverseLeakageFlowRate : Real = 0.00002;
    attribute open : Boolean;
  }

  part def PressureReliefValve {
    port inlet : FuelInletPort;
    port returnOutlet : FuelOutletPort;

    attribute setPressure : Real = 620000.0;
    attribute reseatPressure : Real = 540000.0;
    attribute reliefFlowRate : Real;
    attribute open : Boolean;
  }

  part def PressureSensor {
    port sensedFuelPort : FuelInletPort;
    port statusOutput : StatusPort;

    attribute measurementRangeMinimum : Real = 0.0;
    attribute measurementRangeMaximum : Real = 800000.0;
    attribute accuracy : Real = 2500.0;
    attribute measuredPressure : Real;
  }

  part def FlowSensor {
    port sensedFuelPort : FuelInletPort;
    port statusOutput : StatusPort;

    attribute measurementRangeMinimum : Real = 0.0;
    attribute measurementRangeMaximum : Real = 1.0;
    attribute accuracy : Real = 0.01;
    attribute measuredFlowRate : Real;
  }

  part def PumpController {
    port commandInput : CommandPort;
    port pumpCommandOutput : CommandPort;
    port pumpStatusInput : StatusPort;
    port subsystemStatusOutput : StatusPort;

    attribute targetFlowRate : Real;
    attribute targetPressureRise : Real;
    attribute closedLoopEnabled : Boolean = true;
    attribute proportionalGain : Real = 0.45;
    attribute integralGain : Real = 0.08;
    attribute pressureError : Real;
    attribute flowError : Real;
    attribute commandedMotorSpeed : Real;

    state def ControllerState {
      state disabled;
      state startupCheck;
      state enabled;
      state limiting;
      state faultLatched;

      transition initial then disabled;

      transition disabled_to_startupCheck
        first disabled
        accept PumpCommand
        if commandIn.enable
        then startupCheck;

      transition startupCheck_to_enabled
        first startupCheck
        if pumpStatusInput.statusOut.faulted == false
        then enabled;

      transition enabled_to_limiting
        first enabled
        if pumpStatusInput.statusOut.outletPressure > 580000.0
        then limiting;

      transition limiting_to_enabled
        first limiting
        if pumpStatusInput.statusOut.outletPressure < 520000.0
        then enabled;

      transition enabled_to_faultLatched
        first enabled, limiting, startupCheck
        if pumpStatusInput.statusOut.faulted
        then faultLatched;

      transition faultLatched_to_disabled
        first faultLatched
        accept PumpCommand
        if not commandIn.enable
        then disabled;
    }

    perform ControllerState;
  }

  part def FuelReservoirInterface {
    port supplyOutlet : FuelOutletPort;
    port returnInlet : FuelInletPort;

    attribute availableFuelVolume : Real;
    attribute supplyPressure : Real = 101325.0;
    attribute fuelTemperature : Real;
  }

  part def EngineFeedInterface {
    port feedInlet : FuelInletPort;
    port returnOutlet : FuelOutletPort;

    attribute requiredMinimumFlowRate : Real = 0.30;
    attribute requiredMinimumPressure : Real = 300000.0;
    attribute maximumAllowablePressure : Real = 650000.0;
  }

  part def PumpingSubsystem {
    port reservoirSupply : FuelInletPort;
    port engineFeed : FuelOutletPort;
    port electricalPowerInput : ElectricalPowerPort;
    port operatorCommandInput : CommandPort;
    port subsystemStatusOutput : StatusPort;
    port heatRejection : ThermalPort;

    part reservoirInterface : FuelReservoirInterface;
    part inletFilter : InletFilter;
    part pump : FuelPump;
    part checkValve : CheckValve;
    part reliefValve : PressureReliefValve;
    part pressureSensor : PressureSensor;
    part flowSensor : FlowSensor;
    part controller : PumpController;
    part engineInterface : EngineFeedInterface;

    attribute subsystemFlowRate : Real;
    attribute subsystemOutletPressure : Real;
    attribute subsystemPressureRise : Real;
    attribute electricalPowerConsumed : Real;
    attribute heatRejectedToBay : Real;
    attribute availability : Real = 0.995;
    attribute designLifeHours : Real = 12000.0;

    connect reservoirSupply to inletFilter.upstreamInlet;
    connect inletFilter.downstreamOutlet to pump.inlet;
    connect pump.outlet to checkValve.inlet;
    connect checkValve.outlet to engineFeed;
    connect checkValve.outlet to pressureSensor.sensedFuelPort;
    connect checkValve.outlet to flowSensor.sensedFuelPort;
    connect checkValve.outlet to reliefValve.inlet;
    connect reliefValve.returnOutlet to reservoirInterface.returnInlet;

    connect electricalPowerInput to pump.electricalInput;
    connect operatorCommandInput to controller.commandInput;
    connect controller.pumpCommandOutput to pump.commandInput;
    connect pump.statusOutput to controller.pumpStatusInput;
    connect controller.subsystemStatusOutput to subsystemStatusOutput;
    connect pump.thermalOutput to heatRejection;

    action def MoveFuel {
      in item suppliedFuel : Fuel;
      in item command : PumpCommand;
      in item power : ElectricalPower;
      out item deliveredFuel : Fuel;
      out item status : PumpStatus;

      first start;
      then filterFuel;
      then pressurize;
      then preventBackflow;
      then regulatePressure;
      then reportStatus;
      then done;

      action filterFuel {
        in item rawFuel : Fuel;
        out item filteredFuel : Fuel;
      }

      action pressurize {
        in item lowPressureFuel : Fuel;
        out item highPressureFuel : Fuel;
      }

      action preventBackflow {
        in item pressurizedFuel : Fuel;
        out item checkedFuel : Fuel;
      }

      action regulatePressure {
        in item checkedFuel : Fuel;
        out item regulatedFuel : Fuel;
      }

      action reportStatus {
        out item pumpStatus : PumpStatus;
      }
    }

    perform MoveFuel;
  }

  requirement def FuelTransferRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.subsystemFlowRate >= 0.30 and
      subsystem.subsystemOutletPressure >= 300000.0 and
      subsystem.subsystemOutletPressure <= 650000.0
    }
  }

  requirement def PumpPressureRiseRequirement {
    subject pump : FuelPump;

    require constraint {
      pump.actualPressureRise >= 300000.0 and
      pump.actualPressureRise <= pump.maximumPressureRise
    }
  }

  requirement def ElectricalCompatibilityRequirement {
    subject pump : FuelPump;

    require constraint {
      pump.electricalInput.powerIn.voltage >= pump.minimumVoltage and
      pump.electricalInput.powerIn.voltage <= pump.maximumVoltage
    }
  }

  requirement def ThermalProtectionRequirement {
    subject pump : FuelPump;

    require constraint {
      pump.windingTemperature <= 393.15 and
      pump.inlet.fuelIn.temperature <= pump.maximumFuelTemperature
    }
  }

  requirement def BackflowPreventionRequirement {
    subject valve : CheckValve;

    require constraint {
      valve.reverseLeakageFlowRate <= 0.00002
    }
  }

  requirement def ReliefProtectionRequirement {
    subject relief : PressureReliefValve;

    require constraint {
      relief.setPressure <= 620000.0 and
      relief.reseatPressure >= 540000.0
    }
  }

  requirement def FiltrationRequirement {
    subject filter : InletFilter;

    require constraint {
      filter.nominalMicronRating <= 40.0 and
      filter.cloggedPressureDrop <= filter.bypassCrackingPressure
    }
  }

  requirement def StatusReportingRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.subsystemStatusOutput.statusOut.deliveredFlowRate == subsystem.subsystemFlowRate and
      subsystem.subsystemStatusOutput.statusOut.outletPressure == subsystem.subsystemOutletPressure
    }
  }

  satisfy FuelTransferRequirement by PumpingSubsystem;
  satisfy PumpPressureRiseRequirement by FuelPump;
  satisfy ElectricalCompatibilityRequirement by FuelPump;
  satisfy ThermalProtectionRequirement by FuelPump;
  satisfy BackflowPreventionRequirement by CheckValve;
  satisfy ReliefProtectionRequirement by PressureReliefValve;
  satisfy FiltrationRequirement by InletFilter;
  satisfy StatusReportingRequirement by PumpingSubsystem;
}