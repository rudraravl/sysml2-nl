package RoboticFishSystemModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  value type LengthValue = Real { unit = "m"; }
  value type MassValue = Real { unit = "kg"; }
  value type TimeValue = Real { unit = "s"; }
  value type SpeedValue = Real { unit = "m/s"; }
  value type AccelerationValue = Real { unit = "m/s^2"; }
  value type AngleValue = Real { unit = "deg"; }
  value type AngularRateValue = Real { unit = "deg/s"; }
  value type ForceValue = Real { unit = "N"; }
  value type TorqueValue = Real { unit = "N*m"; }
  value type VoltageValue = Real { unit = "V"; }
  value type CurrentValue = Real { unit = "A"; }
  value type PowerValue = Real { unit = "W"; }
  value type EnergyValue = Real { unit = "Wh"; }
  value type PressureValue = Real { unit = "Pa"; }
  value type TemperatureValue = Real { unit = "degC"; }
  value type SalinityValue = Real { unit = "ppt"; }
  value type DepthValue = Real { unit = "m"; }
  value type HeadingValue = Real { unit = "deg"; }
  value type DataRateValue = Real { unit = "kbps"; }
  value type PercentageValue = Real { unit = "%"; }

  enum def MissionMode {
    enum idle;
    enum cruise;
    enum inspect;
    enum stationKeep;
    enum returnHome;
    enum emergencySurface;
  }

  enum def HealthState {
    enum nominal;
    enum degraded;
    enum critical;
  }

  enum def WaterType {
    enum fresh;
    enum brackish;
    enum salt;
  }

  item def CommandPacket {
    attribute requestedMode : MissionMode;
    attribute targetDepth : DepthValue;
    attribute targetHeading : HeadingValue;
    attribute targetSpeed : SpeedValue;
    attribute missionDuration : TimeValue;
  }

  item def NavigationEstimate {
    attribute depth : DepthValue;
    attribute heading : HeadingValue;
    attribute speed : SpeedValue;
    attribute pitch : AngleValue;
    attribute roll : AngleValue;
    attribute positionUncertainty : LengthValue;
  }

  item def EnvironmentalSample {
    attribute waterTemperature : TemperatureValue;
    attribute salinity : SalinityValue;
    attribute pressure : PressureValue;
    attribute measuredDepth : DepthValue;
    attribute timestamp : TimeValue;
  }

  item def TelemetryPacket {
    attribute currentMode : MissionMode;
    attribute health : HealthState;
    attribute batteryStateOfCharge : PercentageValue;
    attribute navigation : NavigationEstimate;
    attribute latestSample : EnvironmentalSample;
  }

  item def ElectricalEnergy {
    attribute storedEnergy : EnergyValue;
    attribute voltage : VoltageValue;
    attribute current : CurrentValue;
  }

  item def PropulsiveForce {
    attribute magnitude : ForceValue;
    attribute lateralComponent : ForceValue;
    attribute axialComponent : ForceValue;
  }

  item def SteeringTorque {
    attribute magnitude : TorqueValue;
    attribute directionAngle : AngleValue;
  }

  port def CommandPort {
    in item command : CommandPacket;
  }

  port def TelemetryPort {
    out item telemetry : TelemetryPacket;
  }

  port def PowerOutputPort {
    out item energy : ElectricalEnergy;
  }

  port def PowerInputPort {
    in item energy : ElectricalEnergy;
  }

  port def NavigationPort {
    out item estimate : NavigationEstimate;
  }

  port def SensorSamplePort {
    out item sample : EnvironmentalSample;
  }

  port def PropulsionCommandPort {
    in attribute tailBeatFrequency : AngularRateValue;
    in attribute tailAmplitude : AngleValue;
  }

  port def SteeringCommandPort {
    in attribute finAngle : AngleValue;
  }

  port def PropulsiveForcePort {
    out item thrust : PropulsiveForce;
  }

  port def SteeringForcePort {
    out item steering : SteeringTorque;
  }

  port def WaterInteractionPort {
    in attribute ambientPressure : PressureValue;
    in attribute ambientTemperature : TemperatureValue;
    in attribute ambientSalinity : SalinityValue;
    out item thrust : PropulsiveForce;
    out item steering : SteeringTorque;
  }

  part def BatteryPack {
    attribute nominalVoltage : VoltageValue = 24.0;
    attribute capacity : EnergyValue = 220.0;
    attribute stateOfCharge : PercentageValue;
    attribute maxContinuousPower : PowerValue = 180.0;
    attribute mass : MassValue = 1.8;

    port powerOut : PowerOutputPort;
  }

  part def PowerManagementUnit {
    attribute regulatedBusVoltage : VoltageValue = 12.0;
    attribute conversionEfficiency : PercentageValue = 92.0;
    attribute maximumOutputPower : PowerValue = 150.0;

    port inputPower : PowerInputPort;
    port controllerPower : PowerOutputPort;
    port actuatorPower : PowerOutputPort;
    port sensorPower : PowerOutputPort;
  }

  part def MissionComputer {
    attribute processorPower : PowerValue = 12.0;
    attribute telemetryRate : DataRateValue = 64.0;
    attribute activeMode : MissionMode;
    attribute health : HealthState;

    port commandIn : CommandPort;
    port telemetryOut : TelemetryPort;
    port powerIn : PowerInputPort;
    port navigationIn : NavigationPort;
    port environmentIn : SensorSamplePort;
    port propulsionOut : PropulsionCommandPort;
    port steeringOut : SteeringCommandPort;
  }

  part def InertialNavigationUnit {
    attribute headingAccuracy : AngleValue = 2.0;
    attribute depthAccuracy : DepthValue = 0.15;
    attribute updatePeriod : TimeValue = 0.05;

    port powerIn : PowerInputPort;
    port navOut : NavigationPort;
  }

  part def EnvironmentalSensorSuite {
    attribute temperatureAccuracy : TemperatureValue = 0.2;
    attribute salinityAccuracy : SalinityValue = 0.5;
    attribute pressureAccuracy : PressureValue = 500.0;
    attribute samplePeriod : TimeValue = 1.0;

    port powerIn : PowerInputPort;
    port sampleOut : SensorSamplePort;
  }

  part def FlexibleCaudalFinActuator {
    attribute maximumTailAmplitude : AngleValue = 35.0;
    attribute maximumTailBeatRate : AngularRateValue = 240.0;
    attribute nominalPower : PowerValue = 80.0;
    attribute peakPropulsiveForce : ForceValue = 18.0;

    port powerIn : PowerInputPort;
    port commandIn : PropulsionCommandPort;
    port thrustOut : PropulsiveForcePort;
    port waterInterface : WaterInteractionPort;
  }

  part def PectoralFinSteeringActuator {
    attribute maximumFinDeflection : AngleValue = 30.0;
    attribute responseTime : TimeValue = 0.15;
    attribute nominalPower : PowerValue = 35.0;
    attribute peakSteeringTorque : TorqueValue = 3.0;

    port powerIn : PowerInputPort;
    port commandIn : SteeringCommandPort;
    port steeringOut : SteeringForcePort;
    port waterInterface : WaterInteractionPort;
  }

  part def BuoyancyTrimModule {
    attribute trimMass : MassValue = 0.45;
    attribute maximumTrimShift : LengthValue = 0.08;
    attribute neutralBuoyancyDepth : DepthValue = 5.0;
    attribute trimResponseTime : TimeValue = 3.0;

    port powerIn : PowerInputPort;
  }

  part def WatertightHull {
    attribute bodyLength : LengthValue = 0.85;
    attribute bodyDiameter : LengthValue = 0.16;
    attribute dryMass : MassValue = 5.4;
    attribute ratedDepth : DepthValue = 50.0;
    attribute dragCoefficient : Real = 0.18;
    attribute compatibleWaterType : WaterType = WaterType::salt;

    port waterInterface : WaterInteractionPort;
  }

  action def AcquireEnvironmentalData {
    in nav : NavigationEstimate;
    in sample : EnvironmentalSample;
    out telemetrySample : EnvironmentalSample;

    first start;
    then validateDepth;
    then validateTemperature;
    then publishSample;
    then done;

    action validateDepth {
      assert constraint { sample.measuredDepth >= 0.0 and sample.measuredDepth <= 50.0; }
    }

    action validateTemperature {
      assert constraint { sample.waterTemperature >= -2.0 and sample.waterTemperature <= 40.0; }
    }

    action publishSample {
      telemetrySample = sample;
    }
  }

  action def GenerateFishLikePropulsion {
    in desiredSpeed : SpeedValue;
    in currentSpeed : SpeedValue;
    out tailBeatFrequency : AngularRateValue;
    out tailAmplitude : AngleValue;

    first computeSpeedError;
    then computeFrequency;
    then computeAmplitude;
    then commandActuator;
    then done;

    action computeSpeedError;
    action computeFrequency {
      tailBeatFrequency = 60.0 + 120.0 * (desiredSpeed - currentSpeed);
    }

    action computeAmplitude {
      tailAmplitude = 8.0 + 18.0 * (desiredSpeed - currentSpeed);
    }

    action commandActuator;
  }

  action def MaintainDepthAndHeading {
    in targetDepth : DepthValue;
    in targetHeading : HeadingValue;
    in estimate : NavigationEstimate;
    out finAngle : AngleValue;

    first compareNavigation;
    then computeCorrection;
    then commandFins;
    then done;

    action compareNavigation;
    action computeCorrection {
      finAngle = 0.2 * (targetHeading - estimate.heading) + 1.5 * (targetDepth - estimate.depth);
    }

    action commandFins;
  }

  action def ReportMissionTelemetry {
    in mode : MissionMode;
    in health : HealthState;
    in stateOfCharge : PercentageValue;
    in nav : NavigationEstimate;
    in sample : EnvironmentalSample;
    out report : TelemetryPacket;

    first assemble;
    then transmit;
    then done;

    action assemble {
      report.currentMode = mode;
      report.health = health;
      report.batteryStateOfCharge = stateOfCharge;
      report.navigation = nav;
      report.latestSample = sample;
    }

    action transmit;
  }

  state def RoboticFishOperationalStateMachine {
    in command : CommandPacket;
    in batteryStateOfCharge : PercentageValue;
    in health : HealthState;

    state idle;
    state cruise;
    state inspect;
    state stationKeep;
    state returnHome;
    state emergencySurface;

    entry; then idle;

    transition idle_to_cruise
      first idle
      accept command
      if command.requestedMode == MissionMode::cruise
      then cruise;

    transition cruise_to_inspect
      first cruise
      accept command
      if command.requestedMode == MissionMode::inspect
      then inspect;

    transition inspect_to_stationKeep
      first inspect
      accept command
      if command.requestedMode == MissionMode::stationKeep
      then stationKeep;

    transition stationKeep_to_cruise
      first stationKeep
      accept command
      if command.requestedMode == MissionMode::cruise
      then cruise;

    transition any_to_returnHome
      first cruise
      accept command
      if command.requestedMode == MissionMode::returnHome or batteryStateOfCharge < 20.0
      then returnHome;

    transition inspect_to_returnHome
      first inspect
      if batteryStateOfCharge < 20.0
      then returnHome;

    transition stationKeep_to_returnHome
      first stationKeep
      if batteryStateOfCharge < 20.0
      then returnHome;

    transition any_to_emergencySurface
      first cruise
      if health == HealthState::critical or batteryStateOfCharge < 8.0
      then emergencySurface;

    transition inspect_to_emergencySurface
      first inspect
      if health == HealthState::critical or batteryStateOfCharge < 8.0
      then emergencySurface;

    transition stationKeep_to_emergencySurface
      first stationKeep
      if health == HealthState::critical or batteryStateOfCharge < 8.0
      then emergencySurface;

    transition returnHome_to_idle
      first returnHome
      accept command
      if command.requestedMode == MissionMode::idle
      then idle;
  }

  part def RoboticFish {
    attribute designLength : LengthValue = 0.85;
    attribute totalMass : MassValue = 8.2;
    attribute maximumSpeed : SpeedValue = 1.4;
    attribute cruiseSpeed : SpeedValue = 0.7;
    attribute endurance : TimeValue = 7200.0;
    attribute maximumOperatingDepth : DepthValue = 50.0;
    attribute minimumTurnRadius : LengthValue = 0.6;
    attribute primaryFunction : String = "Autonomously swim through an underwater environment using fish-like propulsion while collecting environmental data and reporting mission telemetry.";

    port commandPort : CommandPort;
    port telemetryPort : TelemetryPort;
    port waterInterface : WaterInteractionPort;

    part hull : WatertightHull;
    part battery : BatteryPack;
    part powerManagement : PowerManagementUnit;
    part computer : MissionComputer;
    part navigationUnit : InertialNavigationUnit;
    part environmentSensors : EnvironmentalSensorSuite;
    part caudalActuator : FlexibleCaudalFinActuator;
    part pectoralActuator : PectoralFinSteeringActuator;
    part buoyancyTrim : BuoyancyTrimModule;

    perform operationalBehavior : RoboticFishOperationalStateMachine;

    perform propulsionControl : GenerateFishLikePropulsion;
    perform navigationControl : MaintainDepthAndHeading;
    perform environmentalAcquisition : AcquireEnvironmentalData;
    perform telemetryReporting : ReportMissionTelemetry;

    connect commandPort to computer.commandIn;
    connect computer.telemetryOut to telemetryPort;

    connect battery.powerOut to powerManagement.inputPower;
    connect powerManagement.controllerPower to computer.powerIn;
    connect powerManagement.sensorPower to navigationUnit.powerIn;
    connect powerManagement.sensorPower to environmentSensors.powerIn;
    connect powerManagement.actuatorPower to caudalActuator.powerIn;
    connect powerManagement.actuatorPower to pectoralActuator.powerIn;
    connect powerManagement.actuatorPower to buoyancyTrim.powerIn;

    connect navigationUnit.navOut to computer.navigationIn;
    connect environmentSensors.sampleOut to computer.environmentIn;

    connect computer.propulsionOut to caudalActuator.commandIn;
    connect computer.steeringOut to pectoralActuator.commandIn;

    connect caudalActuator.waterInterface to hull.waterInterface;
    connect pectoralActuator.waterInterface to hull.waterInterface;
    connect hull.waterInterface to waterInterface;

    constraint massBudget {
      totalMass == hull.dryMass + battery.mass + buoyancyTrim.trimMass + 0.55 + 0.35 + 0.42 + 0.58 + 0.37;
    }

    constraint operatingDepthLimit {
      maximumOperatingDepth <= hull.ratedDepth;
    }

    constraint speedLimit {
      cruiseSpeed <= maximumSpeed;
    }

    constraint endurancePowerLimit {
      battery.capacity * 3600.0 >= endurance * 60.0;
    }
  }

  requirement def PrimaryFunctionRequirement {
    id = "RF-REQ-001";
    text = "The robotic fish shall autonomously swim underwater using biomimetic tail propulsion while maintaining commanded depth and heading, collecting environmental samples, and transmitting telemetry.";
  }

  requirement def DepthRequirement {
    id = "RF-REQ-002";
    text = "The robotic fish shall operate at depths from the surface to 50 meters without hull leakage or loss of control.";
  }

  requirement def EnduranceRequirement {
    id = "RF-REQ-003";
    text = "The robotic fish shall perform a nominal cruise mission for at least 2 hours at 0.7 meters per second.";
  }

  requirement def ManeuverRequirement {
    id = "RF-REQ-004";
    text = "The robotic fish shall turn with a radius no greater than 0.6 meters at cruise speed.";
  }

  requirement def TelemetryRequirement {
    id = "RF-REQ-005";
    text = "The robotic fish shall transmit telemetry containing mode, health, battery state, navigation estimate, and environmental sample data.";
  }

  requirement def EmergencyRequirement {
    id = "RF-REQ-006";
    text = "The robotic fish shall enter emergency surface mode when health is critical or battery state of charge is below 8 percent.";
  }

  requirement def BiomimeticPropulsionRequirement {
    id = "RF-REQ-007";
    text = "The robotic fish shall generate forward thrust using an oscillating flexible caudal fin with commanded tail beat frequency and amplitude.";
  }

  satisfy PrimaryFunctionRequirement by RoboticFish;
  satisfy DepthRequirement by RoboticFish::hull;
  satisfy EnduranceRequirement by RoboticFish::battery;
  satisfy ManeuverRequirement by RoboticFish::pectoralActuator;
  satisfy TelemetryRequirement by RoboticFish::computer;
  satisfy EmergencyRequirement by RoboticFish::operationalBehavior;
  satisfy BiomimeticPropulsionRequirement by RoboticFish::caudalActuator;

  analysis def MissionPerformanceAnalysis {
    subject fish : RoboticFish;

    objective verifyCruiseRange {
      assert constraint {
        fish.cruiseSpeed * fish.endurance >= 5040.0;
      }
    }

    objective verifyDepthCapability {
      assert constraint {
        fish.maximumOperatingDepth <= fish.hull.ratedDepth;
      }
    }

    objective verifyPowerMargin {
      assert constraint {
        fish.powerManagement.maximumOutputPower <= fish.battery.maxContinuousPower;
      }
    }
  }

  part missionExample : RoboticFish {
    attribute designLength = 0.85;
    attribute totalMass = 8.2;
    attribute maximumSpeed = 1.4;
    attribute cruiseSpeed = 0.7;
    attribute endurance = 7200.0;
    attribute maximumOperatingDepth = 50.0;
    attribute minimumTurnRadius = 0.6;
  }

}