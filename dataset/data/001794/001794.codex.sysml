package KarassikBasedPumpSystem {

  import ScalarValues::*;

  attribute def FlowRate;
  attribute def Pressure;
  attribute def Head;
  attribute def Power;
  attribute def Efficiency;
  attribute def RotationalSpeed;
  attribute def Temperature;
  attribute def VibrationVelocity;
  attribute def TimeDuration;
  attribute def Length;
  attribute def Density;

  item def Liquid {
    attribute density : Density;
    attribute temperature : Temperature;
    attribute vaporPressure : Pressure;
  }

  item def ElectricalPower {
    attribute voltage : Real;
    attribute frequency : Real;
    attribute power : Power;
  }

  item def MechanicalTorque {
    attribute speed : RotationalSpeed;
    attribute power : Power;
  }

  port def LiquidPort {
    inout liquid : Liquid;
    attribute pressure : Pressure;
    attribute flowRate : FlowRate;
  }

  port def PowerPort {
    in powerIn : ElectricalPower;
  }

  port def ShaftPort {
    out torque : MechanicalTorque;
  }

  port def SignalPort {
    inout signal : Boolean;
  }

  part def KarassikCentrifugalPumpSystem {
    doc
      /* Primary function: convert electrical input power into controlled hydraulic energy so that liquid is moved from a low-pressure source to a higher-pressure discharge header at the required flow, head, efficiency, and reliability. */

    attribute ratedFlow : FlowRate = 450.0;
    attribute ratedHead : Head = 85.0;
    attribute ratedSpeed : RotationalSpeed = 1780.0;
    attribute minimumContinuousStableFlow : FlowRate = 135.0;
    attribute requiredEfficiency : Efficiency = 0.78;
    attribute netPositiveSuctionHeadRequired : Head = 4.2;
    attribute maximumBearingTemperature : Temperature = 90.0;
    attribute maximumVibrationVelocity : VibrationVelocity = 4.5;

    port suction : LiquidPort;
    port discharge : LiquidPort;
    port electricalSupply : PowerPort;
    port startCommand : SignalPort;
    port stopCommand : SignalPort;
    port alarmSignal : SignalPort;

    part suctionPiping : SuctionPiping;
    part casing : VoluteCasing;
    part impeller : Impeller;
    part shaft : PumpShaft;
    part motor : ElectricMotor;
    part coupling : FlexibleCoupling;
    part bearings : BearingAssembly;
    part seal : MechanicalSeal;
    part dischargePiping : DischargePiping;
    part checkValve : CheckValve;
    part isolationValve : IsolationValve;
    part instrumentation : PumpInstrumentation;
    part controller : PumpController;

    connect suction to suctionPiping.inlet;
    connect suctionPiping.outlet to casing.suctionNozzle;
    connect casing.impellerHydraulicPort to impeller.hydraulicPort;
    connect impeller.dischargeHydraulicPort to casing.dischargeNozzle;
    connect casing.dischargeNozzle to dischargePiping.inlet;
    connect dischargePiping.outlet to checkValve.inlet;
    connect checkValve.outlet to isolationValve.inlet;
    connect isolationValve.outlet to discharge;

    connect electricalSupply to motor.powerPort;
    connect motor.shaftOutput to coupling.driverSide;
    connect coupling.drivenSide to shaft.motorEnd;
    connect shaft.impellerEnd to impeller.shaftInput;
    connect shaft.bearingJournal to bearings.shaftSupport;
    connect shaft.sealSleeve to seal.rotatingFace;

    connect instrumentation.flowSignal to controller.flowInput;
    connect instrumentation.pressureSignal to controller.pressureInput;
    connect instrumentation.vibrationSignal to controller.vibrationInput;
    connect instrumentation.temperatureSignal to controller.temperatureInput;
    connect startCommand to controller.startInput;
    connect stopCommand to controller.stopInput;
    connect controller.tripOutput to alarmSignal;

    perform controller.controlBehavior;
    exhibit PumpSystemStates;
  }

  part def SuctionPiping {
    attribute diameter : Length = 0.30;
    attribute length : Length = 8.0;
    attribute allowableVelocity : Real = 2.0;
    port inlet : LiquidPort;
    port outlet : LiquidPort;
  }

  part def DischargePiping {
    attribute diameter : Length = 0.25;
    attribute length : Length = 35.0;
    attribute allowableVelocity : Real = 3.0;
    port inlet : LiquidPort;
    port outlet : LiquidPort;
  }

  part def VoluteCasing {
    attribute designPressure : Pressure = 1600.0;
    attribute hydrotestPressure : Pressure = 2400.0;
    attribute corrosionAllowance : Length = 0.003;
    port suctionNozzle : LiquidPort;
    port impellerHydraulicPort : LiquidPort;
    port dischargeNozzle : LiquidPort;
  }

  part def Impeller {
    attribute outsideDiameter : Length = 0.355;
    attribute eyeDiameter : Length = 0.145;
    attribute bladeCount : Integer = 6;
    attribute designEfficiency : Efficiency = 0.82;
    port hydraulicPort : LiquidPort;
    port dischargeHydraulicPort : LiquidPort;
    port shaftInput : ShaftPort;
  }

  part def PumpShaft {
    attribute diameter : Length = 0.065;
    attribute firstCriticalSpeedMargin : Real = 1.25;
    port motorEnd : ShaftPort;
    port impellerEnd : ShaftPort;
    port bearingJournal : ShaftPort;
    port sealSleeve : ShaftPort;
  }

  part def ElectricMotor {
    attribute ratedPower : Power = 132.0;
    attribute ratedSpeed : RotationalSpeed = 1780.0;
    attribute serviceFactor : Real = 1.15;
    port powerPort : PowerPort;
    port shaftOutput : ShaftPort;
  }

  part def FlexibleCoupling {
    attribute torqueRatingMargin : Real = 1.5;
    port driverSide : ShaftPort;
    port drivenSide : ShaftPort;
  }

  part def BearingAssembly {
    attribute l10Life : TimeDuration = 50000.0;
    attribute maximumTemperature : Temperature = 90.0;
    port shaftSupport : ShaftPort;
  }

  part def MechanicalSeal {
    attribute sealPlanCode : String = "API Plan 11";
    attribute maximumChamberPressure : Pressure = 1200.0;
    attribute maximumFaceTemperature : Temperature = 95.0;
    port rotatingFace : ShaftPort;
  }

  part def CheckValve {
    attribute crackingPressure : Pressure = 20.0;
    port inlet : LiquidPort;
    port outlet : LiquidPort;
  }

  part def IsolationValve {
    attribute fullOpenLossCoefficient : Real = 0.15;
    port inlet : LiquidPort;
    port outlet : LiquidPort;
  }

  part def PumpInstrumentation {
    attribute flowAccuracy : Real = 0.01;
    attribute pressureAccuracy : Real = 0.005;
    attribute vibrationAccuracy : Real = 0.05;
    port flowSignal : SignalPort;
    port pressureSignal : SignalPort;
    port vibrationSignal : SignalPort;
    port temperatureSignal : SignalPort;
  }

  part def PumpController {
    port startInput : SignalPort;
    port stopInput : SignalPort;
    port flowInput : SignalPort;
    port pressureInput : SignalPort;
    port vibrationInput : SignalPort;
    port temperatureInput : SignalPort;
    port tripOutput : SignalPort;

    action controlBehavior : PumpControlAction;
  }

  action def PumpControlAction {
    in startRequested : Boolean;
    in stopRequested : Boolean;
    in measuredFlow : FlowRate;
    in suctionPressure : Pressure;
    in dischargePressure : Pressure;
    in vibration : VibrationVelocity;
    in bearingTemperature : Temperature;
    out motorEnergized : Boolean;
    out alarmActive : Boolean;

    action validateSuctionCondition;
    action energizeMotor;
    action verifyRunoutAndMinimumFlow;
    action monitorProtectionLimits;
    action deenergizeMotor;
  }

  state def PumpSystemStates {
    state Off;
    state Priming;
    state Starting;
    state Running;
    state MinimumFlowProtection;
    state Stopping;
    state Tripped;

    transition initial then Off;
    transition Off_to_Priming
      first Off
      accept startCommand
      then Priming;

    transition Priming_to_Starting
      first Priming
      if suction.pressure > 120.0
      then Starting;

    transition Starting_to_Running
      first Starting
      if motor.ratedSpeed >= 1750.0
      then Running;

    transition Running_to_MinimumFlowProtection
      first Running
      if discharge.flowRate < minimumContinuousStableFlow
      then MinimumFlowProtection;

    transition MinimumFlowProtection_to_Running
      first MinimumFlowProtection
      if discharge.flowRate >= minimumContinuousStableFlow
      then Running;

    transition Running_to_Stopping
      first Running
      accept stopCommand
      then Stopping;

    transition Stopping_to_Off
      first Stopping
      then Off;

    transition Any_to_Tripped
      first Running
      if bearings.maximumTemperature > maximumBearingTemperature or instrumentation.vibrationAccuracy > maximumVibrationVelocity
      then Tripped;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : KarassikCentrifugalPumpSystem;
    require constraint {
      system.discharge.flowRate >= system.minimumContinuousStableFlow and
      system.discharge.pressure > system.suction.pressure
    }
  }

  requirement def HydraulicPerformanceRequirement {
    subject system : KarassikCentrifugalPumpSystem;
    require constraint {
      system.ratedFlow == 450.0 and
      system.ratedHead == 85.0 and
      system.requiredEfficiency >= 0.78
    }
  }

  requirement def CavitationAvoidanceRequirement {
    subject system : KarassikCentrifugalPumpSystem;
    require constraint {
      system.netPositiveSuctionHeadRequired <= 4.2
    }
  }

  requirement def ReliabilityRequirement {
    subject system : KarassikCentrifugalPumpSystem;
    require constraint {
      system.bearings.l10Life >= 50000.0 and
      system.maximumBearingTemperature <= 90.0 and
      system.maximumVibrationVelocity <= 4.5
    }
  }

  requirement def PressureContainmentRequirement {
    subject system : KarassikCentrifugalPumpSystem;
    require constraint {
      system.casing.designPressure >= 1600.0 and
      system.casing.hydrotestPressure >= 1.5 * system.casing.designPressure
    }
  }

  part karassikBasedTransferPump : KarassikCentrifugalPumpSystem;

}