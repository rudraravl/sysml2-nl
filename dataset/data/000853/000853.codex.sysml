package RicePlantationPumpingSubsystem {

  import ScalarValues::*;
  import SI::*;

  enum def PumpOperatingMode {
    enum idle;
    enum priming;
    enum starting;
    enum pumping;
    enum flushing;
    enum faulted;
    enum shutdown;
  }

  enum def ValvePosition {
    enum closed;
    enum opening;
    enum open;
    enum throttled;
    enum closing;
  }

  enum def FluidKind {
    enum irrigationWater;
    enum siltLadenWater;
    enum air;
  }

  attribute def FlowRate {
    :>> unit = "m^3/h";
  }

  attribute def Pressure {
    :>> unit = "kPa";
  }

  attribute def Head {
    :>> unit = "m";
  }

  attribute def RotationalSpeed {
    :>> unit = "rpm";
  }

  attribute def Power {
    :>> unit = "kW";
  }

  attribute def Temperature {
    :>> unit = "degC";
  }

  attribute def Diameter {
    :>> unit = "mm";
  }

  attribute def Volume {
    :>> unit = "L";
  }

  attribute def TimeDuration {
    :>> unit = "s";
  }

  item def Fluid {
    attribute kind : FluidKind;
    attribute temperature : Temperature;
    attribute volumetricFlow : FlowRate;
    attribute pressure : Pressure;
    attribute suspendedSolidsFraction : Real;
  }

  item def MechanicalPower {
    attribute shaftPower : Power;
    attribute shaftSpeed : RotationalSpeed;
  }

  item def ControlSignal {
    attribute command : String;
    attribute value : Real;
  }

  item def SensorReading {
    attribute name : String;
    attribute value : Real;
    attribute valid : Boolean;
  }

  port def FluidPort {
    inout item fluid : Fluid;
    attribute nominalDiameter : Diameter;
    attribute designPressure : Pressure;
  }

  port def PowerPort {
    in item drivePower : MechanicalPower;
  }

  port def SignalPort {
    inout item signal : ControlSignal;
  }

  port def ReadingPort {
    out item reading : SensorReading;
  }

  interface def FluidConnection {
    end upstream : FluidPort;
    end downstream : FluidPort;
    flow item transferredFluid : Fluid from upstream to downstream;
  }

  interface def ShaftPowerConnection {
    end driver : PowerPort;
    end driven : PowerPort;
    flow item transmittedPower : MechanicalPower from driver to driven;
  }

  part def IntakeCanal {
    port outlet : FluidPort {
      :>> nominalDiameter = 450;
      :>> designPressure = 150;
    }
    attribute waterSurfaceHead : Head;
    attribute minimumSubmergence : Head = 1.2;
  }

  part def DischargeCanal {
    port inlet : FluidPort {
      :>> nominalDiameter = 450;
      :>> designPressure = 150;
    }
    attribute fieldDeliveryHead : Head;
    attribute maximumAllowableBankPressure : Pressure = 80;
  }

  part def TrashRackAndStrainer {
    port inlet : FluidPort;
    port outlet : FluidPort;
    attribute barSpacing : Diameter = 25;
    attribute maximumDifferentialPressure : Pressure = 12;
    attribute removableForCleaning : Boolean = true;
  }

  part def SuctionLine {
    port inlet : FluidPort;
    port outlet : FluidPort;
    attribute insideDiameter : Diameter = 450;
    attribute maximumVelocity : FlowRate = 2300;
    attribute equivalentLength : Real;
  }

  part def FootValve {
    port inlet : FluidPort;
    port outlet : FluidPort;
    attribute position : ValvePosition;
    attribute leakageRateWhenClosed : FlowRate = 1.0;
  }

  part def AMBohnertRicePlantationPump {
    port suction : FluidPort {
      :>> nominalDiameter = 450;
      :>> designPressure = 180;
    }
    port discharge : FluidPort {
      :>> nominalDiameter = 400;
      :>> designPressure = 220;
    }
    port shaftInput : PowerPort;

    attribute manufacturer : String = "A.M. Bohnert";
    attribute modelDescription : String = "Rice Plantation Pump";
    attribute ratedFlow : FlowRate = 1800;
    attribute ratedTotalDynamicHead : Head = 6.5;
    attribute ratedSpeed : RotationalSpeed = 420;
    attribute maximumSpeed : RotationalSpeed = 500;
    attribute minimumPrimedSuctionPressure : Pressure = -55;
    attribute requiredNetPositiveSuctionHead : Head = 2.0;
    attribute hydraulicEfficiency : Real = 0.72;
    attribute impellerDiameter : Diameter = 760;
    attribute casingDrainVolume : Volume = 95;
    attribute currentSpeed : RotationalSpeed;
    attribute developedHead : Head;
    attribute deliveredFlow : FlowRate;
    attribute vibrationLevel : Real;
    attribute bearingTemperature : Temperature;

    action def ConvertShaftPowerToHydraulicFlow {
      in powerIn : MechanicalPower;
      in inletFluid : Fluid;
      out outletFluid : Fluid;
      out actualHead : Head;
      out actualFlow : FlowRate;
    }

    state def PumpLifeCycle {
      state stopped;
      state primed;
      state rotating;
      state deliveringWater;
      state cavitating;
      state overheating;
      state stoppedByFault;

      transition stopped_to_primed
        first stopped
        then primed
        accept ControlSignal
        if signal.command == "prime_complete";

      transition primed_to_rotating
        first primed
        then rotating
        accept ControlSignal
        if signal.command == "start";

      transition rotating_to_delivering
        first rotating
        then deliveringWater
        if deliveredFlow >= 300 and developedHead >= 2.0;

      transition delivering_to_cavitating
        first deliveringWater
        then cavitating
        if suction.fluid.pressure < minimumPrimedSuctionPressure;

      transition delivering_to_overheating
        first deliveringWater
        then overheating
        if bearingTemperature > 85;

      transition cavitating_to_fault
        first cavitating
        then stoppedByFault;

      transition overheating_to_fault
        first overheating
        then stoppedByFault;

      transition delivering_to_stopped
        first deliveringWater
        then stopped
        accept ControlSignal
        if signal.command == "stop";
    }
  }

  part def PrimeSystem {
    port suctionConnection : FluidPort;
    port control : SignalPort;
    attribute primingWaterVolume : Volume = 150;
    attribute maximumPrimeTime : TimeDuration = 180;
    attribute primeComplete : Boolean;

    action def FillPumpCasing {
      in availableWater : Fluid;
      out primed : Boolean;
    }
  }

  part def DriverEngine {
    port shaftOutput : PowerPort;
    port command : SignalPort;

    attribute ratedPower : Power = 55;
    attribute idleSpeed : RotationalSpeed = 650;
    attribute governedSpeed : RotationalSpeed = 1200;
    attribute fuelLevel : Volume;
    attribute oilPressure : Pressure;
    attribute coolantTemperature : Temperature;

    state def EngineState {
      state off;
      state cranking;
      state running;
      state warmup;
      state faultStop;

      transition off_to_cranking
        first off
        then cranking
        accept ControlSignal
        if signal.command == "start_engine";

      transition cranking_to_running
        first cranking
        then running
        if oilPressure > 120;

      transition running_to_warmup
        first running
        then warmup
        if coolantTemperature < 60;

      transition warmup_to_running
        first warmup
        then running
        if coolantTemperature >= 60;

      transition running_to_faultStop
        first running
        then faultStop
        if oilPressure < 80 or coolantTemperature > 105;

      transition running_to_off
        first running
        then off
        accept ControlSignal
        if signal.command == "stop_engine";
    }
  }

  part def BeltOrShaftDrive {
    port driverSide : PowerPort;
    port pumpSide : PowerPort;

    attribute speedRatio : Real = 0.35;
    attribute mechanicalEfficiency : Real = 0.94;
    attribute guardInstalled : Boolean = true;
  }

  part def DischargeLine {
    port inlet : FluidPort;
    port outlet : FluidPort;
    attribute insideDiameter : Diameter = 400;
    attribute maximumWorkingPressure : Pressure = 220;
    attribute equivalentLength : Real;
  }

  part def CheckValve {
    port inlet : FluidPort;
    port outlet : FluidPort;
    attribute crackingPressure : Pressure = 5;
    attribute position : ValvePosition;
  }

  part def DischargeGateValve {
    port inlet : FluidPort;
    port outlet : FluidPort;
    port command : SignalPort;
    attribute position : ValvePosition;
    attribute commandedOpening : Real;
  }

  part def PressureSensor {
    port sensedPort : FluidPort;
    port readingOut : ReadingPort;
    attribute rangeMinimum : Pressure = -100;
    attribute rangeMaximum : Pressure = 300;
    attribute accuracy : Real = 0.01;
  }

  part def FlowMeter {
    port inlet : FluidPort;
    port outlet : FluidPort;
    port readingOut : ReadingPort;
    attribute minimumFlow : FlowRate = 100;
    attribute maximumFlow : FlowRate = 2500;
    attribute accuracy : Real = 0.03;
  }

  part def PumpController {
    port commandIn : SignalPort;
    port engineCommand : SignalPort;
    port valveCommand : SignalPort;
    port primeCommand : SignalPort;
    port pumpStatusIn : ReadingPort;
    port flowIn : ReadingPort;
    port suctionPressureIn : ReadingPort;
    port dischargePressureIn : ReadingPort;

    attribute requestedMode : PumpOperatingMode;
    attribute activeMode : PumpOperatingMode;
    attribute minimumOperatingFlow : FlowRate = 500;
    attribute maximumOperatingFlow : FlowRate = 2000;
    attribute lowSuctionPressureTrip : Pressure = -60;
    attribute highDischargePressureTrip : Pressure = 200;
    attribute startTimeout : TimeDuration = 240;

    action def StartPumping {
      out primeCommandOut : ControlSignal;
      out engineCommandOut : ControlSignal;
      out valveCommandOut : ControlSignal;
    }

    action def StopPumping {
      out engineCommandOut : ControlSignal;
      out valveCommandOut : ControlSignal;
    }

    action def TripOnUnsafeCondition {
      in suctionPressure : SensorReading;
      in dischargePressure : SensorReading;
      in flow : SensorReading;
      out shutdownCommand : ControlSignal;
    }

    state def ControlStateMachine {
      state idle;
      state priming;
      state engineStarting;
      state rampingValve;
      state regulatingFlow;
      state alarmed;
      state stopped;

      transition idle_to_priming
        first idle
        then priming
        accept ControlSignal
        if signal.command == "start_pumping";

      transition priming_to_engineStarting
        first priming
        then engineStarting
        if activeMode == PumpOperatingMode::priming;

      transition engineStarting_to_rampingValve
        first engineStarting
        then rampingValve
        if activeMode == PumpOperatingMode::starting;

      transition rampingValve_to_regulatingFlow
        first rampingValve
        then regulatingFlow
        if activeMode == PumpOperatingMode::pumping;

      transition regulatingFlow_to_alarmed
        first regulatingFlow
        then alarmed
        if suctionPressureIn.reading.value < lowSuctionPressureTrip or dischargePressureIn.reading.value > highDischargePressureTrip;

      transition regulatingFlow_to_stopped
        first regulatingFlow
        then stopped
        accept ControlSignal
        if signal.command == "stop_pumping";

      transition alarmed_to_stopped
        first alarmed
        then stopped;
    }
  }

  part def PumpingSubsystem {
    part sourceCanal : IntakeCanal;
    part trashRack : TrashRackAndStrainer;
    part footValve : FootValve;
    part suctionPipe : SuctionLine;
    part pump : AMBohnertRicePlantationPump;
    part primeSystem : PrimeSystem;
    part engine : DriverEngine;
    part drive : BeltOrShaftDrive;
    part dischargePipe : DischargeLine;
    part checkValve : CheckValve;
    part gateValve : DischargeGateValve;
    part flowMeter : FlowMeter;
    part destinationCanal : DischargeCanal;
    part suctionPressureSensor : PressureSensor;
    part dischargePressureSensor : PressureSensor;
    part controller : PumpController;

    attribute subsystemRatedFlow : FlowRate = 1800;
    attribute subsystemMinimumFlow : FlowRate = 500;
    attribute subsystemMaximumFlow : FlowRate = 2000;
    attribute nominalTotalDynamicHead : Head = 6.5;
    attribute maximumContinuousRuntime : TimeDuration = 43200;
    attribute installedForFloodIrrigation : Boolean = true;

    connect sourceCanal.outlet to trashRack.inlet;
    connect trashRack.outlet to footValve.inlet;
    connect footValve.outlet to suctionPipe.inlet;
    connect suctionPipe.outlet to pump.suction;
    connect pump.discharge to dischargePipe.inlet;
    connect dischargePipe.outlet to checkValve.inlet;
    connect checkValve.outlet to flowMeter.inlet;
    connect flowMeter.outlet to gateValve.inlet;
    connect gateValve.outlet to destinationCanal.inlet;

    connect engine.shaftOutput to drive.driverSide;
    connect drive.pumpSide to pump.shaftInput;

    connect primeSystem.suctionConnection to pump.suction;

    connect suctionPressureSensor.sensedPort to pump.suction;
    connect dischargePressureSensor.sensedPort to pump.discharge;

    connect controller.engineCommand to engine.command;
    connect controller.valveCommand to gateValve.command;
    connect controller.primeCommand to primeSystem.control;
    connect flowMeter.readingOut to controller.flowIn;
    connect suctionPressureSensor.readingOut to controller.suctionPressureIn;
    connect dischargePressureSensor.readingOut to controller.dischargePressureIn;

    action def OperateIrrigationTransfer {
      in startCommand : ControlSignal;
      out deliveredWater : Fluid;
      out finalMode : PumpOperatingMode;
    }

    constraint def HydraulicCapacity {
      in q : FlowRate;
      in h : Head;
      q >= subsystemMinimumFlow and q <= subsystemMaximumFlow and h >= 4.0 and h <= 9.0;
    }

    constraint def SafePressureEnvelope {
      in suctionPressure : Pressure;
      in dischargePressure : Pressure;
      suctionPressure >= -60 and dischargePressure <= 200;
    }

    constraint def DriverAdequacy {
      in requiredPower : Power;
      in availablePower : Power;
      availablePower * drive.mechanicalEfficiency >= requiredPower;
    }
  }

  requirement def ReqMoveIrrigationWater {
    subject subsystem : PumpingSubsystem;
    doc /* The pumping subsystem shall move irrigation water from the intake canal to the discharge canal using an A.M. Bohnert Rice Plantation Pump as the hydraulic energy conversion element. */
  }

  requirement def ReqRatedCapacity {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.pump.ratedFlow >= 1800 and
      subsystem.nominalTotalDynamicHead >= 6.5;
    }
  }

  requirement def ReqPrimeBeforeStart {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.primeSystem.primeComplete == true implies subsystem.pump.currentSpeed >= 0;
    }
  }

  requirement def ReqProtectAgainstCavitation {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.pump.suction.fluid.pressure >= subsystem.controller.lowSuctionPressureTrip;
    }
  }

  requirement def ReqDischargePressureLimit {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.pump.discharge.fluid.pressure <= subsystem.controller.highDischargePressureTrip;
    }
  }

  requirement def ReqFlowControl {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.flowMeter.maximumFlow >= subsystem.subsystemMaximumFlow and
      subsystem.flowMeter.minimumFlow <= subsystem.subsystemMinimumFlow;
    }
  }

  requirement def ReqBackflowPrevention {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.checkValve.crackingPressure > 0 and
      subsystem.footValve.leakageRateWhenClosed <= 1.0;
    }
  }

  requirement def ReqMaintainableStrainer {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.trashRack.removableForCleaning == true and
      subsystem.trashRack.barSpacing <= 25;
    }
  }

  requirement def ReqGuardedDrive {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.drive.guardInstalled == true;
    }
  }

  requirement def ReqEnginePowerMargin {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.engine.ratedPower >= 55 and
      subsystem.drive.mechanicalEfficiency >= 0.90;
    }
  }

  satisfy ReqMoveIrrigationWater by PumpingSubsystem::pump;
  satisfy ReqRatedCapacity by PumpingSubsystem::pump;
  satisfy ReqPrimeBeforeStart by PumpingSubsystem::primeSystem;
  satisfy ReqProtectAgainstCavitation by PumpingSubsystem::controller;
  satisfy ReqDischargePressureLimit by PumpingSubsystem::controller;
  satisfy ReqFlowControl by PumpingSubsystem::flowMeter;
  satisfy ReqBackflowPrevention by PumpingSubsystem::checkValve;
  satisfy ReqMaintainableStrainer by PumpingSubsystem::trashRack;
  satisfy ReqGuardedDrive by PumpingSubsystem::drive;
  satisfy ReqEnginePowerMargin by PumpingSubsystem::engine;
}