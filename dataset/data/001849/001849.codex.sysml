package RotaryEngineModel {
  import ScalarValues::*;

  attribute def Pressure { attribute value : Real; attribute unit : String = "kPa"; }
  attribute def Temperature { attribute value : Real; attribute unit : String = "degC"; }
  attribute def Volume { attribute value : Real; attribute unit : String = "L"; }
  attribute def MassFlowRate { attribute value : Real; attribute unit : String = "g/s"; }
  attribute def RotationalSpeed { attribute value : Real; attribute unit : String = "rpm"; }
  attribute def Torque { attribute value : Real; attribute unit : String = "N*m"; }
  attribute def Power { attribute value : Real; attribute unit : String = "kW"; }
  attribute def Angle { attribute value : Real; attribute unit : String = "deg"; }
  attribute def Ratio { attribute value : Real; attribute unit : String = "1"; }

  item def Air {
    attribute massFlow : MassFlowRate;
    attribute temperature : Temperature;
    attribute pressure : Pressure;
  }

  item def Fuel {
    attribute massFlow : MassFlowRate;
    attribute octaneRating : Real;
    attribute lowerHeatingValue : Real;
  }

  item def AirFuelCharge {
    attribute airFuelRatio : Ratio;
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute chamberVolume : Volume;
  }

  item def CombustionGas {
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute residualOxygenFraction : Ratio;
  }

  item def ExhaustGas {
    attribute massFlow : MassFlowRate;
    attribute temperature : Temperature;
    attribute pressure : Pressure;
  }

  item def ShaftPower {
    attribute torque : Torque;
    attribute speed : RotationalSpeed;
    attribute power : Power;
  }

  item def SparkCommand {
    attribute timingBeforeTopDeadCenter : Angle;
    attribute dwellTimeMs : Real;
  }

  item def CoolingFluid {
    attribute massFlow : MassFlowRate;
    attribute inletTemperature : Temperature;
    attribute outletTemperature : Temperature;
  }

  port def AirInletPort {
    in item air : Air;
  }

  port def FuelInletPort {
    in item fuel : Fuel;
  }

  port def ChargePort {
    in item chargeIn : AirFuelCharge;
    out item chargeOut : AirFuelCharge;
  }

  port def GasPort {
    in item gasIn : CombustionGas;
    out item gasOut : CombustionGas;
  }

  port def ExhaustPort {
    out item exhaust : ExhaustGas;
  }

  port def PowerOutputPort {
    out item shaftPower : ShaftPower;
  }

  port def SparkPort {
    in item command : SparkCommand;
  }

  port def CoolantPort {
    in item coolantIn : CoolingFluid;
    out item coolantOut : CoolingFluid;
  }

  part def IntakeSystem {
    port airIn : AirInletPort;
    port chargeOut : ChargePort;

    attribute throttleOpening : Ratio;
    attribute manifoldPressure : Pressure;
    attribute manifoldTemperature : Temperature;

    action meterAir {
      in item incomingAir : Air;
      out item meteredCharge : AirFuelCharge;
    }
  }

  part def FuelInjectionSystem {
    port fuelIn : FuelInletPort;
    port chargeOut : ChargePort;

    attribute injectorPulseWidthMs : Real;
    attribute targetAirFuelRatio : Ratio = 14.7;

    action atomizeFuel {
      in item liquidFuel : Fuel;
      out item preparedCharge : AirFuelCharge;
    }
  }

  part def IgnitionSystem {
    port sparkSignal : SparkPort;

    attribute baseTiming : Angle;
    attribute maximumTimingAdvance : Angle;

    action generateSpark {
      in item command : SparkCommand;
    }
  }

  part def EccentricShaft {
    port powerOut : PowerOutputPort;

    attribute angularSpeed : RotationalSpeed;
    attribute deliveredTorque : Torque;
    attribute deliveredPower : Power;
    attribute eccentricity : Real;

    action convertRotorMotionToShaftPower {
      in item gasForce : CombustionGas;
      out item shaftPower : ShaftPower;
    }
  }

  part def TriangularRotor {
    attribute apexSealCount : Integer = 3;
    attribute faceCount : Integer = 3;
    attribute rotorAngle : Angle;
    attribute rotorSpeed : RotationalSpeed;
    attribute compressionRatio : Ratio;
    attribute sweptVolumePerFace : Volume;

    action sweepChambers {
      in item compressedCharge : AirFuelCharge;
      out item expandedGas : CombustionGas;
    }
  }

  part def EpitrochoidHousing {
    port chargeIn : ChargePort;
    port gasExchange : GasPort;
    port exhaustOut : ExhaustPort;
    port coolant : CoolantPort;

    attribute chamberPressure : Pressure;
    attribute housingTemperature : Temperature;
    attribute displacement : Volume;
    attribute sealLeakageRatio : Ratio;

    part rotor : TriangularRotor;

    action containWorkingChambers {
      in item charge : AirFuelCharge;
      out item combustionGas : CombustionGas;
      out item exhaustGas : ExhaustGas;
    }
  }

  part def CoolingSystem {
    port coolantCircuit : CoolantPort;

    attribute nominalFlowRate : MassFlowRate;
    attribute thermostatOpeningTemperature : Temperature;
    attribute maximumHousingTemperature : Temperature;

    action removeHeat {
      in item hotCoolant : CoolingFluid;
      out item cooledCoolant : CoolingFluid;
    }
  }

  action def RotaryCombustionCycle {
    in item freshCharge : AirFuelCharge;
    in item spark : SparkCommand;
    out item exhaust : ExhaustGas;
    out item shaftOutput : ShaftPower;

    action intake {
      in item charge : AirFuelCharge;
      out item trappedCharge : AirFuelCharge;
    }

    action compression {
      in item trappedCharge : AirFuelCharge;
      out item compressedCharge : AirFuelCharge;
    }

    action ignitionAndCombustion {
      in item compressedCharge : AirFuelCharge;
      in item sparkCommand : SparkCommand;
      out item highPressureGas : CombustionGas;
    }

    action expansion {
      in item highPressureGas : CombustionGas;
      out item mechanicalOutput : ShaftPower;
      out item spentGas : CombustionGas;
    }

    action exhaustBlowdown {
      in item spentGas : CombustionGas;
      out item dischargedExhaust : ExhaustGas;
    }

    flow freshCharge to intake.charge;
    flow intake.trappedCharge to compression.trappedCharge;
    flow compression.compressedCharge to ignitionAndCombustion.compressedCharge;
    flow spark to ignitionAndCombustion.sparkCommand;
    flow ignitionAndCombustion.highPressureGas to expansion.highPressureGas;
    flow expansion.spentGas to exhaustBlowdown.spentGas;
    flow expansion.mechanicalOutput to shaftOutput;
    flow exhaustBlowdown.dischargedExhaust to exhaust;
  }

  state def EngineOperatingState {
    state Off;
    state Starting;
    state Idling;
    state ProducingPower;
    state OverTemperature;
    state Shutdown;

    transition initial then Off;
    transition Off_to_Starting first Off then Starting;
    transition Starting_to_Idling first Starting then Idling;
    transition Idling_to_ProducingPower first Idling then ProducingPower;
    transition ProducingPower_to_Idling first ProducingPower then Idling;
    transition Any_to_OverTemperature first Idling then OverTemperature;
    transition Power_to_OverTemperature first ProducingPower then OverTemperature;
    transition OverTemperature_to_Shutdown first OverTemperature then Shutdown;
    transition Idling_to_Shutdown first Idling then Shutdown;
    transition Shutdown_to_Off first Shutdown then Off;
  }

  part def RotaryEngineSystem {
    doc /* Primary high-level function: convert metered air and fuel into rotating shaft power through the four phases of the Wankel rotary combustion cycle: intake, compression, combustion-expansion, and exhaust. */

    port ambientAirIn : AirInletPort;
    port fuelSupplyIn : FuelInletPort;
    port electricalSparkIn : SparkPort;
    port coolantInterface : CoolantPort;
    port exhaustOut : ExhaustPort;
    port mechanicalPowerOut : PowerOutputPort;

    attribute nominalDisplacement : Volume = (value = 1.3; unit = "L");
    attribute idleSpeed : RotationalSpeed = (value = 900.0; unit = "rpm");
    attribute maximumSpeed : RotationalSpeed = (value = 9000.0; unit = "rpm");
    attribute peakTorque : Torque = (value = 210.0; unit = "N*m");
    attribute peakPower : Power = (value = 170.0; unit = "kW");
    attribute nominalCompressionRatio : Ratio = (value = 10.0; unit = "1");
    attribute minimumOilFilmIntegrity : Ratio = (value = 0.85; unit = "1");

    part intake : IntakeSystem;
    part injection : FuelInjectionSystem;
    part ignition : IgnitionSystem;
    part housing : EpitrochoidHousing;
    part shaft : EccentricShaft;
    part cooling : CoolingSystem;

    perform cycle : RotaryCombustionCycle;
    exhibit states : EngineOperatingState;

    connect ambientAirIn to intake.airIn;
    connect fuelSupplyIn to injection.fuelIn;
    connect electricalSparkIn to ignition.sparkSignal;
    connect coolantInterface to cooling.coolantCircuit;
    connect cooling.coolantCircuit to housing.coolant;
    connect intake.chargeOut to housing.chargeIn;
    connect injection.chargeOut to housing.chargeIn;
    connect housing.exhaustOut to exhaustOut;
    connect shaft.powerOut to mechanicalPowerOut;

    flow housing.gasExchange.gasOut to shaft.convertRotorMotionToShaftPower.gasForce;
    flow shaft.convertRotorMotionToShaftPower.shaftPower to mechanicalPowerOut.shaftPower;
  }

  requirement def PrimaryFunctionRequirement {
    subject engine : RotaryEngineSystem;

    doc /* The rotary engine shall convert a controlled air-fuel charge into continuous rotational shaft power while discharging exhaust gas. */

    require constraint {
      engine.peakPower.value >= 150.0
    }
  }

  requirement def CombustionCycleRequirement {
    subject engine : RotaryEngineSystem;

    doc /* The engine shall complete intake, compression, combustion-expansion, and exhaust for each rotor face during steady operation. */

    require constraint {
      engine.nominalCompressionRatio.value >= 8.5 and
      engine.nominalCompressionRatio.value <= 11.5
    }
  }

  requirement def SpeedRangeRequirement {
    subject engine : RotaryEngineSystem;

    doc /* The eccentric shaft shall support stable idle speed and rated maximum operating speed. */

    require constraint {
      engine.idleSpeed.value >= 700.0 and
      engine.maximumSpeed.value >= 8000.0
    }
  }

  requirement def ThermalProtectionRequirement {
    subject engine : RotaryEngineSystem;

    doc /* The cooling system shall limit housing temperature during sustained power operation. */

    require constraint {
      engine.cooling.maximumHousingTemperature.value <= 115.0
    }
  }

  requirement def ExhaustDischargeRequirement {
    subject engine : RotaryEngineSystem;

    doc /* Exhaust gas produced by combustion shall be routed from the working chambers to the exhaust outlet without entering the intake path. */

    require constraint {
      engine.housing.sealLeakageRatio.value <= 0.03
    }
  }

  satisfy PrimaryFunctionRequirement by RotaryEngineSystem;
  satisfy CombustionCycleRequirement by RotaryEngineSystem;
  satisfy SpeedRangeRequirement by RotaryEngineSystem;
  satisfy ThermalProtectionRequirement by RotaryEngineSystem;
  satisfy ExhaustDischargeRequirement by RotaryEngineSystem;
}