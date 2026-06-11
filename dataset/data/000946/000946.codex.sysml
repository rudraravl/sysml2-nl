package PumpingSubsystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def VolumeFlowRate :> ISQ::volumeFlowRate;
  attribute def Pressure :> ISQ::pressure;
  attribute def Length :> ISQ::length;
  attribute def Time :> ISQ::time;
  attribute def ElectricPotential :> ISQ::electricPotential;
  attribute def ElectricCurrent :> ISQ::electricCurrent;
  attribute def Power :> ISQ::power;
  attribute def Temperature :> ISQ::thermodynamicTemperature;

  item def Fluid {
    attribute density : Real;
    attribute temperature : Temperature;
    attribute suspendedSolidsFraction : Real;
  }

  item def ElectricalEnergy {
    attribute voltage : ElectricPotential;
    attribute current : ElectricCurrent;
    attribute frequency : Real;
  }

  item def ControlSignal {
    attribute commandedState : PumpCommand;
    attribute timestamp : Time;
  }

  enum def PumpCommand {
    enum off;
    enum standby;
    enum run;
    enum faultReset;
  }

  enum def PumpOperatingState {
    enum deenergized;
    enum idle;
    enum priming;
    enum pumping;
    enum blocked;
    enum faulted;
  }

  port def FluidInletPort {
    in item inflow : Fluid;
    attribute staticPressure : Pressure;
    attribute liquidLevelAtPort : Length;
  }

  port def FluidOutletPort {
    out item outflow : Fluid;
    attribute dischargePressure : Pressure;
    attribute actualFlowRate : VolumeFlowRate;
  }

  port def ElectricalPowerPort {
    in item supply : ElectricalEnergy;
    attribute availableVoltage : ElectricPotential;
    attribute breakerClosed : Boolean;
  }

  port def ControlPort {
    in item command : ControlSignal;
    out attribute ready : Boolean;
    out attribute running : Boolean;
    out attribute faultActive : Boolean;
  }

  port def SensorPort {
    out attribute measuredLevel : Length;
    out attribute measuredMotorCurrent : ElectricCurrent;
    out attribute measuredDischargePressure : Pressure;
    out attribute measuredFlowRate : VolumeFlowRate;
  }

  part def SumpBasin {
    attribute capacity : ISQ::volume = 0.35 [SI::m^3];
    attribute lowLevel : Length = 0.10 [SI::m];
    attribute startLevel : Length = 0.35 [SI::m];
    attribute highAlarmLevel : Length = 0.55 [SI::m];
    attribute overflowLevel : Length = 0.70 [SI::m];
    attribute currentLevel : Length;
    attribute inflowRate : VolumeFlowRate;

    port inlet : FluidInletPort;
    port pumpSuction : FluidOutletPort;
  }

  part def SumpPump {
    attribute ratedFlow : VolumeFlowRate = 0.012 [SI::m^3 / SI::s];
    attribute minimumFlow : VolumeFlowRate = 0.002 [SI::m^3 / SI::s];
    attribute ratedHead : Length = 8.0 [SI::m];
    attribute maximumHead : Length = 11.0 [SI::m];
    attribute motorPower : Power = 750 [SI::W];
    attribute nominalVoltage : ElectricPotential = 120 [SI::V];
    attribute nominalCurrent : ElectricCurrent = 8.5 [SI::A];
    attribute maxSolidsDiameter : Length = 0.010 [SI::m];
    attribute thermalTripTemperature : Temperature = 373.15 [SI::K];
    attribute dryRunTimeout : Time = 20 [SI::s];
    attribute state : PumpOperatingState;
    attribute accumulatedRunTime : Time;
    attribute startsCount : Integer;

    port suction : FluidInletPort;
    port discharge : FluidOutletPort;
    port power : ElectricalPowerPort;
    port control : ControlPort;
    port telemetry : SensorPort;

    action def PrimePump {
      in attribute inletLevel : Length;
      out attribute primed : Boolean;
      constraint primeCondition {
        inletLevel >= 0.12 [SI::m]
      }
    }

    action def MoveFluid {
      in item suctionFluid : Fluid;
      out item dischargeFluid : Fluid;
      in attribute availableHead : Length;
      out attribute deliveredFlow : VolumeFlowRate;

      constraint flowLimit {
        deliveredFlow <= ratedFlow
      }

      constraint headLimit {
        availableHead <= maximumHead
      }
    }

    action def StopPump {
      out attribute motorEnergized : Boolean = false;
      out attribute deliveredFlow : VolumeFlowRate = 0.0 [SI::m^3 / SI::s];
    }

    state def PumpStateMachine {
      state deenergized;
      state idle;
      state priming;
      state pumping;
      state blocked;
      state faulted;

      transition first deenergized;

      transition deenergized_to_idle
        first deenergized
        then idle
        if power.breakerClosed and power.availableVoltage >= 108 [SI::V];

      transition idle_to_priming
        first idle
        then priming
        if control.command.commandedState == PumpCommand::run and suction.liquidLevelAtPort >= 0.12 [SI::m];

      transition priming_to_pumping
        first priming
        then pumping
        if telemetry.measuredFlowRate >= minimumFlow;

      transition pumping_to_idle_low_level
        first pumping
        then idle
        if suction.liquidLevelAtPort <= 0.10 [SI::m];

      transition pumping_to_blocked
        first pumping
        then blocked
        if telemetry.measuredMotorCurrent > 13.0 [SI::A] and telemetry.measuredFlowRate < minimumFlow;

      transition blocked_to_faulted
        first blocked
        then faulted
        if telemetry.measuredMotorCurrent > 13.0 [SI::A];

      transition any_to_deenergized
        first idle
        then deenergized
        if not power.breakerClosed;

      transition faulted_to_idle
        first faulted
        then idle
        if control.command.commandedState == PumpCommand::faultReset and power.breakerClosed;
    }

    perform pumpBehavior : PumpStateMachine;
  }

  part def CheckValve {
    attribute crackingPressure : Pressure = 1500 [SI::Pa];
    attribute reverseLeakageRate : VolumeFlowRate = 0.00001 [SI::m^3 / SI::s];

    port upstream : FluidInletPort;
    port downstream : FluidOutletPort;
  }

  part def DischargePipe {
    attribute innerDiameter : Length = 0.038 [SI::m];
    attribute length : Length = 12.0 [SI::m];
    attribute elevationRise : Length = 4.5 [SI::m];
    attribute designPressure : Pressure = 350000 [SI::Pa];

    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;
  }

  part def LevelSwitch {
    attribute lowSetpoint : Length = 0.10 [SI::m];
    attribute startSetpoint : Length = 0.35 [SI::m];
    attribute highAlarmSetpoint : Length = 0.55 [SI::m];
    attribute measuredLevel : Length;

    port sensing : SensorPort;
    port commandOut : ControlPort;
  }

  part def PumpController {
    attribute autoModeEnabled : Boolean = true;
    attribute startDelay : Time = 1 [SI::s];
    attribute restartLockout : Time = 30 [SI::s];
    attribute alarmLatched : Boolean;

    port levelInput : SensorPort;
    port pumpCommand : ControlPort;
    port operatorCommand : ControlPort;

    action def EvaluateLevel {
      in attribute level : Length;
      out item command : ControlSignal;

      constraint startCommand {
        if level >= 0.35 [SI::m] then command.commandedState == PumpCommand::run
      }

      constraint stopCommand {
        if level <= 0.10 [SI::m] then command.commandedState == PumpCommand::standby
      }
    }

    state def ControllerStateMachine {
      state monitoring;
      state startCommanded;
      state runningConfirmed;
      state highLevelAlarm;
      state faultManagement;

      transition first monitoring;

      transition monitoring_to_start
        first monitoring
        then startCommanded
        if levelInput.measuredLevel >= 0.35 [SI::m] and autoModeEnabled;

      transition start_to_running
        first startCommanded
        then runningConfirmed
        if pumpCommand.running;

      transition running_to_monitoring
        first runningConfirmed
        then monitoring
        if levelInput.measuredLevel <= 0.10 [SI::m];

      transition monitoring_to_alarm
        first monitoring
        then highLevelAlarm
        if levelInput.measuredLevel >= 0.55 [SI::m];

      transition any_to_fault
        first runningConfirmed
        then faultManagement
        if pumpCommand.faultActive;

      transition alarm_to_monitoring
        first highLevelAlarm
        then monitoring
        if levelInput.measuredLevel < 0.35 [SI::m];
    }

    perform controllerBehavior : ControllerStateMachine;
  }

  part def PowerFeed {
    attribute nominalVoltage : ElectricPotential = 120 [SI::V];
    attribute breakerRating : ElectricCurrent = 15 [SI::A];
    attribute groundFaultProtection : Boolean = true;

    port output : ElectricalPowerPort;
  }

  part def PumpingSubsystem {
    attribute requiredDesignFlow : VolumeFlowRate = 0.010 [SI::m^3 / SI::s];
    attribute minimumOperatingLevel : Length = 0.10 [SI::m];
    attribute startOperatingLevel : Length = 0.35 [SI::m];
    attribute requiredDischargeHead : Length = 6.0 [SI::m];
    attribute maximumAllowableRunDryTime : Time = 20 [SI::s];

    part basin : SumpBasin;
    part pump : SumpPump;
    part checkValve : CheckValve;
    part dischargePipe : DischargePipe;
    part levelSwitch : LevelSwitch;
    part controller : PumpController;
    part powerFeed : PowerFeed;

    port externalFluidInlet : FluidInletPort;
    port finalDischarge : FluidOutletPort;
    port externalPower : ElectricalPowerPort;
    port operatorInterface : ControlPort;

    connect externalFluidInlet to basin.inlet;
    connect basin.pumpSuction to pump.suction;
    connect pump.discharge to checkValve.upstream;
    connect checkValve.downstream to dischargePipe.inlet;
    connect dischargePipe.outlet to finalDischarge;
    connect externalPower to powerFeed.output;
    connect powerFeed.output to pump.power;
    connect levelSwitch.commandOut to controller.levelInput;
    connect controller.pumpCommand to pump.control;
    connect operatorInterface to controller.operatorCommand;
    connect pump.telemetry to controller.levelInput;

    constraint flowCapability {
      pump.ratedFlow >= requiredDesignFlow
    }

    constraint headCapability {
      pump.maximumHead >= requiredDischargeHead
    }

    constraint basinStartAbovePumpInlet {
      startOperatingLevel > minimumOperatingLevel
    }

    constraint dischargePressureWithinPipeRating {
      pump.discharge.dischargePressure <= dischargePipe.designPressure
    }

    action def DrainSump {
      in item incomingFluid : Fluid;
      out item dischargedFluid : Fluid;
      in attribute initialLevel : Length;
      out attribute finalLevel : Length;

      perform pump.PrimePump;
      perform pump.MoveFluid;

      constraint drainedToLowLevel {
        finalLevel <= minimumOperatingLevel
      }
    }
  }

  requirement def PumpingSubsystemRequirement {
    subject subsystem : PumpingSubsystem;

    requirement flowRequirement {
      doc
      /* The pumping subsystem shall move sump fluid from the basin to the discharge outlet at not less than the required design flow when basin level is at or above the start level and discharge head is within the required limit. */
      require constraint {
        subsystem.pump.ratedFlow >= subsystem.requiredDesignFlow
      }
    }

    requirement headRequirement {
      doc
      /* The sump pump shall provide sufficient head to overcome discharge piping elevation rise and losses. */
      require constraint {
        subsystem.pump.maximumHead >= subsystem.requiredDischargeHead
      }
    }

    requirement automaticStartStopRequirement {
      doc
      /* The controller shall command the pump to run at the start level and stop at the low level. */
      require constraint {
        subsystem.controller.autoModeEnabled == true and
        subsystem.basin.startLevel == subsystem.startOperatingLevel and
        subsystem.basin.lowLevel == subsystem.minimumOperatingLevel
      }
    }

    requirement backflowPreventionRequirement {
      doc
      /* The discharge line shall prevent reverse flow into the sump basin when the pump is stopped. */
      require constraint {
        subsystem.checkValve.reverseLeakageRate <= 0.00001 [SI::m^3 / SI::s]
      }
    }

    requirement electricalProtectionRequirement {
      doc
      /* The pump power feed shall include ground fault protection and a breaker sized above nominal motor current. */
      require constraint {
        subsystem.powerFeed.groundFaultProtection == true and
        subsystem.powerFeed.breakerRating > subsystem.pump.nominalCurrent
      }
    }

    requirement dryRunProtectionRequirement {
      doc
      /* The pump shall stop or enter fault management before exceeding the allowable dry-run duration. */
      require constraint {
        subsystem.pump.dryRunTimeout <= subsystem.maximumAllowableRunDryTime
      }
    }

    requirement highLevelAlarmRequirement {
      doc
      /* The controller shall identify a high-level alarm before basin overflow. */
      require constraint {
        subsystem.basin.highAlarmLevel < subsystem.basin.overflowLevel
      }
    }
  }

  part sumpPumpingSubsystem : PumpingSubsystem {
    attribute requiredDesignFlow = 0.010 [SI::m^3 / SI::s];
    attribute requiredDischargeHead = 6.0 [SI::m];

    part basin {
      attribute capacity = 0.35 [SI::m^3];
      attribute lowLevel = 0.10 [SI::m];
      attribute startLevel = 0.35 [SI::m];
      attribute highAlarmLevel = 0.55 [SI::m];
      attribute overflowLevel = 0.70 [SI::m];
    }

    part pump {
      attribute ratedFlow = 0.012 [SI::m^3 / SI::s];
      attribute ratedHead = 8.0 [SI::m];
      attribute maximumHead = 11.0 [SI::m];
      attribute motorPower = 750 [SI::W];
      attribute nominalVoltage = 120 [SI::V];
      attribute nominalCurrent = 8.5 [SI::A];
      attribute maxSolidsDiameter = 0.010 [SI::m];
    }

    part dischargePipe {
      attribute innerDiameter = 0.038 [SI::m];
      attribute length = 12.0 [SI::m];
      attribute elevationRise = 4.5 [SI::m];
      attribute designPressure = 350000 [SI::Pa];
    }
  }

  requirement sumpPumpingSubsystemSpecification : PumpingSubsystemRequirement {
    subject subsystem = sumpPumpingSubsystem;
  }
}