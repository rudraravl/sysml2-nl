package PistonPumpingSubsystemModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Pressure :> ISQ::PressureValue;
  attribute def DifferentialPressure :> ISQ::PressureValue;
  attribute def Temperature :> ISQ::ThermodynamicTemperatureValue;
  attribute def Density :> ISQ::DensityValue;
  attribute def DynamicViscosity :> ISQ::DynamicViscosityValue;
  attribute def VolumetricFlowRate :> ISQ::VolumeFlowRateValue;
  attribute def Volume :> ISQ::VolumeValue;
  attribute def Length :> ISQ::LengthValue;
  attribute def Area :> ISQ::AreaValue;
  attribute def Diameter :> ISQ::LengthValue;
  attribute def Frequency :> ISQ::FrequencyValue;
  attribute def Force :> ISQ::ForceValue;
  attribute def Torque :> ISQ::TorqueValue;
  attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
  attribute def Power :> ISQ::PowerValue;
  attribute def Voltage :> ISQ::ElectricPotentialValue;
  attribute def Current :> ISQ::ElectricCurrentValue;
  attribute def Time :> ISQ::TimeValue;
  attribute def Efficiency :> ScalarValues::Real;
  attribute def Ratio :> ScalarValues::Real;

  enum def ValvePosition {
    enum open;
    enum closed;
    enum transitioning;
  }

  enum def PumpMode {
    enum stopped;
    enum standby;
    enum priming;
    enum running;
    enum depressurizing;
    enum faulted;
    enum maintenance;
  }

  enum def FaultCode {
    enum none;
    enum lowSuctionPressure;
    enum overPressure;
    enum motorOverCurrent;
    enum noFlow;
    enum valveStuck;
    enum pistonSealLeakage;
    enum excessiveTemperature;
  }

  item def HydraulicFluid {
    attribute density : Density = 860 [kg/m^3];
    attribute dynamicViscosity : DynamicViscosity = 0.032 [Pa*s];
    attribute bulkModulus : Pressure = 1.45e9 [Pa];
    attribute temperature : Temperature = 293.15 [K];
    attribute vaporPressure : Pressure = 2500 [Pa];
  }

  item def PressurizedHydraulicFluid :> HydraulicFluid {
    attribute pressure : Pressure;
    attribute flowRate : VolumetricFlowRate;
  }

  item def StartCommand;
  item def StopCommand;
  item def ResetCommand;
  item def EnableCommand;
  item def DisableCommand;

  item def PumpStatus {
    attribute mode : PumpMode;
    attribute fault : FaultCode;
    attribute measuredDischargePressure : Pressure;
    attribute measuredSuctionPressure : Pressure;
    attribute measuredFlowRate : VolumetricFlowRate;
    attribute measuredMotorCurrent : Current;
  }

  item def ElectricalPower {
    attribute lineVoltage : Voltage = 48 [V];
    attribute phaseCurrent : Current;
    attribute availablePower : Power;
  }

  item def MechanicalRotation {
    attribute speed : RotationalSpeed;
    attribute torque : Torque;
    attribute transmittedPower : Power;
  }

  port def FluidPort {
    inout item fluid : HydraulicFluid;
    attribute pressure : Pressure;
    attribute flowRate : VolumetricFlowRate;
    attribute temperature : Temperature;
  }

  port def ElectricalPowerPort {
    in item power : ElectricalPower;
  }

  port def MechanicalPowerPort {
    inout item rotation : MechanicalRotation;
  }

  port def CommandPort {
    in item start : StartCommand;
    in item stop : StopCommand;
    in item reset : ResetCommand;
    in item enable : EnableCommand;
    in item disable : DisableCommand;
  }

  port def StatusPort {
    out item status : PumpStatus;
  }

  port def SensorPort {
    out attribute pressure : Pressure;
    out attribute flowRate : VolumetricFlowRate;
    out attribute temperature : Temperature;
  }

  connection def FluidConnection {
    end upstream : FluidPort;
    end downstream : FluidPort;
    item conveyedFluid : HydraulicFluid;
    attribute internalVolume : Volume;
    attribute pressureDrop : DifferentialPressure;
  }

  connection def ElectricalConnection {
    end source : ElectricalPowerPort;
    end load : ElectricalPowerPort;
    item suppliedPower : ElectricalPower;
  }

  connection def MechanicalConnection {
    end driver : MechanicalPowerPort;
    end driven : MechanicalPowerPort;
    item transmittedRotation : MechanicalRotation;
  }

  constraint def PistonDisplacementFlowConstraint {
    in pistonArea : Area;
    in strokeLength : Length;
    in strokeFrequency : Frequency;
    in volumetricEfficiency : Efficiency;
    in actualFlow : VolumetricFlowRate;
    constraint {
      actualFlow == pistonArea * strokeLength * strokeFrequency * volumetricEfficiency
    }
  }

  constraint def PistonAreaConstraint {
    in boreDiameter : Diameter;
    in pistonArea : Area;
    constraint {
      pistonArea == 3.141592653589793 * boreDiameter * boreDiameter / 4.0
    }
  }

  constraint def PressureRiseConstraint {
    in dischargePressure : Pressure;
    in suctionPressure : Pressure;
    in pressureRise : DifferentialPressure;
    constraint {
      pressureRise == dischargePressure - suctionPressure
    }
  }

  constraint def PumpHydraulicPowerConstraint {
    in pressureRise : DifferentialPressure;
    in flowRate : VolumetricFlowRate;
    in hydraulicPower : Power;
    constraint {
      hydraulicPower == pressureRise * flowRate
    }
  }

  constraint def EfficiencyConstraint {
    in hydraulicPower : Power;
    in shaftPower : Power;
    in overallEfficiency : Efficiency;
    constraint {
      hydraulicPower <= shaftPower * overallEfficiency
    }
  }

  action def SuctionStroke {
    in item supplyFluid : HydraulicFluid;
    out item chamberCharge : HydraulicFluid;
    in suctionValvePosition : ValvePosition;
    in dischargeValvePosition : ValvePosition;
    in chamberPressure : Pressure;
    in inletPressure : Pressure;

    precondition {
      suctionValvePosition == ValvePosition::open and
      dischargeValvePosition == ValvePosition::closed and
      chamberPressure < inletPressure
    }

    postcondition {
      chamberCharge == supplyFluid
    }
  }

  action def CompressionStroke {
    in item chamberCharge : HydraulicFluid;
    out item compressedCharge : PressurizedHydraulicFluid;
    in suctionValvePosition : ValvePosition;
    in dischargeValvePosition : ValvePosition;
    in chamberPressure : Pressure;
    in dischargeLinePressure : Pressure;

    precondition {
      suctionValvePosition == ValvePosition::closed and
      dischargeValvePosition == ValvePosition::closed
    }

    postcondition {
      compressedCharge.pressure >= dischargeLinePressure
    }
  }

  action def DischargeStroke {
    in item compressedCharge : PressurizedHydraulicFluid;
    out item deliveredFluid : PressurizedHydraulicFluid;
    in suctionValvePosition : ValvePosition;
    in dischargeValvePosition : ValvePosition;
    in chamberPressure : Pressure;
    in dischargeLinePressure : Pressure;

    precondition {
      suctionValvePosition == ValvePosition::closed and
      dischargeValvePosition == ValvePosition::open and
      chamberPressure >= dischargeLinePressure
    }

    postcondition {
      deliveredFluid == compressedCharge
    }
  }

  action def PistonPumpCycle {
    in item incomingFluid : HydraulicFluid;
    out item outgoingFluid : PressurizedHydraulicFluid;
    in boreDiameter : Diameter;
    in strokeLength : Length;
    in strokeFrequency : Frequency;
    in volumetricEfficiency : Efficiency;

    action suction : SuctionStroke;
    action compression : CompressionStroke;
    action discharge : DischargeStroke;

    succession suction then compression;
    succession compression then discharge;

    flow incomingFluid to suction.supplyFluid;
    flow suction.chamberCharge to compression.chamberCharge;
    flow compression.compressedCharge to discharge.compressedCharge;
    flow discharge.deliveredFluid to outgoingFluid;
  }

  state def PumpingSubsystemStateMachine {
    attribute commandedMode : PumpMode;
    attribute activeFault : FaultCode = FaultCode::none;

    entry; then stopped;

    state stopped {
      entry action {
        commandedMode = PumpMode::stopped;
      }
    }

    state standby {
      entry action {
        commandedMode = PumpMode::standby;
      }
    }

    state priming {
      entry action {
        commandedMode = PumpMode::priming;
      }
    }

    state running {
      entry action {
        commandedMode = PumpMode::running;
      }
    }

    state depressurizing {
      entry action {
        commandedMode = PumpMode::depressurizing;
      }
    }

    state faulted {
      entry action {
        commandedMode = PumpMode::faulted;
      }
    }

    transition stopped_to_standby
      first stopped
      accept EnableCommand
      then standby;

    transition standby_to_priming
      first standby
      accept StartCommand
      then priming;

    transition priming_to_running
      first priming
      if activeFault == FaultCode::none
      then running;

    transition running_to_depressurizing
      first running
      accept StopCommand
      then depressurizing;

    transition depressurizing_to_standby
      first depressurizing
      then standby;

    transition any_to_faulted_from_low_suction
      first running
      if activeFault == FaultCode::lowSuctionPressure
      then faulted;

    transition any_to_faulted_from_overpressure
      first running
      if activeFault == FaultCode::overPressure
      then faulted;

    transition faulted_to_standby
      first faulted
      accept ResetCommand
      if activeFault == FaultCode::none
      then standby;

    transition standby_to_stopped
      first standby
      accept DisableCommand
      then stopped;
  }

  part def Reservoir {
    port outlet : FluidPort;
    port returnInlet : FluidPort;

    attribute usableVolume : Volume = 0.030 [m^3];
    attribute minimumOperatingVolume : Volume = 0.006 [m^3];
    attribute ventPressure : Pressure = 101325 [Pa];
    attribute storedFluidTemperature : Temperature = 293.15 [K];

    item storedFluid : HydraulicFluid;
  }

  part def SuctionFilter {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute nominalMicronRating : Length = 25.0e-6 [m];
    attribute cleanPressureDrop : DifferentialPressure = 8000 [Pa];
    attribute cloggedPressureDropLimit : DifferentialPressure = 45000 [Pa];

    connect inlet to outlet;
  }

  part def PipeSegment {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute internalDiameter : Diameter = 0.012 [m];
    attribute length : Length = 1.20 [m];
    attribute internalVolume : Volume = 1.36e-4 [m^3];
    attribute nominalPressureDrop : DifferentialPressure = 12000 [Pa];

    connect inlet to outlet;
  }

  part def CheckValve {
    port upstream : FluidPort;
    port downstream : FluidPort;

    attribute crackingPressure : DifferentialPressure = 15000 [Pa];
    attribute reverseLeakageFlow : VolumetricFlowRate = 1.0e-8 [m^3/s];
    attribute position : ValvePosition = ValvePosition::closed;

    constraint forwardOpening {
      downstream.pressure + crackingPressure <= upstream.pressure implies position == ValvePosition::open
    }

    constraint reverseBlocking {
      downstream.pressure > upstream.pressure implies position == ValvePosition::closed
    }
  }

  part def ReliefValve {
    port protectedLine : FluidPort;
    port bypassReturn : FluidPort;

    attribute setPressure : Pressure = 1.20e7 [Pa];
    attribute reseatPressure : Pressure = 1.05e7 [Pa];
    attribute bypassFlowCapacity : VolumetricFlowRate = 8.0e-4 [m^3/s];
    attribute position : ValvePosition = ValvePosition::closed;

    constraint opensAtSetPressure {
      protectedLine.pressure >= setPressure implies position == ValvePosition::open
    }
  }

  part def DischargeAccumulator {
    port fluidPort : FluidPort;

    attribute gasPrechargePressure : Pressure = 4.0e6 [Pa];
    attribute shellRatedPressure : Pressure = 1.6e7 [Pa];
    attribute fluidVolumeCapacity : Volume = 0.002 [m^3];
    attribute dampingRatio : Ratio = 0.65;
  }

  part def PressureSensor {
    port sensedPort : FluidPort;
    port signal : SensorPort;

    attribute measurementRangeMin : Pressure = 0 [Pa];
    attribute measurementRangeMax : Pressure = 1.6e7 [Pa];
    attribute accuracy : Ratio = 0.005;

    constraint signalFollowsFluidPressure {
      signal.pressure == sensedPort.pressure
    }
  }

  part def FlowSensor {
    port sensedPort : FluidPort;
    port signal : SensorPort;

    attribute measurementRangeMin : VolumetricFlowRate = 0 [m^3/s];
    attribute measurementRangeMax : VolumetricFlowRate = 0.001 [m^3/s];
    attribute accuracy : Ratio = 0.01;

    constraint signalFollowsFluidFlow {
      signal.flowRate == sensedPort.flowRate
    }
  }

  part def ElectricMotor {
    port electricalInput : ElectricalPowerPort;
    port shaftOutput : MechanicalPowerPort;

    attribute ratedVoltage : Voltage = 48 [V];
    attribute ratedCurrent : Current = 32 [A];
    attribute ratedPower : Power = 1100 [W];
    attribute nominalSpeed : RotationalSpeed = 157.08 [rad/s];
    attribute peakTorque : Torque = 11.5 [N*m];
    attribute motorEfficiency : Efficiency = 0.88;

    constraint motorPowerLimit {
      shaftOutput.rotation.transmittedPower <= ratedPower * motorEfficiency
    }
  }

  part def CrankDrive {
    port shaftInput : MechanicalPowerPort;
    port reciprocatingOutput : MechanicalPowerPort;

    attribute gearRatio : Ratio = 1.0;
    attribute crankRadius : Length = 0.015 [m];
    attribute mechanicalEfficiency : Efficiency = 0.94;

    constraint crankStroke {
      2.0 * crankRadius == 0.030 [m]
    }
  }

  part def PistonAssembly {
    port mechanicalInput : MechanicalPowerPort;

    attribute boreDiameter : Diameter = 0.032 [m];
    attribute pistonArea : Area = 8.042e-4 [m^2];
    attribute strokeLength : Length = 0.030 [m];
    attribute sealLeakageRate : VolumetricFlowRate = 2.0e-7 [m^3/s];
    attribute maximumRodForce : Force = 9500 [N];

    constraint areaFromBore : PistonAreaConstraint {
      in boreDiameter = boreDiameter;
      in pistonArea = pistonArea;
    }
  }

  part def PumpCylinderChamber {
    port suctionPort : FluidPort;
    port dischargePort : FluidPort;

    attribute sweptVolume : Volume = 2.413e-5 [m^3];
    attribute clearanceVolume : Volume = 1.2e-6 [m^3];
    attribute maximumWorkingPressure : Pressure = 1.4e7 [Pa];
    attribute chamberPressure : Pressure;

    constraint pressureWithinRating {
      chamberPressure <= maximumWorkingPressure
    }
  }

  part def PistonPump {
    port inlet : FluidPort;
    port outlet : FluidPort;
    port shaftInput : MechanicalPowerPort;
    port command : CommandPort;
    port status : StatusPort;

    part suctionValve : CheckValve {
      attribute crackingPressure = 8000 [Pa];
    }

    part dischargeValve : CheckValve {
      attribute crackingPressure = 12000 [Pa];
    }

    part chamber : PumpCylinderChamber;
    part piston : PistonAssembly;
    part crank : CrankDrive;

    attribute boreDiameter : Diameter = 0.032 [m];
    attribute strokeLength : Length = 0.030 [m];
    attribute strokeFrequency : Frequency = 24.0 [Hz];
    attribute volumetricEfficiency : Efficiency = 0.86;
    attribute mechanicalEfficiency : Efficiency = 0.90;
    attribute nominalFlowRate : VolumetricFlowRate = 4.98e-4 [m^3/s];
    attribute minimumSuctionPressure : Pressure = 55000 [Pa];
    attribute nominalDischargePressure : Pressure = 8.0e6 [Pa];
    attribute maximumDischargePressure : Pressure = 1.2e7 [Pa];
    attribute hydraulicPower : Power = 3984 [W];
    attribute shaftPowerRequired : Power = 4427 [W];

    perform action pumpCycle : PistonPumpCycle {
      in boreDiameter = boreDiameter;
      in strokeLength = strokeLength;
      in strokeFrequency = strokeFrequency;
      in volumetricEfficiency = volumetricEfficiency;
    }

    constraint displacementFlow : PistonDisplacementFlowConstraint {
      in pistonArea = piston.pistonArea;
      in strokeLength = strokeLength;
      in strokeFrequency = strokeFrequency;
      in volumetricEfficiency = volumetricEfficiency;
      in actualFlow = nominalFlowRate;
    }

    constraint dischargePressureLimit {
      outlet.pressure <= maximumDischargePressure
    }

    constraint suctionPressureLimit {
      inlet.pressure >= minimumSuctionPressure
    }

    connect inlet to suctionValve.upstream;
    connect suctionValve.downstream to chamber.suctionPort;
    connect chamber.dischargePort to dischargeValve.upstream;
    connect dischargeValve.downstream to outlet;
    connect shaftInput to crank.shaftInput;
    connect crank.reciprocatingOutput to piston.mechanicalInput;
  }

  part def PumpController {
    port commandInput : CommandPort;
    port pumpCommand : CommandPort;
    port pumpStatus : StatusPort;
    port suctionPressureSignal : SensorPort;
    port dischargePressureSignal : SensorPort;
    port flowSignal : SensorPort;

    attribute commandedMode : PumpMode = PumpMode::stopped;
    attribute detectedFault : FaultCode = FaultCode::none;
    attribute lowSuctionTripPressure : Pressure = 50000 [Pa];
    attribute overPressureTripPressure : Pressure = 1.22e7 [Pa];
    attribute minimumRunningFlow : VolumetricFlowRate = 2.0e-4 [m^3/s];

    exhibit state controllerStates : PumpingSubsystemStateMachine;

    constraint lowSuctionFaultDetection {
      suctionPressureSignal.pressure < lowSuctionTripPressure implies detectedFault == FaultCode::lowSuctionPressure
    }

    constraint overPressureFaultDetection {
      dischargePressureSignal.pressure > overPressureTripPressure implies detectedFault == FaultCode::overPressure
    }

    constraint noFlowFaultDetection {
      commandedMode == PumpMode::running and flowSignal.flowRate < minimumRunningFlow implies detectedFault == FaultCode::noFlow
    }
  }

  part def PumpingSubsystem {
    port suctionInterface : FluidPort;
    port dischargeInterface : FluidPort;
    port electricalSupply : ElectricalPowerPort;
    port commandInterface : CommandPort;
    port statusInterface : StatusPort;

    part reservoir : Reservoir;
    part suctionFilter : SuctionFilter;
    part suctionPipe : PipeSegment {
      attribute internalDiameter = 0.016 [m];
      attribute length = 0.65 [m];
    }

    part pistonPump : PistonPump;
    part motor : ElectricMotor;
    part dischargePipe : PipeSegment {
      attribute internalDiameter = 0.010 [m];
      attribute length = 0.90 [m];
    }

    part accumulator : DischargeAccumulator;
    part reliefValve : ReliefValve;
    part suctionPressureSensor : PressureSensor;
    part dischargePressureSensor : PressureSensor;
    part flowSensor : FlowSensor;
    part controller : PumpController;

    attribute requiredFlowRate : VolumetricFlowRate = 3.5e-4 [m^3/s];
    attribute requiredPressureRise : DifferentialPressure = 7.0e6 [Pa];
    attribute maximumAllowedDischargePressure : Pressure = 1.2e7 [Pa];
    attribute minimumAllowedSuctionPressure : Pressure = 50000 [Pa];
    attribute normalFluidTemperatureMin : Temperature = 278.15 [K];
    attribute normalFluidTemperatureMax : Temperature = 333.15 [K];
    attribute subsystemMode : PumpMode = PumpMode::stopped;

    connect suctionInterface to reservoir.outlet;
    connect reservoir.outlet to suctionFilter.inlet;
    connect suctionFilter.outlet to suctionPipe.inlet;
    connect suctionPipe.outlet to pistonPump.inlet;
    connect pistonPump.outlet to dischargePipe.inlet;
    connect dischargePipe.outlet to accumulator.fluidPort;
    connect accumulator.fluidPort to dischargeInterface;
    connect dischargeInterface to reliefValve.protectedLine;
    connect reliefValve.bypassReturn to reservoir.returnInlet;

    connect electricalSupply to motor.electricalInput;
    connect motor.shaftOutput to pistonPump.shaftInput;

    connect commandInterface to controller.commandInput;
    connect controller.pumpCommand to pistonPump.command;
    connect pistonPump.status to controller.pumpStatus;
    connect pistonPump.status to statusInterface;

    connect pistonPump.inlet to suctionPressureSensor.sensedPort;
    connect pistonPump.outlet to dischargePressureSensor.sensedPort;
    connect dischargeInterface to flowSensor.sensedPort;
    connect suctionPressureSensor.signal to controller.suctionPressureSignal;
    connect dischargePressureSensor.signal to controller.dischargePressureSignal;
    connect flowSensor.signal to controller.flowSignal;

    exhibit state subsystemStates : PumpingSubsystemStateMachine;

    constraint movesRequiredFlow {
      dischargeInterface.flowRate >= requiredFlowRate
    }

    constraint providesRequiredPressureRise : PressureRiseConstraint {
      in dischargePressure = dischargeInterface.pressure;
      in suctionPressure = suctionInterface.pressure;
      in pressureRise = requiredPressureRise;
    }

    constraint safeDischargePressure {
      dischargeInterface.pressure <= maximumAllowedDischargePressure
    }

    constraint safeSuctionPressure {
      pistonPump.inlet.pressure >= minimumAllowedSuctionPressure
    }

    constraint fluidTemperatureRange {
      dischargeInterface.temperature >= normalFluidTemperatureMin and
      dischargeInterface.temperature <= normalFluidTemperatureMax
    }
  }

  requirement def MoveFluidUsingPistonPumpRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.dischargeInterface.flowRate >= subsystem.requiredFlowRate
    }

    require constraint {
      subsystem.pistonPump.nominalFlowRate >= subsystem.requiredFlowRate
    }
  }

  requirement def PistonPumpArchitectureRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.pistonPump.strokeLength > 0 [m]
    }

    require constraint {
      subsystem.pistonPump.boreDiameter > 0 [m]
    }

    require constraint {
      subsystem.pistonPump.volumetricEfficiency >= 0.75
    }
  }

  requirement def DischargePressureRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.dischargeInterface.pressure - subsystem.suctionInterface.pressure >= subsystem.requiredPressureRise
    }

    require constraint {
      subsystem.dischargeInterface.pressure <= subsystem.maximumAllowedDischargePressure
    }
  }

  requirement def BackflowPreventionRequirement {
    subject pump : PistonPump;

    require constraint {
      pump.suctionValve.reverseLeakageFlow <= 1.0e-7 [m^3/s]
    }

    require constraint {
      pump.dischargeValve.reverseLeakageFlow <= 1.0e-7 [m^3/s]
    }
  }

  requirement def OverPressureProtectionRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.reliefValve.setPressure <= subsystem.maximumAllowedDischargePressure
    }

    require constraint {
      subsystem.reliefValve.bypassFlowCapacity >= subsystem.pistonPump.nominalFlowRate
    }
  }

  requirement def FaultMonitoringRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.controller.lowSuctionTripPressure >= subsystem.minimumAllowedSuctionPressure
    }

    require constraint {
      subsystem.controller.overPressureTripPressure >= subsystem.maximumAllowedDischargePressure
    }
  }

  part pumpingSubsystem : PumpingSubsystem;

  requirement moveFluidUsingPistonPump : MoveFluidUsingPistonPumpRequirement {
    subject subsystem = pumpingSubsystem;
  }

  requirement pistonPumpArchitecture : PistonPumpArchitectureRequirement {
    subject subsystem = pumpingSubsystem;
  }

  requirement dischargePressure : DischargePressureRequirement {
    subject subsystem = pumpingSubsystem;
  }

  requirement backflowPrevention : BackflowPreventionRequirement {
    subject pump = pumpingSubsystem.pistonPump;
  }

  requirement overPressureProtection : OverPressureProtectionRequirement {
    subject subsystem = pumpingSubsystem;
  }

  requirement faultMonitoring : FaultMonitoringRequirement {
    subject subsystem = pumpingSubsystem;
  }

  satisfy moveFluidUsingPistonPump by pumpingSubsystem.pistonPump;
  satisfy pistonPumpArchitecture by pumpingSubsystem.pistonPump;
  satisfy dischargePressure by pumpingSubsystem.pistonPump;
  satisfy backflowPrevention by pumpingSubsystem.pistonPump.suctionValve;
  satisfy backflowPrevention by pumpingSubsystem.pistonPump.dischargeValve;
  satisfy overPressureProtection by pumpingSubsystem.reliefValve;
  satisfy faultMonitoring by pumpingSubsystem.controller;
}
