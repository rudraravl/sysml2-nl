package LiquidRingPumpingSubsystem {

  import ScalarValues::*;
  import ISQ::*;

  attribute def Pressure :> Real {
    unit = "kPa";
  }

  attribute def FlowRate :> Real {
    unit = "m^3/h";
  }

  attribute def Temperature :> Real {
    unit = "degC";
  }

  attribute def RotationalSpeed :> Real {
    unit = "rpm";
  }

  attribute def Power :> Real {
    unit = "kW";
  }

  attribute def Volume :> Real {
    unit = "L";
  }

  attribute def Level :> Real {
    unit = "%";
  }

  attribute def Vibration :> Real {
    unit = "mm/s";
  }

  attribute def Current :> Real {
    unit = "A";
  }

  item def ProcessFluid {
    attribute temperature : Temperature;
    attribute pressure : Pressure;
    attribute volumetricFlow : FlowRate;
    attribute vaporFraction : Real;
  }

  item def SealLiquid {
    attribute temperature : Temperature;
    attribute pressure : Pressure;
    attribute volumetricFlow : FlowRate;
    attribute dissolvedGasFraction : Real;
  }

  item def GasLiquidMixture {
    attribute temperature : Temperature;
    attribute pressure : Pressure;
    attribute volumetricFlow : FlowRate;
    attribute liquidCarryoverFraction : Real;
  }

  item def ElectricalPower {
    attribute voltage : Real;
    attribute current : Current;
    attribute realPower : Power;
  }

  item def ControlSignal {
    attribute command : String;
    attribute value : Real;
  }

  item def StatusSignal {
    attribute healthy : Boolean;
    attribute message : String;
    attribute measuredValue : Real;
  }

  port def FluidInletPort {
    in item fluid : ProcessFluid;
  }

  port def FluidOutletPort {
    out item mixture : GasLiquidMixture;
  }

  port def SealLiquidSupplyPort {
    in item sealLiquid : SealLiquid;
  }

  port def SealLiquidReturnPort {
    out item sealLiquid : SealLiquid;
  }

  port def PowerPort {
    in item power : ElectricalPower;
  }

  port def ControlPort {
    in item command : ControlSignal;
    out item status : StatusSignal;
  }

  port def VentPort {
    out item ventedGas : ProcessFluid;
  }

  port def DrainPort {
    out item drainedLiquid : SealLiquid;
  }

  part def LiquidRingPump {
    attribute casingDesignPressure : Pressure = 600.0;
    attribute nominalSuctionPressure : Pressure = 35.0;
    attribute nominalDischargePressure : Pressure = 160.0;
    attribute ratedCapacity : FlowRate = 240.0;
    attribute ratedSpeed : RotationalSpeed = 1750.0;
    attribute minimumSealLiquidFlow : FlowRate = 4.0;
    attribute maximumSealLiquidTemperature : Temperature = 32.0;
    attribute shaftPowerAtRatedPoint : Power = 38.0;
    attribute vibrationLimit : Vibration = 7.1;

    port suction : FluidInletPort;
    port discharge : FluidOutletPort;
    port sealIn : SealLiquidSupplyPort;
    port sealOut : SealLiquidReturnPort;
    port shaftPower : PowerPort;
    port control : ControlPort;
    port drain : DrainPort;

    part casing {
      attribute internalVolume : Volume = 95.0;
      attribute material : String = "316 stainless steel";
      attribute corrosionAllowance : Real = 3.0;
    }

    part impeller {
      attribute bladeCount : Integer = 16;
      attribute diameter : Real = 420.0;
      attribute material : String = "316 stainless steel";
    }

    part shaftSeal {
      attribute sealType : String = "single mechanical seal";
      attribute flushRequired : Boolean = true;
    }

    part bearingSet {
      attribute bearingType : String = "oil lubricated rolling element";
      attribute maximumBearingTemperature : Temperature = 85.0;
    }

    action createLiquidRing {
      in sealLiquidFlow : FlowRate;
      in shaftSpeed : RotationalSpeed;
      out ringEstablished : Boolean;

      first startRotation;
      then admitSealLiquid;
      then stabilizeRing;

      action startRotation;
      action admitSealLiquid;
      action stabilizeRing;
    }

    action compressAndDischarge {
      in inletFluid : ProcessFluid;
      in sealLiquidFlow : FlowRate;
      out dischargedMixture : GasLiquidMixture;

      first ingestFluid;
      then trapFluidBetweenBlades;
      then reduceCellVolume;
      then dischargeMixture;

      action ingestFluid;
      action trapFluidBetweenBlades;
      action reduceCellVolume;
      action dischargeMixture;
    }

    state machine operatingStates {
      state off;
      state preLubrication;
      state priming;
      state starting;
      state running;
      state lowFlowProtection;
      state shutdown;
      state fault;

      initial then off;

      transition off_to_preLubrication
        first off
        accept ControlSignal
        if command == "START"
        then preLubrication;

      transition preLubrication_to_priming
        first preLubrication
        if sealIn.sealLiquid.volumetricFlow >= minimumSealLiquidFlow
        then priming;

      transition priming_to_starting
        first priming
        if sealIn.sealLiquid.temperature <= maximumSealLiquidTemperature
        then starting;

      transition starting_to_running
        first starting
        if shaftPower.power.realPower > 5.0
        then running;

      transition running_to_lowFlowProtection
        first running
        if suction.fluid.volumetricFlow < 24.0
        then lowFlowProtection;

      transition lowFlowProtection_to_running
        first lowFlowProtection
        if suction.fluid.volumetricFlow >= 36.0
        then running;

      transition running_to_shutdown
        first running
        accept ControlSignal
        if command == "STOP"
        then shutdown;

      transition shutdown_to_off
        first shutdown
        then off;

      transition any_to_fault
        first running
        if sealIn.sealLiquid.volumetricFlow < minimumSealLiquidFlow or sealIn.sealLiquid.temperature > maximumSealLiquidTemperature
        then fault;
    }
  }

  part def DriveMotor {
    attribute ratedPower : Power = 45.0;
    attribute ratedSpeed : RotationalSpeed = 1800.0;
    attribute ratedCurrent : Current = 72.0;
    attribute enclosure : String = "TEFC";
    attribute insulationClass : String = "F";

    port electricalSupply : PowerPort;
    port control : ControlPort;
    port mechanicalOutput : PowerPort;

    state machine motorStates {
      state deenergized;
      state accelerating;
      state energized;
      state tripped;

      initial then deenergized;

      transition startMotor
        first deenergized
        accept ControlSignal
        if command == "START"
        then accelerating;

      transition reachSpeed
        first accelerating
        if mechanicalOutput.power.realPower >= 30.0
        then energized;

      transition stopMotor
        first energized
        accept ControlSignal
        if command == "STOP"
        then deenergized;

      transition overloadTrip
        first energized
        if electricalSupply.power.current > ratedCurrent * 1.15
        then tripped;
    }
  }

  part def SealLiquidSystem {
    attribute reservoirCapacity : Volume = 350.0;
    attribute normalLevel : Level = 65.0;
    attribute lowLevelTrip : Level = 25.0;
    attribute coolerDuty : Power = 12.0;
    attribute supplyPressure : Pressure = 250.0;

    port makeUpIn : SealLiquidSupplyPort;
    port supplyToPump : SealLiquidSupplyPort;
    port returnFromPump : SealLiquidReturnPort;
    port drain : DrainPort;
    port control : ControlPort;

    part reservoir {
      attribute capacity : Volume = 350.0;
      attribute operatingLevel : Level = 65.0;
      attribute material : String = "carbon steel with epoxy lining";
    }

    part heatExchanger {
      attribute duty : Power = 12.0;
      attribute outletTemperature : Temperature = 28.0;
    }

    part strainer {
      attribute meshSize : Real = 500.0;
      attribute differentialPressureAlarm : Pressure = 35.0;
    }

    part circulationValve {
      attribute valveType : String = "modulating globe valve";
      attribute failPosition : String = "open";
    }

    action conditionSealLiquid {
      in returnedLiquid : SealLiquid;
      out cooledFilteredLiquid : SealLiquid;

      first separateEntrainedGas;
      then coolLiquid;
      then filterSolids;
      then regulateFlow;

      action separateEntrainedGas;
      action coolLiquid;
      action filterSolids;
      action regulateFlow;
    }
  }

  part def Separator {
    attribute vesselVolume : Volume = 900.0;
    attribute designPressure : Pressure = 400.0;
    attribute normalLiquidLevel : Level = 55.0;
    attribute highLevelAlarm : Level = 80.0;
    attribute demisterEfficiency : Real = 0.99;

    port mixtureIn : FluidInletPort;
    port liquidReturn : SealLiquidReturnPort;
    port gasVent : VentPort;
    port drain : DrainPort;
    port control : ControlPort;

    part inletBaffle {
      attribute material : String = "316 stainless steel";
    }

    part demisterPad {
      attribute material : String = "316 stainless steel mesh";
      attribute removalEfficiencyFor10MicronDroplets : Real = 0.99;
    }

    part levelTransmitter {
      attribute rangeLow : Level = 0.0;
      attribute rangeHigh : Level = 100.0;
    }

    action separateMixture {
      in incomingMixture : GasLiquidMixture;
      out recoveredSealLiquid : SealLiquid;
      out ventedProcessGas : ProcessFluid;

      first reduceVelocity;
      then knockOutLiquid;
      then demistGas;
      then returnSealLiquid;

      action reduceVelocity;
      action knockOutLiquid;
      action demistGas;
      action returnSealLiquid;
    }
  }

  part def InstrumentationAndControl {
    port pumpControl : ControlPort;
    port motorControl : ControlPort;
    port sealSystemControl : ControlPort;
    port separatorControl : ControlPort;
    port operatorInterface : ControlPort;

    part suctionPressureTransmitter {
      attribute rangeLow : Pressure = 0.0;
      attribute rangeHigh : Pressure = 200.0;
      attribute alarmLow : Pressure = 15.0;
    }

    part dischargePressureTransmitter {
      attribute rangeLow : Pressure = 0.0;
      attribute rangeHigh : Pressure = 400.0;
      attribute alarmHigh : Pressure = 220.0;
    }

    part sealLiquidFlowTransmitter {
      attribute rangeLow : FlowRate = 0.0;
      attribute rangeHigh : FlowRate = 12.0;
      attribute tripLow : FlowRate = 3.2;
    }

    part sealLiquidTemperatureTransmitter {
      attribute rangeLow : Temperature = 0.0;
      attribute rangeHigh : Temperature = 80.0;
      attribute tripHigh : Temperature = 38.0;
    }

    part vibrationTransmitter {
      attribute rangeLow : Vibration = 0.0;
      attribute rangeHigh : Vibration = 25.0;
      attribute tripHigh : Vibration = 10.0;
    }

    action startSequence {
      first verifyPermissives;
      then openSealLiquidValve;
      then energizeMotor;
      then confirmPumpRunning;
      then releaseProcessFlow;

      action verifyPermissives;
      action openSealLiquidValve;
      action energizeMotor;
      action confirmPumpRunning;
      action releaseProcessFlow;
    }

    action protectiveShutdown {
      first closeProcessIsolation;
      then tripMotor;
      then keepSealLiquidPurge;
      then alarmOperator;

      action closeProcessIsolation;
      action tripMotor;
      action keepSealLiquidPurge;
      action alarmOperator;
    }
  }

  part def PumpingSubsystem {
    attribute requiredCapacity : FlowRate = 200.0;
    attribute minimumContinuousCapacity : FlowRate = 24.0;
    attribute normalSuctionPressure : Pressure = 35.0;
    attribute normalDischargePressure : Pressure = 160.0;
    attribute maximumFluidTemperature : Temperature = 45.0;
    attribute availabilityTarget : Real = 0.985;

    port processInlet : FluidInletPort;
    port processOutletVent : VentPort;
    port electricalInlet : PowerPort;
    port makeUpSealLiquid : SealLiquidSupplyPort;
    port drainOutlet : DrainPort;
    port operatorCommand : ControlPort;

    part pump : LiquidRingPump;
    part motor : DriveMotor;
    part sealLiquidSkid : SealLiquidSystem;
    part dischargeSeparator : Separator;
    part controls : InstrumentationAndControl;

    connect processInlet.fluid to pump.suction.fluid;
    connect pump.discharge.mixture to dischargeSeparator.mixtureIn.fluid;
    connect dischargeSeparator.gasVent.ventedGas to processOutletVent.ventedGas;
    connect dischargeSeparator.liquidReturn.sealLiquid to sealLiquidSkid.returnFromPump.sealLiquid;
    connect sealLiquidSkid.supplyToPump.sealLiquid to pump.sealIn.sealLiquid;
    connect pump.sealOut.sealLiquid to sealLiquidSkid.returnFromPump.sealLiquid;
    connect makeUpSealLiquid.sealLiquid to sealLiquidSkid.makeUpIn.sealLiquid;
    connect electricalInlet.power to motor.electricalSupply.power;
    connect motor.mechanicalOutput.power to pump.shaftPower.power;
    connect operatorCommand.command to controls.operatorInterface.command;
    connect controls.pumpControl.command to pump.control.command;
    connect controls.motorControl.command to motor.control.command;
    connect controls.sealSystemControl.command to sealLiquidSkid.control.command;
    connect controls.separatorControl.command to dischargeSeparator.control.command;
    connect pump.drain.drainedLiquid to drainOutlet.drainedLiquid;
    connect sealLiquidSkid.drain.drainedLiquid to drainOutlet.drainedLiquid;
    connect dischargeSeparator.drain.drainedLiquid to drainOutlet.drainedLiquid;

    action normalOperation {
      first receiveStartCommand;
      then controls.startSequence;
      then pump.createLiquidRing;
      then pump.compressAndDischarge;
      then dischargeSeparator.separateMixture;
      then sealLiquidSkid.conditionSealLiquid;

      action receiveStartCommand;
    }

    action shutdownOperation {
      first receiveStopCommand;
      then controls.protectiveShutdown;
      then stopSealLiquidAfterCooldown;

      action receiveStopCommand;
      action stopSealLiquidAfterCooldown;
    }
  }

  requirement def CapacityRequirement {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.requiredCapacity >= 200.0
    }
  }

  requirement def SealLiquidProtectionRequirement {
    subject pump : LiquidRingPump;
    require constraint {
      pump.sealIn.sealLiquid.volumetricFlow >= pump.minimumSealLiquidFlow and
      pump.sealIn.sealLiquid.temperature <= pump.maximumSealLiquidTemperature
    }
  }

  requirement def PressureContainmentRequirement {
    subject pump : LiquidRingPump;
    require constraint {
      pump.casingDesignPressure >= 2.5 * pump.nominalDischargePressure
    }
  }

  requirement def MotorSizingRequirement {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.motor.ratedPower >= 1.15 * subsystem.pump.shaftPowerAtRatedPoint
    }
  }

  requirement def SeparatorCarryoverRequirement {
    subject separator : Separator;
    require constraint {
      separator.demisterEfficiency >= 0.99
    }
  }

  requirement def LowFlowProtectionRequirement {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.minimumContinuousCapacity >= 0.10 * subsystem.requiredCapacity
    }
  }

  requirement def AvailabilityRequirement {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.availabilityTarget >= 0.985
    }
  }

  part liquidRingPumpingSubsystem : PumpingSubsystem;

  requirement capacitySatisfied : CapacityRequirement {
    subject subsystem = liquidRingPumpingSubsystem;
  }

  requirement sealLiquidProtected : SealLiquidProtectionRequirement {
    subject pump = liquidRingPumpingSubsystem.pump;
  }

  requirement pressureContained : PressureContainmentRequirement {
    subject pump = liquidRingPumpingSubsystem.pump;
  }

  requirement motorSized : MotorSizingRequirement {
    subject subsystem = liquidRingPumpingSubsystem;
  }

  requirement separatorPerformance : SeparatorCarryoverRequirement {
    subject separator = liquidRingPumpingSubsystem.dischargeSeparator;
  }

  requirement lowFlowProtected : LowFlowProtectionRequirement {
    subject subsystem = liquidRingPumpingSubsystem;
  }

  requirement availabilitySpecified : AvailabilityRequirement {
    subject subsystem = liquidRingPumpingSubsystem;
  }
}