package PumpingSubsystem_Wendelkolben {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;
  import RequirementVerification::*;

  attribute def Pressure :> ISQ::pressure {
    unit = SI::Pa;
  }

  attribute def FlowRate :> ISQ::volumeFlowRate {
    unit = SI::m3_per_s;
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    unit = SI::K;
  }

  attribute def RotationalSpeed :> ISQ::frequency {
    unit = SI::Hz;
  }

  attribute def Torque :> ISQ::torque {
    unit = SI::N_m;
  }

  attribute def Power :> ISQ::power {
    unit = SI::W;
  }

  attribute def Volume :> ISQ::volume {
    unit = SI::m3;
  }

  attribute def DynamicViscosity :> ISQ::dynamicViscosity {
    unit = SI::Pa_s;
  }

  attribute def Density :> ISQ::massDensity {
    unit = SI::kg_per_m3;
  }

  attribute def Length :> ISQ::length {
    unit = SI::m;
  }

  attribute def Efficiency {
    :>> scalarValues = Real;
  }

  attribute def Percent {
    :>> scalarValues = Real;
  }

  attribute def Current :> ISQ::electricCurrent {
    unit = SI::A;
  }

  attribute def Voltage :> ISQ::electricPotential {
    unit = SI::V;
  }

  attribute def TimeDuration :> ISQ::duration {
    unit = SI::s;
  }

  item def ProcessFluid {
    attribute density : Density;
    attribute viscosity : DynamicViscosity;
    attribute temperature : Temperature;
    attribute vaporPressure : Pressure;
    attribute solidsContent : Percent;
    attribute chemicallyCompatible : Boolean;
  }

  item def ElectricalPower {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute frequency : RotationalSpeed;
    attribute availablePower : Power;
  }

  item def ControlSignal {
    attribute requestedSpeed : RotationalSpeed;
    attribute enable : Boolean;
    attribute emergencyStop : Boolean;
    attribute resetFault : Boolean;
  }

  item def StatusSignal {
    attribute actualSpeed : RotationalSpeed;
    attribute suctionPressure : Pressure;
    attribute dischargePressure : Pressure;
    attribute measuredFlow : FlowRate;
    attribute motorCurrent : Current;
    attribute casingTemperature : Temperature;
    attribute running : Boolean;
    attribute faultActive : Boolean;
    attribute faultCode : String;
  }

  port def FluidInletPort {
    in item fluid : ProcessFluid;
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute availableNPSH : Length;
  }

  port def FluidOutletPort {
    out item fluid : ProcessFluid;
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute deliveredFlow : FlowRate;
  }

  port def ElectricalPowerPort {
    in item power : ElectricalPower;
  }

  port def ControlInputPort {
    in item command : ControlSignal;
  }

  port def StatusOutputPort {
    out item status : StatusSignal;
  }

  port def DrainPort {
    out item leakage : ProcessFluid;
    attribute leakageFlow : FlowRate;
  }

  part def WendelkolbenRotor {
    attribute helixPitch : Length;
    attribute lobeCount : Integer = 1;
    attribute eccentricity : Length;
    attribute rotationalSpeed : RotationalSpeed;
    attribute generatedChamberVolume : Volume;
    attribute surfaceHardness : Real;
  }

  part def ElastomerStator {
    attribute internalHelixPitch : Length;
    attribute interferenceFit : Length;
    attribute allowableTemperature : Temperature;
    attribute compressionSet : Percent;
    attribute compatibleWithFluid : Boolean;
  }

  part def WendelkolbenPumpElement {
    port suction : FluidInletPort;
    port discharge : FluidOutletPort;
    port leakageDrain : DrainPort;

    part rotor : WendelkolbenRotor;
    part stator : ElastomerStator;

    attribute displacementPerRevolution : Volume;
    attribute volumetricEfficiency : Efficiency;
    attribute differentialPressure : Pressure;
    attribute slipFlow : FlowRate;
    attribute hydraulicFlow : FlowRate;
    attribute maximumDifferentialPressure : Pressure = 1200000 [SI::Pa];
    attribute maximumSpeed : RotationalSpeed = 25 [SI::Hz];

    constraint flowGeneration {
      hydraulicFlow == displacementPerRevolution * rotor.rotationalSpeed * volumetricEfficiency - slipFlow;
      differentialPressure == discharge.pressure - suction.pressure;
    }

    constraint operatingLimits {
      differentialPressure <= maximumDifferentialPressure;
      rotor.rotationalSpeed <= maximumSpeed;
      stator.compatibleWithFluid == suction.fluid.chemicallyCompatible;
    }
  }

  part def MechanicalSeal {
    port processSide : FluidInletPort;
    port drain : DrainPort;

    attribute allowableLeakage : FlowRate = 1.0e-8 [SI::m3_per_s];
    attribute measuredLeakage : FlowRate;
    attribute sealFaceTemperature : Temperature;
    attribute healthy : Boolean;

    constraint sealHealth {
      healthy == measuredLeakage <= allowableLeakage;
    }
  }

  part def BearingSet {
    attribute radialLoadCapacity : Force;
    attribute axialLoadCapacity : Force;
    attribute bearingTemperature : Temperature;
    attribute lubricationLevel : Percent;
    attribute healthy : Boolean;

    constraint bearingCondition {
      healthy == bearingTemperature < 353.15 [SI::K] and lubricationLevel >= 40.0;
    }
  }

  part def ElectricMotor {
    port electricalSupply : ElectricalPowerPort;

    attribute ratedPower : Power = 7500 [SI::W];
    attribute ratedVoltage : Voltage = 400 [SI::V];
    attribute actualSpeed : RotationalSpeed;
    attribute outputTorque : Torque;
    attribute currentDraw : Current;
    attribute windingTemperature : Temperature;
    attribute efficiency : Efficiency = 0.91;

    constraint motorPower {
      ratedPower >= outputTorque * actualSpeed / efficiency;
    }
  }

  part def VariableFrequencyDrive {
    port supply : ElectricalPowerPort;
    port command : ControlInputPort;
    port motorPower : ElectricalPowerPort;
    port status : StatusOutputPort;

    attribute commandedSpeed : RotationalSpeed;
    attribute outputFrequency : RotationalSpeed;
    attribute outputVoltage : Voltage;
    attribute healthy : Boolean;
    attribute tripActive : Boolean;

    constraint commandMapping {
      commandedSpeed == command.command.requestedSpeed;
      outputFrequency == commandedSpeed;
      tripActive == command.command.emergencyStop or not healthy;
    }
  }

  part def Coupling {
    attribute transmittedTorque : Torque;
    attribute ratedTorque : Torque = 90 [SI::N_m];
    attribute torsionalDamping : Real;
    attribute guardInstalled : Boolean;

    constraint torqueLimit {
      transmittedTorque <= ratedTorque;
      guardInstalled == true;
    }
  }

  part def SuctionStrainer {
    port inlet : FluidInletPort;
    port outlet : FluidInletPort;

    attribute meshSize : Length = 0.001 [SI::m];
    attribute differentialPressure : Pressure;
    attribute cloggingPercent : Percent;
    attribute bypassOpen : Boolean;

    constraint strainerCondition {
      differentialPressure == inlet.pressure - outlet.pressure;
      bypassOpen == cloggingPercent > 85.0;
    }
  }

  part def CheckValve {
    port inlet : FluidOutletPort;
    port outlet : FluidOutletPort;

    attribute crackingPressure : Pressure = 12000 [SI::Pa];
    attribute open : Boolean;
    attribute reverseFlowPrevented : Boolean;

    constraint valveOpening {
      open == inlet.pressure > outlet.pressure + crackingPressure;
      reverseFlowPrevented == true;
    }
  }

  part def PressureReliefValve {
    port inlet : FluidOutletPort;
    port returnToSuction : FluidInletPort;

    attribute setPressure : Pressure = 1100000 [SI::Pa];
    attribute reseatPressure : Pressure = 950000 [SI::Pa];
    attribute open : Boolean;
    attribute reliefFlow : FlowRate;

    constraint reliefLogic {
      open == inlet.pressure >= setPressure;
      reliefFlow >= 0.0 [SI::m3_per_s];
    }
  }

  part def Instrumentation {
    port statusOut : StatusOutputPort;

    attribute suctionPressure : Pressure;
    attribute dischargePressure : Pressure;
    attribute flowRate : FlowRate;
    attribute casingTemperature : Temperature;
    attribute vibrationVelocity : Real;
    attribute dryRunDetected : Boolean;
    attribute overPressureDetected : Boolean;
    attribute overTemperatureDetected : Boolean;

    constraint alarmLogic {
      dryRunDetected == suctionPressure < 30000 [SI::Pa];
      overPressureDetected == dischargePressure > 1150000 [SI::Pa];
      overTemperatureDetected == casingTemperature > 353.15 [SI::K];
    }
  }

  state def PumpingStateMachine {
    entry action initializeStatus;
    state Off;
    state Priming;
    state Starting;
    state Running;
    state ReliefBypass;
    state Shutdown;
    state Fault;

    transition first Off;

    transition Off_to_Priming
      first Off
      then Priming
      accept ControlSignal
      if enable == true and emergencyStop == false;

    transition Priming_to_Starting
      first Priming
      then Starting
      if suctionPressure > 50000 [SI::Pa] and availableNPSH > 1.5 [SI::m];

    transition Starting_to_Running
      first Starting
      then Running
      if actualSpeed >= requestedSpeed * 0.95;

    transition Running_to_ReliefBypass
      first Running
      then ReliefBypass
      if dischargePressure >= 1100000 [SI::Pa];

    transition ReliefBypass_to_Running
      first ReliefBypass
      then Running
      if dischargePressure <= 950000 [SI::Pa];

    transition Running_to_Shutdown
      first Running
      then Shutdown
      accept ControlSignal
      if enable == false;

    transition Shutdown_to_Off
      first Shutdown
      then Off
      if actualSpeed <= 0.2 [SI::Hz];

    transition Any_to_Fault
      first Off, Priming, Starting, Running, ReliefBypass, Shutdown
      then Fault
      if emergencyStop == true or dryRunDetected == true or overTemperatureDetected == true;

    transition Fault_to_Off
      first Fault
      then Off
      accept ControlSignal
      if resetFault == true and emergencyStop == false;
  }

  action def PrimePump {
    in suctionPressure : Pressure;
    in availableNPSH : Length;
    out primed : Boolean;

    constraint primingResult {
      primed == suctionPressure > 50000 [SI::Pa] and availableNPSH > 1.5 [SI::m];
    }
  }

  action def StartPump {
    in requestedSpeed : RotationalSpeed;
    out rampTime : TimeDuration;
    out started : Boolean;

    constraint startResult {
      rampTime <= 10 [SI::s];
      started == requestedSpeed > 0 [SI::Hz];
    }
  }

  action def MoveFluid {
    in displacementPerRevolution : Volume;
    in speed : RotationalSpeed;
    in volumetricEfficiency : Efficiency;
    out deliveredFlow : FlowRate;

    constraint flowResult {
      deliveredFlow == displacementPerRevolution * speed * volumetricEfficiency;
    }
  }

  action def ProtectAgainstOverpressure {
    in dischargePressure : Pressure;
    in reliefSetPressure : Pressure;
    out reliefOpen : Boolean;

    constraint protectionResult {
      reliefOpen == dischargePressure >= reliefSetPressure;
    }
  }

  action def StopPump {
    in emergencyStop : Boolean;
    out stopped : Boolean;
    out coastDownTime : TimeDuration;

    constraint stopResult {
      coastDownTime <= 8 [SI::s];
      stopped == true;
    }
  }

  part def WendelkolbenPumpingSubsystem {
    port fluidIn : FluidInletPort;
    port fluidOut : FluidOutletPort;
    port powerIn : ElectricalPowerPort;
    port controlIn : ControlInputPort;
    port statusOut : StatusOutputPort;
    port sealDrain : DrainPort;

    part strainer : SuctionStrainer;
    part pumpElement : WendelkolbenPumpElement;
    part seal : MechanicalSeal;
    part bearings : BearingSet;
    part motor : ElectricMotor;
    part drive : VariableFrequencyDrive;
    part coupling : Coupling;
    part dischargeCheckValve : CheckValve;
    part reliefValve : PressureReliefValve;
    part instruments : Instrumentation;

    attribute requiredFlow : FlowRate = 0.0042 [SI::m3_per_s];
    attribute nominalDischargePressure : Pressure = 800000 [SI::Pa];
    attribute maximumFluidTemperature : Temperature = 333.15 [SI::K];
    attribute minimumNPSHAvailable : Length = 1.8 [SI::m];
    attribute subsystemEfficiency : Efficiency;
    attribute operatingState : PumpingStateMachine;

    connect fluidIn to strainer.inlet;
    connect strainer.outlet to pumpElement.suction;
    connect pumpElement.discharge to dischargeCheckValve.inlet;
    connect dischargeCheckValve.outlet to fluidOut;
    connect pumpElement.leakageDrain to sealDrain;
    connect seal.drain to sealDrain;
    connect powerIn to drive.supply;
    connect controlIn to drive.command;
    connect drive.motorPower to motor.electricalSupply;
    connect drive.status to statusOut;
    connect instruments.statusOut to statusOut;
    connect reliefValve.inlet to pumpElement.discharge;
    connect reliefValve.returnToSuction to pumpElement.suction;

    constraint subsystemPerformance {
      fluidOut.deliveredFlow >= requiredFlow;
      fluidOut.pressure >= nominalDischargePressure;
      fluidIn.availableNPSH >= minimumNPSHAvailable;
      fluidIn.temperature <= maximumFluidTemperature;
      pumpElement.rotor.rotationalSpeed == motor.actualSpeed;
      coupling.transmittedTorque == motor.outputTorque;
      instruments.suctionPressure == pumpElement.suction.pressure;
      instruments.dischargePressure == pumpElement.discharge.pressure;
      instruments.flowRate == fluidOut.deliveredFlow;
      seal.processSide.pressure == pumpElement.suction.pressure;
    }

    perform action PrimePump {
      in suctionPressure = fluidIn.pressure;
      in availableNPSH = fluidIn.availableNPSH;
    }

    perform action StartPump {
      in requestedSpeed = controlIn.command.requestedSpeed;
    }

    perform action MoveFluid {
      in displacementPerRevolution = pumpElement.displacementPerRevolution;
      in speed = motor.actualSpeed;
      in volumetricEfficiency = pumpElement.volumetricEfficiency;
      out deliveredFlow = fluidOut.deliveredFlow;
    }

    perform action ProtectAgainstOverpressure {
      in dischargePressure = pumpElement.discharge.pressure;
      in reliefSetPressure = reliefValve.setPressure;
      out reliefOpen = reliefValve.open;
    }

    perform action StopPump {
      in emergencyStop = controlIn.command.emergencyStop;
    }
  }

  requirement def PumpingSubsystemRequirement {
    subject subsystem : WendelkolbenPumpingSubsystem;

    require constraint {
      subsystem.fluidOut.deliveredFlow >= 0.0042 [SI::m3_per_s];
      subsystem.fluidOut.pressure >= 800000 [SI::Pa];
      subsystem.fluidIn.availableNPSH >= 1.8 [SI::m];
      subsystem.pumpElement.differentialPressure <= 1200000 [SI::Pa];
      subsystem.fluidIn.fluid.viscosity >= 0.001 [SI::Pa_s];
      subsystem.fluidIn.fluid.viscosity <= 2.5 [SI::Pa_s];
      subsystem.fluidIn.temperature <= 333.15 [SI::K];
      subsystem.seal.measuredLeakage <= subsystem.seal.allowableLeakage;
      subsystem.reliefValve.open == true implies subsystem.pumpElement.discharge.pressure >= subsystem.reliefValve.setPressure;
      subsystem.dischargeCheckValve.reverseFlowPrevented == true;
      subsystem.coupling.guardInstalled == true;
    }
  }

  requirement def WendelkolbenPumpElementRequirement {
    subject element : WendelkolbenPumpElement;

    require constraint {
      element.rotor.lobeCount == 1;
      element.rotor.helixPitch > 0.0 [SI::m];
      element.stator.internalHelixPitch > element.rotor.helixPitch;
      element.stator.interferenceFit > 0.0 [SI::m];
      element.volumetricEfficiency >= 0.82;
      element.slipFlow <= element.displacementPerRevolution * element.rotor.rotationalSpeed * 0.10;
      element.stator.compatibleWithFluid == true;
    }
  }

  requirement def ControlAndProtectionRequirement {
    subject subsystem : WendelkolbenPumpingSubsystem;

    require constraint {
      subsystem.drive.tripActive == true implies subsystem.motor.actualSpeed <= 0.2 [SI::Hz];
      subsystem.instruments.dryRunDetected == true implies subsystem.operatingState == PumpingStateMachine::Fault;
      subsystem.instruments.overPressureDetected == true implies subsystem.reliefValve.open == true;
      subsystem.controlIn.command.emergencyStop == true implies subsystem.operatingState == PumpingStateMachine::Fault;
    }
  }

  satisfy PumpingSubsystemRequirement by WendelkolbenPumpingSubsystem;
  satisfy WendelkolbenPumpElementRequirement by WendelkolbenPumpElement;
  satisfy ControlAndProtectionRequirement by WendelkolbenPumpingSubsystem;

  analysis case NominalTransferAnalysis {
    subject subsystem : WendelkolbenPumpingSubsystem;

    objective {
      verify subsystem.fluidOut.deliveredFlow >= subsystem.requiredFlow;
      verify subsystem.fluidOut.pressure >= subsystem.nominalDischargePressure;
      verify subsystem.pumpElement.volumetricEfficiency >= 0.82;
      verify subsystem.reliefValve.open == false;
    }
  }

  verification case OverpressureProtectionTest {
    subject subsystem : WendelkolbenPumpingSubsystem;

    objective {
      verify subsystem.reliefValve.open == true;
      verify subsystem.dischargeCheckValve.reverseFlowPrevented == true;
      verify subsystem.drive.tripActive == false;
    }
  }

  verification case DryRunFaultTest {
    subject subsystem : WendelkolbenPumpingSubsystem;

    objective {
      verify subsystem.instruments.dryRunDetected == true;
      verify subsystem.operatingState == PumpingStateMachine::Fault;
      verify subsystem.motor.actualSpeed <= 0.2 [SI::Hz];
    }
  }

}