package RemotelyOperatedUnderwaterVehicleModel {

  import ScalarValues::*;
  import SI::*;

  enum def MissionMode {
    enum idle;
    enum preDiveCheck;
    enum launch;
    enum transit;
    enum inspect;
    enum manipulate;
    enum recover;
    enum emergencyReturn;
  }

  enum def HealthState {
    enum nominal;
    enum degraded;
    enum faulted;
    enum critical;
  }

  attribute def Depth {
    :> scalar;
    unit = SI::metre;
  }

  attribute def Speed {
    :> scalar;
    unit = SI::metrePerSecond;
  }

  attribute def ElectricalPower {
    :> scalar;
    unit = SI::watt;
  }

  attribute def Voltage {
    :> scalar;
    unit = SI::volt;
  }

  attribute def Force {
    :> scalar;
    unit = SI::newton;
  }

  attribute def DataRate {
    :> scalar;
    unit = SI::bitPerSecond;
  }

  attribute def Temperature {
    :> scalar;
    unit = SI::kelvin;
  }

  item def PowerDC {
    attribute voltage : Voltage;
    attribute power : ElectricalPower;
  }

  item def CommandPacket {
    attribute commandedMode : MissionMode;
    attribute desiredDepth : Depth;
    attribute desiredHeadingDeg : Real;
    attribute desiredSpeed : Speed;
    attribute manipulatorCommand : String;
  }

  item def TelemetryPacket {
    attribute actualDepth : Depth;
    attribute headingDeg : Real;
    attribute speed : Speed;
    attribute internalTemperature : Temperature;
    attribute vehicleHealth : HealthState;
    attribute leakDetected : Boolean;
  }

  item def VideoStream {
    attribute resolution : String;
    attribute frameRateHz : Real;
    attribute dataRate : DataRate;
  }

  item def SonarImage {
    attribute range : Real;
    attribute bearingDeg : Real;
    attribute confidence : Real;
  }

  port def ElectricalPowerPort {
    in item powerIn : PowerDC;
    out item powerOut : PowerDC;
  }

  port def CommandPort {
    in item commandIn : CommandPacket;
    out item commandOut : CommandPacket;
  }

  port def TelemetryPort {
    in item telemetryIn : TelemetryPacket;
    out item telemetryOut : TelemetryPacket;
  }

  port def VideoPort {
    in item videoIn : VideoStream;
    out item videoOut : VideoStream;
  }

  port def SonarPort {
    in item sonarIn : SonarImage;
    out item sonarOut : SonarImage;
  }

  part def SurfaceControlStation {
    attribute operatorCount : Integer = 2;
    attribute displayCount : Integer = 3;

    port commandLink : CommandPort;
    port telemetryLink : TelemetryPort;
    port videoLink : VideoPort;
    port powerFeed : ElectricalPowerPort;
  }

  part def UmbilicalTether {
    attribute length : Depth = 300 [SI::metre];
    attribute maxDataRate : DataRate = 100000000 [SI::bitPerSecond];
    attribute maxPowerTransfer : ElectricalPower = 12000 [SI::watt];

    port surfacePower : ElectricalPowerPort;
    port vehiclePower : ElectricalPowerPort;
    port surfaceCommand : CommandPort;
    port vehicleCommand : CommandPort;
    port surfaceTelemetry : TelemetryPort;
    port vehicleTelemetry : TelemetryPort;
    port surfaceVideo : VideoPort;
    port vehicleVideo : VideoPort;
  }

  part def PressureHull {
    attribute maximumOperatingDepth : Depth = 300 [SI::metre];
    attribute dryMassKg : Real = 410.0;
    attribute buoyancyMarginPercent : Real = 8.0;
  }

  part def PropulsionModule {
    attribute thrusterCount : Integer = 6;
    attribute maximumForwardSpeed : Speed = 1.5 [SI::metrePerSecond];
    attribute maximumVerticalSpeed : Speed = 0.7 [SI::metrePerSecond];
    attribute totalBollardThrust : Force = 900 [SI::newton];

    port power : ElectricalPowerPort;
    port command : CommandPort;
    port telemetry : TelemetryPort;
  }

  part def NavigationModule {
    attribute depthAccuracy : Depth = 0.05 [SI::metre];
    attribute headingAccuracyDeg : Real = 0.5;

    port power : ElectricalPowerPort;
    port command : CommandPort;
    port telemetry : TelemetryPort;
  }

  part def SensorPayload {
    attribute cameraCount : Integer = 3;
    attribute lightOutputLumen : Real = 24000.0;
    attribute sonarRangeM : Real = 120.0;

    port power : ElectricalPowerPort;
    port command : CommandPort;
    port telemetry : TelemetryPort;
    port video : VideoPort;
    port sonar : SonarPort;
  }

  part def ManipulatorArm {
    attribute degreeOfFreedom : Integer = 5;
    attribute maximumGripForce : Force = 450 [SI::newton];
    attribute reachM : Real = 1.2;

    port power : ElectricalPowerPort;
    port command : CommandPort;
    port telemetry : TelemetryPort;
  }

  part def VehicleComputer {
    attribute controlLoopRateHz : Real = 100.0;
    attribute dataRecorderCapacityGB : Real = 2048.0;

    port power : ElectricalPowerPort;
    port commandFromSurface : CommandPort;
    port telemetryToSurface : TelemetryPort;
    port videoToSurface : VideoPort;
    port propulsionCommand : CommandPort;
    port navigationTelemetry : TelemetryPort;
    port sensorCommand : CommandPort;
    port manipulatorCommand : CommandPort;
  }

  part def RemotelyOperatedUnderwaterVehicle {
    attribute ratedDepth : Depth = 300 [SI::metre];
    attribute enduranceHours : Real = 12.0;
    attribute currentMode : MissionMode = MissionMode::idle;
    attribute health : HealthState = HealthState::nominal;

    port tetherPower : ElectricalPowerPort;
    port tetherCommand : CommandPort;
    port tetherTelemetry : TelemetryPort;
    port tetherVideo : VideoPort;

    part hull : PressureHull;
    part propulsion : PropulsionModule;
    part navigation : NavigationModule;
    part sensors : SensorPayload;
    part manipulator : ManipulatorArm;
    part computer : VehicleComputer;

    connect tetherPower to computer.power;
    connect computer.propulsionCommand to propulsion.command;
    connect computer.sensorCommand to sensors.command;
    connect computer.manipulatorCommand to manipulator.command;
    connect navigation.telemetry to computer.navigationTelemetry;
    connect tetherCommand to computer.commandFromSurface;
    connect computer.telemetryToSurface to tetherTelemetry;
    connect computer.videoToSurface to tetherVideo;
  }

  part def ROVMissionSystem {
    attribute primaryFunction : String = "Provide remotely controlled underwater inspection, observation, data collection, and light intervention while keeping human operators at the surface.";

    part station : SurfaceControlStation;
    part tether : UmbilicalTether;
    part rov : RemotelyOperatedUnderwaterVehicle;

    connect station.powerFeed to tether.surfacePower;
    connect tether.vehiclePower to rov.tetherPower;

    connect station.commandLink to tether.surfaceCommand;
    connect tether.vehicleCommand to rov.tetherCommand;

    connect rov.tetherTelemetry to tether.vehicleTelemetry;
    connect tether.surfaceTelemetry to station.telemetryLink;

    connect rov.tetherVideo to tether.vehicleVideo;
    connect tether.surfaceVideo to station.videoLink;
  }

  action def ExecuteInspectionMission {
    in item operatorCommand : CommandPacket;
    out item missionTelemetry : TelemetryPacket;
    out item visualRecord : VideoStream;

    first start;
    then performPreDiveCheck;
    then launchVehicle;
    then descendToTargetDepth;
    then stabilizeNearWorksite;
    then captureVideoAndSonar;
    then performOptionalManipulation;
    then returnToLaunchPoint;
    then recoverVehicle;
    then finish;

    action performPreDiveCheck;
    action launchVehicle;
    action descendToTargetDepth;
    action stabilizeNearWorksite;
    action captureVideoAndSonar;
    action performOptionalManipulation;
    action returnToLaunchPoint;
    action recoverVehicle;
  }

  state def VehicleOperationalStateMachine {
    entry action initializeVehicle;

    state idle;
    state preDiveCheck;
    state launched;
    state transiting;
    state inspecting;
    state manipulating;
    state returning;
    state recovered;
    state emergencyReturn;
    state safeShutdown;

    transition idle_to_preDiveCheck
      first idle
      accept CommandPacket
      if commandedMode == MissionMode::preDiveCheck
      then preDiveCheck;

    transition preDiveCheck_to_launched
      first preDiveCheck
      if health == HealthState::nominal
      then launched;

    transition launched_to_transiting
      first launched
      accept CommandPacket
      if commandedMode == MissionMode::transit
      then transiting;

    transition transiting_to_inspecting
      first transiting
      accept CommandPacket
      if commandedMode == MissionMode::inspect
      then inspecting;

    transition inspecting_to_manipulating
      first inspecting
      accept CommandPacket
      if commandedMode == MissionMode::manipulate
      then manipulating;

    transition manipulating_to_inspecting
      first manipulating
      accept CommandPacket
      if commandedMode == MissionMode::inspect
      then inspecting;

    transition inspecting_to_returning
      first inspecting
      accept CommandPacket
      if commandedMode == MissionMode::recover
      then returning;

    transition returning_to_recovered
      first returning
      then recovered;

    transition any_to_emergencyReturn
      first idle
      if health == HealthState::critical
      then emergencyReturn;

    transition emergencyReturn_to_safeShutdown
      first emergencyReturn
      then safeShutdown;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : ROVMissionSystem;

    doc /* The system shall allow surface operators to remotely control an underwater vehicle through a tether to inspect underwater structures, collect visual and sonar data, transmit telemetry, and perform light manipulation without placing humans underwater. */

    require constraint {
      system.rov.ratedDepth >= 300 [SI::metre]
    }
  }

  requirement def TetheredOperationRequirement {
    subject system : ROVMissionSystem;

    doc /* The underwater vehicle shall receive power and command data from the surface control station through the tether and shall return telemetry and video through the tether. */

    require constraint {
      system.tether.maxPowerTransfer >= 12000 [SI::watt]
    }
  }

  requirement def InspectionCapabilityRequirement {
    subject vehicle : RemotelyOperatedUnderwaterVehicle;

    doc /* The vehicle shall provide continuous visual observation, sonar imaging, depth measurement, heading measurement, and operator-commanded station keeping during underwater inspection. */

    require constraint {
      vehicle.sensors.cameraCount >= 3 and
      vehicle.navigation.depthAccuracy <= 0.05 [SI::metre]
    }
  }

  requirement def MobilityRequirement {
    subject vehicle : RemotelyOperatedUnderwaterVehicle;

    doc /* The vehicle shall maneuver in surge, sway, heave, and yaw to maintain position near underwater assets while compensating for current. */

    require constraint {
      vehicle.propulsion.thrusterCount >= 6 and
      vehicle.propulsion.maximumForwardSpeed >= 1.5 [SI::metrePerSecond]
    }
  }

  requirement def ManipulationRequirement {
    subject vehicle : RemotelyOperatedUnderwaterVehicle;

    doc /* The vehicle shall support light underwater intervention using a manipulator arm capable of grasping tools, samples, or inspection targets. */

    require constraint {
      vehicle.manipulator.maximumGripForce >= 450 [SI::newton]
    }
  }

  requirement def SafetyRequirement {
    subject vehicle : RemotelyOperatedUnderwaterVehicle;

    doc /* The vehicle shall enter emergency return mode upon critical health, leak detection, or loss of stable navigation. */

    require constraint {
      vehicle.health != HealthState::critical
    }
  }

  satisfy PrimaryFunctionRequirement by ROVMissionSystem;
  satisfy TetheredOperationRequirement by ROVMissionSystem::tether;
  satisfy InspectionCapabilityRequirement by RemotelyOperatedUnderwaterVehicle::sensors;
  satisfy MobilityRequirement by RemotelyOperatedUnderwaterVehicle::propulsion;
  satisfy ManipulationRequirement by RemotelyOperatedUnderwaterVehicle::manipulator;
  satisfy SafetyRequirement by VehicleOperationalStateMachine;

}