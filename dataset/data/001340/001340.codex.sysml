package AmorphousMetalIsolationSystem {
  import ScalarValues::*;
  import ISQ::*;

  value def Millimeter :> length;
  value def Newton :> force;
  value def Hertz :> frequency;
  value def Celsius :> temperature;
  value def Volt :> electricPotential;
  value def Watt :> power;
  value def Percent :> dimensionless;
  value def Kilogram :> mass;

  item def MechanicalVibration {
    attribute amplitude : Millimeter;
    attribute frequency : Hertz;
    attribute forceMagnitude : Newton;
  }

  item def ElectricalPower {
    attribute voltage : Volt;
    attribute availablePower : Watt;
  }

  item def ThermalEnergy {
    attribute temperature : Celsius;
    attribute heatFlow : Watt;
  }

  item def HealthData {
    attribute dampingRatio : Percent;
    attribute coreTemperature : Celsius;
    attribute detectedCrackRisk : Percent;
    attribute overloadCount : Integer;
  }

  port def MechanicalMountPort {
    in item vibrationIn : MechanicalVibration;
    out item vibrationOut : MechanicalVibration;
  }

  port def ThermalPort {
    inout item heat : ThermalEnergy;
  }

  port def PowerPort {
    in item power : ElectricalPower;
  }

  port def DataPort {
    out item status : HealthData;
  }

  part def AmorphousMetalCore {
    attribute materialName : String = "zirconium-based bulk metallic glass";
    attribute glassTransitionTemperature : Celsius = 395;
    attribute crystallizationTemperature : Celsius = 475;
    attribute elasticLimit : Percent = 2;
    attribute density : Kilogram = 6.1;
    attribute nominalDampingRatio : Percent = 18;

    port mechanicalPort : MechanicalMountPort;
    port thermalPort : ThermalPort;
  }

  part def LaminatedRibbonStack {
    attribute layerCount : Integer = 96;
    attribute ribbonThickness : Millimeter = 0.025;
    attribute stackHeight : Millimeter = 8.0;
    attribute maximumRecoverableDeflection : Millimeter = 1.6;

    part core : AmorphousMetalCore;
    port mechanicalPort : MechanicalMountPort;
    port thermalPort : ThermalPort;
  }

  part def ConstraintHousing {
    attribute housingMaterial : String = "anodized aluminum alloy";
    attribute mass : Kilogram = 1.8;
    attribute maximumStaticLoad : Newton = 12000;

    port baseMount : MechanicalMountPort;
    port payloadMount : MechanicalMountPort;
    port thermalPort : ThermalPort;
  }

  part def PiezoTrimActuator {
    attribute stroke : Millimeter = 0.08;
    attribute blockingForce : Newton = 900;
    attribute driveVoltage : Volt = 48;

    port powerPort : PowerPort;
    port mechanicalPort : MechanicalMountPort;
  }

  part def VibrationSensor {
    attribute sampleRate : Hertz = 2000;
    attribute minimumFrequency : Hertz = 1;
    attribute maximumFrequency : Hertz = 800;

    port sensedMount : MechanicalMountPort;
    port dataPort : DataPort;
  }

  part def ThermalSensor {
    attribute accuracy : Celsius = 1.5;
    attribute tripTemperature : Celsius = 120;

    port thermalPort : ThermalPort;
    port dataPort : DataPort;
  }

  part def ControlElectronics {
    attribute processorMode : String = "adaptive damping supervision";
    attribute updateRate : Hertz = 500;
    attribute shutdownTemperature : Celsius = 135;

    port powerPort : PowerPort;
    port sensorIn : DataPort;
    port healthOut : DataPort;
  }

  part def HeatSpreader {
    attribute thermalConductivity : Watt = 170;
    attribute surfaceArea : Millimeter = 18000;

    port coreThermalPort : ThermalPort;
    port environmentThermalPort : ThermalPort;
  }

  action def AttenuateVibration {
    in item inputVibration : MechanicalVibration;
    out item outputVibration : MechanicalVibration;

    constraint {
      outputVibration.amplitude <= inputVibration.amplitude * 0.35;
      outputVibration.forceMagnitude <= inputVibration.forceMagnitude * 0.50;
    }
  }

  action def MonitorCoreHealth {
    in item measuredThermalEnergy : ThermalEnergy;
    out item health : HealthData;

    constraint {
      health.coreTemperature == measuredThermalEnergy.temperature;
      health.detectedCrackRisk <= 15;
    }
  }

  state def IsolationOperatingState {
    entry action initializeMonitoring;

    state idle;
    state characterizingInput;
    state isolating;
    state overloadProtection;
    state thermalProtection;
    state fault;

    transition first idle;

    transition idle_to_characterizing
      first idle
      then characterizingInput
      accept MechanicalVibration;

    transition characterizing_to_isolating
      first characterizingInput
      then isolating
      if inputAmplitudeKnown;

    transition isolating_to_overload
      first isolating
      then overloadProtection
      if inputForceAboveLimit;

    transition overload_to_isolating
      first overloadProtection
      then isolating
      if forceRecovered;

    transition isolating_to_thermal
      first isolating
      then thermalProtection
      if coreTemperatureAbove120C;

    transition thermal_to_idle
      first thermalProtection
      then idle
      if coreTemperatureBelow80C;

    transition any_to_fault
      first idle
      then fault
      if sensorInvalid or coreCrackRiskHigh;
  }

  part def AmorphousMetalVibrationIsolationModule {
    attribute primaryFunction : String =
      "Use the high elastic strain limit and intrinsic damping of amorphous metal to attenuate mechanical vibration transmitted from a base structure to a protected payload.";

    attribute ratedPayloadMass : Kilogram = 85;
    attribute ratedInputForce : Newton = 6000;
    attribute operatingTemperatureMin : Celsius = -40;
    attribute operatingTemperatureMax : Celsius = 120;
    attribute targetAmplitudeReduction : Percent = 65;

    port baseInterface : MechanicalMountPort;
    port payloadInterface : MechanicalMountPort;
    port powerInput : PowerPort;
    port healthOutput : DataPort;
    port ambientThermalPort : ThermalPort;

    part ribbonStack : LaminatedRibbonStack;
    part housing : ConstraintHousing;
    part trimActuator : PiezoTrimActuator;
    part vibrationSensor : VibrationSensor;
    part thermalSensor : ThermalSensor;
    part controller : ControlElectronics;
    part heatSpreader : HeatSpreader;

    connection base_to_housing connect baseInterface to housing.baseMount;
    connection housing_to_stack connect housing.payloadMount to ribbonStack.mechanicalPort;
    connection stack_to_payload connect ribbonStack.mechanicalPort to payloadInterface;
    connection actuator_to_stack connect trimActuator.mechanicalPort to ribbonStack.mechanicalPort;
    connection power_to_actuator connect powerInput to trimActuator.powerPort;
    connection power_to_controller connect powerInput to controller.powerPort;
    connection sensor_mount connect vibrationSensor.sensedMount to housing.payloadMount;
    connection sensor_to_controller connect vibrationSensor.dataPort to controller.sensorIn;
    connection thermal_sensor_to_core connect thermalSensor.thermalPort to ribbonStack.thermalPort;
    connection thermal_data_to_controller connect thermalSensor.dataPort to controller.sensorIn;
    connection controller_to_health connect controller.healthOut to healthOutput;
    connection stack_to_heat_spreader connect ribbonStack.thermalPort to heatSpreader.coreThermalPort;
    connection heat_spreader_to_ambient connect heatSpreader.environmentThermalPort to ambientThermalPort;

    perform action attenuate : AttenuateVibration;
    perform action monitor : MonitorCoreHealth;

    exhibit state behavior : IsolationOperatingState;
  }

  requirement def PrimaryFunctionRequirement {
    subject module : AmorphousMetalVibrationIsolationModule;

    require constraint {
      module.targetAmplitudeReduction >= 60;
      module.operatingTemperatureMax < module.ribbonStack.core.crystallizationTemperature;
    }
  }

  requirement def ElasticRecoveryRequirement {
    subject core : AmorphousMetalCore;

    require constraint {
      core.elasticLimit >= 1.8;
      core.nominalDampingRatio >= 15;
    }
  }

  requirement def ThermalSafetyRequirement {
    subject module : AmorphousMetalVibrationIsolationModule;

    require constraint {
      module.operatingTemperatureMax <= 120;
      module.ribbonStack.core.glassTransitionTemperature >= 350;
    }
  }

  requirement def PayloadProtectionRequirement {
    subject vibration : MechanicalVibration;

    require constraint {
      vibration.amplitude <= 0.35;
      vibration.frequency >= 1;
      vibration.frequency <= 800;
    }
  }

  part operationalSystem : AmorphousMetalVibrationIsolationModule;

  satisfy PrimaryFunctionRequirement by operationalSystem;
  satisfy ThermalSafetyRequirement by operationalSystem;
  satisfy ElasticRecoveryRequirement by operationalSystem.ribbonStack.core;
}