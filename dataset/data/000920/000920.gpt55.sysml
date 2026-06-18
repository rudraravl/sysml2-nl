package PlungerPumpingSubsystemModel {
  import ScalarValues::*;

  quantity kind def LengthKind;
  quantity kind def AreaKind;
  quantity kind def VolumeKind;
  quantity kind def TimeKind;
  quantity kind def MassKind;
  quantity kind def PressureKind;
  quantity kind def TemperatureKind;
  quantity kind def VolumeFlowRateKind;
  quantity kind def FrequencyKind;
  quantity kind def ForceKind;
  quantity kind def PowerKind;
  quantity kind def VoltageKind;
  quantity kind def CurrentKind;
  quantity kind def SpeedKind;

  unit def m {
    symbol = "m";
    quantityKind = LengthKind;
  }

  unit def m2 {
    symbol = "m^2";
    quantityKind = AreaKind;
  }

  unit def m3 {
    symbol = "m^3";
    quantityKind = VolumeKind;
  }

  unit def s {
    symbol = "s";
    quantityKind = TimeKind;
  }

  unit def kg {
    symbol = "kg";
    quantityKind = MassKind;
  }

  unit def Pa {
    symbol = "Pa";
    quantityKind = PressureKind;
  }

  unit def degC {
    symbol = "degC";
    quantityKind = TemperatureKind;
  }

  unit def m3_per_s {
    symbol = "m^3/s";
    quantityKind = VolumeFlowRateKind;
  }

  unit def Hz {
    symbol = "Hz";
    quantityKind = FrequencyKind;
  }

  unit def N {
    symbol = "N";
    quantityKind = ForceKind;
  }

  unit def W {
    symbol = "W";
    quantityKind = PowerKind;
  }

  unit def V {
    symbol = "V";
    quantityKind = VoltageKind;
  }

  unit def A {
    symbol = "A";
    quantityKind = CurrentKind;
  }

  unit def rpm {
    symbol = "rpm";
    quantityKind = SpeedKind;
  }

  attribute def Length :> Real {
    :>> unit = m;
  }

  attribute def Area :> Real {
    :>> unit = m2;
  }

  attribute def Volume :> Real {
    :>> unit = m3;
  }

  attribute def Time :> Real {
    :>> unit = s;
  }

  attribute def Mass :> Real {
    :>> unit = kg;
  }

  attribute def Pressure :> Real {
    :>> unit = Pa;
  }

  attribute def Temperature :> Real {
    :>> unit = degC;
  }

  attribute def VolumeFlowRate :> Real {
    :>> unit = m3_per_s;
  }

  attribute def Frequency :> Real {
    :>> unit = Hz;
  }

  attribute def Force :> Real {
    :>> unit = N;
  }

  attribute def Power :> Real {
    :>> unit = W;
  }

  attribute def Voltage :> Real {
    :>> unit = V;
  }

  attribute def Current :> Real {
    :>> unit = A;
  }

  attribute def RotationalSpeed :> Real {
    :>> unit = rpm;
  }

  attribute def Efficiency :> Real;
  attribute def OpenFraction :> Real;
  attribute def BooleanSignal :> Boolean;

  item def WorkingFluid {
    attribute density : Real;
    attribute dynamicViscosity : Real;
    attribute vaporPressure : Pressure;
    attribute temperature : Temperature;
    attribute contaminationLevel : Real;
  }

  item def HydraulicEnergy {
    attribute pressure : Pressure;
    attribute flowRate : VolumeFlowRate;
  }

  item def ElectricalPower {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute realPower : Power;
  }

  item def MechanicalPower {
    attribute torque : Real;
    attribute shaftSpeed : RotationalSpeed;
    attribute transmittedPower : Power;
  }

  item def PumpCommand {
    attribute requestedFlow : VolumeFlowRate;
    attribute requestedDischargePressure : Pressure;
  }

  item def StartCommand :> PumpCommand;
  item def StopCommand :> PumpCommand;
  item def PrimeCommand :> PumpCommand;
  item def ResetFaultCommand :> PumpCommand;

  item def PumpStatus {
    attribute running : BooleanSignal;
    attribute primed : BooleanSignal;
    attribute faulted : BooleanSignal;
    attribute measuredFlow : VolumeFlowRate;
    attribute measuredSuctionPressure : Pressure;
    attribute measuredDischargePressure : Pressure;
  }

  port def FluidPort {
    inout item fluid : WorkingFluid;
    attribute staticPressure : Pressure;
    attribute temperature : Temperature;
    attribute flowRate : VolumeFlowRate;
  }

  port def ElectricalPowerPort {
    in item electricalPower : ElectricalPower;
    attribute lineVoltage : Voltage;
    attribute lineCurrent : Current;
  }

  port def MechanicalPowerPort {
    inout item mechanicalPower : MechanicalPower;
    attribute rotationalSpeed : RotationalSpeed;
    attribute transmittedPower : Power;
  }

  port def CommandPort {
    in item command : PumpCommand;
  }

  port def StatusPort {
    out item status : PumpStatus;
  }

  port def SensorSignalPort {
    out attribute value : Real;
    out attribute valid : BooleanSignal;
  }

  port def ActuatorSignalPort {
    in attribute commandValue : Real;
    in attribute enabled : BooleanSignal;
  }

  constraint def FlowToleranceConstraint {
    in actualFlow : VolumeFlowRate;
    in requestedFlow : VolumeFlowRate;
    in tolerance : Real;
    constraint flowWithinTolerance {
      actualFlow >= requestedFlow * (1.0 - tolerance) and actualFlow <= requestedFlow * (1.0 + tolerance)
    }
  }

  constraint def PressureLimitConstraint {
    in actualPressure : Pressure;
    in maximumPressure : Pressure;
    constraint pressureBelowLimit {
      actualPressure <= maximumPressure
    }
  }

  constraint def NetPositiveSuctionHeadConstraint {
    in suctionPressure : Pressure;
    in vaporPressure : Pressure;
    in requiredMargin : Pressure;
    constraint sufficientNpsh {
      suctionPressure - vaporPressure >= requiredMargin
    }
  }

  part def PipeSegment {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute internalDiameter : Length;
    attribute length : Length;
    attribute designPressure : Pressure;
    attribute pressureDrop : Pressure;

    constraint pressureBalance {
      outlet.staticPressure == inlet.staticPressure - pressureDrop
    }

    constraint flowContinuity {
      outlet.flowRate == inlet.flowRate
    }
  }

  part def Reservoir {
    port outlet : FluidPort;

    attribute storedVolume : Volume;
    attribute fluidTemperature : Temperature;
    attribute surfacePressure : Pressure;
    attribute minimumUsableVolume : Volume;

    item containedFluid : WorkingFluid;
  }

  part def Filter {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute nominalMicronRating : Real;
    attribute cleanPressureDrop : Pressure;
    attribute cloggedPressureDrop : Pressure;
    attribute differentialPressure : Pressure;

    constraint flowContinuity {
      outlet.flowRate == inlet.flowRate
    }

    constraint pressureDropDefinition {
      differentialPressure == inlet.staticPressure - outlet.staticPressure
    }
  }

  part def ManualIsolationValve {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute openFraction : OpenFraction;
    attribute pressureDropWhenOpen : Pressure;

    constraint flowBlockedWhenClosed {
      openFraction == 0.0 implies outlet.flowRate == 0.0
    }

    constraint openValveContinuity {
      openFraction > 0.0 implies outlet.flowRate == inlet.flowRate
    }
  }

  part def CheckValve {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute crackingPressure : Pressure;
    attribute reverseLeakageFlow : VolumeFlowRate;
    attribute open : BooleanSignal;

    constraint opensOnForwardPressure {
      open == (inlet.staticPressure - outlet.staticPressure >= crackingPressure)
    }

    constraint preventsReverseFlow {
      open == false implies outlet.flowRate <= reverseLeakageFlow
    }
  }

  part def ReliefValve {
    port protectedSide : FluidPort;
    port returnSide : FluidPort;

    attribute setPressure : Pressure;
    attribute reseatPressure : Pressure;
    attribute ratedReliefFlow : VolumeFlowRate;
    attribute open : BooleanSignal;

    constraint reliefOpensAtSetPressure {
      open == (protectedSide.staticPressure >= setPressure)
    }

    constraint reliefFlowWhenOpen {
      open == true implies returnSide.flowRate <= ratedReliefFlow
    }
  }

  part def PulsationDampener {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute gasPrechargePressure : Pressure;
    attribute hydraulicVolume : Volume;
    attribute allowableRipplePressure : Pressure;

    constraint flowContinuityAverage {
      outlet.flowRate == inlet.flowRate
    }
  }

  part def PressureSensor {
    port processPort : FluidPort;
    port signal : SensorSignalPort;

    attribute rangeMin : Pressure;
    attribute rangeMax : Pressure;
    attribute accuracy : Pressure;
    attribute sensedPressure : Pressure;

    bind sensedPressure = processPort.staticPressure;
  }

  part def FlowSensor {
    port inlet : FluidPort;
    port outlet : FluidPort;
    port signal : SensorSignalPort;

    attribute rangeMin : VolumeFlowRate;
    attribute rangeMax : VolumeFlowRate;
    attribute accuracy : VolumeFlowRate;
    attribute sensedFlow : VolumeFlowRate;

    bind sensedFlow = inlet.flowRate;

    constraint flowContinuity {
      outlet.flowRate == inlet.flowRate
    }
  }

  part def ElectricMotor {
    port electricalInput : ElectricalPowerPort;
    port shaftOutput : MechanicalPowerPort;

    attribute ratedPower : Power;
    attribute ratedVoltage : Voltage;
    attribute ratedCurrent : Current;
    attribute nominalSpeed : RotationalSpeed;
    attribute motorEfficiency : Efficiency;
    attribute enabled : BooleanSignal;

    constraint powerLimit {
      shaftOutput.transmittedPower <= ratedPower
    }
  }

  part def VariableFrequencyDrive {
    port powerInput : ElectricalPowerPort;
    port motorPowerOutput : ElectricalPowerPort;
    port commandInput : ActuatorSignalPort;

    attribute commandedSpeed : RotationalSpeed;
    attribute outputFrequency : Frequency;
    attribute enabled : BooleanSignal;

    constraint disabledRemovesMotorPower {
      enabled == false implies motorPowerOutput.lineCurrent == 0.0
    }
  }

  part def CrankSliderMechanism {
    port shaftInput : MechanicalPowerPort;

    attribute crankRadius : Length;
    attribute connectingRodLength : Length;
    attribute plungerStroke : Length;
    attribute plungerFrequency : Frequency;
    attribute mechanicalEfficiency : Efficiency;

    constraint strokeFromCrank {
      plungerStroke == 2.0 * crankRadius
    }
  }

  part def Plunger {
    attribute diameter : Length;
    attribute strokeLength : Length;
    attribute faceArea : Area;
    attribute sealFrictionForce : Force;

    constraint faceAreaDefinition {
      faceArea == 3.141592654 * diameter * diameter / 4.0
    }
  }

  part def PumpChamber {
    port suctionPort : FluidPort;
    port dischargePort : FluidPort;

    part inletCheckValve : CheckValve;
    part outletCheckValve : CheckValve;
    part plunger : Plunger;

    attribute clearanceVolume : Volume;
    attribute sweptVolumePerStroke : Volume;
    attribute chamberPressure : Pressure;
    attribute volumetricEfficiency : Efficiency;

    connect suctionPort to inletCheckValve.inlet;
    connect inletCheckValve.outlet to dischargePort;
    connect dischargePort to outletCheckValve.inlet;

    constraint sweptVolumeDefinition {
      sweptVolumePerStroke == plunger.faceArea * plunger.strokeLength
    }
  }

  action def SuctionStroke {
    in suctionPressure : Pressure;
    in chamberPressure : Pressure;
    out inletValveOpen : BooleanSignal;
    out outletValveOpen : BooleanSignal;

    constraint suctionValveLogic {
      inletValveOpen == (suctionPressure > chamberPressure)
    }

    constraint dischargeValveLogic {
      outletValveOpen == false
    }
  }

  action def CompressionStroke {
    in chamberPressure : Pressure;
    in dischargePressure : Pressure;
    out inletValveOpen : BooleanSignal;
    out outletValveOpen : BooleanSignal;

    constraint inletClosed {
      inletValveOpen == false
    }

    constraint outletRemainsClosedUntilCracking {
      outletValveOpen == (chamberPressure > dischargePressure)
    }
  }

  action def DischargeStroke {
    in chamberPressure : Pressure;
    in dischargePressure : Pressure;
    out inletValveOpen : BooleanSignal;
    out outletValveOpen : BooleanSignal;
    out deliveredFlow : VolumeFlowRate;

    constraint dischargeValveLogic {
      outletValveOpen == (chamberPressure >= dischargePressure)
    }

    constraint inletValveClosed {
      inletValveOpen == false
    }
  }

  action def PlungerPumpCycle {
    in strokeLength : Length;
    in plungerArea : Area;
    in strokeFrequency : Frequency;
    in volumetricEfficiency : Efficiency;
    in suctionPressure : Pressure;
    in dischargePressure : Pressure;
    out averageFlow : VolumeFlowRate;

    action draw : SuctionStroke;
    action compress : CompressionStroke;
    action expel : DischargeStroke;

    first draw then compress;
    then expel;

    constraint flowPerCycle {
      averageFlow == plungerArea * strokeLength * strokeFrequency * volumetricEfficiency
    }
  }

  part def PlungerPump {
    port suction : FluidPort;
    port discharge : FluidPort;
    port shaftInput : MechanicalPowerPort;

    part chamber : PumpChamber;
    part crankSlider : CrankSliderMechanism;

    attribute ratedFlow : VolumeFlowRate;
    attribute maximumDischargePressure : Pressure;
    attribute minimumSuctionPressure : Pressure;
    attribute requiredNpshMargin : Pressure;
    attribute strokeFrequency : Frequency;
    attribute volumetricEfficiency : Efficiency;
    attribute hydraulicEfficiency : Efficiency;
    attribute actualFlow : VolumeFlowRate;
    attribute actualDischargePressure : Pressure;

    connect suction to chamber.suctionPort;
    connect chamber.dischargePort to discharge;
    connect shaftInput to crankSlider.shaftInput;

    perform action cycle : PlungerPumpCycle {
      in strokeLength = chamber.plunger.strokeLength;
      in plungerArea = chamber.plunger.faceArea;
      in strokeFrequency = strokeFrequency;
      in volumetricEfficiency = volumetricEfficiency;
      in suctionPressure = suction.staticPressure;
      in dischargePressure = discharge.staticPressure;
      out averageFlow = actualFlow;
    }

    constraint dischargePressureLimit {
      actualDischargePressure <= maximumDischargePressure
    }

    constraint suctionPressureMargin {
      suction.staticPressure >= minimumSuctionPressure
    }

    constraint ratedFlowLimit {
      actualFlow <= ratedFlow
    }
  }

  state def PumpingSubsystemStates {
    state stopped;
    state priming;
    state running {
      state suctionStroke;
      state compressionStroke;
      state dischargeStroke;

      transition first suctionStroke then compressionStroke;
      transition compressionToDischarge first compressionStroke then dischargeStroke;
      transition dischargeToSuction first dischargeStroke then suctionStroke;
    }
    state bypassing;
    state shutdown;
    state faulted;

    transition initialToStopped first start then stopped;

    transition stoppedToPriming
      first stopped
      then priming
      accept PrimeCommand;

    transition primingToRunning
      first priming
      then running
      if primed == true
      accept StartCommand;

    transition stoppedToRunning
      first stopped
      then running
      accept StartCommand;

    transition runningToBypassing
      first running
      then bypassing
      if dischargePressureHigh == true;

    transition bypassingToRunning
      first bypassing
      then running
      if dischargePressureHigh == false;

    transition runningToShutdown
      first running
      then shutdown
      accept StopCommand;

    transition shutdownToStopped
      first shutdown
      then stopped;

    transition anyToFaulted
      first stopped, priming, running, bypassing, shutdown
      then faulted
      if faultDetected == true;

    transition faultedToStopped
      first faulted
      then stopped
      accept ResetFaultCommand;
  }

  action def StartPumpingSubsystem {
    out motorEnabled : BooleanSignal;
    out inletValveOpen : OpenFraction;
    out dischargeValveOpen : OpenFraction;

    constraint enableMotor {
      motorEnabled == true
    }

    constraint openFlowPath {
      inletValveOpen == 1.0 and dischargeValveOpen == 1.0
    }
  }

  action def StopPumpingSubsystem {
    out motorEnabled : BooleanSignal;
    out reliefBypassOpen : BooleanSignal;

    constraint disableMotor {
      motorEnabled == false
    }

    constraint closeBypass {
      reliefBypassOpen == false
    }
  }

  action def RegulatePumpSpeed {
    in requestedFlow : VolumeFlowRate;
    in measuredFlow : VolumeFlowRate;
    out commandedSpeed : RotationalSpeed;

    constraint increaseSpeedWhenLowFlow {
      measuredFlow < requestedFlow implies commandedSpeed > 0.0
    }
  }

  action def OperatePumpingSubsystem {
    in command : PumpCommand;
    in measuredFlow : VolumeFlowRate;
    in measuredDischargePressure : Pressure;
    out status : PumpStatus;

    action startSequence : StartPumpingSubsystem;
    action speedControl : RegulatePumpSpeed;
    action stopSequence : StopPumpingSubsystem;

    first startSequence then speedControl;
  }

  part def PumpController {
    port commandInput : CommandPort;
    port statusOutput : StatusPort;
    port motorCommand : ActuatorSignalPort;
    port reliefCommand : ActuatorSignalPort;

    attribute requestedFlow : VolumeFlowRate;
    attribute requestedDischargePressure : Pressure;
    attribute measuredFlow : VolumeFlowRate;
    attribute measuredSuctionPressure : Pressure;
    attribute measuredDischargePressure : Pressure;
    attribute dischargePressureHigh : BooleanSignal;
    attribute suctionPressureLow : BooleanSignal;
    attribute motorOverload : BooleanSignal;
    attribute primed : BooleanSignal;
    attribute faultDetected : BooleanSignal;

    exhibit state controlState : PumpingSubsystemStates;

    perform action operate : OperatePumpingSubsystem {
      in command = commandInput.command;
      in measuredFlow = measuredFlow;
      in measuredDischargePressure = measuredDischargePressure;
      out status = statusOutput.status;
    }

    constraint highPressureTrip {
      dischargePressureHigh == (measuredDischargePressure >= requestedDischargePressure * 1.10)
    }

    constraint lowSuctionTrip {
      suctionPressureLow == (measuredSuctionPressure <= 50000.0)
    }

    constraint faultLogic {
      faultDetected == (suctionPressureLow or motorOverload)
    }
  }

  part def PlungerPumpingSubsystem {
    port suctionIn : FluidPort;
    port dischargeOut : FluidPort;
    port electricalPowerIn : ElectricalPowerPort;
    port commandIn : CommandPort;
    port statusOut : StatusPort;

    part suctionIsolationValve : ManualIsolationValve;
    part suctionLine : PipeSegment;
    part inletFilter : Filter;
    part suctionPressureSensor : PressureSensor;
    part plungerPump : PlungerPump;
    part dischargeDampener : PulsationDampener;
    part dischargePressureSensor : PressureSensor;
    part flowMeter : FlowSensor;
    part dischargeIsolationValve : ManualIsolationValve;
    part reliefValve : ReliefValve;
    part recycleLine : PipeSegment;
    part vfd : VariableFrequencyDrive;
    part driveMotor : ElectricMotor;
    part controller : PumpController;

    attribute requestedFlow : VolumeFlowRate;
    attribute measuredFlow : VolumeFlowRate;
    attribute measuredSuctionPressure : Pressure;
    attribute measuredDischargePressure : Pressure;
    attribute normalSuctionPressure : Pressure;
    attribute designDischargePressure : Pressure;
    attribute maximumAllowableWorkingPressure : Pressure;
    attribute minimumContinuousFlow : VolumeFlowRate;
    attribute ratedContinuousFlow : VolumeFlowRate;

    connect suctionIn to suctionIsolationValve.inlet;
    connect suctionIsolationValve.outlet to suctionLine.inlet;
    connect suctionLine.outlet to inletFilter.inlet;
    connect inletFilter.outlet to suctionPressureSensor.processPort;
    connect suctionPressureSensor.processPort to plungerPump.suction;

    connect plungerPump.discharge to dischargeDampener.inlet;
    connect dischargeDampener.outlet to dischargePressureSensor.processPort;
    connect dischargePressureSensor.processPort to flowMeter.inlet;
    connect flowMeter.outlet to dischargeIsolationValve.inlet;
    connect dischargeIsolationValve.outlet to dischargeOut;

    connect dischargePressureSensor.processPort to reliefValve.protectedSide;
    connect reliefValve.returnSide to recycleLine.inlet;
    connect recycleLine.outlet to suctionLine.inlet;

    connect electricalPowerIn to vfd.powerInput;
    connect vfd.motorPowerOutput to driveMotor.electricalInput;
    connect driveMotor.shaftOutput to plungerPump.shaftInput;

    connect commandIn to controller.commandInput;
    connect controller.statusOutput to statusOut;
    connect controller.motorCommand to vfd.commandInput;
    connect controller.reliefCommand to reliefValveControl;

    bind requestedFlow = controller.requestedFlow;
    bind measuredFlow = flowMeter.sensedFlow;
    bind measuredSuctionPressure = suctionPressureSensor.sensedPressure;
    bind measuredDischargePressure = dischargePressureSensor.sensedPressure;
    bind controller.measuredFlow = measuredFlow;
    bind controller.measuredSuctionPressure = measuredSuctionPressure;
    bind controller.measuredDischargePressure = measuredDischargePressure;

    exhibit state operatingState : PumpingSubsystemStates;

    perform action operation : OperatePumpingSubsystem {
      in command = commandIn.command;
      in measuredFlow = measuredFlow;
      in measuredDischargePressure = measuredDischargePressure;
      out status = statusOut.status;
    }

    constraint moveFluidFromSuctionToDischarge {
      dischargeOut.flowRate == suctionIn.flowRate and dischargeOut.flowRate == measuredFlow
    }

    constraint dischargePressureAboveSuctionPressure {
      measuredDischargePressure > measuredSuctionPressure
    }

    constraint maximumPressureProtected {
      measuredDischargePressure <= maximumAllowableWorkingPressure
    }

    constraint minimumFlowWhenRunning {
      controller.statusOutput.status.running == true implies measuredFlow >= minimumContinuousFlow
    }

    constraint ratedFlowCapability {
      ratedContinuousFlow <= plungerPump.ratedFlow
    }
  }

  requirement def MoveFluidRequirement {
    subject subsystem : PlungerPumpingSubsystem;

    doc /* The pumping subsystem shall move working fluid from the suction inlet to the discharge outlet using a plunger pump as the pressure-generating element. */

    require constraint {
      subsystem.dischargeOut.flowRate == subsystem.suctionIn.flowRate and
      subsystem.measuredDischargePressure > subsystem.measuredSuctionPressure
    }
  }

  requirement def PlungerPumpRequirement {
    subject subsystem : PlungerPumpingSubsystem;

    doc /* The subsystem shall use a reciprocating plunger pump driven by an electric motor through a crank-slider mechanism. */

    require constraint {
      subsystem.plungerPump.chamber.plunger.strokeLength > 0.0 and
      subsystem.plungerPump.crankSlider.crankRadius > 0.0 and
      subsystem.driveMotor.ratedPower > 0.0
    }
  }

  requirement def RatedFlowRequirement {
    subject subsystem : PlungerPumpingSubsystem;

    doc /* The subsystem shall deliver commanded flow within five percent while operating in the running state and while suction pressure is adequate. */

    require constraint flowAccuracy : FlowToleranceConstraint {
      actualFlow = subsystem.measuredFlow;
      requestedFlow = subsystem.requestedFlow;
      tolerance = 0.05;
    }
  }

  requirement def OverPressureProtectionRequirement {
    subject subsystem : PlungerPumpingSubsystem;

    doc /* The subsystem shall protect downstream components from over-pressure by using discharge monitoring and a relief path to the suction side. */

    require constraint pressureProtection : PressureLimitConstraint {
      actualPressure = subsystem.measuredDischargePressure;
      maximumPressure = subsystem.maximumAllowableWorkingPressure;
    }
  }

  requirement def SuctionProtectionRequirement {
    subject subsystem : PlungerPumpingSubsystem;

    doc /* The subsystem shall maintain sufficient suction pressure margin above vapor pressure to avoid cavitation of the plunger chamber. */

    require constraint npshProtection : NetPositiveSuctionHeadConstraint {
      suctionPressure = subsystem.measuredSuctionPressure;
      vaporPressure = subsystem.suctionIn.fluid.vaporPressure;
      requiredMargin = subsystem.plungerPump.requiredNpshMargin;
    }
  }

  requirement def PulsationControlRequirement {
    subject subsystem : PlungerPumpingSubsystem;

    doc /* The subsystem shall reduce discharge pressure ripple using a pulsation dampener downstream of the plunger pump. */

    require constraint {
      subsystem.dischargeDampener.allowableRipplePressure <= subsystem.designDischargePressure * 0.05
    }
  }

  requirement def IsolationRequirement {
    subject subsystem : PlungerPumpingSubsystem;

    doc /* The subsystem shall provide manual isolation on both suction and discharge sides for maintenance. */

    require constraint {
      subsystem.suctionIsolationValve.openFraction >= 0.0 and
      subsystem.dischargeIsolationValve.openFraction >= 0.0
    }
  }

  part sourceTank : Reservoir {
    attribute storedVolume = 2.5;
    attribute fluidTemperature = 25.0;
    attribute surfacePressure = 101325.0;
    attribute minimumUsableVolume = 0.25;
  }

  part processHeader {
    port inlet : FluidPort;
    attribute requiredPressure : Pressure = 3000000.0;
    attribute acceptedFlow : VolumeFlowRate;
  }

  part pumpingSkid : PlungerPumpingSubsystem {
    attribute normalSuctionPressure = 120000.0;
    attribute designDischargePressure = 3000000.0;
    attribute maximumAllowableWorkingPressure = 3500000.0;
    attribute minimumContinuousFlow = 0.00010;
    attribute ratedContinuousFlow = 0.00120;

    part plungerPump {
      attribute ratedFlow = 0.00150;
      attribute maximumDischargePressure = 3500000.0;
      attribute minimumSuctionPressure = 80000.0;
      attribute requiredNpshMargin = 35000.0;
      attribute strokeFrequency = 4.0;
      attribute volumetricEfficiency = 0.92;
      attribute hydraulicEfficiency = 0.86;

      part chamber {
        attribute clearanceVolume = 0.000015;
        part plunger {
          attribute diameter = 0.032;
          attribute strokeLength = 0.055;
        }

        part inletCheckValve {
          attribute crackingPressure = 5000.0;
          attribute reverseLeakageFlow = 0.000001;
        }

        part outletCheckValve {
          attribute crackingPressure = 7000.0;
          attribute reverseLeakageFlow = 0.000001;
        }
      }

      part crankSlider {
        attribute crankRadius = 0.0275;
        attribute connectingRodLength = 0.160;
        attribute mechanicalEfficiency = 0.94;
      }
    }

    part driveMotor {
      attribute ratedPower = 5500.0;
      attribute ratedVoltage = 480.0;
      attribute ratedCurrent = 12.0;
      attribute nominalSpeed = 1750.0;
      attribute motorEfficiency = 0.90;
    }

    part vfd {
      attribute outputFrequency = 60.0;
      attribute commandedSpeed = 1750.0;
    }

    part inletFilter {
      attribute nominalMicronRating = 25.0;
      attribute cleanPressureDrop = 10000.0;
      attribute cloggedPressureDrop = 60000.0;
    }

    part suctionLine {
      attribute internalDiameter = 0.050;
      attribute length = 1.50;
      attribute designPressure = 1000000.0;
      attribute pressureDrop = 5000.0;
    }

    part recycleLine {
      attribute internalDiameter = 0.025;
      attribute length = 1.20;
      attribute designPressure = 3500000.0;
      attribute pressureDrop = 25000.0;
    }

    part dischargeDampener {
      attribute gasPrechargePressure = 2100000.0;
      attribute hydraulicVolume = 0.0020;
      attribute allowableRipplePressure = 150000.0;
    }

    part reliefValve {
      attribute setPressure = 3300000.0;
      attribute reseatPressure = 3000000.0;
      attribute ratedReliefFlow = 0.00200;
    }

    part suctionIsolationValve {
      attribute openFraction = 1.0;
      attribute pressureDropWhenOpen = 2000.0;
    }

    part dischargeIsolationValve {
      attribute openFraction = 1.0;
      attribute pressureDropWhenOpen = 5000.0;
    }
  }

  connect sourceTank.outlet to pumpingSkid.suctionIn;
  connect pumpingSkid.dischargeOut to processHeader.inlet;

  requirement moveFluidReq : MoveFluidRequirement {
    subject subsystem = pumpingSkid;
  }

  requirement plungerPumpReq : PlungerPumpRequirement {
    subject subsystem = pumpingSkid;
  }

  requirement ratedFlowReq : RatedFlowRequirement {
    subject subsystem = pumpingSkid;
  }

  requirement overPressureReq : OverPressureProtectionRequirement {
    subject subsystem = pumpingSkid;
  }

  requirement suctionProtectionReq : SuctionProtectionRequirement {
    subject subsystem = pumpingSkid;
  }

  requirement pulsationControlReq : PulsationControlRequirement {
    subject subsystem = pumpingSkid;
  }

  requirement isolationReq : IsolationRequirement {
    subject subsystem = pumpingSkid;
  }

  satisfy moveFluidReq by pumpingSkid;
  satisfy plungerPumpReq by pumpingSkid.plungerPump;
  satisfy ratedFlowReq by pumpingSkid.controller;
  satisfy overPressureReq by pumpingSkid.reliefValve;
  satisfy suctionProtectionReq by pumpingSkid.suctionPressureSensor;
  satisfy pulsationControlReq by pumpingSkid.dischargeDampener;
  satisfy isolationReq by pumpingSkid.suctionIsolationValve;
  satisfy isolationReq by pumpingSkid.dischargeIsolationValve;
}
