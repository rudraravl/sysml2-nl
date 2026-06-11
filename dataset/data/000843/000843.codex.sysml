package AldgatePumpingSubsystemModel {

  import ScalarValues::*;
  import SI::*;

  value def Pressure {
    unit : String = "kPa";
    quantityKind : String = "fluid pressure";
  }

  value def VolumeFlowRate {
    unit : String = "L/min";
    quantityKind : String = "volumetric flow rate";
  }

  value def Volume {
    unit : String = "L";
    quantityKind : String = "fluid volume";
  }

  value def Temperature {
    unit : String = "degC";
    quantityKind : String = "fluid temperature";
  }

  value def Power {
    unit : String = "W";
    quantityKind : String = "electrical power";
  }

  value def Speed {
    unit : String = "rpm";
    quantityKind : String = "rotational speed";
  }

  value def TimeDuration {
    unit : String = "s";
    quantityKind : String = "time duration";
  }

  item def ProcessFluid {
    attribute density : Real;
    attribute dynamicViscosity : Real;
    attribute temperature : Temperature;
    attribute vaporPressure : Pressure;
    attribute containsGas : Boolean;
  }

  item def ElectricalEnergy {
    attribute voltage : Real;
    attribute current : Real;
    attribute frequency : Real;
    attribute power : Power;
  }

  port def FluidPort {
    inout item fluid : ProcessFluid;
    attribute pressure : Pressure;
    attribute flowRate : VolumeFlowRate;
  }

  port def ElectricalPowerPort {
    in item energy : ElectricalEnergy;
  }

  port def ControlPort {
    in attribute enable : Boolean;
    in attribute resetFault : Boolean;
    out attribute running : Boolean;
    out attribute faulted : Boolean;
    out attribute commandedSpeed : Speed;
  }

  port def SignalPort {
    out attribute value : Real;
    out attribute valid : Boolean;
  }

  part def IsolationValve {
    port upstream : FluidPort;
    port downstream : FluidPort;

    attribute openCommand : Boolean;
    attribute positionOpen : Boolean;
    attribute leakageRate : VolumeFlowRate = 0.02;
    attribute pressureRating : Pressure = 900.0;
  }

  part def CheckValve {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute crackingPressure : Pressure = 8.0;
    attribute reverseLeakageRate : VolumeFlowRate = 0.01;
    attribute open : Boolean;
  }

  part def Strainer {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute meshSizeMicrometer : Real = 250.0;
    attribute differentialPressure : Pressure;
    attribute clogged : Boolean;
  }

  part def PressureSensor {
    port processConnection : FluidPort;
    port signal : SignalPort;

    attribute measurementRangeLow : Pressure = 0.0;
    attribute measurementRangeHigh : Pressure = 1000.0;
    attribute accuracyPercentSpan : Real = 0.5;
    attribute measuredPressure : Pressure;
  }

  part def FlowSensor {
    port inlet : FluidPort;
    port outlet : FluidPort;
    port signal : SignalPort;

    attribute measurementRangeLow : VolumeFlowRate = 0.0;
    attribute measurementRangeHigh : VolumeFlowRate = 120.0;
    attribute accuracyPercentReading : Real = 1.0;
    attribute measuredFlow : VolumeFlowRate;
  }

  part def ElectricMotor {
    port powerInput : ElectricalPowerPort;
    port control : ControlPort;

    attribute ratedPower : Power = 1500.0;
    attribute ratedVoltage : Real = 230.0;
    attribute ratedSpeed : Speed = 1750.0;
    attribute actualSpeed : Speed;
    attribute enabled : Boolean;
    attribute windingTemperature : Temperature;
  }

  part def AldgatePump {
    port suction : FluidPort;
    port discharge : FluidPort;
    port shaftControl : ControlPort;

    attribute displayName : String = "Aldgate Pump";
    attribute nominalFlowRate : VolumeFlowRate = 60.0;
    attribute minimumContinuousFlowRate : VolumeFlowRate = 12.0;
    attribute maximumFlowRate : VolumeFlowRate = 90.0;
    attribute nominalDifferentialPressure : Pressure = 350.0;
    attribute maximumDischargePressure : Pressure = 800.0;
    attribute minimumSuctionPressure : Pressure = 25.0;
    attribute primingVolume : Volume = 3.5;
    attribute primed : Boolean;
    attribute cavitationDetected : Boolean;
    attribute hydraulicEfficiency : Real = 0.72;
    attribute currentFlowRate : VolumeFlowRate;
    attribute currentDifferentialPressure : Pressure;
  }

  action def PrimePump {
    inout item fluid : ProcessFluid;
    in attribute availableSuctionPressure : Pressure;
    out attribute pumpPrimed : Boolean;

    precondition {
      availableSuctionPressure >= 25.0
    }

    postcondition {
      pumpPrimed == true
    }
  }

  action def TransferFluid {
    in item incomingFluid : ProcessFluid;
    out item deliveredFluid : ProcessFluid;
    in attribute requestedFlowRate : VolumeFlowRate;
    in attribute suctionPressure : Pressure;
    out attribute dischargePressure : Pressure;
    out attribute deliveredFlowRate : VolumeFlowRate;

    precondition {
      requestedFlowRate >= 12.0 and requestedFlowRate <= 90.0 and suctionPressure >= 25.0
    }

    postcondition {
      deliveredFlowRate >= 12.0 and dischargePressure <= 800.0
    }
  }

  action def ShutdownPump {
    in attribute faultPresent : Boolean;
    out attribute motorEnabled : Boolean;
    out attribute isolationClosed : Boolean;

    postcondition {
      motorEnabled == false and isolationClosed == true
    }
  }

  state def PumpingControlStateMachine {
    state Off;
    state Standby;
    state Priming;
    state Running;
    state LowFlowProtection;
    state Faulted;
    state Shutdown;

    transition initial then Off;

    transition Off_to_Standby
      first Off
      accept enable
      then Standby;

    transition Standby_to_Priming
      first Standby
      if suctionPressure >= 25.0
      then Priming;

    transition Priming_to_Running
      first Priming
      if primed == true
      then Running;

    transition Running_to_LowFlowProtection
      first Running
      if currentFlowRate < 12.0
      then LowFlowProtection;

    transition LowFlowProtection_to_Running
      first LowFlowProtection
      if currentFlowRate >= 12.0
      then Running;

    transition Running_to_Faulted
      first Running
      if dischargePressure > 800.0 or cavitationDetected == true or windingTemperature > 120.0
      then Faulted;

    transition Faulted_to_Shutdown
      first Faulted
      then Shutdown;

    transition Shutdown_to_Off
      first Shutdown
      if running == false
      then Off;

    transition Faulted_to_Standby
      first Faulted
      accept resetFault
      if dischargePressure <= 800.0 and cavitationDetected == false
      then Standby;
  }

  part def PumpingSubsystem {
    port suctionInlet : FluidPort;
    port dischargeOutlet : FluidPort;
    port electricalSupply : ElectricalPowerPort;
    port commandInterface : ControlPort;

    part suctionIsolationValve : IsolationValve;
    part suctionStrainer : Strainer;
    part suctionPressureSensor : PressureSensor;
    part aldgatePump : AldgatePump;
    part driveMotor : ElectricMotor;
    part dischargeCheckValve : CheckValve;
    part flowSensor : FlowSensor;
    part dischargePressureSensor : PressureSensor;
    part dischargeIsolationValve : IsolationValve;

    attribute requiredFlowRate : VolumeFlowRate = 60.0;
    attribute deliveredFlowRate : VolumeFlowRate;
    attribute suctionPressure : Pressure;
    attribute dischargePressure : Pressure;
    attribute operatingTemperature : Temperature;
    attribute startupTimeout : TimeDuration = 20.0;
    attribute shutdownTimeout : TimeDuration = 10.0;
    attribute subsystemAvailable : Boolean;
    attribute faultPresent : Boolean;

    connect suctionInlet to suctionIsolationValve.upstream;
    connect suctionIsolationValve.downstream to suctionStrainer.inlet;
    connect suctionStrainer.outlet to suctionPressureSensor.processConnection;
    connect suctionPressureSensor.processConnection to aldgatePump.suction;
    connect aldgatePump.discharge to dischargeCheckValve.inlet;
    connect dischargeCheckValve.outlet to flowSensor.inlet;
    connect flowSensor.outlet to dischargePressureSensor.processConnection;
    connect dischargePressureSensor.processConnection to dischargeIsolationValve.upstream;
    connect dischargeIsolationValve.downstream to dischargeOutlet;

    connect electricalSupply to driveMotor.powerInput;
    connect commandInterface to driveMotor.control;
    connect driveMotor.control to aldgatePump.shaftControl;

    perform action primingAction : PrimePump {
      inout fluid = suctionInlet.fluid;
      in availableSuctionPressure = suctionPressure;
      out pumpPrimed = aldgatePump.primed;
    }

    perform action pumpingAction : TransferFluid {
      in incomingFluid = suctionInlet.fluid;
      out deliveredFluid = dischargeOutlet.fluid;
      in requestedFlowRate = requiredFlowRate;
      in suctionPressure = suctionPressure;
      out dischargePressure = dischargePressure;
      out deliveredFlowRate = deliveredFlowRate;
    }

    perform action shutdownAction : ShutdownPump {
      in faultPresent = faultPresent;
      out motorEnabled = driveMotor.enabled;
      out isolationClosed = suctionIsolationValve.openCommand;
    }

    exhibit state behavior controlBehavior : PumpingControlStateMachine;
  }

  requirement def FluidTransferRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.deliveredFlowRate >= 45.0 and subsystem.deliveredFlowRate <= 75.0
    }
  }

  requirement def AldgatePumpUseRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.aldgatePump.displayName == "Aldgate Pump"
    }
  }

  requirement def PressureLimitRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.dischargePressure <= 800.0 and subsystem.suctionPressure >= 25.0
    }
  }

  requirement def LowFlowProtectionRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.aldgatePump.currentFlowRate >= subsystem.aldgatePump.minimumContinuousFlowRate
      or subsystem.driveMotor.enabled == false
    }
  }

  requirement def CavitationProtectionRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.aldgatePump.cavitationDetected == false
      or subsystem.faultPresent == true
    }
  }

  requirement def ElectricalPowerRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.driveMotor.ratedPower >= 1500.0 and subsystem.driveMotor.ratedVoltage == 230.0
    }
  }

  requirement def StartupRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.startupTimeout <= 20.0
    }
  }

  requirement def ShutdownRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.shutdownTimeout <= 10.0
    }
  }

  part aldgatePumpingSubsystem : PumpingSubsystem;

  satisfy FluidTransferRequirement by aldgatePumpingSubsystem;
  satisfy AldgatePumpUseRequirement by aldgatePumpingSubsystem;
  satisfy PressureLimitRequirement by aldgatePumpingSubsystem;
  satisfy LowFlowProtectionRequirement by aldgatePumpingSubsystem;
  satisfy CavitationProtectionRequirement by aldgatePumpingSubsystem;
  satisfy ElectricalPowerRequirement by aldgatePumpingSubsystem;
  satisfy StartupRequirement by aldgatePumpingSubsystem;
  satisfy ShutdownRequirement by aldgatePumpingSubsystem;
}