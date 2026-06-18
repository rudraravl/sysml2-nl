package PistonBasedSystemModel {

  import ScalarValues::*;

  attribute def Length :> Real {
    attribute unitSymbol : String = "m";
    attribute quantityKind : String = "length";
  }

  attribute def Area :> Real {
    attribute unitSymbol : String = "m^2";
    attribute quantityKind : String = "area";
  }

  attribute def Volume :> Real {
    attribute unitSymbol : String = "m^3";
    attribute quantityKind : String = "volume";
  }

  attribute def Pressure :> Real {
    attribute unitSymbol : String = "Pa";
    attribute quantityKind : String = "pressure";
  }

  attribute def Force :> Real {
    attribute unitSymbol : String = "N";
    attribute quantityKind : String = "force";
  }

  attribute def Velocity :> Real {
    attribute unitSymbol : String = "m/s";
    attribute quantityKind : String = "linear velocity";
  }

  attribute def Acceleration :> Real {
    attribute unitSymbol : String = "m/s^2";
    attribute quantityKind : String = "linear acceleration";
  }

  attribute def Mass :> Real {
    attribute unitSymbol : String = "kg";
    attribute quantityKind : String = "mass";
  }

  attribute def Temperature :> Real {
    attribute unitSymbol : String = "K";
    attribute quantityKind : String = "thermodynamic temperature";
  }

  attribute def FlowRate :> Real {
    attribute unitSymbol : String = "m^3/s";
    attribute quantityKind : String = "volumetric flow rate";
  }

  attribute def Viscosity :> Real {
    attribute unitSymbol : String = "Pa*s";
    attribute quantityKind : String = "dynamic viscosity";
  }

  attribute def Voltage :> Real {
    attribute unitSymbol : String = "V";
    attribute quantityKind : String = "electric potential";
  }

  attribute def Current :> Real {
    attribute unitSymbol : String = "A";
    attribute quantityKind : String = "electric current";
  }

  attribute def Power :> Real {
    attribute unitSymbol : String = "W";
    attribute quantityKind : String = "power";
  }

  attribute def Time :> Real {
    attribute unitSymbol : String = "s";
    attribute quantityKind : String = "time";
  }

  attribute def Ratio :> Real {
    attribute unitSymbol : String = "1";
    attribute quantityKind : String = "dimensionless ratio";
  }

  enum def ActuationMode {
    enum idle;
    enum extend;
    enum retract;
    enum hold;
    enum depressurize;
    enum fault;
  }

  enum def StrokeEnd {
    enum none;
    enum fullyRetracted;
    enum fullyExtended;
  }

  enum def HealthState {
    enum nominal;
    enum degraded;
    enum faulted;
  }

  item def HydraulicFluid {
    attribute density : Mass = 850.0;
    attribute temperature : Temperature = 313.15;
    attribute dynamicViscosity : Viscosity = 0.046;
    attribute bulkModulus : Pressure = 1400000000.0;
    attribute contaminationClass : String = "ISO 4406 18/16/13";
  }

  item def ElectricalPower {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute availablePower : Power;
  }

  item def MotionCommand {
    attribute requestedMode : ActuationMode;
    attribute targetPosition : Length;
    attribute targetVelocity : Velocity;
    attribute maximumForce : Force;
  }

  item def ValveCommand {
    attribute commandedMode : ActuationMode;
    attribute spoolOpening : Ratio;
  }

  item def PistonTelemetry {
    attribute measuredPosition : Length;
    attribute measuredVelocity : Velocity;
    attribute chamberAPressure : Pressure;
    attribute chamberBPressure : Pressure;
    attribute estimatedOutputForce : Force;
    attribute strokeEnd : StrokeEnd;
    attribute health : HealthState;
  }

  item def TranslationalForce {
    attribute magnitude : Force;
    attribute velocity : Velocity;
    attribute position : Length;
  }

  item def PressureMeasurement {
    attribute measuredPressure : Pressure;
    attribute measurementTemperature : Temperature;
  }

  port def ElectricalPowerPort {
    in item suppliedPower : ElectricalPower;
  }

  port def CommandInputPort {
    in item command : MotionCommand;
  }

  port def TelemetryOutputPort {
    out item telemetry : PistonTelemetry;
  }

  port def ValveControlPort {
    in item valveCommand : ValveCommand;
  }

  port def ControllerValvePort {
    out item valveCommand : ValveCommand;
  }

  port def HydraulicSupplyPort {
    in item fluid : HydraulicFluid;
    in attribute supplyPressure : Pressure;
    in attribute supplyFlow : FlowRate;
  }

  port def HydraulicReturnPort {
    out item fluid : HydraulicFluid;
    out attribute returnPressure : Pressure;
    out attribute returnFlow : FlowRate;
  }

  port def BidirectionalHydraulicPort {
    inout item fluid : HydraulicFluid;
    inout attribute pressure : Pressure;
    inout attribute flow : FlowRate;
  }

  port def TranslationalMechanicalPort {
    in item reactionForce : TranslationalForce;
    out item deliveredForce : TranslationalForce;
    out attribute position : Length;
    out attribute velocity : Velocity;
  }

  port def SensorOutputPort {
    out item telemetry : PistonTelemetry;
  }

  port def PressureSensorPort {
    in attribute sensedPressure : Pressure;
    out item measurement : PressureMeasurement;
  }

  constraint def CircularPistonArea {
    in boreDiameter : Length;
    out pistonArea : Area;
    pistonArea == 3.141592653589793 * boreDiameter * boreDiameter / 4.0;
  }

  constraint def AnnularRodSideArea {
    in boreDiameter : Length;
    in rodDiameter : Length;
    out annularArea : Area;
    annularArea == 3.141592653589793 * (boreDiameter * boreDiameter - rodDiameter * rodDiameter) / 4.0;
  }

  constraint def HydraulicForceBalance {
    in pressureA : Pressure;
    in pressureB : Pressure;
    in areaA : Area;
    in areaB : Area;
    in sealFriction : Force;
    out netForce : Force;
    netForce == pressureA * areaA - pressureB * areaB - sealFriction;
  }

  constraint def StrokeLimit {
    in position : Length;
    in minimumPosition : Length;
    in maximumPosition : Length;
    position >= minimumPosition and position <= maximumPosition;
  }

  constraint def VelocityLimit {
    in velocity : Velocity;
    in maximumVelocity : Velocity;
    velocity >= -maximumVelocity and velocity <= maximumVelocity;
  }

  action def ReceiveMotionCommand {
    in item requestedCommand : MotionCommand;
    out item acceptedCommand : MotionCommand;
  }

  action def ComputeValveCommand {
    in item acceptedCommand : MotionCommand;
    in item feedback : PistonTelemetry;
    out item valveCommand : ValveCommand;
  }

  action def PressurizeHydraulicFluid {
    in item inletFluid : HydraulicFluid;
    in attribute inletPressure : Pressure;
    in attribute motorPower : Power;
    out item outletFluid : HydraulicFluid;
    out attribute outletPressure : Pressure;
    out attribute outletFlow : FlowRate;
  }

  action def MeterFlowToCylinder {
    in item valveCommand : ValveCommand;
    in attribute supplyPressure : Pressure;
    in attribute returnPressure : Pressure;
    out attribute chamberAFlow : FlowRate;
    out attribute chamberBFlow : FlowRate;
  }

  action def ConvertPressureToLinearMotion {
    in attribute chamberAPressure : Pressure;
    in attribute chamberBPressure : Pressure;
    in attribute pistonHeadArea : Area;
    in attribute rodSideArea : Area;
    in attribute resistingLoad : Force;
    out attribute actuatorForce : Force;
    out attribute pistonAcceleration : Acceleration;
    out attribute pistonVelocity : Velocity;
    out attribute pistonPosition : Length;
  }

  action def TransmitLinearForceToLoad {
    in item pistonForce : TranslationalForce;
    out item loadForce : TranslationalForce;
  }

  action def GenerateTelemetry {
    in attribute pistonPosition : Length;
    in attribute pistonVelocity : Velocity;
    in attribute pressureA : Pressure;
    in attribute pressureB : Pressure;
    in attribute outputForce : Force;
    out item telemetry : PistonTelemetry;
  }

  action def PerformPistonActuation {
    in item command : MotionCommand;
    in item electricalPower : ElectricalPower;
    in item inletFluid : HydraulicFluid;
    in item externalReaction : TranslationalForce;
    out item telemetry : PistonTelemetry;
    out item deliveredForce : TranslationalForce;

    action receiveCommand : ReceiveMotionCommand;
    action computeValveCommand : ComputeValveCommand;
    action pressurizeFluid : PressurizeHydraulicFluid;
    action meterCylinderFlow : MeterFlowToCylinder;
    action convertPressure : ConvertPressureToLinearMotion;
    action transmitForce : TransmitLinearForceToLoad;
    action generateTelemetry : GenerateTelemetry;

    flow command to receiveCommand.requestedCommand;
    flow receiveCommand.acceptedCommand to computeValveCommand.acceptedCommand;
    flow computeValveCommand.valveCommand to meterCylinderFlow.valveCommand;
    flow electricalPower.availablePower to pressurizeFluid.motorPower;
    flow inletFluid to pressurizeFluid.inletFluid;
    flow pressurizeFluid.outletPressure to meterCylinderFlow.supplyPressure;
    flow convertPressure.actuatorForce to deliveredForce.magnitude;
    flow convertPressure.pistonVelocity to deliveredForce.velocity;
    flow convertPressure.pistonPosition to deliveredForce.position;
    flow deliveredForce to transmitForce.pistonForce;
    flow convertPressure.pistonPosition to generateTelemetry.pistonPosition;
    flow convertPressure.pistonVelocity to generateTelemetry.pistonVelocity;
    flow convertPressure.actuatorForce to generateTelemetry.outputForce;
    flow generateTelemetry.telemetry to telemetry;
  }

  state def PistonActuatorOperatingState {
    state Initializing;
    state Idle;
    state Extending;
    state Holding;
    state Retracting;
    state EndOfStroke;
    state Depressurizing;
    state Faulted;

    transition initialize first Initializing then Idle;

    transition commandExtend
      first Idle
      accept MotionCommand
      if requestedMode == ActuationMode::extend
      then Extending;

    transition commandRetract
      first Idle
      accept MotionCommand
      if requestedMode == ActuationMode::retract
      then Retracting;

    transition extensionHold
      first Extending
      accept MotionCommand
      if requestedMode == ActuationMode::hold
      then Holding;

    transition retractionHold
      first Retracting
      accept MotionCommand
      if requestedMode == ActuationMode::hold
      then Holding;

    transition holdExtend
      first Holding
      accept MotionCommand
      if requestedMode == ActuationMode::extend
      then Extending;

    transition holdRetract
      first Holding
      accept MotionCommand
      if requestedMode == ActuationMode::retract
      then Retracting;

    transition extensionEnd
      first Extending
      if strokeEnd == StrokeEnd::fullyExtended
      then EndOfStroke;

    transition retractionEnd
      first Retracting
      if strokeEnd == StrokeEnd::fullyRetracted
      then EndOfStroke;

    transition endToHold
      first EndOfStroke
      then Holding;

    transition commandedDepressurize
      first Holding
      accept MotionCommand
      if requestedMode == ActuationMode::depressurize
      then Depressurizing;

    transition depressurizedIdle
      first Depressurizing
      then Idle;

    transition faultFromIdle first Idle if health == HealthState::faulted then Faulted;
    transition faultFromExtend first Extending if health == HealthState::faulted then Faulted;
    transition faultFromRetract first Retracting if health == HealthState::faulted then Faulted;
    transition faultFromHold first Holding if health == HealthState::faulted then Faulted;
  }

  part def ElectricMotor {
    attribute ratedPower : Power = 1500.0;
    attribute nominalVoltage : Voltage = 24.0;
    attribute efficiency : Ratio = 0.88;

    port powerIn : ElectricalPowerPort;
    port shaftPowerOut : ElectricalPowerPort;
  }

  part def HydraulicPump {
    attribute displacementPerRev : Volume = 0.000012;
    attribute nominalOutletPressure : Pressure = 16000000.0;
    attribute maximumOutletPressure : Pressure = 21000000.0;
    attribute nominalFlow : FlowRate = 0.00035;
    attribute volumetricEfficiency : Ratio = 0.92;

    port inlet : BidirectionalHydraulicPort;
    port outlet : BidirectionalHydraulicPort;
    port drivePower : ElectricalPowerPort;

    perform action pressurize : PressurizeHydraulicFluid;
  }

  part def FluidReservoir {
    attribute usableVolume : Volume = 0.006;
    attribute nominalReturnPressure : Pressure = 101325.0;
    attribute fluidTemperature : Temperature = 313.15;

    port outlet : BidirectionalHydraulicPort;
    port returnIn : BidirectionalHydraulicPort;
  }

  part def ReliefValve {
    attribute crackingPressure : Pressure = 19000000.0;
    attribute fullOpenPressure : Pressure = 21000000.0;

    port inlet : BidirectionalHydraulicPort;
    port returnOut : BidirectionalHydraulicPort;
  }

  part def DirectionalControlValve {
    attribute spoolOpening : Ratio = 0.0;
    attribute nominalPressureDrop : Pressure = 700000.0;
    attribute maximumFlow : FlowRate = 0.0005;

    port controlIn : ValveControlPort;
    port pressurePort : BidirectionalHydraulicPort;
    port tankPort : BidirectionalHydraulicPort;
    port cylinderPortA : BidirectionalHydraulicPort;
    port cylinderPortB : BidirectionalHydraulicPort;

    perform action meterFlow : MeterFlowToCylinder;
  }

  part def CylinderBarrel {
    attribute boreDiameter : Length = 0.080;
    attribute strokeLength : Length = 0.300;
    attribute wallThickness : Length = 0.010;
    attribute proofPressure : Pressure = 31500000.0;

    port chamberA : BidirectionalHydraulicPort;
    port chamberB : BidirectionalHydraulicPort;
  }

  part def PistonHead {
    attribute diameter : Length = 0.0795;
    attribute headArea : Area = 0.004963;
    attribute mass : Mass = 1.40;
    attribute nominalSealFriction : Force = 120.0;

    port pressureFaceA : BidirectionalHydraulicPort;
    port pressureFaceB : BidirectionalHydraulicPort;
    port rodInterface : TranslationalMechanicalPort;
  }

  part def PistonRod {
    attribute diameter : Length = 0.032;
    attribute rodSideArea : Area = 0.004159;
    attribute extendedLength : Length = 0.360;
    attribute mass : Mass = 1.20;
    attribute bucklingLimit : Force = 18000.0;

    port pistonEnd : TranslationalMechanicalPort;
    port loadEnd : TranslationalMechanicalPort;
  }

  part def SealPack {
    attribute leakageAtNominalPressure : FlowRate = 0.000000002;
    attribute maximumAllowedLeakage : FlowRate = 0.000000010;
    attribute frictionForce : Force = 120.0;
    attribute operatingTemperatureLimit : Temperature = 373.15;

    port sealedChamberA : BidirectionalHydraulicPort;
    port sealedChamberB : BidirectionalHydraulicPort;
  }

  part def PositionSensor {
    attribute measurementRange : Length = 0.300;
    attribute resolution : Length = 0.0001;
    attribute updatePeriod : Time = 0.010;

    port mechanicalSense : TranslationalMechanicalPort;
    port telemetryOut : SensorOutputPort;
  }

  part def PressureSensor {
    attribute range : Pressure = 25000000.0;
    attribute accuracy : Pressure = 50000.0;
    attribute updatePeriod : Time = 0.010;

    port pressureTap : PressureSensorPort;
    port telemetryOut : SensorOutputPort;
  }

  part def ElectronicController {
    attribute controlLoopPeriod : Time = 0.010;
    attribute positionTolerance : Length = 0.001;
    attribute velocityTolerance : Velocity = 0.005;
    attribute forceLimit : Force = 16000.0;

    port powerIn : ElectricalPowerPort;
    port commandIn : CommandInputPort;
    port valveCommandOut : ControllerValvePort;
    port sensorIn : SensorOutputPort;
    port telemetryOut : TelemetryOutputPort;

    perform action receive : ReceiveMotionCommand;
    perform action compute : ComputeValveCommand;
    perform action report : GenerateTelemetry;
  }

  part def ExternalLinearLoad {
    attribute nominalLoadMass : Mass = 250.0;
    attribute nominalResistingForce : Force = 6000.0;
    attribute maximumAllowedForce : Force = 16000.0;

    port mechanicalInterface : TranslationalMechanicalPort;
  }

  part def PistonLinearActuatorSystem {
    doc /* The system is based on a piston contained in a cylinder. Its primary high-level function is to convert controlled hydraulic pressure and flow into controlled linear motion and force at an external load interface. */

    attribute minimumPosition : Length = 0.0;
    attribute maximumStroke : Length = 0.300;
    attribute commandedPosition : Length = 0.0;
    attribute measuredPosition : Length = 0.0;
    attribute measuredVelocity : Velocity = 0.0;
    attribute maximumVelocity : Velocity = 0.15;
    attribute maximumOutputForce : Force = 16000.0;
    attribute nominalSupplyPressure : Pressure = 16000000.0;
    attribute returnPressure : Pressure = 101325.0;
    attribute health : HealthState = HealthState::nominal;

    port electricalPowerIn : ElectricalPowerPort;
    port commandIn : CommandInputPort;
    port telemetryOut : TelemetryOutputPort;
    port loadInterface : TranslationalMechanicalPort;

    part motor : ElectricMotor;
    part pump : HydraulicPump;
    part reservoir : FluidReservoir;
    part reliefValve : ReliefValve;
    part directionalValve : DirectionalControlValve;
    part barrel : CylinderBarrel;
    part piston : PistonHead;
    part rod : PistonRod;
    part seals : SealPack;
    part positionSensor : PositionSensor;
    part pressureSensorA : PressureSensor;
    part pressureSensorB : PressureSensor;
    part controller : ElectronicController;
    part load : ExternalLinearLoad;

    state operatingState : PistonActuatorOperatingState;

    perform action primaryActuation : PerformPistonActuation;

    connect electricalPowerIn to controller.powerIn;
    connect electricalPowerIn to motor.powerIn;
    connect motor.shaftPowerOut to pump.drivePower;

    connect reservoir.outlet to pump.inlet;
    connect pump.outlet to directionalValve.pressurePort;
    connect pump.outlet to reliefValve.inlet;
    connect reliefValve.returnOut to reservoir.returnIn;
    connect directionalValve.tankPort to reservoir.returnIn;

    connect directionalValve.cylinderPortA to barrel.chamberA;
    connect directionalValve.cylinderPortB to barrel.chamberB;
    connect barrel.chamberA to seals.sealedChamberA;
    connect barrel.chamberB to seals.sealedChamberB;
    connect barrel.chamberA to piston.pressureFaceA;
    connect barrel.chamberB to piston.pressureFaceB;

    connect piston.rodInterface to rod.pistonEnd;
    connect rod.loadEnd to loadInterface;
    connect rod.loadEnd to load.mechanicalInterface;

    connect commandIn to controller.commandIn;
    connect controller.valveCommandOut to directionalValve.controlIn;
    connect positionSensor.telemetryOut to controller.sensorIn;
    connect pressureSensorA.telemetryOut to controller.sensorIn;
    connect pressureSensorB.telemetryOut to controller.sensorIn;
    connect controller.telemetryOut to telemetryOut;

    connect positionSensor.mechanicalSense to rod.loadEnd;
    connect pressureSensorA.pressureTap to barrel.chamberA;
    connect pressureSensorB.pressureTap to barrel.chamberB;

    assert constraint boreArea : CircularPistonArea {
      in boreDiameter = barrel.boreDiameter;
      out pistonArea = piston.headArea;
    }

    assert constraint rodSideArea : AnnularRodSideArea {
      in boreDiameter = barrel.boreDiameter;
      in rodDiameter = rod.diameter;
      out annularArea = rod.rodSideArea;
    }

    assert constraint pistonForce : HydraulicForceBalance {
      in pressureA = nominalSupplyPressure;
      in pressureB = returnPressure;
      in areaA = piston.headArea;
      in areaB = rod.rodSideArea;
      in sealFriction = seals.frictionForce;
      out netForce = maximumOutputForce;
    }

    assert constraint positionIsWithinStroke : StrokeLimit {
      in position = measuredPosition;
      in minimumPosition = minimumPosition;
      in maximumPosition = maximumStroke;
    }

    assert constraint velocityIsLimited : VelocityLimit {
      in velocity = measuredVelocity;
      in maximumVelocity = maximumVelocity;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The piston-based system shall convert pressurized hydraulic fluid energy into controlled linear displacement and force delivered through the piston rod to an external load. */
    subject system : PistonLinearActuatorSystem;
    require constraint {
      system.maximumStroke >= 0.300 and
      system.maximumOutputForce >= 16000.0 and
      system.nominalSupplyPressure >= 16000000.0
    }
  }

  requirement def ControlledMotionRequirement {
    doc /* The system shall extend, retract, and hold the piston rod according to commanded mode, target position, and target velocity. */
    subject system : PistonLinearActuatorSystem;
    require constraint {
      system.maximumVelocity <= 0.15 and
      system.maximumStroke == 0.300
    }
  }

  requirement def StrokeContainmentRequirement {
    doc /* The piston shall remain within the mechanical stroke limits of the cylinder during all commanded operation. */
    subject system : PistonLinearActuatorSystem;
    require constraint {
      system.measuredPosition >= system.minimumPosition and
      system.measuredPosition <= system.maximumStroke
    }
  }

  requirement def ForceProtectionRequirement {
    doc /* The controller and hydraulic relief path shall prevent delivered force from exceeding the load interface limit. */
    subject system : PistonLinearActuatorSystem;
    require constraint {
      system.maximumOutputForce <= system.load.maximumAllowedForce
    }
  }

  requirement def LeakageRequirement {
    doc /* The seal pack shall limit internal leakage so that commanded holding position can be maintained without continuous uncontrolled drift. */
    subject system : PistonLinearActuatorSystem;
    require constraint {
      system.seals.leakageAtNominalPressure <= system.seals.maximumAllowedLeakage
    }
  }

  requirement def FeedbackRequirement {
    doc /* The system shall provide position, velocity, pressure, force estimate, stroke-end, and health telemetry for closed-loop control and monitoring. */
    subject system : PistonLinearActuatorSystem;
    require constraint {
      system.controller.controlLoopPeriod <= 0.010 and
      system.positionSensor.resolution <= 0.0001 and
      system.pressureSensorA.accuracy <= 50000.0 and
      system.pressureSensorB.accuracy <= 50000.0
    }
  }

  part pistonLinearActuator : PistonLinearActuatorSystem;

  requirement primaryFunction : PrimaryFunctionRequirement {
    subject system = pistonLinearActuator;
  }

  requirement controlledMotion : ControlledMotionRequirement {
    subject system = pistonLinearActuator;
  }

  requirement strokeContainment : StrokeContainmentRequirement {
    subject system = pistonLinearActuator;
  }

  requirement forceProtection : ForceProtectionRequirement {
    subject system = pistonLinearActuator;
  }

  requirement leakageControl : LeakageRequirement {
    subject system = pistonLinearActuator;
  }

  requirement feedbackProvision : FeedbackRequirement {
    subject system = pistonLinearActuator;
  }

  satisfy primaryFunction by pistonLinearActuator;
  satisfy controlledMotion by pistonLinearActuator.controller;
  satisfy controlledMotion by pistonLinearActuator.directionalValve;
  satisfy controlledMotion by pistonLinearActuator.barrel;
  satisfy controlledMotion by pistonLinearActuator.piston;
  satisfy strokeContainment by pistonLinearActuator.barrel;
  satisfy strokeContainment by pistonLinearActuator.positionSensor;
  satisfy forceProtection by pistonLinearActuator.controller;
  satisfy forceProtection by pistonLinearActuator.reliefValve;
  satisfy leakageControl by pistonLinearActuator.seals;
  satisfy feedbackProvision by pistonLinearActuator.positionSensor;
  satisfy feedbackProvision by pistonLinearActuator.pressureSensorA;
  satisfy feedbackProvision by pistonLinearActuator.pressureSensorB;
  satisfy feedbackProvision by pistonLinearActuator.controller;
}
