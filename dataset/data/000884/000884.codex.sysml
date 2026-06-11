package GasolinePumpingSubsystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def VolumeFlowRate :> ISQ::volumeFlowRate {
    unit = "L/min";
  }

  attribute def Pressure :> ISQ::pressure {
    unit = "kPa";
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    unit = "degC";
  }

  attribute def RotationalSpeed {
    unit = "rpm";
  }

  attribute def FuelVolume {
    unit = "L";
  }

  attribute def Power :> ISQ::power {
    unit = "kW";
  }

  attribute def TimeDuration :> ISQ::duration {
    unit = "s";
  }

  item def Fluid {
    attribute density : Real;
    attribute viscosity : Real;
    attribute temperature : Temperature;
  }

  item def Gasoline :> Fluid {
    attribute octaneRating : Real;
    attribute vaporPressure : Pressure;
  }

  item def PumpedFluid :> Fluid {
    attribute inletPressure : Pressure;
    attribute outletPressure : Pressure;
    attribute flowRate : VolumeFlowRate;
  }

  item def ExhaustGas {
    attribute temperature : Temperature;
    attribute carbonMonoxideFraction : Real;
  }

  item def StartCommand;
  item def StopCommand;
  item def FaultSignal {
    attribute faultCode : String;
    attribute severity : String;
  }

  port def FluidInletPort {
    in item incomingFluid : PumpedFluid;
    attribute pressure : Pressure;
  }

  port def FluidOutletPort {
    out item outgoingFluid : PumpedFluid;
    attribute pressure : Pressure;
  }

  port def FuelPort {
    out item fuel : Gasoline;
    attribute remainingFuel : FuelVolume;
  }

  port def EngineDrivePort {
    out attribute shaftSpeed : RotationalSpeed;
    out attribute shaftPower : Power;
  }

  port def PumpDrivePort {
    in attribute shaftSpeed : RotationalSpeed;
    in attribute shaftPower : Power;
  }

  port def ControlPort {
    in item start : StartCommand;
    in item stop : StopCommand;
    out item fault : FaultSignal;
  }

  port def ExhaustPort {
    out item exhaust : ExhaustGas;
  }

  action def DrawFuel {
    in item fuelSupply : Gasoline;
    out item meteredFuel : Gasoline;
  }

  action def IgniteEngine {
    in item meteredFuel : Gasoline;
    out attribute shaftSpeed : RotationalSpeed;
  }

  action def TransferFluid {
    in item inletFluid : PumpedFluid;
    in attribute impellerSpeed : RotationalSpeed;
    out item outletFluid : PumpedFluid;
  }

  action def DetectPumpFaults {
    in attribute inletPressure : Pressure;
    in attribute outletPressure : Pressure;
    in attribute engineSpeed : RotationalSpeed;
    out item fault : FaultSignal;
  }

  state def PumpOperatingStateMachine {
    in item startCommand : StartCommand;
    in item stopCommand : StopCommand;
    in item detectedFault : FaultSignal;

    state Off;
    state Starting;
    state Priming;
    state Running;
    state Stopping;
    state Faulted;

    transition initial_to_off first Off;

    transition start_requested
      first Off
      accept startCommand
      then Starting;

    transition engine_started
      first Starting
      then Priming;

    transition prime_complete
      first Priming
      then Running;

    transition stop_requested_from_running
      first Running
      accept stopCommand
      then Stopping;

    transition stop_requested_from_priming
      first Priming
      accept stopCommand
      then Stopping;

    transition stopped
      first Stopping
      then Off;

    transition fault_from_starting
      first Starting
      accept detectedFault
      then Faulted;

    transition fault_from_priming
      first Priming
      accept detectedFault
      then Faulted;

    transition fault_from_running
      first Running
      accept detectedFault
      then Faulted;

    transition reset_after_fault
      first Faulted
      accept stopCommand
      then Off;
  }

  part def FuelTank {
    attribute capacity : FuelVolume = 15.0;
    attribute usableFuel : FuelVolume = 14.0;
    attribute minimumOperatingFuel : FuelVolume = 0.75;

    port fuelOutlet : FuelPort;
  }

  part def GasolineEngine {
    attribute ratedPower : Power = 4.8;
    attribute idleSpeed : RotationalSpeed = 1800.0;
    attribute ratedSpeed : RotationalSpeed = 3600.0;
    attribute maximumCylinderTemperature : Temperature = 240.0;

    port fuelIn : FuelPort;
    port driveOut : EngineDrivePort;
    port exhaustOut : ExhaustPort;
    port control : ControlPort;

    action startEngine : IgniteEngine;
    action consumeFuel : DrawFuel;
  }

  part def CentrifugalPumpHead {
    attribute nominalFlowRate : VolumeFlowRate = 220.0;
    attribute minimumFlowRate : VolumeFlowRate = 40.0;
    attribute maximumFlowRate : VolumeFlowRate = 260.0;
    attribute nominalPressureRise : Pressure = 280.0;
    attribute maximumOutletPressure : Pressure = 420.0;
    attribute minimumInletPressure : Pressure = 20.0;
    attribute requiredPrimeTime : TimeDuration = 12.0;

    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;
    port driveIn : PumpDrivePort;

    action pumpFluid : TransferFluid;
  }

  part def MechanicalCoupling {
    attribute torqueEfficiency : Real = 0.93;
    attribute maximumSpeed : RotationalSpeed = 4000.0;

    port engineSide : EngineDrivePort;
    port pumpSide : PumpDrivePort;
  }

  part def PumpController {
    attribute automaticShutdownEnabled : Boolean = true;
    attribute dryRunPressureThreshold : Pressure = 15.0;
    attribute overspeedThreshold : RotationalSpeed = 3900.0;
    attribute overpressureThreshold : Pressure = 420.0;

    port operatorControl : ControlPort;
    port engineControl : ControlPort;
    port pumpMonitor : ControlPort;

    action faultDetection : DetectPumpFaults;
    state behavior : PumpOperatingStateMachine;
  }

  part def Strainer {
    attribute meshSize : Real = 1.5;
    attribute maximumDifferentialPressure : Pressure = 35.0;

    port fluidIn : FluidInletPort;
    port fluidOut : FluidOutletPort;
  }

  part def DischargeValve {
    attribute openFraction : Real = 1.0;
    attribute ratedPressure : Pressure = 500.0;

    port valveIn : FluidInletPort;
    port valveOut : FluidOutletPort;
  }

  part def GasolinePoweredPumpingSubsystem {
    attribute nominalSubsystemFlowRate : VolumeFlowRate = 220.0;
    attribute nominalDischargePressure : Pressure = 300.0;
    attribute continuousRunTimeAtNominalLoad : TimeDuration = 7200.0;
    attribute dryMass : Real = 38.0;

    port suctionPort : FluidInletPort;
    port dischargePort : FluidOutletPort;
    port commandPort : ControlPort;
    port exhaustPort : ExhaustPort;

    part fuelTank : FuelTank;
    part gasolineEngine : GasolineEngine;
    part coupling : MechanicalCoupling;
    part pumpHead : CentrifugalPumpHead;
    part inletStrainer : Strainer;
    part dischargeValve : DischargeValve;
    part controller : PumpController;

    connect suctionPort to inletStrainer.fluidIn;
    connect inletStrainer.fluidOut to pumpHead.inlet;
    connect pumpHead.outlet to dischargeValve.valveIn;
    connect dischargeValve.valveOut to dischargePort;

    connect fuelTank.fuelOutlet to gasolineEngine.fuelIn;
    connect gasolineEngine.driveOut to coupling.engineSide;
    connect coupling.pumpSide to pumpHead.driveIn;
    connect gasolineEngine.exhaustOut to exhaustPort;

    connect commandPort to controller.operatorControl;
    connect controller.engineControl to gasolineEngine.control;
  }

  requirement def MoveFluidRequirement {
    subject subsystem : GasolinePoweredPumpingSubsystem;

    require constraint {
      subsystem.nominalSubsystemFlowRate >= 200.0
    }

    require constraint {
      subsystem.nominalDischargePressure >= 250.0
    }
  }

  requirement def GasolinePowerRequirement {
    subject subsystem : GasolinePoweredPumpingSubsystem;

    require constraint {
      subsystem.gasolineEngine.ratedPower >= 4.0
    }

    require constraint {
      subsystem.fuelTank.usableFuel >= 10.0
    }
  }

  requirement def OperatingSafetyRequirement {
    subject subsystem : GasolinePoweredPumpingSubsystem;

    require constraint {
      subsystem.controller.automaticShutdownEnabled == true
    }

    require constraint {
      subsystem.pumpHead.maximumOutletPressure <= 500.0
    }

    require constraint {
      subsystem.controller.dryRunPressureThreshold >= 10.0
    }
  }

  requirement def RuntimeRequirement {
    subject subsystem : GasolinePoweredPumpingSubsystem;

    require constraint {
      subsystem.continuousRunTimeAtNominalLoad >= 3600.0
    }
  }

  requirement def PumpingSubsystemRequirement {
    subject subsystem : GasolinePoweredPumpingSubsystem;

    require requirement MoveFluidRequirement {
      subject subsystem = PumpingSubsystemRequirement::subsystem;
    }

    require requirement GasolinePowerRequirement {
      subject subsystem = PumpingSubsystemRequirement::subsystem;
    }

    require requirement OperatingSafetyRequirement {
      subject subsystem = PumpingSubsystemRequirement::subsystem;
    }

    require requirement RuntimeRequirement {
      subject subsystem = PumpingSubsystemRequirement::subsystem;
    }
  }

  part gasolinePoweredPumpSystem : GasolinePoweredPumpingSubsystem;

  satisfy MoveFluidRequirement by gasolinePoweredPumpSystem;
  satisfy GasolinePowerRequirement by gasolinePoweredPumpSystem;
  satisfy OperatingSafetyRequirement by gasolinePoweredPumpSystem;
  satisfy RuntimeRequirement by gasolinePoweredPumpSystem;
}