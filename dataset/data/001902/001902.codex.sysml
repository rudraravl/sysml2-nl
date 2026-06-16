package ValkyrieGuardianRescueSystem {

  import ScalarValues::*;
  import ISQ::*;

  value def Percent {
    unit = "%";
  }

  value def Meter {
    unit = "m";
  }

  value def MeterPerSecond {
    unit = "m/s";
  }

  value def Kilogram {
    unit = "kg";
  }

  value def Second {
    unit = "s";
  }

  value def WattHour {
    unit = "Wh";
  }

  value def Celsius {
    unit = "degC";
  }

  value def Newton {
    unit = "N";
  }

  value def Lux {
    unit = "lx";
  }

  item def HumanSurvivor {
    attribute bodyMass : Kilogram;
    attribute conscious : Boolean;
    attribute triageScore : Integer;
    attribute coreTemperature : Celsius;
    attribute mobilityLimited : Boolean;
  }

  item def RescueBeacon {
    attribute latitude : Real;
    attribute longitude : Real;
    attribute altitude : Meter;
    attribute urgency : Integer;
  }

  item def TerrainMap {
    attribute resolution : Meter;
    attribute hazardProbability : Percent;
    attribute safeLandingZones : Integer;
  }

  item def MedicalStatus {
    attribute oxygenSaturation : Percent;
    attribute pulseRate : Integer;
    attribute skinTemperature : Celsius;
    attribute hemorrhageDetected : Boolean;
  }

  item def CommandMessage {
    attribute missionId : String;
    attribute priority : Integer;
    attribute encrypted : Boolean;
  }

  item def ElectricalEnergy {
    attribute storedEnergy : WattHour;
    attribute stateOfCharge : Percent;
  }

  item def LiftThrust {
    attribute magnitude : Newton;
    attribute vectorAzimuth : Real;
    attribute vectorElevation : Real;
  }

  item def StabilizationForce {
    attribute magnitude : Newton;
  }

  item def Illumination {
    attribute intensity : Lux;
  }

  port def PowerPort {
    in item electricalEnergy : ElectricalEnergy;
  }

  port def CommandPort {
    in item command : CommandMessage;
    out item missionStatus : CommandMessage;
  }

  port def SensorPort {
    out item terrainMap : TerrainMap;
    out item beacon : RescueBeacon;
    out item medicalStatus : MedicalStatus;
  }

  port def LiftPort {
    out item thrust : LiftThrust;
  }

  port def ManipulatorPort {
    in item survivor : HumanSurvivor;
    out item stabilizationForce : StabilizationForce;
  }

  port def IlluminationPort {
    out item illumination : Illumination;
  }

  part def ValkyrieGuardian {
    attribute primaryFunction : String = "Autonomously locate, assess, stabilize, and evacuate vulnerable humans from hazardous areas while preserving responder and survivor safety.";
    attribute maximumPayload : Kilogram = 140;
    attribute cruiseSpeed : MeterPerSecond = 28;
    attribute hoverEndurance : Second = 1800;
    attribute operatingCeiling : Meter = 3000;
    attribute minimumSafeCharge : Percent = 20;

    port powerIn : PowerPort;
    port commandLink : CommandPort;
    port sensing : SensorPort;
    port liftOutput : LiftPort;
    port rescueGrip : ManipulatorPort;
    port haloLight : IlluminationPort;

    part perceptionSuite : PerceptionSuite;
    part wingPropulsion : WingPropulsionSystem;
    part rescueHarness : RescueHarness;
    part medicalTriageUnit : MedicalTriageUnit;
    part missionComputer : MissionComputer;
    part energyCore : EnergyCore;
    part communicationsArray : CommunicationsArray;
    part guardianFrame : GuardianFrame;
    part haloIlluminator : HaloIlluminator;

    connect energyCore.powerOut to powerIn;
    connect communicationsArray.commandPort to commandLink;
    connect perceptionSuite.sensorOut to sensing;
    connect medicalTriageUnit.statusOut to sensing;
    connect wingPropulsion.liftPort to liftOutput;
    connect rescueHarness.manipulatorPort to rescueGrip;
    connect haloIlluminator.lightPort to haloLight;

    connect energyCore.powerOut to wingPropulsion.powerIn;
    connect energyCore.powerOut to missionComputer.powerIn;
    connect energyCore.powerOut to perceptionSuite.powerIn;
    connect energyCore.powerOut to medicalTriageUnit.powerIn;
    connect energyCore.powerOut to communicationsArray.powerIn;
    connect energyCore.powerOut to haloIlluminator.powerIn;

    connect perceptionSuite.sensorOut to missionComputer.sensorIn;
    connect communicationsArray.commandPort to missionComputer.commandIn;
    connect missionComputer.flightCommandOut to wingPropulsion.commandIn;
    connect missionComputer.rescueCommandOut to rescueHarness.commandIn;
    connect missionComputer.triageCommandOut to medicalTriageUnit.commandIn;
  }

  part def PerceptionSuite {
    attribute thermalRange : Meter = 1200;
    attribute lidarRange : Meter = 800;
    attribute acousticDetectionRange : Meter = 300;

    port powerIn : PowerPort;
    port sensorOut : SensorPort;

    part thermalImager : ThermalImager;
    part lidarMapper : LidarMapper;
    part acousticLocator : AcousticLocator;
  }

  part def ThermalImager {
    attribute minimumDetectableTemperatureDelta : Celsius = 1.5;
    port powerIn : PowerPort;
    port sensorOut : SensorPort;
  }

  part def LidarMapper {
    attribute scanRate : Integer = 20;
    attribute mapResolution : Meter = 0.15;
    port powerIn : PowerPort;
    port sensorOut : SensorPort;
  }

  part def AcousticLocator {
    attribute voiceDetectionConfidence : Percent = 92;
    port powerIn : PowerPort;
    port sensorOut : SensorPort;
  }

  part def WingPropulsionSystem {
    attribute maximumThrust : Newton = 5200;
    attribute rotorCount : Integer = 8;
    attribute wingSpan : Meter = 6.4;

    port powerIn : PowerPort;
    port commandIn : CommandPort;
    port liftPort : LiftPort;
  }

  part def RescueHarness {
    attribute restraintCapacity : Kilogram = 160;
    attribute stabilizationResponseTime : Second = 0.4;

    port commandIn : CommandPort;
    port manipulatorPort : ManipulatorPort;

    part adaptiveGrip : AdaptiveGrip;
    part spinalSupportSling : SpinalSupportSling;
  }

  part def AdaptiveGrip {
    attribute maximumGripForce : Newton = 450;
    attribute forceLimitForHumanContact : Newton = 120;
    port manipulatorPort : ManipulatorPort;
  }

  part def SpinalSupportSling {
    attribute deploymentTime : Second = 3;
    attribute supportedMass : Kilogram = 160;
    port manipulatorPort : ManipulatorPort;
  }

  part def MedicalTriageUnit {
    attribute scanDuration : Second = 8;
    attribute minimumOxygenThreshold : Percent = 88;

    port powerIn : PowerPort;
    port commandIn : CommandPort;
    port statusOut : SensorPort;
  }

  part def MissionComputer {
    attribute autonomyLevel : Integer = 4;
    attribute hazardAvoidanceConfidence : Percent = 98;
    attribute decisionCycleTime : Second = 0.05;

    port powerIn : PowerPort;
    port sensorIn : SensorPort;
    port commandIn : CommandPort;
    port flightCommandOut : CommandPort;
    port rescueCommandOut : CommandPort;
    port triageCommandOut : CommandPort;

    behavior missionBehavior : ValkyrieMissionStateMachine;
  }

  part def EnergyCore {
    attribute capacity : WattHour = 18000;
    attribute reserveEnergy : WattHour = 3600;
    attribute nominalVoltage : Real = 800;

    port powerOut : PowerPort;
  }

  part def CommunicationsArray {
    attribute lineOfSightRange : Meter = 20000;
    attribute encrypted : Boolean = true;

    port powerIn : PowerPort;
    port commandPort : CommandPort;
  }

  part def GuardianFrame {
    attribute emptyMass : Kilogram = 210;
    attribute crashLoadRating : Newton = 18000;
    attribute heatShieldLimit : Celsius = 650;
  }

  part def HaloIlluminator {
    attribute searchIntensity : Lux = 18000;
    attribute medicalModeIntensity : Lux = 900;

    port powerIn : PowerPort;
    port lightPort : IlluminationPort;
  }

  action def ExecuteRescueMission {
    in item distressBeacon : RescueBeacon;
    in item initialCommand : CommandMessage;
    out item rescuedSurvivor : HumanSurvivor;
    out item finalStatus : CommandMessage;

    action receiveMission;
    action launchAndNavigate;
    action searchHazardArea;
    action classifySurvivor;
    action stabilizeSurvivor;
    action evacuateToSafeZone;
    action reportCompletion;

    first receiveMission;
    then launchAndNavigate;
    then searchHazardArea;
    then classifySurvivor;
    then stabilizeSurvivor;
    then evacuateToSafeZone;
    then reportCompletion;
  }

  action def SearchHazardArea {
    in item beacon : RescueBeacon;
    out item terrainMap : TerrainMap;
    out item detectedSurvivor : HumanSurvivor;

    action illuminateArea;
    action scanThermalSignatures;
    action mapObstacles;
    action localizeVoiceOrBeacon;

    first illuminateArea;
    then scanThermalSignatures;
    then mapObstacles;
    then localizeVoiceOrBeacon;
  }

  action def StabilizeAndLiftSurvivor {
    in item survivor : HumanSurvivor;
    out item stabilizedSurvivor : HumanSurvivor;

    action assessMedicalStatus;
    action deploySupportSling;
    action applyAdaptiveGrip;
    action confirmAirwayAndTemperature;
    action liftVertically;

    first assessMedicalStatus;
    then deploySupportSling;
    then applyAdaptiveGrip;
    then confirmAirwayAndTemperature;
    then liftVertically;
  }

  state def ValkyrieMissionStateMachine {
    state Standby;
    state Launch;
    state Transit;
    state Search;
    state Triage;
    state Stabilize;
    state Evacuate;
    state ReturnToBase;
    state Recharge;
    state FaultSafeLanding;

    transition initial then Standby;
    transition Standby to Launch accept CommandMessage;
    transition Launch to Transit;
    transition Transit to Search;
    transition Search to Triage;
    transition Triage to Stabilize;
    transition Stabilize to Evacuate;
    transition Evacuate to ReturnToBase;
    transition ReturnToBase to Recharge;
    transition Recharge to Standby;
    transition Search to FaultSafeLanding if missionComputer.hazardAvoidanceConfidence < 75;
    transition Transit to ReturnToBase if energyCore.capacity < 3600;
    transition Evacuate to FaultSafeLanding if rescuedSurvivor.bodyMass > 140;
  }

  requirement def PrimaryFunctionRequirement {
    subject valkyrie : ValkyrieGuardian;
    doc "The Valkyrie Guardian shall provide autonomous aerial rescue by finding survivors in dangerous terrain, assessing their condition, stabilizing them, and transporting them to a safe recovery location.";
  }

  requirement def SurvivorDetectionRequirement {
    subject perception : PerceptionSuite;
    require constraint {
      perception.thermalRange >= 1000 and perception.lidarRange >= 500
    }
  }

  requirement def PayloadRequirement {
    subject valkyrie : ValkyrieGuardian;
    require constraint {
      valkyrie.maximumPayload >= 120
    }
  }

  requirement def EnduranceRequirement {
    subject valkyrie : ValkyrieGuardian;
    require constraint {
      valkyrie.hoverEndurance >= 1500
    }
  }

  requirement def HumanContactForceRequirement {
    subject harness : RescueHarness;
    require constraint {
      harness.adaptiveGrip.forceLimitForHumanContact <= 120
    }
  }

  requirement def EnergyReserveRequirement {
    subject core : EnergyCore;
    require constraint {
      core.reserveEnergy >= core.capacity * 0.20
    }
  }

  requirement def IlluminationRequirement {
    subject halo : HaloIlluminator;
    require constraint {
      halo.searchIntensity >= 10000 and halo.medicalModeIntensity <= 1200
    }
  }

  requirement def CommunicationSecurityRequirement {
    subject comms : CommunicationsArray;
    require constraint {
      comms.encrypted == true
    }
  }

  requirement def SafeReturnRequirement {
    subject valkyrie : ValkyrieGuardian;
    require constraint {
      valkyrie.minimumSafeCharge >= 20
    }
  }

  part valkyrieGuardianSystem : ValkyrieGuardian;

  satisfy PrimaryFunctionRequirement by valkyrieGuardianSystem;
  satisfy SurvivorDetectionRequirement by valkyrieGuardianSystem.perceptionSuite;
  satisfy PayloadRequirement by valkyrieGuardianSystem;
  satisfy EnduranceRequirement by valkyrieGuardianSystem;
  satisfy HumanContactForceRequirement by valkyrieGuardianSystem.rescueHarness;
  satisfy EnergyReserveRequirement by valkyrieGuardianSystem.energyCore;
  satisfy IlluminationRequirement by valkyrieGuardianSystem.haloIlluminator;
  satisfy CommunicationSecurityRequirement by valkyrieGuardianSystem.communicationsArray;
  satisfy SafeReturnRequirement by valkyrieGuardianSystem;

}